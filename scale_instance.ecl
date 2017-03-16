IMPORT $.Types;
//
SVM_Scale := Types.SVM_Scale;
SVM_Instance := Types.SVM_Instance;
SVM_Feature := Types.SVM_Feature;
Feature_Scale := Types.Feature_Scale;

EXPORT scale_instance(DATASET(SVM_Scale) f, DATASET(SVM_Instance) ds) := FUNCTION
  SVM_Feature scaleF(SVM_Feature f, Feature_Scale fs, REAL8 l, REAL8 u) := TRANSFORM
    SELF.v := MAP(f.v=fs.min_value    => l,
                  f.v=fs.max_value    => u,
                  l+(u-l)*(f.v-fs.min_value)/(fs.max_value-fs.min_value));
    SELF := f;
  END;
  SVM_Instance scaleI(SVM_Instance inst, SVM_Scale sc) := TRANSFORM
    newF := JOIN(inst.x, sc.features, LEFT.nominal=RIGHT.nominal,
                 scaleF(LEFT, RIGHT, sc.x_lower, sc.x_upper));
    newY := sc.y_lower+(sc.y_upper-sc.y_lower)*(inst.y-sc.y_min)/(sc.y_max-sc.y_min);
    SELF.max_value := MAX(newF, v);
    SELF.x := newF;
    SELF.y := MAP(inst.y=sc.y_min  => sc.y_lower,
                  inst.y=sc.y_max  => sc.y_upper,
                  newY);
    SELF := inst;
  END;
  rslt := JOIN(ds, f, TRUE, scaleI(LEFT,RIGHT), ALL);
  RETURN rslt;
END;