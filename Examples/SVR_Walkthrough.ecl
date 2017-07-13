/*
 * The following script exemplifies the use the SupportVectorMachines HPCC bundle
 * in training, classifying and analysing SVMs.
 */

// Imports
IMPORT ML_Core;
IMPORT ML_Core.Types as Types;
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM;
IMPORT SVM.datasets.HeartScale;

// Pull in the HeartScale dataset (included in bundle repository)
heartScaleDS := HeartScale.Content;
OUTPUT(heartScaleDS, NAMED('Dataset'));

// Convert dataset to the standard NumericField format used by HPCC ML algorithm
ML_Core.ToField(heartScaleDS,heartScaleDS_NF);
OUTPUT(heartScaleDS_NF, NAMED('Dataset_NumberField'));

// Create a testing dataset by concatenating three identical datasets.
// Individual datasets are identified by a work ID column, 'wi'.
Types.NumericField IncrementWID(Types.NumericField L) := TRANSFORM
  SELF.wi := L.wi + 1;
  SELF := L;
END;
heartScaleDS_NFx3 := heartScaleDS_NF +
  PROJECT(heartScaleDS_NF, IncrementWID(LEFT)) +
  PROJECT(PROJECT(heartScaleDS_NF, IncrementWID(LEFT)), IncrementWID(LEFT));

// Split out features and classes ('number' identifies column, and number = 1
// corresponds to the labels).
X := heartScaleDS_NFx3(number <> 1);
Y := heartScaleDS_NFx3(number = 1);
OUTPUT(X, NAMED('X'));
OUTPUT(Y, NAMED('Y'));

// Define a set of model parameters
// Here these are all explicitly defined, but any/all may be omitted in later function
// calls if the default values are preferred.
svmType    := LibSVM.Types.LibSVM_Type.EPSILON_SVR;
kernelType := LibSVM.Types.LibSVM_Kernel.RBF;
gamma      := 0.05;
C          := 1.0;
degree     := 3;
coef0      := 0.0;
nu         := 0.5;
eps        := 0.001;
p          := 0.1;
shrinking  := true;
prob_est   := false;
scale      := true;
nr_weight  := 1;
lbl        := DATASET([], SVM.Types.I4Entry);
weight     := DATASET([], SVM.Types.R8Entry);

// Define model parameters
SVMSetup := SVM.SVR(
  NAMED X           := X,
  NAMED Y           := Y,
  NAMED svmType     := svmType,
  NAMED kernelType  := kernelType,
  NAMED gamma       := gamma,
  NAMED C           := C,
  NAMED degree      := degree,
  NAMED coef0       := coef0,
  NAMED eps         := eps,
  NAMED nu          := nu,
  NAMED p           := p,
  NAMED shrinking   := shrinking,
  NAMED prob_est    := prob_est,
  NAMED scale       := scale,
  NAMED nr_weight   := nr_weight,
  NAMED lbl         := lbl,
  NAMED weight      := weight
);

// Cross-validate the chosen set of model parameters.
cvResults := SVMSetup.CrossValidate(
  NAMED folds := 10
);
OUTPUT(cvResults, NAMED('CVResults'));

// Build SVM models using chosen parameters
SVMModel := SVMSetup.GetModel;
ConvertedModel := SVM.Converted.ToModel(SVMModel);
OUTPUT(ConvertedModel, NAMED('FittedModels'));
OUTPUT(ConvertedModel[1].sv_coef, NAMED('SVCoefs'));

// Use fitted models to predict training data
predictResults := SVMSetup.Predict(
  NAMED model             := SVMModel,
  NAMED newX              := X
);
OUTPUT(predictResults, NAMED('Predictions'));

// Get human-readable model summary
modelSummary := SVMSetup.ModelSummary(SVMModel);
OUTPUT(modelSummary, NAMED('ModelSummary'));