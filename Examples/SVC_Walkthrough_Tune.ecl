/*
 * The following script exemplifies the use the SupportVectorMachines HPCC bundle
 * in training, classifying and analysing SVMs, using the grid search functionality
 * to search for optimal parameters C and gamma. This process can be completed for
 * for many datasets simultaneously, by performing each of the grid search, model
 * training, and classification processes in parallel. In this example, default
 * parameters are used for all models, with the only required inputs being the data
 * used for training.
 */

// Imports
IMPORT ML_Core as Core;
IMPORT Core.Types as Types;
IMPORT SupportVectorMachines as SVM;
IMPORT SVM.LibSVM;
IMPORT SVM.datasets.HeartScale;

// Pull in the HeartScale dataset (included in bundle repository)
heartScaleDS := HeartScale.Content;
OUTPUT(heartScaleDS, NAMED('Dataset'));

// Convert dataset to the standard NumericField format used by HPCC ML algorithm
Core.ToField(heartScaleDS,heartScaleDS_NF);
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
features := heartScaleDS_NFx3(number <> 1);
classes := Core.Discretize.ByRounding(heartScaleDS_NFx3(number = 1));
OUTPUT(features, NAMED('Features'));
OUTPUT(classes, NAMED('Classes'));

// Define base model parameter setup (using defaults)
SVMSetup := SVM.SVC(
  NAMED scale := true,
  NAMED prob_est := false
);

// Tune parameters C and gamma using a grid search (with default grid params)
tuneResults := SVMSetup.Tune(
  NAMED observations      := features,
  NAMED classifications   := classes
);
OUTPUT(tuneResults, NAMED('TuneResults'));

// For each input dataset (work id) chose the best set of C and gamma and
// train a model
tunedSVMModel := SVMSetup.GetTunedModel(
  NAMED tuneResult      := tuneResults,
  NAMED observations    := features,
  NAMED classifications := classes
);
OUTPUT(SVM.Converted.ToModel(tunedSVMModel), NAMED('FittedTunedModels'));

// Use fitted models to classify training data
classifyResults := SVMSetup.Classify(
  NAMED model             := tunedSVMModel,
  NAMED new_observations  := features
);
OUTPUT(classifyResults, NAMED('PredictedClasses'));

// Get confusion matrix for the predictions
confusionMatrix := SVMSetup.Report(
  NAMED model := tunedSVMModel,
  NAMED observations := features,
  NAMED classifications := classes
);
OUTPUT(confusionMatrix, NAMED('ConfusionMatrix'));

// Get human-readable model summary
modelSummary := SVMSetup.ModelSummary(tunedSVMModel);
OUTPUT(modelSummary, NAMED('ModelSummary'));