IMPORT $ as SVM;
IMPORT SVM.Types;
IMPORT SVM.LibSVM.Types AS LibSVM_Types;
IMPORT SVM.LibSVM;
IMPORT SVM.LibSVM.Converted;
IMPORT ML_Core.Types as ML_Types;

// aliases for convenience
Parms := Types.Training_Parameters;
Instance := Types.SVM_Instance;
XV_Result := Types.CrossValidate_Result;
ProblemList := LibSVM_Types.ECL_LibSVM_ProblemList;
Problem := LibSVM_Types.ECL_LibSVM_Problem;
SVM_Parms := LibSVM_Types.ECL_LibSVM_Train_Param;

/**
 * Perform n-fold cross-validation to assess the performance of the
 * given model parameters.
 *
 * @internal
 * @param p The parameters which define the model(s) to be trained.
 * @param observations The observed explanatory values.
 * @param actuals The dependent variable(s).
 * @return Dataset of cross-validated scores.
 */
EXPORT CrossValidate(
  DATASET(Parms) p = DATASET(Types.Training_Parameters_Default),
  DATASET(ML_Types.NumericField) observations,
  DATASET(ML_Types.NumericField) actuals,
  UNSIGNED2 folds = 10) := FUNCTION
  Work1 := RECORD(SVM_Parms)
    Types.Model_ID id;
    UNSIGNED2 wi;
    BOOLEAN scale;
  END;
  Work1 cvt2Parm(Parms p) := TRANSFORM
    SELF.cache_size := 100;
    SELF.prob_est := IF(p.prob_est, 1, 0);
    SELF.shrinking := IF(p.shrinking, 1, 0);
    SELF := p;
  END;
  parm_data := PROJECT(p, cvt2Parm(LEFT));
  d := SVM.Converted.ToInstance(observations, actuals);
  problem_data := Converted.Instance2Problem(d); // 1 record file per work id
  XV_Result LibSVM_Call(ProblemList d, Work1 prm) := TRANSFORM
    SELF.wi := d.wi;
    SELF.id := prm.id;
    d_problem := ROW(d, Problem);
    scaleData := SVM.Scale(d_problem, prm.Scale);
    d_probScaled := scaleData.problemScaled;
    SELF := LibSVM.SVMCrossValidate(prm, d_probScaled, folds);
  END;
  ParamWeighted := COUNT(parm_data) > COUNT(problem_data);
  rslt := IF(
    ParamWeighted,
    JOIN(parm_data, problem_data, LEFT.wi = RIGHT.wi OR LEFT.id = -1,
      LibSVM_Call(RIGHT, LEFT), ALL),
    JOIN(problem_data, parm_data, LEFT.wi = RIGHT.wi OR RIGHT.id = -1,
      LibSVM_Call(LEFT, RIGHT), ALL)
  );
  RETURN rslt;
END;
