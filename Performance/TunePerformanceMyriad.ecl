/*
################################################################################
## HPCC SYSTEMS software Copyright (C) 2016 HPCC Systems®.  All rights reserved.
################################################################################
*/
/**
  * Performance test for Tune.  Performs a Tune
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

EXPORT TunePerformanceMyriad(UNSIGNED4 test_size, REAL8 maxIncr_log2C, REAL8 maxIncr_log2Gamma, BOOLEAN regress) := FUNCTION

  // Read the X and Y test files and train a model with them.
  X_file := 'GetModelPerfMyr_X_' + test_size + '.dat';
  Y_file := 'GetModelPerfMyr_Y_' + test_size + '.dat';
  X := DATASET(X_file, NumericField, FLAT);
  Y := DATASET(Y_file, NumericField, FLAT);

  SVMTuneRslt := IF(regress,
    SVM.SVR(NAMED X := X, NAMED Y := Y).Tune(
      NAMED folds := 2,
      NAMED start_log2C := -5,
      NAMED stop_log2C := 5,
      NAMED maxIncr_log2C := maxIncr_log2C,
      NAMED start_log2gamma := -15,
      NAMED stop_log2gamma := 5,
      NAMED maxIncr_log2gamma := maxIncr_log2gamma
    ),
    SVM.SVC().Tune(
      NAMED folds := 2,
      NAMED start_log2C := -5,
      NAMED stop_log2C := 5,
      NAMED maxIncr_log2C := maxIncr_log2C,
      NAMED start_log2gamma := -15,
      NAMED stop_log2gamma := 5,
      NAMED maxIncr_log2gamma := maxIncr_log2gamma,
      NAMED observations := X,
      NAMED classifications := ML.Discretize.ByRounding(Y)
    )
  );

  RETURN(SVMTuneRslt);
END;
