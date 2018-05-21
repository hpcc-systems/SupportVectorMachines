IMPORT $ as SV;
IMPORT SV.Types as Types;
IMPORT SV.LibSVM.Types AS LibSVM_Types;
IMPORT PBblas;
IMPORT ML_Core;
IMPORT ML_Core.Types as ML_Types;
IMPORT ML_Core.Interfaces;

NumericField := ML_Types.NumericField;
Layout_Model := ML_Types.Layout_Model;

/**
  * Support Vector Machine Regression.
  *
  * <p>Utilizes the open-source libSVM under the hood.
  * <p>This module is appropriate for small to medium sized Machine Learning
  * problems or multitudes of small-to-medium problems using the Myriad interface.
  * <p>This is due to both scaling limitations endemic to SVM, as well as the fact
  * that libSVM runs independently on each node, and cannot, therefore scale to very
  * large single problems.
  * <p>Other techniques should be employed for Machine Learning with more than 10,000
  * data points.
  * <p>This module also provides a mechanism for doing a grid search for regularization
  * parameters using the full resources of the HPCC cluster rather than searching
  * sequentially (see GridSearch.ecl).
  *
  * @param X The observed explanatory values in NumericField format.
  * @param Y The observed values the model aims to fit in NumericField format.
  * @param svmType The SVR type, which may be one of 3 (EPSILON_SVR, default),
  *                or 4 (NU_SVR).
  * @param kernelType The kernel used in training and predicting, which may be one of
  *                 0 (LINEAR), 1 (POLY), 2 (RBF, default), 3 (SIGMOID), or 4 (PRECOMPUTED).
  * @param gamma regularization parameter needed for all kernels except LINEAR (default: 0.05).
  * @param C Cost of constraint violation regularization parameter(default: 1).
  * @param degree Parameter needed for kernel of type POLY (default: 3).
  * @param coef0 Parameter needed for kernels of type POLY and SIGMOID (default: 0).
  * @param eps Tolerance of termination criterion (default: 0.001).
  * @param nu Parameter needed for NU_SVC and ONE_CLASS (default: 0.5).
  * @param p Epsilon in the insensitive-loss function (default: 0.1).
  * @param shrinking Flag indicating the use of shrinking-heuristics (default: true).
  * @param prob_est Whether to train for probability estimates (default true).
  * @param scale Whether to standardize the data (subtract mean, divide by sd) before fitting.
  * @see ML_Core.Types.NumericField
  */
