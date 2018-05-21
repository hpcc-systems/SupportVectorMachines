IMPORT $.LibSVM.Types AS LibSVM_Types;

/**
 * SupportVectorMachines type definitions.
 */
EXPORT Types := MODULE
  /**
    * @internal
    */
  EXPORT Model_ID := INTEGER4;
  /**
    * @internal
    */
  EXPORT R8Entry := LibSVM_Types.R8Entry;
  /**
    * @internal
    */
  EXPORT I4Entry := LibSVM_Types.I4Entry;
  /**
    * @internal
    */
  EXPORT SVM_Type := LibSVM_Types.LibSVM_Type;
  /**
    * @internal
    */
  EXPORT Kernel_Type := LibSVM_Types.LibSVM_Kernel;

  /**
    * Feature value data structure for communication with libSVM
    *
    * @internal
    * @field nominal The feature identifier.
    * @field v The feature value.
    */
  EXPORT SVM_Feature := RECORD
    UNSIGNED4 nominal;
    REAL8 v;
  END;

  /**
    * Support Vector Machine Instance structure for communication with libSVM
    *
    * @internal
    * @field wi The work-item number.
    * @field rid The source identifier.
    * @field y The Y (dependent) value.
    * @field max_value Maximum value for feature Y.
    * @field x Independent data for this observation in SVM_Feature format.
    * @see SVM_Feature
    */
  EXPORT SVM_Instance := RECORD
    UNSIGNED2 wi;
    UNSIGNED8 rid;    // source identifier
    REAL8 y;          // label
    REAL8 max_value;  // max value of the feature
    DATASET(SVM_Feature) x;
  END;

  /**
    * Support Vector data structure for communication with libSVM
    *
    * @internal
    * @field v_ord Identifier for the vector
    * @field features Dataset of SVM_Feature records
    */
  EXPORT SVM_SV := RECORD
    UNSIGNED v_ord;
    DATASET(SVM_Feature) features;
  END;
  /**
    * Arguments for grid search.  This is a sub-format for SVM_Grid_Plan
    * below.
    *
    * @internal
    * @field start The value at which to start the search.
    * @field stop The value at which to stop the search.
    * @field max_incr The maximum increment to use in the search.
    * @see SVM_Grid_Plan
    */
  EXPORT SVM_Grid_Args := RECORD
    REAL8 start;
    REAL8 stop;
    REAL8 max_incr;
  END;

  /**
    * This record provides the format for the argument to GridSearch.
    *
    * @internal
    * @field log2_C Start, stop and increment values for the log base 2 of C, in SVM_Grid_Args
    *               format.
    * @field log2_gamma Start, stop and increment values for the log base 2 of
    *                   gamma, in SVM_Grid_Args format.
    * @see SVM_Grid_Args
    * @see GridSearch
    */
  EXPORT SVM_Grid_Plan := RECORD
    UNSIGNED4 Folds;
    SVM_Grid_Args log2_C;
    SVM_Grid_Args log2_gamma;
  END;
  SVM_Grid_Plan makePlan() := TRANSFORM
    SELF.Folds      := 10;
    SELF.log2_C     := ROW({-5, 15, 2}, SVM_Grid_Args);
    SELF.log2_gamma := ROW({-15, 3, 2}, SVM_Grid_Args);
  END;
  /**
    * Default Grid Plan
    *
    * @internal
    * @see SVM_Grid_Plan
    */
  EXPORT SVM_Grid_Plan_Default := ROW(makePlan());

  /**
    * Training Parameter Base Record
    *
    * @internal
    */
  EXPORT Training_Base := RECORD
    SVM_Type svmType;
    Kernel_Type kernelType;
    INTEGER4 degree;    // for Poly
    REAL8 coef0;        // for Poly, Sigmoid
    REAL8 eps;          // epsilon for stopping
    REAL8 nu;           // for NU_SVC, ONE_CLASS, and NU_SVR
    REAL8 p;            // loss epsilon for EPISILON_SVR
    INTEGER4 nr_weight; // number of weights for C_SVC
    BOOLEAN shrinking;  // shrinking heuristic if TRUE
    BOOLEAN prob_est;   // do probability estimates
    BOOLEAN scale;      // standardize feature data
    DATASET(I4Entry) lbl;// weight labels for C_SVC
    DATASET(R8Entry) weight;// for C_SVC
  END;
  Training_Base makeBase() := TRANSFORM
    SELF.svmType    := LibSVM_Types.LibSVM_Type.C_SVC;
    SELF.kernelType := LibSVM_Types.LibSVM_Kernel.RBF;
    SELF.degree     := 3;
    SELF.coef0      := 0.0;
    SELF.nu         := 0.5;
    SELF.eps        := 0.001;
    SELF.p          := 0.1;
    SELF.shrinking  := true;
    SELF.prob_est   := true;
    SELF.scale      := true;
    SELF.nr_weight  := 0;
    SELF.lbl        := DATASET([], I4Entry);
    SELF.weight     := DATASET([], R8Entry);
  END;
  /**
    * Default base training parameters
    *
    * @internal
    */
  EXPORT Training_Base_Default := ROW(makeBase());
  /**
    * @internal
    */
  EXPORT Training_Parameters := RECORD
    Model_ID id;
    UNSIGNED2 wi;
    Training_Base;
    REAL8 gamma;        // for Poly, RBF, Sigmoid
    REAL8 C;            // for C_SVC, EPSILON_SVR and nu_SVR
  END;
  Training_Parameters makeParams() := TRANSFORM
    SELF.id     := -1;
    SELF.wi     := 0;
    SELF.gamma  := 0.05;
    SELF.C      := 1;
    SELF        := Training_Base_Default;
  END;
  /**
    * Default Training Parameters
    *
    * @internal
    */
  EXPORT Training_Parameters_Default := ROW(makeParams());

  /**
    * Inforation about each feature
    *
    * @internal
    */
  EXPORT FeatureStats := RECORD
    INTEGER4 indx;
    REAL8 mean;
    REAL8 sd;
  END;
  /**
    * Record to libSVM form of the model
    *
    * @internal
    */
  EXPORT Model := RECORD
    UNSIGNED2 wi;
    Model_ID id;
    SVM_Type svmType;
    Kernel_Type kernelType;
    INTEGER4 degree;    // for Poly
    REAL8 gamma;        // for Poly, RBF, Sigmoid
    REAL8 coef0;        // for Poly, Sigmoid
    UNSIGNED4 k;  // number of classes
    UNSIGNED4 l;  // number of support vectors
    BOOLEAN scale;
    DATASET(FeatureStats) scaleInfo;
    DATASET(SVM_SV)  sv;
    DATASET(R8Entry) sv_coef;
    DATASET(R8Entry) rho;
    DATASET(R8Entry) probA;
    DATASET(R8Entry) probB;
    DATASET(I4Entry) labels;
    DATASET(I4Entry) nSV;
  END;
  /**
    * Record to hold the results of call to CrossValidate
    *
    * @field wi The work-item number.
    * @field id The id of the cross-validation set (i.e. fold).
    * @field correct The number of correct values.
    * @field mse The mean squared error of the regression
    * @field r_sq The R-squared value indicating the strength of
    *             the regression.
    */
  EXPORT CrossValidate_Result := RECORD
    UNSIGNED2 wi;
    Model_ID id;
    REAL8   correct;
    REAL8   mse;
    REAL8   r_sq;
  END;

  /**
    * Record for the results of call to GridSearch
    *
    * Contains both CrossValidate_Result and Training_Parameters.
    *
    * @field wi The work-item number.
    * @field id The id of the cross-validation set (i.e. fold).
    * @field correct The number of correct values.
    * @field mse The mean squared error of the regression
    * @field r_sq The R-squared value indicating the strength of
    *             the regression.
    * @field gamma The gamma regularization parameter value.
    * @field C The C regularization parameter value.
    */
  EXPORT GridSearch_Result := RECORD
    CrossValidate_Result OR Training_Parameters;
  END;

  /**
    * Record to hold scale information for each feature
    *
    * @internal
    */
  EXPORT Feature_Scale := RECORD
    UNSIGNED4 nominal;
    REAL8 min_value;
    REAL8 max_value;
  END;
  /**
    * @internal
    */
  EXPORT Class_Scale := RECORD
    REAL8 y_min;
    REAL8 y_max;
  END;
  /**
    * @internal
    */
  EXPORT Scale_Parms := RECORD
    REAL8 x_lower;
    REAL8 x_upper;
    REAL8 y_lower;
    REAL8 y_upper;
  END;
  /**
    * @internal
    */
  EXPORT SVM_Scale := RECORD
    Scale_Parms;
    Class_Scale;
    DATASET(Feature_Scale) features;
  END;

  /**
    * @internal
    */
  EXPORT SVM_Prediction := RECORD
    UNSIGNED2 wi;
    Model_ID id;
    UNSIGNED8 rid;    // source identifier
    REAL8 target_y;   // from input
    REAL8 predict_y;  // from SVM
  END;

  /**
    * @internal
    */
  EXPORT SVM_Pred_Values := RECORD(SVM_Prediction)
    DATASET(R8Entry) decision_values;
  END;
  /**
    * @internal
    */
  EXPORT SVM_Pred_Prob_Est := RECORD(SVM_Prediction)
    DATASET(R8Entry) prob_estimates;
  END;
END;
