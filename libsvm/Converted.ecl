//Convert data to SVM_Problem format
//
//Sources include SVM Problem data from LibSVM sample data files,
//and ML NumericField format datasets.
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM.Types;
IMPORT SVM.Types AS SVM_Types;
IMPORT STD;
// aliases for shorter names
ECL_LibSVM_ProblemList := Types.ECL_LibSVM_ProblemList;
R8Entry := Types.R8Entry;
LibSVM_Node := Types.LibSVM_Node;
SVM_Feature := SVM_Types.SVM_Feature;
SVM_Instance := SVM_Types.SVM_Instance;
EXPORT Converted := MODULE
  // MAke Instance data from a text file in LibSVM test data format
  EXPORT DATASET(SVM_Instance) LIBSVMDATA2Instance(STRING fname):=FUNCTION
    svmread_format := RECORD
      STRING line;
      UNSIGNED8 fpos{VIRTUAL(fileposition)};
    END;
    StringEntry := RECORD
      STRING v;
    END;
    ds := DATASET(fname, svmread_format, CSV(SEPARATOR([])));
    // convert the file
    F_Plus := RECORD(SVM_Feature)
      BOOLEAN good;
      BOOLEAN flag;
    END;
    F_Plus makeFeature(STRING pair) := TRANSFORM
      pair_set := STD.Str.SplitWords(pair, ':');
      SELF.nominal := (INTEGER) pair_set[1];
      SELF.v:= (REAL8) pair_set[2];
      SELF.good := TRUE;
      SELF.flag := TRUE;  // distinguish first call to iterate
    END;
    F_Plus checkAscending(F_Plus prev, F_Plus curr) := TRANSFORM
      SELF.good := (NOT prev.flag AND curr.nominal >= 0)
                OR (curr.nominal >= 0 AND curr.nominal > prev.nominal);
      SELF := curr;
    END;
    STRING delims := ' \t\r\n';
    SVM_Instance cvtInstance(svmread_format lr) := TRANSFORM
      SELF.wi := 1;
      preped := STD.Str.substituteincluded(lr.line, delims, '|');
      elems := STD.Str.SplitWords(preped, '|');
      elems_ds := DATASET(elems, StringEntry);
      w_x0 := PROJECT(elems_ds[2..], makeFeature(LEFT.v));
      w_x1 := ITERATE(w_x0, checkAscending(LEFT,RIGHT));
      w_x2 := ASSERT(w_x1, good, 'Indx out of order, label ' + elems[1], FAIL);
      SELF.y := (REAL8)elems[1];
      SELF.max_value:= MAX(w_x2, v);
      SELF.x := PROJECT(w_x2, SVM_Feature);
      SELF.rid := lr.fpos;    // use the file position as identifier
    END;
    problem := PROJECT(ds, cvtInstance(LEFT));
    RETURN problem;
  END;
  //
  // Make a LibSVM Problem file from an Instance file.  This
  //will be a single record file.
  EXPORT DATASET(ECL_LibSVM_ProblemList)
         Instance2Problem(DATASET(SVM_Instance) ds) := FUNCTION
    LibSVM_Node lastNode() := TRANSFORM
      SELF.indx := -1;
      SELF.value := 0.0;
    END;
    LibSVM_Node cvtFeature(SVM_Feature feature) := TRANSFORM
      SELF.indx := feature.nominal;
      SELF.value := feature.v;
    END;
    ECL_LibSVM_ProblemList cvtInstance(SVM_Instance instance) := TRANSFORM
      SELF.wi := instance.wi;
      SELF.elements := COUNT(instance.x) + 1;  //include -1 row
      SELF.entries := 1;
      SELF.features := MAX(instance.x, nominal);
      SELF.max_value := instance.max_value;
      SELF.y := DATASET([{instance.y}], R8Entry);
      SELF.x := PROJECT(SORT(instance.x, nominal), cvtFeature(LEFT))
              & DATASET(1, lastNode());
    END;
    es := PROJECT(ds, cvtInstance(LEFT));
    ECL_LibSVM_ProblemList r(ECL_LibSVM_ProblemList l, DATASET(ECL_LibSVM_ProblemList) a):=TRANSFORM
      SELF.wi := l.wi;
      SELF.elements := SUM(a, elements);
      SELF.entries := SUM(a, entries);
      SELF.features:= MAX(a, features);
      SELF.max_value:= MAX(a, max_value);
      SELF.y := a.y;
      SELF.x := a.x;
    END;
    g_es := GROUP(SORT(es, wi), wi);
    prob := ROLLUP(g_es, GROUP, r(LEFT, ROWS(LEFT)));
    RETURN prob;
  END;
END;
