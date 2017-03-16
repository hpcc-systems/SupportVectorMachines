// Converted to and from SVM and generic formats for ML/Classify
IMPORT ML_Core as ML;
IMPORT $ as SVM;
IMPORT ML_Core.Types AS ML_Types;
EXPORT Converted := MODULE
  //Instance data
  // Don't need from instance.  This can be a one-way trip.
  dummy := DATASET([], ML_Types.NumericField);
  EXPORT ToInstance(DATASET(ML_Types.NumericField) Ind,
                    DATASET(ML_Types.NumericField) Dep=dummy) := FUNCTION
    g_i := GROUP(SORT(Ind, id, number), id);
    SVM.Types.SVM_Feature cvtF(ML_Types.NumericField nf) := TRANSFORM
      SELF.nominal := nf.number;
      SELF.v := nf.value;
    END;
    SVM.Types.SVM_Instance rollNF(ML_Types.NumericField f,
                                  DATASET(ML_Types.NumericField) ds) := TRANSFORM
      SELF.rid := f.id;
      SELF.y := 0;
      SELF.max_value := MAX(ds,value);
      SELF.x := PROJECT(ds, cvtF(LEFT));
    END;
    indy := ROLLUP(g_i, GROUP, rollNF(LEFT, ROWS(LEFT)));
    SVM.Types.SVM_Instance getD(SVM.Types.SVM_Instance i, ML_Types.NumericField d):=TRANSFORM
      SELF.y := d.value;
      SELF := i;
    END;
    rslt := JOIN(indy, dep, LEFT.rid=RIGHT.id, getD(LEFT,RIGHT),
                 LEFT OUTER, LIMIT(1,FAIL));
    RETURN rslt;
  END;  // to instance data
  // Model data
  SHARED Field_ID := 1;
  SHARED s_type_id:= Field_ID + 1;        // 2
  SHARED k_type_id:= s_type_id + 1;       // 3
  SHARED degree_id:= k_type_id + 1;       // 4
  SHARED gamma_id := degree_id + 1;       // 5
  SHARED coef0_id := gamma_id + 1;        // 6
  SHARED k_id := coef0_id + 1;            // 7
  SHARED l_id := k_id + 1;                // 8
  SHARED pairs_a_id := l_id + 1;          // 9
  SHARED pairs_b_id := pairs_a_id + 1;    //10
  SHARED n_label_id := pairs_b_id + 1;    //11
  SHARED n_sv_id := n_label_id + 1;       //12
  SHARED lf_id := n_sv_id; //last field id
  UNSIGNED4 get_SV_Count(DATASET(SVM.Types.SVM_SV) sv) := FUNCTION
    sv_count := COUNT(sv);
    features := SUM(sv, COUNT(sv.features));
    RETURN 2*sv_count + 2*features;
  END;
  SVM.Types.R8Entry norm_feature(SVM.Types.SVM_Feature f, UNSIGNED c):=TRANSFORM
    SELF.v := CHOOSE(c, (REAL8)f.nominal, f.v);
  END;
  Work1 := RECORD
    DATASET(SVM.Types.R8Entry) d;
  END;
  Work1 cvt_2_r8(SVM.Types.SVM_SV s) := TRANSFORM
    SELF.d := DATASET([{2*(COUNT(s.features)+1)},{s.v_ord}], SVM.Types.R8Entry)
            + NORMALIZE(s.features, 2, norm_feature(LEFT, COUNTER));
  END;
  SVM.Types.R8Entry cvt_sv(DATASET(SVM.Types.SVM_SV) sv) := FUNCTION
    w1 := PROJECT(sv, cvt_2_r8(LEFT));
    rslt := NORMALIZE(w1, LEFT.d, TRANSFORM(SVM.Types.R8Entry, SELF.v:=RIGHT.v));
    RETURN rslt;
  END;

  //
  EXPORT FromModel(UNSIGNED id_base, DATASET(SVM.Types.Model) mdl) := FUNCTION
    ML_Types.NumericField getField(SVM.Types.Model m, UNSIGNED c) := TRANSFORM
      SELF.wi := 1;
      SELF.id := id_base + m.id;
      SELF.number := c;
      SELF.value := CHOOSE(c, (REAL8) m.id, (REAL8) m.svmType,
                              (REAL8) m.kernelType, (REAL8) m.degree,
                              m.gamma, m.coef0, (REAL8) m.k, (REAL8) m.l,
                              (REAL8) COUNT(m.probA), (REAL8) COUNT(m.probB),
                              (REAL8) COUNT(m.labels), (REAL8) get_SV_Count(m.sv));
    END;
    fixed_part := NORMALIZE(mdl, lf_id-field_id+1, getField(LEFT,COUNTER));
    ML_Types.NumericField normSV(SVM.Types.Model m, SVM.Types.R8Entry e, UNSIGNED8 c) := TRANSFORM
      SELF.wi := 1;
      SELF.id := id_base + m.id;
      SELF.number := lf_id + c;
      SELF.value  := e.v;
    END;
    sv_part := NORMALIZE(mdl, cvt_SV(LEFT.sv), normSV(LEFT, RIGHT, COUNTER));
    ML_Types.NumericField normR8(SVM.Types.Model m, SVM.Types.R8Entry d,
                                 UNSIGNED c, UNSIGNED4 base) := TRANSFORM
      SELF.wi := 1;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value := d.v;
    END;
    coef_part := NORMALIZE(mdl, LEFT.sv_coef,
                          normR8(LEFT, RIGHT, COUNTER,
                                 lf_id + get_SV_Count(LEFT.sv)));
    rho_part  := NORMALIZE(mdl, LEFT.rho,
                          normR8(LEFT, RIGHT, COUNTER,
                                lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.sv_coef)));
    probA_part:= NORMALIZE(mdl, LEFT.probA,
                           normR8(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho) ));
    probB_part:= NORMALIZE(mdl, LEFT.probB,
                           normR8(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho) + COUNT(LEFT.probA)  ));
    ML_Types.NumericField normI4(SVM.Types.Model m, SVM.Types.I4Entry d,
                                 UNSIGNED c, UNSIGNED4 base) := TRANSFORM
      SELF.wi := 1;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value := (REAL8) d.v;
    END;
    lab_part  := NORMALIZE(mdl, LEFT.labels,
                           normI4(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho) + COUNT(LEFT.probA)
                                  + COUNT(LEFT.probB)  ));
    nsv_part  := NORMALIZE(mdl, LEFT.nSV,
                           normI4(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho) + COUNT(LEFT.probA)
                                  + COUNT(LEFT.probB) + COUNT(LEFT.Labels) ));
    RETURN fixed_part + sv_part + coef_part + rho_part + probA_part
                + probB_part + lab_part + nsv_part;
  END;
  //
  Exp_NF := RECORD(ML_Types.NumericField)
    UNSIGNED feature;
    UNSIGNED vector;
  END;
  Exp_NF mark_xnf(Exp_NF prev, Exp_NF curr) := TRANSFORM
    SELF.vector := IF(curr.number>prev.vector,
                      curr.number+(UNSIGNED)curr.value-1,
                      prev.vector);
    SELF.feature:= IF(curr.number=prev.feature, prev.feature, curr.number+1);
    SELF := curr;
  END;
  SVM.Types.SVM_Feature makeFeature(DATASET(Exp_NF) d) := TRANSFORM
    SELF.nominal := (INTEGER) d[1].value;
    SELF.v := d[2].value;
  END;
  SVM.Types.SVM_SV roll_xnf(Exp_NF f, DATASET(Exp_NF) ds) := TRANSFORM
    feature_data := GROUP(CHOOSEN(ds, ALL, 3), feature);
    SELF.v_ord := (INTEGER) ds[2].value;
    SELF.features := ROLLUP(feature_data, GROUP, makeFeature(ROWS(LEFT)));
  END;
  SVM.Types.R8Entry toR8(ML_Types.NumericField nf) := TRANSFORM
    SELF.v := nf.value;
  END;
  SVM.Types.I4Entry toI4(ML_Types.NumericField nf) := TRANSFORM
    SELF.v := (INTEGER) nf.value;
  END;
  toSV_Dataset(DATASET(ML_Types.NumericField) nf) := FUNCTION
    x_nf := PROJECT(nf, TRANSFORM(Exp_NF, SELF:=LEFT,SELF:=[]));
    marked_x := ITERATE(x_nf, mark_xnf(LEFT,RIGHT));
    group_x := GROUP(marked_x, vector);
    rslt := ROLLUP(group_x, GROUP, roll_xnf(LEFT, ROWS(LEFT)));
    RETURN rslt;
  END;
  EXPORT ToModel(DATASET(ML_Types.NumericField) mdl) := FUNCTION
    gs0 := SORT(GROUP(mdl, id, ALL), number);
    SVM.Types.Model rollModel(DATASET(ML_Types.NumericField) d) := TRANSFORM
      fixed := DICTIONARY(d(number<=lf_id), {number=>value});
      nsv := (UNSIGNED) fixed[n_sv_id].value;
      probA := (UNSIGNED) fixed[pairs_a_id].value;
      probB := (UNSIGNED) fixed[pairs_b_id].value;
      labels:= (UNSIGNED) fixed[n_label_id].value;
      k := (UNSIGNED) fixed[k_id].value;
      l := (UNSIGNED) fixed[l_id].value;
      sv_start := lf_id + 1;
      sv_stop := sv_start + nsv - 1;
      coef_start := sv_stop + 1;
      coef_stop := coef_start + (k-1)*l - 1;
      rho_start := coef_stop + 1;
      rho_stop := rho_start + (k-1)*k/2 - 1;
      probA_start := rho_stop + 1;
      probA_stop := probA_start + probA - 1;
      probB_start := probA_stop + 1;
      probB_stop := probB_start + probB - 1;
      label_start := probB_stop + 1;
      label_stop := label_start + labels - 1;
      nSV_start := label_stop + 1;
      nSV_stop := nSV_start + labels - 1;
      SELF.id := (UNSIGNED) fixed[Field_ID].value;
      SELF.svmType := (UNSIGNED1) fixed[s_type_id].value;
      SELF.kernelType := (UNSIGNED1) fixed[k_type_id].value;
      SELF.degree := (UNSIGNED) fixed[degree_id].value;
      SELF.coef0 := fixed[coef0_id].value;
      SELF.gamma := fixed[gamma_id].value;
      SELF.k := k;
      SELF.l := l;
      SELF.sv := toSV_Dataset(d(number BETWEEN sv_start AND sv_stop));
      SELF.sv_coef := PROJECT(d(number BETWEEN coef_start AND coef_stop), toR8(LEFT));
      SELF.rho := PROJECT(d(number BETWEEN rho_start AND rho_stop), toR8(LEFT));
      SELF.probA := PROJECT(d(number BETWEEN probA_start AND probA_stop), toR8(LEFT));
      SELF.probB := PROJECT(d(number BETWEEN probB_start AND probB_stop), toR8(LEFT));
      SELF.labels:= PROJECT(d(number BETWEEN label_start AND label_stop), toI4(LEFT));
      SELF.nSV := PROJECT(d(number BETWEEN nSV_start AND nSV_stop), toI4(LEFT));
    END;
    rslt := ROLLUP(gs0, GROUP, rollModel(ROWS(LEFT)));
    RETURN rslt;
  END;
END;