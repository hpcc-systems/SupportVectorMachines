// Produce a data set of predictions for each model
IMPORT SupportVectorMachines as SVM;
IMPORT SVM.LibSVM;
IMPORT ML_Core.Types as ML_Types;

// aliases
Model := SVM.Types.Model;
SVM_Model := LibSVM.Types.ECL_LibSVM_Model;
SVM_Output:= LibSVM.Types.LibSVM_Output;
SVM_Instance := SVM.Types.SVM_Instance;
SVM_Prediction := SVM.Types.SVM_Prediction;
SVM_Pred_Values := SVM.Types.SVM_Pred_Values;
SVM_Pred_Prob_Est := SVM.Types.SVM_Pred_Prob_Est;
SVM_Predict := LibSVM.SVMPredict;
LibSVM_Node := LibSVM.Types.LibSVM_Node;

/**
 * Module for generating predictions on data from SVM models.
 * @param models Trained SVM models.
 * @param observations Independent variables to apply model to and generate predictions.
 */
EXPORT Predict(DATASET(Model) models, DATASET(ML_Types.NumericField) observations) := MODULE
  SHARED d := SVM.Converted.ToInstance(observations);

  SHARED LibSVM_Node cvtNode(SVM.Types.SVM_Feature f) := TRANSFORM
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
    UNSIGNED2 wi;
    SVM.Types.Model_ID id;
    BOOLEAN scale;
    DATASET(SVM.Types.FeatureStats) scaleInfo;
  END;
  SHARED LibSVM_Node normN(LibSVM_Node node) := TRANSFORM
    SELF := node;
  END;
  Work1 cvtModel(Model m) := TRANSFORM
    sv := NORMALIZE(PROJECT(m.sv, cvtSV(LEFT)), LEFT.nodes, normN(RIGHT));
    SELF.wi := m.wi;
    SELF.sv := sv;
    SELF.elements := COUNT(sv);
    SELF.nr_nSV := COUNT(m.nSV);
    SELF.pairs_A := COUNT(m.probA);
    SELF.pairs_B := COUNT(m.probB);
    SELF.nr_label := COUNT(m.labels);
    SELF := m;
  END;
  SHARED svm_mdls := PROJECT(models, cvtModel(LEFT));

  SHARED LibSVM_Node applyScale(LibSVM_Node x, SVM.Types.FeatureStats s)
  := TRANSFORM
    SELF.indx := x.indx;
    SELF.value := (x.value - s.mean) / s.sd;
  END;

  // Prediction only
  SHARED SVM_Prediction p_only(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT));
    x_nodes_scale := JOIN(x_nodes, m.scaleInfo, LEFT.indx = RIGHT.indx, applyScale(LEFT, RIGHT))
      & DATASET([{-1,0.0}], LibSVM_Node);
    SELF.wi := inst.wi;
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := SVM_Predict(m, x_nodes_scale, SVM_Output.LABEL_ONLY)[1].v;
  END;

  // Prediction and decision values.  Values are empty if not supported
  SHARED SVM_Pred_Values p_values(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT));
    x_nodes_scale := JOIN(x_nodes, m.scaleInfo, LEFT.indx = RIGHT.indx, applyScale(LEFT, RIGHT))
      & DATASET([{-1,0.0}], LibSVM_Node);
    rslt_array := SVM_Predict(m, x_nodes_scale, SVM_Output.VALUES);
    SELF.wi := inst.wi;
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := rslt_array[1].v;
    SELF.decision_values := CHOOSEN(rslt_array, ALL, 2);
  END;

  // Prediction and probabilities.  Probability estimates empty if not supported.
  SHARED SVM_Pred_Prob_Est p_pest(SVM_Instance inst, Work1 m) := TRANSFORM
    x_nodes := PROJECT(inst.x,cvtNode(LEFT));
    x_nodes_scale := JOIN(x_nodes, m.scaleInfo, LEFT.indx = RIGHT.indx, applyScale(LEFT, RIGHT))
      & DATASET([{-1,0.0}], LibSVM_Node);
    rslt_array := SVM_Predict(m, x_nodes_scale, SVM_Output.PROBS);
    SELF.wi := inst.wi;
    SELF.id := m.id;
    SELF.rid := inst.rid;
    SELF.target_y := inst.y;
    SELF.predict_y := rslt_array[1].v;
    SELF.prob_estimates := CHOOSEN(rslt_array, ALL, 2);
  END;

  /**
   * Get predictions (classes or values) only.
   * @return Dataset with predictions.
   */
  EXPORT Prediction := JOIN(d, svm_mdls, LEFT.wi = RIGHT.wi, p_only(LEFT, RIGHT), ALL);

  /**
   * Get predictions (classes or values) and decision values. Values are empty if not supported.
   * @return Dataset with predictions and decision values.
   */
  EXPORT Pred_Values := JOIN(d, svm_mdls, LEFT.wi = RIGHT.wi, p_values(LEFT, RIGHT), ALL);

  /**
   * Get predictions (classes or values) and probabilities. Values are empty if not supported.
   * @return Dataset with predictions and probabilities.
   */
  EXPORT Pred_Prob_Est := JOIN(d, svm_mdls, LEFT.wi = RIGHT.wi, p_pest(LEFT, RIGHT), ALL);
END;