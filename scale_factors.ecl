// Determine scaling factors for instance data
IMPORT $.Types;
EXPORT DATASET(Types.SVM_Scale)
       scale_factors(Types.Scale_Parms parms,
                     DATASET(Types.SVM_Instance) ds) := FUNCTION
  Types.SVM_Feature extractFeatures(Types.SVM_Feature rec) := TRANSFORM
    SELF := rec;
  END;
  features := NORMALIZE(ds, LEFT.x, extractFeatures(RIGHT));
  f_stats := TABLE(features, {STRING1 lbl:='1', nominal,
                              REAL8 mx_v := MAX(GROUP, v),
                              REAL8 mn_v:= MIN(GROUP, v)},
                  nominal, FEW, UNSORTED);
  l_stats := TABLE(ds, {STRING1 lbl:='1', REAL8 mx_v := MAX(GROUP,y),
                        REAL8 mn_v:=MIN(GROUP, y)},
                  FEW, UNSORTED);
  Types.Feature_Scale cvt(RECORDOF(f_stats) f) := TRANSFORM
    SELF.nominal := f.nominal;
    SELF.max_value := f.mx_v;
    SELF.min_value := f.mn_v;
  END;
  Types.SVM_Scale mrgData(RECORDOF(l_stats) l, DATASET(RECORDOF(f_stats)) f):=TRANSFORM
    SELF.y_max := l.mx_v;
    SELF.y_min := l.mn_v;
    SELF.features := PROJECT(f, cvt(LEFT));
    SELF := parms;
  END;
  f_grp := SORT(GROUP(f_stats(mx_v<>mn_v), lbl, ALL), nominal);
  rslt := DENORMALIZE(l_stats, f_grp, LEFT.lbl=RIGHT.lbl, GROUP,
                      mrgData(LEFT, ROWS(RIGHT)));
  RETURN rslt;
END;
