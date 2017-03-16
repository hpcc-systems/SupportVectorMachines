// Produce a data set of predictions for each model
IMPORT $ as SVM;
IMPORT $.LibSVM;
// aliases
Model := SVM.Types.Model;
SVM_Model := LibSVM.Types.ECL_LibSVM_Model;
SVM_Output:= LibSVM.Types.LibSVM_Output;
SVM_Instance := SVM.Types.SVM_Instance;
SVM_Prediction := SVM.Types.SVM_Prediction;
SVM_Pred_Values := SVM.Types.SVM_Pred_Values;
SVM_Pred_Prob_Est := SVM.Types.SVM_Pred_Prob_Est;
SVM_Predict := LibSVM.SVM_Predict;
LibSVM_Node := LibSVM.Types.LibSVM_Node;
//
EXPORT Predict(DATASET(Model) models, DATASET(SVM_Instance) d) := MODULE
  SHARED LibSVM.Types.LibSVM_Node cvtNode(SVM.Types.SVM_Feature f) := TRANSFORM
    SELF.indx := f.nominal;
    SELF.value := f.v;
  END;
  SHARED Work_SV := RECORD
    UNSIGNED4 v_ord;
    DATASET(LibSVM_Node) nodes;
  END;
  SHARED Work_SV cvtSV(SVM.Types.SVM_SV sv_rec) := TRANSFORM
    SELF.v_ord := sv_rec.v_ord;
    SELF.nodes := PROJECT(sv_rec.features, cvtNode(LEFT))
                & DATASET([{-1, 0.0}], LibSVM_Node);
  END;
  SHARED Work1 := RECORD(SVM_Model)
    SVM.Types.Model_ID id;
  END;
  SHARED LibSVM_Node normN(LibSVM_Node node) := TRANSFORM
    SELF := node;
  END;
  Work1 cvtModel(Model m) := TRANSFORM
    sv := NORMALIZE(PROJECT(m.sv, cvtSV(LEFT)), LEFT.nodes, normN(RIGHT));
    SELF.sv := sv;
    SELF.elements := COUNT(sv);
    SELF.nr_nSV := COUNT(m.nSV);
    SELF.pairs_A := COUNT(m.probA);
    SELF.pairs_B := COUNT(m.probB);
    SELF.nr_label := COUNT(m.labels);
    SELF := m;
  END;
  SHARED svm_mdls := PROJECT(models, cvtModel(LEFT));
  // Prediction only
  SVM_Prediction p_only(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT))
             & DATASET([{-1,0.0}], LibSVM_Node);
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := SVM_Predict(m, x_nodes, SVM_Output.LABEL_ONLY)[1].v;
  END;
  EXPORT Prediction := JOIN(d, svm_mdls, TRUE, p_only(LEFT, RIGHT), ALL);
  // Prediction and decision values.  Values are empty if not supported
  SVM_Pred_Values p_values(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT))
             & DATASET([{-1,0.0}], LibSVM_Node);
    rslt_array := SVM_Predict(m, x_nodes, SVM_Output.VALUES);
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := rslt_array[1].v;
    SELF.decision_values := CHOOSEN(rslt_array, ALL, 2);
  END;
  EXPORT Pred_Values := JOIN(d, svm_mdls, TRUE, p_values(LEFT, RIGHT), ALL);
  // Prediction and probabilities.  Probability estimates empty if not supported.
  SVM_Pred_Prob_Est p_pest(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT))
             & DATASET([{-1,0.0}], LibSVM_Node);
    rslt_array := SVM_Predict(m, x_nodes, SVM_Output.PROBS);
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := rslt_array[1].v;
    SELF.prob_estimates := CHOOSEN(rslt_array, ALL, 2);
  END;
  EXPORT Pred_Prob_Est := JOIN(d, svm_mdls, TRUE, p_pest(LEFT, RIGHT), ALL);
END;