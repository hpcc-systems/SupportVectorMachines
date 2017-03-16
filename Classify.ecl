IMPORT $ as SVM;
IMPORT PBblas;
IMPORT ML_Core;
IMPORT ML_Core.Types as Types;

Layout_Cell := PBblas.Types.Layout_Cell;

/*
    The object of the classify module is to generate a classifier.
    A classifier is an 'equation' or 'algorithm' that allows the 'class' of an object to be imputed based upon other properties
    of an object.
*/

EXPORT Classify := MODULE

  SHARED l_result := Types.l_result;

  SHARED l_model := RECORD
    Types.t_RecordId    id := 0;      // A record-id - allows a model to have an ordered sequence of results
    Types.t_FieldNumber number;       // A reference to a feature (or field) in the independants
    Types.t_Discrete    class_number; // The field number of the dependant variable
    REAL8 w;
  END;

  EXPORT Compare(DATASET(Types.DiscreteField) Dep,DATASET(l_result) Computed) := MODULE
    DiffRec := RECORD
      Types.t_FieldNumber classifier;  // The classifier in question (value of 'number' on outcome data)
      Types.t_Discrete  c_actual;      // The value of c provided
      Types.t_Discrete  c_modeled;     // The value produced by the classifier
      Types.t_FieldReal score;         // Score allocated by classifier
    END;
    DiffRec  notediff(Computed le,Dep ri) := TRANSFORM
      SELF.c_actual := ri.value;
      SELF.c_modeled := le.value;
      SELF.score := le.conf;
      SELF.classifier := ri.number;
    END;
    SHARED J := JOIN(Computed,Dep,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,notediff(LEFT,RIGHT));
    // Building the Confusion Matrix
    SHARED ConfMatrix_Rec := RECORD
      Types.t_FieldNumber classifier; // The classifier in question (value of 'number' on outcome data)
      Types.t_Discrete c_actual;      // The value of c provided
      Types.t_Discrete c_modeled;     // The value produced by the classifier
      Types.t_FieldNumber Cnt:=0;     // Number of occurences
    END;
    SHARED class_cnt := TABLE(Dep,{classifier:= number, c_actual:= value, Cnt:= COUNT(GROUP)},number, value, FEW); // Looking for class values
    ConfMatrix_Rec form_cfmx(class_cnt le, class_cnt ri) := TRANSFORM
      SELF.classifier := le.classifier;
      SELF.c_actual:= le.c_actual;
      SELF.c_modeled:= ri.c_actual;
    END;
    SHARED cfmx := JOIN(class_cnt, class_cnt, LEFT.classifier = RIGHT.classifier, form_cfmx(LEFT, RIGHT)); // Initialzing the Confusion Matrix with 0 counts
    SHARED cross_raw := TABLE(J,{classifier,c_actual,c_modeled,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,FEW); // Counting ocurrences
    ConfMatrix_Rec form_confmatrix(ConfMatrix_Rec le, cross_raw ri) := TRANSFORM
      SELF.Cnt  := ri.Cnt;
      SELF      := le;
    END;
    //CrossAssignments, it returns information about actual and predicted classifications done by a classifier
    //                  also known as Confusion Matrix
    EXPORT CrossAssignments := JOIN(cfmx, cross_raw,
                                LEFT.classifier = RIGHT.classifier AND LEFT.c_actual = RIGHT.c_actual AND LEFT.c_modeled = RIGHT.c_modeled,
                                form_confmatrix(LEFT,RIGHT), LEFT OUTER, LOOKUP);
    //RecallByClass, it returns the proportion of instances belonging to a class that was correctly classified,
    //               also know as True positive rate and sensivity, TP/(TP+FN).
    EXPORT RecallByClass := SORT(TABLE(CrossAssignments, {classifier, c_actual, tp_rate := SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP,cnt)}, classifier, c_actual, FEW), classifier, c_actual);
    //PrecisionByClass, returns the proportion of instances classified as a class that really belong to this class: TP /(TP + FP).
    EXPORT PrecisionByClass := SORT(TABLE(CrossAssignments,{classifier,c_modeled, Precision := SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP,cnt)},classifier,c_modeled,FEW), classifier, c_modeled);
    //FP_Rate_ByClass, it returns the proportion of instances not belonging to a class that were incorrectly classified as this class,
    //                 also known as False Positive rate FP / (FP + TN).
    FalseRate_rec := RECORD
      Types.t_FieldNumber classifier; // The classifier in question (value of 'number' on outcome data)
      Types.t_Discrete c_modeled;     // The value produced by the classifier
      Types.t_FieldReal fp_rate;      // False Positive Rate
    END;
    wrong_modeled:= TABLE(CrossAssignments(c_modeled<>c_actual), {classifier, c_modeled, wcnt:= SUM(GROUP, cnt)}, classifier, c_modeled);
    j2:= JOIN(wrong_modeled, class_cnt, LEFT.classifier=RIGHT.classifier AND LEFT.c_modeled<>RIGHT.c_actual);
    allfalse:= TABLE(j2, {classifier, c_modeled, not_actual:= SUM(GROUP, cnt)}, classifier, c_modeled);
    EXPORT FP_Rate_ByClass := JOIN(wrong_modeled, allfalse, LEFT.classifier=RIGHT.classifier AND LEFT.c_modeled=RIGHT.c_modeled,
                            TRANSFORM(FalseRate_rec, SELF.fp_rate:= LEFT.wcnt/RIGHT.not_actual, SELF:= LEFT));
    // Accuracy, it returns the proportion of instances correctly classified (total, without class distinction)
    EXPORT Accuracy := TABLE(CrossAssignments, {classifier, Accuracy:= SUM(GROUP,IF(c_actual=c_modeled,cnt,0))/SUM(GROUP, cnt)}, classifier);
  END;

  EXPORT Default := MODULE,VIRTUAL
    EXPORT Base := 1000; // ID Base - all ids should be higher than this
    // Premise - two models can be combined by concatenating (in terms of ID number) the under-base and over-base parts
    SHARED CombineModels(DATASET(Types.NumericField) sofar,DATASET(Types.NumericField) new) := FUNCTION
      UBaseHigh := MAX(sofar(id<Base),id);
      High := IF(EXISTS(sofar),MAX(sofar,id),Base);
      UB := PROJECT(new(id<Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+UBaseHigh,SELF := LEFT));
      UO := PROJECT(new(id>=Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+High-Base,SELF := LEFT));
      RETURN sofar+UB+UO;
    END;
    // Learn from continuous data
    EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := DATASET([],Types.NumericField); // All classifiers serialized to numeric field format
    // Learn from discrete data - worst case - convert to continuous
    EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := LearnC(PROJECT(Indep,Types.NumericField),Dep);
    // Learn from continuous data - using a prebuilt model
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := DATASET([],l_result);
    // Classify discrete data - using a prebuilt model
    EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := ClassifyC(PROJECT(Indep,Types.NumericField),mod);
    EXPORT TestD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
      a := LearnD(Indep,Dep);
      res := ClassifyD(Indep,a);
      RETURN Compare(Dep,res);
    END;
    EXPORT TestC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
      a := LearnC(Indep,Dep);
      res := ClassifyC(Indep,a);
      RETURN Compare(Dep,res);
    END;
    EXPORT LearnDConcat(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep, LearnD fnc) := FUNCTION
      // Call fnc once for each dependency; concatenate the results
      // First get all the dependant numbers
      dn := DEDUP(Dep,number,ALL);
      Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
        RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
      END;
      RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
    END;
    EXPORT LearnCConcat(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep, LearnC fnc) := FUNCTION
      // Call fnc once for each dependency; concatenate the results
      // First get all the dependant numbers
      dn := DEDUP(Dep,number,ALL);
      Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
        RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
      END;
      RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
    END;
  END;

  // Support Vector Machine.
  // see https://en.wikipedia.org/wiki/Support_vector_machine
  // Use the SVM attributes directly for scaling and grid search.  This
  // module acts as a facade to the actual SVM attributes and provides only
  // the interface and capabilities defined for the Classify abstract.
  //
  // The inputs are:
  /*  svm_type : set type of SVM, SVM.Types.SVM_Type enum
              C_SVC    (multi-class classification)
              NU_SVC   (multi-class classification)
              ONE_CLASS SVM
              EPSILON_SVR  (regression)
              NU_SVR   (regression)
      kernel_type : set type of kernel function, SVM.Types.Kernel_Type enum
              LINEAR: u'*v
              POLY:   polynomial,  (gamma*u'*v + coef0)^degree
              RBF:    radial basis function: exp(-gamma*|u-v|^2)
              SIGMOID: tanh(gamma*u'*v + coef0)
              PRECOMPUTED: precomputed kernel (kernel values in training_set_file)
      degree : degree in kernel function for POLY
      gamma  : gamma in kernel function for POLY, RBF, and SIGMOID
      coef0  : coef0 in kernel function for POLY, SIGMOID
      cost   : the parameter C of C-SVC, epsilon-SVR, and nu-SVR
      eps    : the epsilon for stopping
      nu     : the parameter nu of nu-SVC, one-class SVM, and nu-SVR
      p      : the epsilon in loss function of epsilon-SVR
      shrinking : whether to use the shrinking heuristics, default TRUE
  */
  // The LibSVM development package must be installed on your cluster!
  EXPORT SVM(SVM.Types.SVM_Type svm_type, SVM.Types.Kernel_Type kernel_type,
             INTEGER4 degree, REAL8 gamma, REAL8 coef0, REAL8 cost, REAL8 eps,
             REAL8 nu, REAL8 p, BOOLEAN shrinking) := MODULE(DEFAULT)
    SVM.Types.Training_Parameters
    makeParm(UNSIGNED4 dep_field, SVM.Types.SVM_Type svm_type,
             SVM.Types.Kernel_Type kernel_type,
             INTEGER4 degree, REAL8 gamma, REAL8 coef0, REAL8 cost,
             REAL8 eps, REAL8 nu, REAL8 p, BOOLEAN shrinking) := TRANSFORM
      SELF.id := dep_field;
      SELF.svmType := svm_type;
      SELF.kernelType := kernel_type;
      SELF.degree := degree;
      SELF.gamma := gamma;
      SELF.coef0 := coef0;
      SELF.C := cost;
      SELF.eps := eps;
      SELF.nu := nu;
      SELF.p := p;
      SELF.shrinking := shrinking;
      SELF.prob_est := FALSE;
      SELF := [];
    END;
    SHARED Training_Param(UNSIGNED4 df) := ROW(makeParm(df, svm_type,
                                          kernel_type, degree,
                                          gamma, coef0, cost, eps, nu,
                                          p, shrinking));
    // Learn from continuous data
    EXPORT LearnC(DATASET(Types.NumericField) Indep,
                  DATASET(Types.DiscreteField) Dep) := FUNCTION
      depc := PROJECT(Dep, Types.NumericField);
      inst_data := SVM.Converted.ToInstance(Indep, Depc);
      dep_field := dep[1].number;
      tp := DATASET(Training_Param(dep_field));
      mdl := SVM.train(tp, inst_data);
      nf_mdl := SVM.Converted.FromModel(Base, mdl);
      RETURN nf_mdl; // All classifiers serialized to numeric field format
    END;
    // Learn from discrete data uses DEFAULT implementation
    // Classify continuous data - using a prebuilt model
    EXPORT ClassifyC(DATASET(Types.NumericField) Indep,
                     DATASET(Types.NumericField) mod) := FUNCTION
      inst_data := SVM.Converted.ToInstance(Indep);
      mdl := SVM.Converted.ToModel(mod);
      pred := SVM.predict(mdl, inst_data).Prediction;
      // convert to standard form
      l_result cvt(SVM.Types.SVM_Prediction p) := TRANSFORM
        SELF.wi := 1;
        SELF.id := p.rid;
        SELF.number := p.id; // model ID is the dependent var field ID
        SELF.value := p.predict_y;
        SELF.conf := 0.5; // no confidence measures
      END;
      rslt := PROJECT(pred, cvt(LEFT));
      RETURN rslt;
    END;
    // Classify discrete data - uses DEFAULT implementation
  END; // SVM

END;
