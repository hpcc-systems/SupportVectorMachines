/*
 * The following script performs a range of validation tests by comparing
 * the output of this implementation of LibSVM with that of the e1071 package
 * for R.
 */

// Imports
IMPORT $.^ as SVM;
IMPORT SVM.Validation.R_Validation as R;
IMPORT SVM.LibSVM;
IMPORT SVM.datasets.HeartScale;
IMPORT ML_Core;
IMPORT ML_Core.Types as Types;

// Pull in the HeartScale dataset
heartScaleDS := HeartScale.Content;
ML_Core.ToField(heartScaleDS,heartScaleDS_NF);

X := heartScaleDS_NF(number <> 1);
features := X;
Y := heartScaleDS_NF(number = 1);
classes := ML_Core.Discretize.ByRounding(Y);

// Define model parameters
kernelType := LibSVM.Types.LibSVM_Kernel.RBF;
gamma      := 0.1;
C          := 1.0;
degree     := 3;
coef0      := 0.0;
nu         := 0.5;
eps        := 0.001;
p          := 0.1;
shrinking  := true;
nr_weight  := 1;
lbl        := DATASET([], SVM.Types.I4Entry);
weight     := DATASET([], SVM.Types.R8Entry);

// SVC, without scaling

SVMSetup_SVC_NoScaling := SVM.SVC(
  NAMED svmType     := LibSVM.Types.LibSVM_Type.C_SVC,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := true,
  NAMED scale       := false,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

SVMMdl_SVC_NoScaling := SVMSetup_SVC_NoScaling.GetModel(
  NAMED observations    := features,
  NAMED classifications := classes
);
Mdl_SVC_NoScaling := SVM.Converted.ToModel(SVMMdl_SVC_NoScaling);
Preds_SVC_NoScaling := SVMSetup_SVC_NoScaling.Classify(
  NAMED model             := SVMMdl_SVC_NoScaling,
  NAMED new_observations  := features
);

// SVC, with scaling

SVMSetup_SVC_Scaling := SVM.SVC(
  NAMED svmType     := LibSVM.Types.LibSVM_Type.C_SVC,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := true,
  NAMED scale       := true,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

SVMMdl_SVC_Scaling := SVMSetup_SVC_Scaling.GetModel(
  NAMED observations    := features,
  NAMED classifications := classes
);
Mdl_SVC_Scaling := SVM.Converted.ToModel(SVMMdl_SVC_Scaling);;
Preds_SVC_Scaling := SVMSetup_SVC_Scaling.Classify(
  NAMED model             := SVMMdl_SVC_Scaling,
  NAMED new_observations  := features
);

// SVR, without scaling

SVMSetup_SVR_NoScaling := SVM.SVR(
  NAMED X           := X,
  NAMED Y           := Y,
  NAMED svmType     := LibSVM.Types.LibSVM_Type.EPSILON_SVR,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := false,
  NAMED scale       := false,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

SVMMdl_SVR_NoScaling := SVMSetup_SVR_NoScaling.GetModel;
Mdl_SVR_NoScaling := SVM.Converted.ToModel(SVMMdl_SVR_NoScaling);
Preds_SVR_NoScaling := SVMSetup_SVR_NoScaling.Predict(
  NAMED model             := SVMMdl_SVR_NoScaling,
  NAMED newX              := X
);

// SVR, with scaling

SVMSetup_SVR_Scaling := SVM.SVR(
  NAMED X           := X,
  NAMED Y           := Y,
  NAMED svmType     := LibSVM.Types.LibSVM_Type.EPSILON_SVR,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := false,
  NAMED scale       := true,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

SVMMdl_SVR_Scaling := SVMSetup_SVR_Scaling.GetModel;
Mdl_SVR_Scaling := SVM.Converted.ToModel(SVMMdl_SVR_Scaling);
Preds_SVR_Scaling := SVMSetup_SVR_Scaling.Predict(
  NAMED model             := SVMMdl_SVR_Scaling,
  NAMED newX              := X
);

NumberOfSVs := DATASET([
  {'NumberOfSVs - SVC, without scaling', 0, R.NumberOfSVs_SVC_NoScaling, Mdl_SVC_NoScaling[1].l},
  {'NumberOfSVs - SVC, with scaling', 0, R.NumberOfSVs_SVC_Scaling, Mdl_SVC_Scaling[1].l},
  {'NumberOfSVs - SVR, without scaling', 0, R.NumberOfSVs_SVR_NoScaling, Mdl_SVR_NoScaling[1].l},
  {'NumberOfSVs - SVR, with scaling', 0, R.NumberOfSVs_SVR_Scaling, Mdl_SVR_Scaling[1].l}
], {STRING40 Test, INTEGER ID, REAL8 R, REAL8 HPCC});
OUTPUT(NumberOfSVs, NAMED('NumberOfSVs'));

SVCoefs := SORT(
  JOIN(
    PROJECT(R.SVCoefs_SVC_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'SVCoefs - SVC, without scaling';
        SELF := LEFT;)),
    PROJECT(Mdl_SVC_NoScaling[1].SV_Coef,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'SVCoefs - SVC, without scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.v;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.SVCoefs_SVC_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'SVCoefs - SVC, with scaling';
        SELF := LEFT;)),
    PROJECT(Mdl_SVC_Scaling[1].SV_Coef,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'SVCoefs - SVC, with scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.v;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.SVCoefs_SVR_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'SVCoefs - SVR, without scaling';
        SELF := LEFT;)),
    PROJECT(Mdl_SVR_NoScaling[1].SV_Coef,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'SVCoefs - SVR, without scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.v;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.SVCoefs_SVR_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'SVCoefs - SVR, with scaling';
        SELF := LEFT;)),
    PROJECT(Mdl_SVR_Scaling[1].SV_Coef,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'SVCoefs - SVR, with scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.v;)), LEFT.ID = RIGHT.ID), Test, ID);
OUTPUT(SVCoefs, NAMED('SVCoefs'));


Predictions := SORT(
  JOIN(
    PROJECT(R.Predictions_SVC_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Predictions - SVC, without scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVC_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Predictions - SVC, without scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.value;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.Predictions_SVC_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Predictions - SVC, with scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVC_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Predictions - SVC, with scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.value;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.Predictions_SVR_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Predictions - SVR, without scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVR_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Predictions - SVR, without scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.value;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.Predictions_SVR_Scaling,
      TRANSFORM({ STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Predictions - SVR, with scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVR_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Predictions - SVR, with scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.value;)), LEFT.ID = RIGHT.ID), Test, ID);
OUTPUT(Predictions, NAMED('Predictions'));

Probabilities := SORT(
  JOIN(
    PROJECT(R.Probabilities_SVC_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Probabilities - SVC, without scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVC_NoScaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Probabilities - SVC, without scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.conf;)), LEFT.ID = RIGHT.ID) +
  JOIN(
    PROJECT(R.Probabilities_SVC_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R},
        SELF.Test := 'Probabilities - SVC, with scaling';
        SELF := LEFT;)),
    PROJECT(Preds_SVC_Scaling,
      TRANSFORM({STRING40 Test, INTEGER ID, REAL8 HPCC},
        SELF.Test := 'Probabilities - SVC, with scaling';
        SELF.ID := COUNTER;
        SELF.HPCC := LEFT.conf;)), LEFT.ID = RIGHT.ID), Test, ID);
OUTPUT(Probabilities, NAMED('Probabilities_SVCOnly'));

SVMSetup_SVC_Grid := SVM.SVC(
  NAMED svmType     := LibSVM.Types.LibSVM_Type.C_SVC,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := false,
  NAMED scale       := true,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

tuneResults_SVC := SVMSetup_SVC_Grid.Tune(
  NAMED folds              := 10,
  NAMED observations      := features,
  NAMED classifications   := classes
);
GridSearchAccuracy_SVC := SORT(
  JOIN(
    R.GridSearchResults_SVC,
    PROJECT(tuneResults_SVC,
      TRANSFORM({INTEGER ID, REAL8 Cost, REAL8 Gamma, REAL8 HPCC},
        SELF.ID := LEFT.ID;
        SELF.Cost := LEFT.C;
        SELF.Gamma := LEFT.Gamma;
        SELF.HPCC := 1-LEFT.Correct/100;)),
    LEFT.ID = RIGHT.ID),
  ID
);
OUTPUT(GridSearchAccuracy_SVC, NAMED('GridSearchAccuracy_SVC'));

SVMSetup_SVR_Grid := SVM.SVR(
  NAMED X           := X,
  NAMED Y           := Y,
  NAMED svmType     := LibSVM.Types.LibSVM_Type.EPSILON_SVR,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := false,
  NAMED scale       := true,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

tuneResults_SVR := SVMSetup_SVR_Grid.Tune(
  NAMED folds := 10
);
GridSearchAccuracy_SVR := SORT(
  JOIN(
    R.GridSearchResults_SVR,
    PROJECT(tuneResults_SVR,
      TRANSFORM({INTEGER ID, REAL8 Cost, REAL8 Gamma, REAL8 HPCC},
        SELF.ID := LEFT.ID;
        SELF.Cost := LEFT.C;
        SELF.Gamma := LEFT.Gamma;
        SELF.HPCC := LEFT.mse;)),
    LEFT.ID = RIGHT.ID),
  ID
);
OUTPUT(GridSearchAccuracy_SVR, NAMED('GridSearchAccuracy_SVR'));

// Get summary of R-HPCC comparisons
allResults := NumberOfSVs +
  SVCoefs +
  Predictions +
  Probabilities +
  PROJECT(GridSearchAccuracy_SVC,
    TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R, REAL8 HPCC},
      SELF.Test := 'Grid_SVC';
      SELF.ID := 0;
      SELF.R := LEFT.R;
      SELF.HPCC := LEFT.HPCC;)) +
  PROJECT(GridSearchAccuracy_SVR,
    TRANSFORM({STRING40 Test, INTEGER ID, REAL8 R, REAL8 HPCC},
      SELF.Test := 'Grid_SVR';
      SELF.ID := 0;
      SELF.R := LEFT.R;
      SELF.HPCC := LEFT.HPCC;));

summaryRec := RECORD
  STRING40 Test := allResults.Test;
  MeanAbsoluteError :=  AVE(GROUP, ABS(allResults.HPCC - allResults.R));
  MaxAbsoluteError := MAX(GROUP, ABS(allResults.HPCC - allResults.R));
END;

SummaryResults := TABLE(allResults, summaryRec, Test);
OUTPUT(SummaryResults, NAMED('SummaryResults'));