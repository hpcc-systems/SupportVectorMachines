IMPORT SupportVectorMachines as SV;
IMPORT SV.Types as Types;
IMPORT SV.LibSVM.Types AS LibSVM_Types;
IMPORT PBblas;
IMPORT ML_Core;
IMPORT ML_Core.Types as ML_Types;
IMPORT ML_Core.Interfaces;

NumericField := ML_Types.NumericField;
DiscreteField := ML_Types.DiscreteField;
Layout_Model := ML_Types.Layout_Model;

/**
 * Support vector machine classification.
 * @param svmType The SVC type, which may be one of 0 (C_SVC, default),
 * 1 (NU_SVC), or 2 (ONE_CLASS).
 * @param kernelType The kernel used in training and predicting, which may be one of
 * 0 (LINEAR), 1 (POLY), 2 (RBF, default), 3 (SIGMOID), or 4 (PRECOMPUTED).
 * @param gamma Parameter needed for all kernels except LINEAR (default: 0.05).
 * @param C Cost of constraint violation (default: 1).
 * @param degree Parameter needed for kernel of type POLY (default: 3).
 * @param coef0 Parameter needed for kernels of type POLY and SIGMOID (default: 0).
 * @param eps Tolerance of termination criterion (default: 0.001).
 * @param nu Parameter needed for NU_SVC and ONE_CLASS (default: 0.5).
 * @param p Epsilon in the insensitive-loss function (default: 0.1).
 * @param shrinking Flag indicating the use of shrinking-heuristics (default: true).
 * @param prob_est Whether to train for probability estimates (default true).
 * @param scale Whether to standardize the data (subtract mean, divide by sd) before fitting.
 * @param nr_weight The number of elements in the 'lbl' parameter (default: 0).
 * @param lbl Labels to indicate classes, used with the 'weight' parameter (default: []).
 * @param weight Class weights, assigned to classes using the 'lbl' parameter (default: []).
 */
