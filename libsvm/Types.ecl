// Types for the LibSVM and LibLINEAR implementations
EXPORT Types := MODULE
  //Interfqce for C++ wrappers, DO NOT ALTER BELOW WITHOUT CHANGING WRAPPERS
  EXPORT LibSVM_Output:= ENUM(UNSIGNED2, LABEL_ONLY=0, VALUES, PROBS);
  EXPORT LibSVM_Kernel:= ENUM(UNSIGNED2, LINEAR=0, POLY, RBF, SIGMOID, PRECOMPUTED);
  EXPORT LibSVM_Type := ENUM(UNSIGNED2, C_SVC=0, NU_SVC, ONE_CLASS, EPSILON_SVR, NU_SVR);
  EXPORT LibSVM_Node := RECORD  // Sparse 1 based and 0 based for pre-computed
    INTEGER4 indx;  // -1 indicates end of vector when in LibSVM problem format
    REAL8 value;
  END;
  EXPORT R8Entry := RECORD
    REAL8 v;
  END;
  EXPORT I4Entry := RECORD
    INTEGER4 v;
  END;
  EXPORT ECL_LibSVM_Problem := RECORD
    UNSIGNED4 elements;
    INTEGER4 entries;
    UNSIGNED4 features;
    REAL8 max_value;
    DATASET(R8Entry, COUNT(SELF.entries)) y;
    DATASET(LibSVM_Node, COUNT(SELF.elements)) x;
  END;
  EXPORT ECL_LibSVM_Parameter := RECORD
    LibSVM_Type svmType;
    LibSVM_Kernel kernelType;
    INTEGER4 degree;    // for Poly
    REAL8 gamma;        // for Poly, RBF, Sigmoid
    REAL8 coef0;        // for Poly, Sigmoid
  END;
  EXPORT ECL_LibSVM_Train_Param:= RECORD(ECL_LibSVM_Parameter)
    REAL8 cache_size;   // in MB
    REAL8 eps;          // epsilon for stopping
    REAL8 C;            // for C_SVC, EPSILON_SVR and nu_SVR
    REAL8 nu;           // for NU_SVC, ONE_CLASS, and NU_SVR
    REAL8 p;            // loss epsilon for EPISILON_SVR
    INTEGER4 nr_weight; // number of weights for C_SVC
    UNSIGNED2 shrinking;// shrinking heuristic if 1
    UNSIGNED2 prob_est; // do probability estimates
    DATASET(I4Entry, COUNT(SELF.nr_weight)) lbl;// weight labels for C_SVC
    DATASET(R8Entry, COUNT(SELF.nr_weight)) weight;// for C_SVC
  END;
  EXPORT ECL_LibSVM_Model := RECORD
    ECL_LibSVM_Parameter;
    UNSIGNED4 k;  // number of classes
    UNSIGNED4 l;  // number of support vectors
    UNSIGNED4 elements; // number of nodes
    UNSIGNED4 pairs_A; //k*(k-1)/2 or 0
    UNSIGNED4 pairs_B; //k*(k-1)/2 or 0
    UNSIGNED4 nr_label; //k or zero
    UNSIGNED4 nr_nSV; // k or 0
    DATASET(LibSVM_Node, COUNT(SELF.elements)) sv;
    DATASET(R8Entry, COUNT((SELF.k-1)*SELF.l)) sv_coef;
    DATASET(R8Entry, COUNT(SELF.k*(SELF.k-1)/2)) rho;
    DATASET(R8Entry, COUNT(SELF.pairs_A)) probA;
    DATASET(R8Entry, COUNT(SELF.pairs_B)) probB;
    DATASET(I4Entry, COUNT(SELF.nr_label)) labels;
    DATASET(I4Entry, COUNT(SELF.nr_nSV)) nSV;
  END;
  EXPORT CrossValidate_Result := RECORD
    REAL8   mse;
    REAL8   r_sq;
    REAL8   correct;
  END;
  //Interface for C++ wrappers, DO NOT ALTER ABOVE WITHOUT CHANGING WRAPPERS
  EXPORT SET OF UNSIGNED2 LibSVM_Version_set := [312,320];
END;
