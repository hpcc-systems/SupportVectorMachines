/*
################################################################################
## HPCC SYSTEMS software Copyright (C) 2016 HPCC Systems®.  All rights reserved.
################################################################################
*/
/**
  * Performance test for ToModel.  Performs a myriad ToModel
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
IMPORT $.^ as SVM;

NumericField := Core_Types.NumericField;
DiscreteField := Core_Types.DiscreteField;
Layout_Model := Core_Types.Layout_Model;

EXPORT ToModelPerformanceMyriad(UNSIGNED4 test_size, BOOLEAN regress) := FUNCTION

  mdl_file := IF(regress,
    'PredictPerfMyr_SVR_' + test_size + '.dat',
    'PredictPerfMyr_SVC_' + test_size + '.dat'
  );
  SVMModel := DATASET(mdl_file, Layout_Model, FLAT);

  SVMModelConverted := SVM.Converted.ToModel(SVMModel);

  RETURN(SVMModelConverted);
END;
