// Converted to and from SVM and generic formats for ML/Classify
IMPORT ML_Core as ML;
IMPORT $ as SVM;
IMPORT ML_Core.Types AS ML_Types;

/**
 * Module for various data conversions, including from a NumericField to an
 * SVM_Instance, and to/from a Layout_Model/NumericField.
 */
EXPORT Converted := MODULE
  //Instance data
  // Don't need from instance.  This can be a one-way trip.
  dummy := DATASET([], ML_Types.NumericField);

  /**
   * Convert dataset in NumericField format (with separate NumericFields for
   * dependent and independent variables) to an SVM_Instance format.
   * @param Ind NumericField dataset of independent variables.
   * @param Dep NumericField dataset of dependent variable(s) (default: empty dataset).
   * @return Dataset converted to SVM_Instance format (see SupportVectorMachines.Types
   * for type definition).
   */
  EXPORT ToInstance(DATASET(ML_Types.NumericField) Ind,
                    DATASET(ML_Types.NumericField) Dep=dummy) := FUNCTION
    g_i := GROUP(SORT(Ind, wi, id, number), wi, id);
    SVM.Types.SVM_Feature cvtF(ML_Types.NumericField nf) := TRANSFORM
      SELF.nominal := nf.number;
      SELF.v := nf.value;
    END;
    SVM.Types.SVM_Instance rollNF(ML_Types.NumericField f,
                                  DATASET(ML_Types.NumericField) ds) := TRANSFORM
      SELF.wi := f.wi;
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
    rslt := JOIN(indy, dep, LEFT.rid=RIGHT.id AND LEFT.wi=RIGHT.wi, getD(LEFT,RIGHT),
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
  SHARED scale_id := l_id + 1;            // 9
  SHARED scaleInfo_id := scale_id + 1;    //10
  SHARED pairs_a_id := scaleInfo_id + 1;  //11
  SHARED pairs_b_id := pairs_a_id + 1;    //12
  SHARED n_label_id := pairs_b_id + 1;    //13
  SHARED n_sv_id := n_label_id + 1;       //14
  SHARED lf_id := n_sv_id; //last field id
  SHARED UNSIGNED4 get_SV_Count(DATASET(SVM.Types.SVM_SV) sv) := FUNCTION
    sv_count := COUNT(sv);
    features := COUNT(sv[1].features);
    RETURN sv_count * features;
  END;
  SHARED ML_Types.Layout_Model normSVFeatures(SVM.Types.SVM_SV s, SVM.Types.SVM_Feature f, UNSIGNED c) := TRANSFORM
    SELF.id := s.v_ord;
    SELF.number := c;
    SELF.value := f.v;
    SELF := [];
  END;
  SHARED cvt_sv(DATASET(SVM.Types.SVM_SV) sv) := FUNCTION
    RETURN NORMALIZE(sv, LEFT.features, normSVFeatures(LEFT, RIGHT, COUNTER));
  END;

  SHARED FromModelRow(UNSIGNED id_base = 1000, DATASET(SVM.Types.Model) mdl) := FUNCTION
    ML_Types.Layout_Model getField(SVM.Types.Model m, UNSIGNED c) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := c;
      SELF.value := CHOOSE(c, (REAL8) m.id, (REAL8) m.svmType,
                              (REAL8) m.kernelType, (REAL8) m.degree,
                              m.gamma, m.coef0, (REAL8) m.k, (REAL8) m.l,
                              (REAL8) m.scale, (REAL8) COUNT(m.scaleInfo)*2,
                              (REAL8) COUNT(m.probA), (REAL8) COUNT(m.probB),
                              (REAL8) COUNT(m.labels), (REAL8) get_SV_Count(m.sv));
    END;
    fixed_part := NORMALIZE(mdl, lf_id-field_id+1, getField(LEFT,COUNTER));
    ML_Types.Layout_Model normSV(SVM.Types.Model m, ML_Types.Layout_Model e, UNSIGNED8 c) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := lf_id + c;
      SELF.value  := e.value;
    END;
    sv_part := NORMALIZE(mdl, cvt_SV(LEFT.sv), normSV(LEFT, RIGHT, COUNTER));
    ML_Types.Layout_Model normMean(SVM.Types.Model m, SVM.Types.FeatureStats ft,
                                UNSIGNED8 c, UNSIGNED base) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value  := ft.mean;
    END;
    ML_Types.Layout_Model normSD(SVM.Types.Model m, SVM.Types.FeatureStats ft,
                                UNSIGNED8 c, UNSIGNED base) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value  := ft.sd;
    END;
    mean_part := NORMALIZE(mdl, LEFT.ScaleInfo,
                          normMean(LEFT, RIGHT, COUNTER,
                                 lf_id + get_SV_Count(LEFT.sv)));
    sd_part   := NORMALIZE(mdl, LEFT.ScaleInfo,
                          normSD(LEFT, RIGHT, COUNTER,
                                 lf_id + get_SV_Count(LEFT.sv) + COUNT(LEFT.ScaleInfo)));
    ML_Types.Layout_Model normR8(SVM.Types.Model m, SVM.Types.R8Entry d,
                                 UNSIGNED c, UNSIGNED4 base) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value := d.v;
    END;
    coef_part := NORMALIZE(mdl, LEFT.sv_coef,
                          normR8(LEFT, RIGHT, COUNTER,
                                 lf_id + get_SV_Count(LEFT.sv)
                                 + 2*COUNT(LEFT.ScaleInfo)));
    rho_part  := NORMALIZE(mdl, LEFT.rho,
                          normR8(LEFT, RIGHT, COUNTER,
                                lf_id + get_SV_Count(LEFT.sv)
                                + 2*COUNT(LEFT.ScaleInfo)
                                + COUNT(LEFT.sv_coef)));
    probA_part:= NORMALIZE(mdl, LEFT.probA,
                           normR8(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv)
                                  + 2*COUNT(LEFT.ScaleInfo)
                                  + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho)));
    probB_part:= NORMALIZE(mdl, LEFT.probB,
                           normR8(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv)
                                  + 2*COUNT(LEFT.ScaleInfo)
                                  + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho)
                                  + COUNT(LEFT.probA)));
    ML_Types.Layout_Model normI4(SVM.Types.Model m, SVM.Types.I4Entry d,
                                 UNSIGNED c, UNSIGNED4 base) := TRANSFORM
      SELF.wi := m.wi;
      SELF.id := id_base + m.id;
      SELF.number := base + c;
      SELF.value := (REAL8) d.v;
    END;
    lab_part  := NORMALIZE(mdl, LEFT.labels,
                           normI4(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv)
                                  + 2*COUNT(LEFT.ScaleInfo)
                                  + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho)
                                  + COUNT(LEFT.probA)
                                  + COUNT(LEFT.probB)));
    nsv_part  := NORMALIZE(mdl, LEFT.nSV,
                           normI4(LEFT, RIGHT, COUNTER,
                                  lf_id + get_SV_Count(LEFT.sv)
                                  + 2*COUNT(LEFT.ScaleInfo)
                                  + COUNT(LEFT.sv_coef)
                                  + COUNT(LEFT.rho)
                                  + COUNT(LEFT.probA)
                                  + COUNT(LEFT.probB)
                                  + COUNT(LEFT.Labels)));
    RETURN fixed_part
         + sv_part
         + mean_part
         + sd_part
         + coef_part
         + rho_part
         + probA_part
         + probB_part
         + lab_part
         + nsv_part;
  END;

  /**
   * Convert from SVM Model type to standardized Layout_Model format. The
   * Layout_Model format is harder to interpret, but more generalized.
   * @param id_base Base number from which to start model IDs (default: 1000).
   * @param mdl Object of SVM Model type (see SupportVectorMachines.Types).
   * @return Convert SVM model in Layout_Model format (see ML_Core.Types for
   * format definition).
   */
  EXPORT FromModel(UNSIGNED id_base = 1000, DATASET(SVM.Types.Model) mdl) := FUNCTION
    {UNSIGNED2 wi, INTEGER4 id, DATASET(ML_Types.Layout_Model) mdls} convertModel(SVM.Types.Model mdl) := TRANSFORM
      SELF.wi := mdl.wi;
      SELF.id := mdl.id;
      SELF.mdls := FromModelRow(id_base, PROJECT(DATASET(mdl), SVM.Types.Model));
    END;
    mdls_LM := PROJECT(mdl, convertModel(LEFT));
    mdls_LM_sort := SORT(mdls_LM, wi, id);

    ML_Types.Layout_Model combineMdls(ML_Types.Layout_Model mdl_LM) := TRANSFORM
      SELF := mdl_LM;
    END;
    rslt := NORMALIZE(mdls_LM, LEFT.mdls, combineMdls(RIGHT));
    RETURN rslt;
  END;


  SHARED Exp_NF := RECORD(ML_Types.NumericField)
    UNSIGNED feature;
    UNSIGNED vector;
  END;


  SHARED Exp_NF to_xnf(ML_Types.Layout_Model nf, UNSIGNED4 featureCnt) := TRANSFORM
    SELF.vector := ROUNDUP((nf.number - lf_id) / featureCnt);
    SELF.feature:= ((nf.number - lf_id - 1) % featureCnt) + 2;
    SELF := nf;
  END;
  SHARED SVM.Types.SVM_Feature makeFeature(Exp_NF d) := TRANSFORM
    SELF.nominal := d.feature;
    SELF.v := d.value;
  END;
  SHARED SVM.Types.SVM_SV roll_xnf(Exp_NF f, DATASET(Exp_NF) ds) := TRANSFORM
    SELF.v_ord := f.vector;
    SELF.features := PROJECT(ds, makeFeature(LEFT));
  END;
  SHARED toSV_Dataset(DATASET(ML_Types.Layout_Model) nf, UNSIGNED4 featureCnt) := FUNCTION
    marked_x := PROJECT(nf, to_xnf(LEFT, featureCnt));
    group_x := GROUP(marked_x, vector, LOCAL);
    rslt := ROLLUP(group_x, GROUP, roll_xnf(LEFT, ROWS(LEFT)));
    RETURN rslt;
  END;


  SHARED SVM.Types.R8Entry toR8(ML_Types.Layout_Model nf) := TRANSFORM
    SELF.v := nf.value;
  END;
  SHARED SVM.Types.I4Entry toI4(ML_Types.Layout_Model nf) := TRANSFORM
    SELF.v := (INTEGER) nf.value;
  END;

  SHARED toFeatStat_Dataset(
    DATASET(ML_Types.Layout_Model) means,
    DATASET(ML_Types.Layout_Model) sds) := FUNCTION

    numberStart := MIN(means, number);

    {INTEGER4 indx, REAL8 mean} renameMeans(ML_Types.Layout_Model lm) := TRANSFORM
      SELF.indx := lm.number - numberStart + 2;
      SELF.mean := lm.value;
    END;
    {REAL8 sd} renameSDs(ML_Types.Layout_Model lm) := TRANSFORM
      SELF.sd := lm.value;
    END;
    means_rn := PROJECT(means, renameMeans(LEFT));
    sds_rn := PROJECT(sds, renameSDs(LEFT));

    rslt := DATASET([{-1, 0.0, 1.0}], SVM.Types.FeatureStats)
      + COMBINE(means_rn, sds_rn);

    RETURN rslt;
  END;

  /**
   * Convert from standardized Layout_Model format (see ML_Core.Types) to
   * SVM Model format (see SupportVectorMachines.Types). The SVM model format
   * is less general, but easier to interpret.
   * @param mdl Trained SVM in Layout_Model format.
   * @return Converted SVM model in SVM Model format.
   */
  EXPORT ToModel(DATASET(ML_Types.Layout_Model) mdl) := FUNCTION
    mdl_grp := GROUP(SORTED(mdl, wi, id, number, ASSERT), wi, id);

    SVM.Types.Model rollModel(DATASET(ML_Types.Layout_Model) d) := TRANSFORM
      fixed := d(number<=lf_id);
      nsv := __COMMON__((UNSIGNED) fixed[n_sv_id].value);
      probA := __COMMON__((UNSIGNED) fixed[pairs_a_id].value);
      probB := __COMMON__((UNSIGNED) fixed[pairs_b_id].value);
      labels:= __COMMON__((UNSIGNED) fixed[n_label_id].value);
      k := __COMMON__((UNSIGNED) fixed[k_id].value);
      l := __COMMON__((UNSIGNED) fixed[l_id].value);
      scale := __COMMON__((BOOLEAN) fixed[scale_id].value);
      scaleInfo := __COMMON__((UNSIGNED) fixed[scaleInfo_id].value);
      sv_start := __COMMON__(lf_id + 1);
      sv_stop := __COMMON__(sv_start + nsv - 1);
      scaleInfo_start := __COMMON__(sv_stop + 1);
      scaleInfo_stop := __COMMON__(scaleInfo_start + scaleInfo - 1);
      coef_start := __COMMON__(scaleInfo_stop + 1);
      coef_stop := __COMMON__(coef_start + (k-1)*l - 1);
      rho_start := __COMMON__(coef_stop + 1);
      rho_stop := __COMMON__(rho_start + (k-1)*k/2 - 1);
      probA_start := __COMMON__(rho_stop + 1);
      probA_stop := __COMMON__(probA_start + probA - 1);
      probB_start := __COMMON__(probA_stop + 1);
      probB_stop := __COMMON__(probB_start + probB - 1);
      label_start := __COMMON__(probB_stop + 1);
      label_stop := __COMMON__(label_start + labels - 1);
      nSV_start := __COMMON__(label_stop + 1);
      nSV_stop := __COMMON__(nSV_start + labels - 1);
      SELF.wi := d[1].wi;
      SELF.id := (UNSIGNED) fixed[Field_ID].value;
      SELF.svmType := (UNSIGNED1) fixed[s_type_id].value;
      SELF.kernelType := (UNSIGNED1) fixed[k_type_id].value;
      SELF.degree := (UNSIGNED) fixed[degree_id].value;
      SELF.coef0 := fixed[coef0_id].value;
      SELF.gamma := fixed[gamma_id].value;
      SELF.k := k;
      SELF.l := l;
      SELF.scale := scale;
      SELF.scaleInfo := toFeatStat_Dataset(
        d(number BETWEEN scaleInfo_start + 1 AND scaleInfo_start + scaleInfo/2-1),
        d(number BETWEEN scaleInfo_start + scaleInfo/2 + 1 AND scaleInfo_stop)
      );
      SELF.sv := toSV_Dataset(d(number BETWEEN sv_start AND sv_stop), scaleInfo / 2 - 1);
      SELF.sv_coef := PROJECT(d(number BETWEEN coef_start AND coef_stop), toR8(LEFT));
      SELF.rho := PROJECT(d(number BETWEEN rho_start AND rho_stop), toR8(LEFT));
      SELF.probA := PROJECT(d(number BETWEEN probA_start AND probA_stop), toR8(LEFT));
      SELF.probB := PROJECT(d(number BETWEEN probB_start AND probB_stop), toR8(LEFT));
      SELF.labels:= PROJECT(d(number BETWEEN label_start AND label_stop), toI4(LEFT));
      SELF.nSV := PROJECT(d(number BETWEEN nSV_start AND nSV_stop), toI4(LEFT));
    END;
    rslt := ROLLUP(SORTED(mdl_grp, wi, id, number, ASSERT), GROUP, rollModel(ROWS(LEFT)));
    RETURN rslt;
  END;
END;