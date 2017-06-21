/*
################################################################################
## HPCC SYSTEMS software Copyright (C) 2016 HPCC Systems®.  All rights reserved.
################################################################################
*/
/**
  * Performance test for GetModel.  Performs a myriad train
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

EXPORT GetModelPerformanceMyriad(UNSIGNED4 test_size, BOOLEAN regress) := FUNCTION

  // Read the X and Y test files and train a model with them.
  X_file := 'GetModelPerfMyr_X_' + test_size + '.dat';
  Y_file := 'GetModelPerfMyr_Y_' + test_size + '.dat';
  X := DATASET(X_file, NumericField, FLAT);
  Y := DATASET(Y_file, NumericField, FLAT);

  SVMModel := IF(regress,
    SVM.SVR(NAMED X := X, NAMED Y := Y).GetModel(),
    SVM.SVC().GetModel(X, ML.Discretize.ByRounding(Y))
  );

  RETURN(SVMModel);
END;