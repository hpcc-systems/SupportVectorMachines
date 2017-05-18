IMPORT $.LibSVM.Types AS LibSVM_Types;

/**
 * SupportVectorMachines type definitions.
 */
EXPORT Types := MODULE
  EXPORT Model_ID := INTEGER4;
  EXPORT R8Entry := LibSVM_Types.R8Entry;
  EXPORT I4Entry := LibSVM_Types.I4Entry;
  EXPORT SVM_Type := LibSVM_Types.LibSVM_Type;
  EXPORT Kernel_Type := LibSVM_Types.LibSVM_Kernel;

  EXPORT SVM_Feature := RECORD
    UNSIGNED4 nominal;
    REAL8 v;
  END;

  EXPORT SVM_Instance := RECORD
    UNSIGNED2 wi;
    UNSIGNED8 rid;    // source identifier
    REAL8 y;          // label
    REAL8 max_value;  // max value of the feature
    DATASET(SVM_Feature) x;
  END;

  EXPORT SVM_SV := RECORD
    UNSIGNED v_ord;
    DATASET(SVM_Feature) features;
  END;

  EXPORT SVM_Grid_Args := RECORD
    REAL8 start;
    REAL8 stop;
    REAL8 max_incr;
  END;

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
  EXPORT SVM_Grid_Plan_Default := ROW(makePlan());

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
    SELF.nr_weight  := 1;
    SELF.lbl        := DATASET([], I4Entry);
    SELF.weight     := DATASET([], R8Entry);
  END;
  EXPORT Training_Base_Default := ROW(makeBase());

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
  EXPORT Training_Parameters_Default := ROW(makeParams());

  EXPORT FeatureStats := RECORD
    INTEGER4 indx;
    REAL8 mean;
    REAL8 sd;
  END;

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

  EXPORT CrossValidate_Result := RECORD
    UNSIGNED2 wi;
    Model_ID id;
    REAL8   correct;
    REAL8   mse;
    REAL8   r_sq;
  END;

  EXPORT GridSearch_Result := RECORD
    CrossValidate_Result OR Training_Parameters;
  END;

  EXPORT Feature_Scale := RECORD
    UNSIGNED4 nominal;
    REAL8 min_value;
    REAL8 max_value;
  END;

  EXPORT Class_Scale := RECORD
    REAL8 y_min;
    REAL8 y_max;
  END;

  EXPORT Scale_Parms := RECORD
    REAL8 x_lower;
    REAL8 x_upper;
    REAL8 y_lower;
    REAL8 y_upper;
  END;

  EXPORT SVM_Scale := RECORD
    Scale_Parms;
    Class_Scale;
    DATASET(Feature_Scale) features;
  END;

  EXPORT SVM_Prediction := RECORD
    UNSIGNED2 wi;
    Model_ID id;
    UNSIGNED8 rid;    // source identifier
    REAL8 target_y;   // from input
    REAL8 predict_y;  // from SVM
  END;

  EXPORT SVM_Pred_Values := RECORD(SVM_Prediction)
    DATASET(R8Entry) decision_values;
  END;

  EXPORT SVM_Pred_Prob_Est := RECORD(SVM_Prediction)
    DATASET(R8Entry) prob_estimates;
  END;
END;
