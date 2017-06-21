/*
################################################################################
## HPCC SYSTEMS software Copyright (C) 2016 HPCC Systems®.  All rights reserved.
################################################################################
*/
/**
  * Performance test for Classify and Predict.  Performs a myriad Classify or Predict
  * operation to observe performance.  PerformanceMyriad_Prep.ecl should be run
  * prior to running this test to stage the data.
  */

IMPORT PBblas as PBblas;
IMPORT PBblas.internal as int;
IMPORT int.Types as iTypes;
IMPORT PBblas.Types;
IMPORT int.MatDims;
IMPORT PBblas.test as Tests;
IMPORT Tests.MakeTestMatrix as tm;
IMPORT ML_Core as ML;
IMPORT ML.Types as Core_Types;
IMPORT SupportVectorMachines as SVM;

NumericField := Core_Types.NumericField;
DiscreteField := Core_Types.DiscreteField;
Layout_Model := Core_Types.Layout_Model;

EXPORT PredictPerformanceMyriad(UNSIGNED4 test_size, BOOLEAN regress) := FUNCTION

  // Read the X and Y test files and train a model with them.
  X_file := 'GetModelPerfMyr_X_' + test_size + '.dat';
  Y_file := 'GetModelPerfMyr_Y_' + test_size + '.dat';
  mdl_file := IF(regress,
    'PredictPerfMyr_SVR_' + test_size + '.dat',
    'PredictPerfMyr_SVC_' + test_size + '.dat'
  );
  X := DATASET(X_file, NumericField, FLAT);
  Y := DATASET(Y_file, NumericField, FLAT);
  SVMModel := DATASET(mdl_file, Layout_Model, FLAT);

  SVMPreds := IF(regress,
    SVM.SVR(NAMED X := X, NAMED Y := Y).Predict(X, SVMModel),
    PROJECT(SVM.SVC().Classify(SVMModel, X), NumericField)
  );

  RETURN(SVMPreds);
END;
