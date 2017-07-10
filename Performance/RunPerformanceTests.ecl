/*
################################################################################
## HPCC SYSTEMS software Copyright (C) 2016 HPCC Systems®.  All rights reserved.
################################################################################
*/
/**
  * Performance tests for SupportVectorMachines bundle.
  * PerformanceMyriad_Prep.ecl should be run prior to running this test
  * to stage the data.
  */

IMPORT $.^ as SVM;
IMPORT SVM.Performance as Perf;

SEQUENTIAL(
  OUTPUT(Perf.GetModelPerformanceMyriad(1, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(2, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(4, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(8, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(16, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(20, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(21, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(22, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(25, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(30, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(40, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(50, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(64, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(256, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(1024, false), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.GetModelPerformanceMyriad(1, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(2, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(4, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(8, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(16, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(20, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(21, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(22, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(25, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(30, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(40, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(50, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(64, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(256, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.GetModelPerformanceMyriad(1024, true), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.ToModelPerformanceMyriad(1, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(2, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(4, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(8, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(16, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(20, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(21, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(22, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(25, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(30, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(40, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(50, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(64, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(256, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(1024, false), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.ToModelPerformanceMyriad(1, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(2, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(4, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(8, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(16, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(20, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(21, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(22, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(25, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(30, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(40, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(50, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(64, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(256, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.ToModelPerformanceMyriad(1024, true), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.PredictPerformanceMyriad(1, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(2, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(4, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(8, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(16, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(20, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(21, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(22, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(25, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(30, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(40, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(50, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(64, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(256, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(1024, false), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.PredictPerformanceMyriad(1, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(2, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(4, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(8, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(16, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(20, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(21, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(22, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(25, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(30, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(40, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(50, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(64, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(256, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.PredictPerformanceMyriad(1024, true), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 4, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 16, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 64, false), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 256, false), , 'tmpOutput.dat', OVERWRITE),

  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 4, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 16, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 64, true), , 'tmpOutput.dat', OVERWRITE),
  OUTPUT(Perf.TunePerformanceMyriad(1, 5, 10 / 256, true), , 'tmpOutput.dat', OVERWRITE)
);