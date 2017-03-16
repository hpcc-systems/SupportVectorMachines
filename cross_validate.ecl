IMPORT $.Types;
IMPORT $.LibSVM.Types AS LibSVM_Types;
IMPORT $.LibSVM;
IMPORT $.LibSVM.Converted;
// aliases for convenience
Parms := Types.Training_Parameters;
Instance := Types.SVM_Instance;
XV_Result := Types.CrossValidate_Result;
Problem := LibSVM_Types.ECL_LibSVM_Problem;
SVM_Parms := LibSVM_Types.ECL_LibSVM_Train_Param;

EXPORT cross_validate(DATASET(Parms) p,
                      DATASET(Instance) d,
                      UNSIGNED2 folds):= FUNCTION
  Work1 := RECORD(SVM_Parms)
    Types.Model_ID id;
  END;
  Work1 cvt2Parm(Parms p) := TRANSFORM
    SELF.cache_size := 100;
    SELF.prob_est := IF(p.prob_est, 1, 0);
    SELF.shrinking := IF(p.shrinking, 1, 0);
    SELF := p;
  END;
  parm_data := PROJECT(p, cvt2Parm(LEFT));
  problem_data := Converted.Instance2Problem(d); // 1 record file
  XV_Result LibSVM_Call(Work1 prm, Problem d) := TRANSFORM
    SELF.id := prm.id;
    SELF := LibSVM.svm_cross_validate(prm, d, folds);
  END;
  rslt := JOIN(parm_data, problem_data, TRUE,
               LibSVM_Call(LEFT, RIGHT), ALL);
  RETURN rslt;
END;
