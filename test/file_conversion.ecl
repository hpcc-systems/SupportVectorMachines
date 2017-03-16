//Check the file conversion routines
//export file_conversion := 'todo';
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM;

ECL_LibSVM_Problem := LibSVM.Types.ECL_LibSVM_Problem;
LibSVM_Node := LibSVM.Types.LibSVM_Node;
R8Entry := LibSVM.Types.R8Entry;
fileName := '~thor::libsvm_data::heart_scale_csv';
rawInput := DATASET(fileName, {STRING line}, CSV(SEPARATOR([])));
OUTPUT(CHOOSEN(rawInput, 300), ALL, NAMED('raw_input'));

instance_data := LibSVM.Converted.LIBSVMDATA2Instance(fileName);
OUTPUT(CHOOSEN(instance_data, 300), ALL, NAMED('Instance_data'));

problem_data := LibSVM.Converted.Instance2Problem(instance_data);


LibSVM_Node_Exp := RECORD(LibSVM_Node)
  UNSIGNED4 entry;
END;
LibSVM_Node_Exp cvt(LibSVM_Node n) := TRANSFORM
  SELF.entry := 0;
  SELF := n;
END;
LibSVM_Node_Exp mark(LibSVM_Node_Exp prev, LibSVM_Node_Exp curr) := TRANSFORM
  newEntry := prev.entry=0 OR prev.indx=-1;
  SELF.entry := IF(newEntry, prev.entry+1, prev.entry);
  SELF := curr;
END;
Expanded_Prob := RECORD
    UNSIGNED4 elements;
    INTEGER4 entries;
    UNSIGNED4 features;
    REAL8 max_value;
    DATASET(R8Entry, COUNT(SELF.entries)) y;
    DATASET(LibSVM_Node_Exp, COUNT(SELF.elements)) x;
END;
Expanded_Prob expand(ECL_LibSVM_Problem p) := TRANSFORM
  SELF.x := ITERATE(PROJECT(p.x,cvt(LEFT)), mark(LEFT,RIGHT));
  SELF := p;
END;
xproblem_data := PROJECT(problem_data, expand(LEFT));
OUTPUT(xproblem_data, NAMED('Problem_Data'));

// Decompose problem data for easier display
Head_Prob := RECORD
  UNSIGNED4 elements;
  INTEGER4 entries;
  UNSIGNED4 features;
  REAL8 max_value;
END;
Flat_Prob := RECORD
  UNSIGNED4 entry;
  UNSIGNED4 elements;
  REAL8 y;
  DATASET(LibSVM_Node, COUNT(SELF.elements)) x;
END;
Head_Prob extHead(Expanded_Prob p) := TRANSFORM
  SELF := p;
END;
problem_head := PROJECT(xproblem_data, extHead(LEFT));
OUTPUT(problem_head, NAMED('problem_head'));

Flat_Prob extNode(Expanded_Prob p, UNSIGNED4 c) := TRANSFORM
  these_elements := p.x(entry=c);
  SELF.entry := c;
  SELF.y := p.y[c].v;
  SELF.elements := COUNT(these_elements);
  SELF.x := PROJECT(these_elements, LibSVM_Node);
END;
prob_lines := NORMALIZE(xproblem_data, LEFT.entries, extNode(LEFT,COUNTER));
OUTPUT(CHOOSEN(prob_lines, 300), ALL, NAMED('prob_lines'));