EXPORT SVR(
  DATASET(NumericField) X       = DATASET([], NumericField),
  DATASET(NumericField) Y       = DATASET([], NumericField),
  Types.SVM_Type svmType        = LibSVM_Types.LibSVM_Type.C_SVC,
  Types.Kernel_Type kernelType  = LibSVM_Types.LibSVM_Kernel.RBF,
  REAL8 gamma                   = 0.05,
  REAL8 C                       = 1,
  INTEGER4 degree               = 3,
  REAL8 coef0                   = 0.0,
  REAL8 eps                     = 0.001,
  REAL8 nu                      = 0.5,
  REAL8 p                       = 0.1,
  BOOLEAN shrinking             = true,
  BOOLEAN prob_est              = true,
  BOOLEAN scale                 = true,
  INTEGER4 nr_weight            = 0,
  DATASET(Types.I4Entry) lbl    = DATASET([], Types.I4Entry),
  DATASET(Types.R8Entry) weight = DATASET([], Types.R8Entry)) :=
                                      MODULE(Interfaces.IRegression())
  Types.Training_Base makeBase() :=
  TRANSFORM
    SELF.svmType    := svmType;
    SELF.kernelType := kernelType;
    SELF.degree     := degree;
    SELF.coef0      := coef0;
    SELF.nu         := nu;
    SELF.eps        := eps;
    SELF.p          := p;
    SELF.shrinking  := shrinking;
    SELF.prob_est   := prob_est;
    SELF.scale      := scale;
    SELF.nr_weight  := 0;
    SELF.lbl        := DATASET([], Types.I4Entry);
    SELF.weight     := DATASET([], Types.R8Entry);
  END;
  SHARED paramBase := ROW(makeBase());

  SHARED base := 1000;

  Types.Training_Parameters makeParam(INTEGER4 mid, REAL8 C, REAL8 gamma) :=
  TRANSFORM
    SELF.id := mid;
    SELF.wi := 0;
    SELF.C := C;
    SELF.gamma := gamma;
    SELF := paramBase;
  END;
  SHARED callMakeParam(INTEGER8 mid, REAL8 C, REAL8 gamma) := ROW(makeParam(mid, C, gamma));

  /**
    * Train and return a model that fits the observation data to the observed values.
    * For a single given set of model parameters, models can be fit to a number of datasets
    * by concatenating multiple datasets into single 'X' and 'Y'
    * datasets, with separate datasets being identified by a work-item column, 'wi'.
    *
    * @return The encoded models in Layout_Model format.
    * @see ML_Core.Types.Layout_Model
    */
  EXPORT DATASET(Layout_Model) GetModel :=
  FUNCTION
    observations := X;
    actuals := Y;

    params := DATASET(callMakeParam(-1, C, gamma));

    mdl := SV.Train(params, observations, actuals);
    mdl_LM := SV.Converted.FromModel(base, mdl);
    RETURN mdl_LM;
  END;

  /**
    * Predict values for the new observations using models trained by the GetModel function.
    *
    * @param model The models, which should be produced by a corresponding GetModel function.
    * @param newX Observations to be classified in NumericField format.
    * @return Predictions in NumericField format.
    * @see ML_Core.Types.NumericField
    */
  EXPORT DATASET(NumericField) Predict(
    DATASET(NumericField) newX,
    DATASET(Layout_Model) model) :=
  FUNCTION
    new_observations := newX;
    mdl_SVM := SV.Converted.ToModel(model);

    rslt_pred_values := SV.Predict(mdl_SVM, new_observations).Pred_Values;

    NumericField getPredictRslt(SV.Types.SVM_Pred_Values L) :=
    TRANSFORM
        SELF.wi := L.wi;
        SELF.id := L.rid;
        SELF.number := 1;
        SELF.value := L.Predict_y;
    END;
    rslt := PROJECT(rslt_pred_values, getPredictRslt(LEFT));

    RETURN rslt;
  END;

  /**
    * Perform a regularization tuning in order to align the granularity of the algorithm
    * with the complexity of the data.  This is to avoid under or over fitting of the data.
    * <p>Finds a reasonable setting for the regularization parameters gamma and C by
    * performing a grid search over them and testing each using cross-validation.  The
    * parameters that provide the lowest out-of-sample error (i.e. when tested on data
    * not in the training set) are the ones chosen.
    * <p>Returns a set of training parameter combinations and their results that can then
    * be passed to GetTunedModel below
    * to acquire a model that has been properly regularized.
    * <p>The grid resolution is increased
    * automatically to utilize any otherwise idle nodes.
    * <p>For a single given set of model parameters, models can be tuned to a number of datasets
    * by concatenating multiple datasets into single 'observations' and 'classifications'
    * datasets, with separate datasets being identified by a work ID column, 'wi'.
    *
    * @param folds The number of cross-validation folds for evaluating each candidate model.
    * @param start_log2C The lower bound for log2(C): C >= 2^(start_log2C).
    * @param stop_log2C The upper bound for log2(C): C <= 2^(start_log2C).
    * @param maxIncr_log2C Taximum allowable exponential increment for C.
    * @param start_log2gamma The lower bound for log2(gamma): gamma >= 2^(start_log2gamma).
    * @param stop_log2gamma The upper bound for log2(gamma): gamma <= 2^(start_log2gamma).
    * @param maxIncr_log2gamma Taximum allowable exponential increment for gamma.
    * @return Dataset with sets of model parameters and corresponding cross-validated scores
    *         in GridSearch_Result format.
    * @see GetTunedModel
    * @see Types.GridSearch_Result
    */
  EXPORT DATASET(Types.GridSearch_Result) Tune(
    INTEGER4 folds          = 10,
    REAL8 start_log2C       = -5,
    REAL8 stop_log2C        = 15,
    REAL8 maxIncr_log2C     = 2,
    REAL8 start_log2gamma   = -15,
    REAL8 stop_log2gamma    = 3,
    REAL8 maxIncr_log2gamma = 2) :=
  FUNCTION
    observations := X;
    actuals := Y;

    Types.SVM_Grid_Plan makePlan() :=
    TRANSFORM
      SELF.Folds      := folds;
      SELF.log2_C     := ROW({start_log2C, stop_log2C, maxIncr_log2C}, Types.SVM_Grid_Args);
      SELF.log2_gamma := ROW({start_log2gamma, stop_log2gamma, maxIncr_log2gamma}, Types.SVM_Grid_Args);
    END;
    plan := ROW(makePlan());

    gridSearch_rslt := SV.GridSearch(plan, paramBase, observations, actuals);
    RETURN gridSearch_rslt;
  END;

  /**
   * Choose the best set of regularization parameters and use it to train the models.
   * Using the output of Tune(), find the best set of modeling parameters for each work id,
   * and train the corresponding models.  The the most regularized (i.e. coarsest)
   * set of parameters that achieved near-maximum performance is used to create the models.
   *
   * @param tuneResult The results of a grid search over C and gamma, produced by Tune().
   * @return The encoded models.
   */
  EXPORT DATASET(Layout_Model) GetTunedModel(
    DATASET(Types.GridSearch_Result) tuneResult) :=
                                              FUNCTION
    observations := X;
    actuals := Y;

    tuneResult_grp := GROUP(SORT(tuneResult, wi), wi);

    Types.Training_Parameters getBestParams(
      Types.GridSearch_Result firstRow,
      DATASET(Types.GridSearch_Result) grp) :=
    TRANSFORM
      grpBest := grp(mse = MAX(grp, mse));
      SELF.C := grpBest[1].C;
      SELF.gamma := grpBest[1].gamma;
      SELF.id := grpBest[1].id;
      SELF := firstRow;
    END;

    bestParams := ROLLUP(tuneResult_grp, GROUP, getBestParams(LEFT, ROWS(LEFT)));

    mdl := SV.Train(bestParams, observations, actuals);
    mdl_LM := SV.Converted.FromModel(base, mdl);
    RETURN mdl_LM;
  END;


  /**
    * Perform n-fold cross-validation of a given model for each work ID.
    * For a single given set of model parameters, models can be cross-validated against
    * a number of datasets by concatenating multiple datasets into single 'X'
    * and 'Y' datasets, with separate datasets being identified by a work
    * ID column, 'wi'.
    *
    * @param folds The number of cross-validation folds.
    * @return Dataset of cross-validated scores i CrossValidate_Result format.
    * @see Types.CrossValidate_Result
    */
  EXPORT DATASET(Types.CrossValidate_Result) CrossValidate(
    INTEGER4 folds = 10) :=
  FUNCTION
    observations := X;
    actuals := Y;

    params := DATASET(callMakeParam(-1, C, gamma));

    cv_result := SV.CrossValidate(params, observations, actuals, folds);
    RETURN cv_result;
  END;

  /**
    * Generate human-readable model summary of trained SVM model(s).
    * <p>Multiple models can be simultaneously summarized by concatenating a number of models
    * into a single 'model' object, with separate models being identified by a work ID
    * column, 'wi'.
    *
    * @param model The models, which should be produced by a corresponding GetModel function.
    * @return Single-column dataset with textual description of models.
    */
  EXPORT DATASET({UNSIGNED4 r, STRING60 Txt}) ModelSummary(
    DATASET(Layout_Model) model) := SV.ModelSummary(model);

END;