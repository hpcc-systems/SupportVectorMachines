//The test of LibSVM implementation using the heart scale dataset
//export run_heart_scale := 'todo';
IMPORT ML_Core as ML;
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM;

//Training_Parameters := SVM.Types.Training_Parameters;

fileName := '~thor::libsvm_data::heart_scale_csv';
instance_data := LibSVM.Converted.LIBSVMDATA2Instance(fileName);
OUTPUT(instance_data, NAMED('Instance'));

SVM.Types.Training_Parameters base(UNSIGNED c) := TRANSFORM
  SELF.svmType := LibSVM.Types.LibSVM_Type.C_SVC;
  SELF.kernelType := LibSVM.Types.LibSVM_Kernel.RBF;
  SELF.degree := 3;
  SELF.gamma := 0.0;
  SELF.coef0 := 0.0;
  SELF.nu := 0.5;
  SELF.C := 1.0;
  SELF.eps := 0.001;
  SELF.p := 0.1;
  SELF.shrinking := 1;
  SELF.prob_est := 0;
  SELF.nr_weight := 0;
  SELF.lbl := DATASET([], SVM.Types.I4Entry);
  SELF.weight := DATASET([], SVM.Types.R8Entry);
  SELF.id := c;
END;
heart_parms := DATASET(1, base(COUNTER));

OUTPUT(LibSVM.LibSVM_Version, NAMED('Version'));

score_data := SVM.cross_validate(heart_parms, instance_data, 5);
OUTPUT(SORT(score_data, id), NAMED('Scores'));

//Now run model
heart_model := SVM.train(heart_parms, instance_data);
OUTPUT(heart_model, NAMED('Full_Heart_Model'));

//Decompose model for easier display
Model_Head := RECORD
  SVM.Types.Model_ID id;
  SVM.LibSVM.Types.LibSVM_Type svmType;
  SVM.LibSVM.Types.LibSVM_Kernel kernelType;
  INTEGER4 degree;    // for Poly
  REAL8 gamma;        // for Poly, RBF, Sigmoid
  REAL8 coef0;        // for Poly, Sigmoid
  UNSIGNED4 k;  // number of classes
  UNSIGNED4 l;  // number of support vectors
END;
heart_head := PROJECT(heart_model, Model_Head);
OUTPUT(heart_head, NAMED('Heart_Head'));
Model_SV := RECORD
  SVM.Types.Model_ID id;
  UNSIGNED4 v_ord;
  DATASET(SVM.Types.SVM_Feature) features;
END;
Model_SV normNodes(SVM.Types.Model model,
                     SVM.Types.SVM_SV sv) := TRANSFORM
  SELF.id := model.id;
  SELF.v_ord := sv.v_ord;
  SELF.features := sv.features;
END;
heart_sv := NORMALIZE(heart_model, LEFT.sv, normNodes(LEFT, RIGHT));
OUTPUT(heart_sv, NAMED('Heart_SV'));

Model_R8 := RECORD
  SVM.Types.Model_ID id;
  UNSIGNED4 c;
  REAL8 set_sum;
  DATASET(SVM.LibSVM.Types.R8Entry) ds;
END;
Model_R8 extractR8(SVM.Types.Model model, UNSIGNED fld) := TRANSFORM
  ds := CHOOSE(fld, model.sv_coef, model.rho, model.ProbA, model.probB);
  SELF.id := model.id;
  SELF.c  := COUNT(ds);
  SELF.set_sum := SUM(ds, v);
  SELF.ds := ds;
END;
heart_coef := PROJECT(heart_model, extractR8(LEFT, 1));
OUTPUT(heart_coef, NAMED('Heart_Coef'));
heart_rho := PROJECT(heart_model, extractR8(LEFT, 2));
OUTPUT(heart_rho, NAMED('Heart_rho'));
heart_probA := PROJECT(heart_model, extractR8(LEFT, 3));
OUTPUT(heart_probA, NAMED('Heart_probA'));
heart_probB := PROJECT(heart_model, extractR8(LEFT, 4));
OUTPUT(heart_probB, NAMED('Heart_probB'));

Model_I4 := RECORD
  SVM.Types.Model_ID id;
  UNSIGNED4 c;
  INTEGER8 set_sum;
  DATASET(SVM.LibSVM.Types.I4Entry) ds;
END;
Model_I4 extractI4(SVM.Types.Model model, UNSIGNED fld) := TRANSFORM
  ds := CHOOSE(fld, model.labels, model.nSV);
  SELF.id := model.id;
  SELF.c := COUNT(ds);
  SELF.set_sum := SUM(ds, v);
  SELF.ds := ds;
END;
heart_labels := PROJECT(heart_model, extractI4(LEFT, 1));
OUTPUT(heart_labels, NAMED('Heart_Label'));
heart_nSV := PROJECT(heart_model, extractI4(LEFT, 2));
OUTPUT(heart_nSV, NAMED('heart_nSV'));

//Predictions
heart_pred := SVM.Predict(heart_model, instance_data).Prediction;
OUTPUT(CHOOSEN(heart_pred, 100), NAMED('Detail_pred'));
Raw_Result := RECORD
  heart_pred.rid;
  UNSIGNED4 correct := IF(heart_pred.predict_y=heart_pred.target_y, 1, 0);
  UNSIGNED4 wrong := IF(heart_pred.predict_y<>heart_pred.target_y, 1, 0);
END;
pred_raw := TABLE(heart_pred, Raw_Result);
pred_rslt := TABLE(pred_raw, {REAL8 score:=SUM(GROUP,correct)/COUNT(GROUP),
                              UNSIGNED tot_correct:=SUM(GROUP,correct),
                              UNSIGNED tot_wrong:=SUM(GROUP,wrong)});
OUTPUT(pred_rslt, NAMED('Pred_Result'));