EXPORT SVC(
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
MODULE(Interfaces.IClassify)
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
    SELF.nr_weight  := nr_weight;
    SELF.lbl        := lbl;
    SELF.weight     := weight;
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
   * Calculate a model to fit the observation data to the observed classes.
   * For a single given set of model parameters, models can be fit to a number of datasets
   * by concatenating multiple datasets into single 'observations' and 'classifications'
   * datasets, with separate datasets being identified by a work ID column, 'wi'.
   * @param observations The observed explanatory values.
   * @param classifications The observed classification used to build the model.
   * @return The encoded models.
   */
  EXPORT DATASET(Layout_Model) GetModel(
    DATASET(NumericField) observations,
    DATASET(DiscreteField) classifications) :=
  FUNCTION
    actuals := PROJECT(classifications, NumericField);

    params := DATASET(callMakeParam(-1, C, gamma));

    mdl := SV.Train(params, observations, actuals);
    mdl_LM := SV.Converted.FromModel(base, mdl);
    RETURN mdl_LM;
  END;

  /**
   * Classify the observations using models trained by the GetModel function.
   * @param model The models, which should be produced by a corresponding GetModel function.
   * @param new_observations Observations to be classified.
   * @return Classifications with a probability value.
   */
  EXPORT DATASET(ML_Types.Classify_Result) Classify(
    DATASET(Layout_Model) model,
    DATASET(NumericField) new_observations) :=
  FUNCTION
    mdl_SVM := SV.Converted.ToModel(model);

    rslt_pred_prob := SV.Predict(mdl_SVM, new_observations).Pred_Prob_Est;

    ML_Types.Classify_Result getClassifyRslt(SV.Types.SVM_Pred_Prob_Est L) :=
    TRANSFORM
        SELF.wi := L.wi;
        SELF.id := L.rid;
        SELF.number := 1;
        SELF.value := L.Predict_y;
        SELF.Conf := IF(prob_est, L.prob_estimates[1].v, -1);
    END;
    rslt := PROJECT(rslt_pred_prob, getClassifyRslt(LEFT));

    RETURN rslt;
  END;

  /**
   * Report the confusion matrix for the classifier and training data.
   * @param model The models, which should be produced by a corresponding GetModel function.
   * @param observations The explanatory values.
   * @param classifications The classifications associated with the observations.
   * @return The confusion matrix showing correct and incorrect results.
   */
  EXPORT DATASET(ML_Types.Confusion_Detail) Report(
    DATASET(Layout_Model) model,
    DATASET(NumericField) observations,
    DATASET(DiscreteField) classifications) :=
    SV.Confusion(
      classifications,
      PROJECT(Classify(model, observations),
        DiscreteField)
    );

  /**
   * Perform grid search over parameters gamma and C. The grid resolution is increased
   * automatically to utilize any otherwise idle nodes.
   * For a single given set of model parameters, models can be tuned to a number of datasets
   * by concatenating multiple datasets into single 'observations' and 'classifications'
   * datasets, with separate datasets being identified by a work ID column, 'wi'.
   * @param folds The number of cross-validation folds for evaluating each candidate model.
   * @param start_log2C The lower bound for log2(C): C >= 2^(start_log2C).
   * @param stop_log2C The upper bound for log2(C): C <= 2^(start_log2C).
   * @param maxIncr_log2C Taximum allowable exponential increment for C.
   * @param start_log2gamma The lower bound for log2(gamma): gamma >= 2^(start_log2gamma).
   * @param stop_log2gamma The upper bound for log2(gamma): gamma <= 2^(start_log2gamma).
   * @param maxIncr_log2gamma Taximum allowable exponential increment for gamma.
   * @param observations The observed explanatory values.
   * @param classifications The observed classification used to build the model.
   * @return Dataset with sets of model parameters and corresponding cross-validated scores.
   */
  EXPORT DATASET(Types.GridSearch_Result) Tune(
    INTEGER4 folds          = 10,
    REAL8 start_log2C       = -5,
    REAL8 stop_log2C        = 15,
    REAL8 maxIncr_log2C     = 2,
    REAL8 start_log2gamma   = -15,
    REAL8 stop_log2gamma    = 3,
    REAL8 maxIncr_log2gamma = 2,
    DATASET(NumericField) observations,
    DATASET(DiscreteField) classifications) :=
  FUNCTION
    Types.SVM_Grid_Plan makePlan() :=
    TRANSFORM
      SELF.Folds      := folds;
      SELF.log2_C     := ROW({start_log2C, stop_log2C, maxIncr_log2C}, Types.SVM_Grid_Args);
      SELF.log2_gamma := ROW({start_log2gamma, stop_log2gamma, maxIncr_log2gamma}, Types.SVM_Grid_Args);
    END;
    plan := ROW(makePlan());

    actuals := PROJECT(classifications, NumericField);

    gridSearch_rslt := SV.GridSearch(plan, paramBase, observations, actuals);
    RETURN gridSearch_rslt;
  END;

  /**
   * Using the output of Tune(), find the best set of modeling parameters for each work id,
   * and train the corresponding models.
   * @param tuneResult The results of a grid search over C and gamma, produced by Tune().
   * @param observations The observed explanatory values.
   * @param classifications The observed classification used to build the model.
   * @return The encoded models.
   */
  EXPORT DATASET(Layout_Model) GetTunedModel(
    DATASET(Types.GridSearch_Result) tuneResult,
    DATASET(NumericField) observations,
    DATASET(DiscreteField) classifications) :=
  FUNCTION
    tuneResult_grp := GROUP(SORT(tuneResult, wi), wi);

    Types.Training_Parameters getBestParams(
      Types.GridSearch_Result firstRow,
      DATASET(Types.GridSearch_Result) grp) :=
    TRANSFORM
      grpBest := grp(correct = MAX(grp, correct));
      SELF.C := grpBest[1].C;
      SELF.gamma := grpBest[1].gamma;
      SELF.id := grpBest[1].id;
      SELF := firstRow;
    END;

    bestParams := ROLLUP(tuneResult_grp, GROUP, getBestParams(LEFT, ROWS(LEFT)));

    actuals := PROJECT(classifications, NumericField);

    mdl := SV.Train(bestParams, observations, actuals);
    mdl_LM := SV.Converted.FromModel(base, mdl);
    RETURN mdl_LM;
  END;


  /**
   * Perform n-fold cross-validation of a given model for each work ID.
   * For a single given set of model parameters, models can be cross-validated against
   * a number of datasets by concatenating multiple datasets into single 'observations'
   * and 'classifications' datasets, with separate datasets being identified by a work
   * ID column, 'wi'.
   * @param folds The number of cross-validation folds.
   * @param observations The observed explanatory values.
   * @param classifications The observed classification used to build.
   * @return Dataset of cross-validated scores.
   */
  EXPORT DATASET(Types.CrossValidate_Result) CrossValidate(
    INTEGER4 folds = 10,
    DATASET(NumericField) observations,
    DATASET(DiscreteField) classifications) :=
  FUNCTION
    actuals := PROJECT(classifications, NumericField);

    params := DATASET(callMakeParam(-1, C, gamma));

    cv_result := SV.CrossValidate(params, observations, actuals, folds);
    RETURN cv_result;
  END;

  /**
   * Generate human-readable model summary of trained SVM model(s).
   * Multiple models can be simultaneously summarized by concatenating a number of models
   * into a single 'model' object, with separate models being identified by a work ID
   * column, 'wi'.
   * @param model The models, which should be produced by a corresponding GetModel function.
   * @return Single-column dataset with textual description of models.
   */
  EXPORT DATASET({UNSIGNED4 r, STRING60 Txt}) ModelSummary(
    DATASET(Layout_Model) model) := SV.ModelSummary(model);

END;