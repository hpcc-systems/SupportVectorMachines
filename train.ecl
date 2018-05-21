IMPORT $ as SVM;
IMPORT SVM.Types;
IMPORT SVM.LibSVM.Types AS LibSVM_Types;
IMPORT SVM.LibSVM;
IMPORT SVM.LibSVM.Converted;
IMPORT ML_Core.Types as ML_Types;

// aliases for convenience
Parms := Types.Training_Parameters;
Instance := Types.SVM_Instance;
Model := Types.Model;
ProblemList := LibSVM_Types.ECL_LibSVM_ProblemList;
Problem := LibSVM_Types.ECL_LibSVM_Problem;
LibSVM_Parms := LibSVM_Types.ECL_LibSVM_Train_Param;
LibSVM_Model := LibSVM_Types.ECL_LibSVM_Model;
SVM_SV := Types.SVM_SV;
SVM_Feature := Types.SVM_Feature;

/**
 * Train SVM classification and regression models.
 * @internal
 * @param p The parameters which define the model(s) to be trained.
 * @param observations The observed explanatory values.
 * @param actuals The dependent variable(s).
 * @return Trained SVM model(s) in SVM Model format.
 */
EXPORT DATASET(Model) Train(
  DATASET(Parms) p = DATASET(Types.Training_Parameters_Default),
  DATASET(ML_Types.NumericField) observations,
  DATASET(ML_Types.NumericField) actuals):= FUNCTION
  Work1 := RECORD(LibSVM_Parms)
    Types.Model_ID id;
    UNSIGNED2 wi;
    BOOLEAN scale;
  END;
  Work1 cvt2Parm(Parms p) := TRANSFORM
    SELF.cache_size := 100;
    SELF.shrinking := IF(p.shrinking, 1, 0);
    SELF.prob_est := IF(p.prob_est, 1, 0);
    SELF := p;
  END;
  parm_data := PROJECT(p, cvt2Parm(LEFT));
  d := SVM.Converted.ToInstance(observations, actuals);
  problem_data := Converted.Instance2Problem(d); // 1 record file

  Work_F := RECORD(SVM_Feature)
    UNSIGNED4 v_ord;
    BOOLEAN keep_me;
  END;
  Work_F cvtNode(LibSVM_Types.LibSVM_Node node) := TRANSFORM
    SELF.v_ord := IF(node.indx >=0, 0, 1);
    SELF.nominal := node.indx;
    SELF.v := node.value;
    SELF.keep_me := node.indx >= 0;   // not end mark
  END;
  Work_F vidMark(Work_F prev, Work_F curr) := TRANSFORM
    SELF.v_ord := IF(prev.v_ord=0,1, prev.v_ord+curr.v_ord);
    SELF := curr;
  END;
  SVM_SV rollF(Work_F f_1, DATASET(Work_F) f_set) := TRANSFORM
    SELF.v_ord := f_1.v_ord;
    SELF.features := PROJECT(f_set, SVM_Feature);
  END;
  Model LibSVM_Call(ProblemList d, Work1 prm) := TRANSFORM
    d_problem := ROW(d, Problem);
    scaleData := SVM.Scale(d_problem, prm.Scale);
    d_probScaled := scaleData.problemScaled;
    LibSVM_Model mdl := LibSVM.SVMTrain(prm, d_probScaled);
    raw_features := PROJECT(mdl.sv, cvtNode(LEFT));
    marked_features := ITERATE(raw_features, vidMark(LEFT,RIGHT))(keep_me);
    grouped_features := GROUP(marked_features, v_ord);
    SELF.wi := d.wi;
    SELF.id := prm.id;
    SELF.scale := prm.Scale;
    SELF.scaleInfo := scaleData.stats;
    SELF.sv := ROLLUP(grouped_features, GROUP, rollF(LEFT,ROWS(LEFT)));
    SELF := mdl;
  END;
  rslt := JOIN(problem_data, parm_data, LEFT.wi = RIGHT.wi OR RIGHT.id = -1,
               LibSVM_Call(LEFT, RIGHT), ALL);
  RETURN rslt;
END;
