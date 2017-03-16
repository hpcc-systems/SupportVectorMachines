// Predict Y for a vector
// Create a model from training data
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM.Types;
IMPORT SVM.LibSVM.Constants;
IMPORT SVM.LibSVM.Converted;
// aliases
Model := Types.ECL_LibSVM_Model;
Node  := Types.LibSVM_Node;
Rqst  := Types.LibSVM_Output;
ErrCode := Constants.LibSVM_BadParm;
R8Entry := Types.R8Entry;
EXPORT DATASET(R8Entry) svm_predict(Model ecl_model, DATASET(Node) ecl_nodes,
                                    Rqst output_request ) := BEGINC++
  extern "C" {
    #include <libsvm/svm.h>
  }
  #if (LIBSVM_VERSION < 300 || LIBSVM_VERSION > 399)
  #error Installed LibSVM version not known to be compatible
  #endif
    #ifndef ECL_SVM_NODE
    #define ECL_SVM_NODE
    typedef struct __attribute__ ((__packed__))  Packed_SVM_Node {
      int indx;
      double value;
    };
  #endif
  #ifndef ECL_SVM_MODEL
  #define ECL_SVM_MODEL
    typedef struct __attribute__ ((__packed__)) Packed_SVM_Model {
      unsigned short svm_type;
      unsigned short kernel_type;
      int degree;
      double gamma;
      double coef0;
      unsigned int k;   // number classes
      unsigned int l;   // number of support vectors
      unsigned int elements; // number of elements
      unsigned int pairs_A; // prob A pairs or zero
      unsigned int pairs_B; // prob B pairs or zero
      unsigned int nr_label; // number of labels, 0
      unsigned int nr_nSV; // number of support vector inx, 0
    }; // Packed arrays follow.
  #endif
  #option library svm
  #body
  //Convert into LibSVM formats, first the x vector
  const Packed_SVM_Node* in_node = (Packed_SVM_Node*) ecl_nodes;
  uint32_t obs = lenEcl_nodes/sizeof(Packed_SVM_Node); // includes -1 entry
  struct svm_node* x = (struct svm_node*) malloc(obs*sizeof(struct svm_node));
  for (uint32_t i=0; i<obs; i++) {
    x[i].index = in_node[i].indx;
    x[i].value = in_node[i].value;
  }
  // now the model
  const Packed_SVM_Model* in_mdl = (Packed_SVM_Model*) ecl_model;
  struct svm_model* mdl = (struct svm_model*) malloc(sizeof(struct svm_model));
  mdl->free_sv = 0;
  mdl->param.svm_type = in_mdl->svm_type;
  mdl->param.kernel_type = in_mdl->kernel_type;
  mdl->param.degree = in_mdl->degree;
  mdl->param.gamma = in_mdl->gamma;
  mdl->param.coef0 = in_mdl->coef0;
  mdl->nr_class = in_mdl->k;
  mdl->l = in_mdl->l;
  // SV
  int elements = in_mdl->elements;
  struct svm_node* x_all = (struct svm_node*) NULL;
  const Packed_SVM_Node* sv_in = (Packed_SVM_Node*) (in_mdl+1);
  mdl->SV = (struct svm_node **) malloc(in_mdl->l*sizeof(struct svm_node *));
  int curr_sv = 0;
  size_t len_x_nodes = elements*sizeof(struct svm_node);
  x_all = (struct svm_node*) malloc(len_x_nodes);
  mdl->SV[0] = x_all;
  x_all[0].index = sv_in[0].indx;
  x_all[0].value = sv_in[0].value;
  for (int i=1; i<elements; i++) {
    if (sv_in[i-1].indx == -1) mdl->SV[++curr_sv] = x_all+i;
    x_all[i].index = sv_in[i].indx;
    x_all[i].value = sv_in[i].value;
  }
  // coef
  const double* sv_coef = (double*) (sv_in + elements);
  size_t num_coef = (in_mdl->k-1) * in_mdl->l;
  mdl->sv_coef = (double**) malloc((in_mdl->k-1)*sizeof(double*));
  for (uint32_t i=0; i<in_mdl->k-1; i++) {
    mdl->sv_coef[i] = (double*) malloc(in_mdl->l*sizeof(double));
    for (uint32_t j=0; j<in_mdl->l; j++) {
      mdl->sv_coef[i][j] = sv_coef[((in_mdl->l)*i)+j];
    }
  }
  // rho
  const double* rho = sv_coef + num_coef;
  size_t num_pairs = in_mdl->k * (in_mdl->k-1)/2;//rho
  mdl->rho = (double*) malloc(num_pairs*sizeof(double));
  memcpy(mdl->rho, rho, num_pairs*sizeof(double));
  // ProbA
  const double* probA = rho + num_pairs;
  if (in_mdl->pairs_A > 0) {
    mdl->probA = (double*) malloc(in_mdl->pairs_A*sizeof(double));
    memcpy(mdl->probA, probA, in_mdl->pairs_A*sizeof(double));
  } else mdl->probA = (double*) NULL;
  // ProbB
  const double* probB = probA + in_mdl->pairs_A;
  if (in_mdl->pairs_B > 0) {
    mdl->probB = (double*) malloc(in_mdl->pairs_B*sizeof(double));
    memcpy(mdl->probB, probB, in_mdl->pairs_B*sizeof(double));
  } else mdl->probB = (double*) NULL;
  // label
  const int * label = (int*) (probB + in_mdl->pairs_B);
  if (in_mdl->nr_label>0) {
    mdl->label = (int*) malloc(in_mdl->nr_label*sizeof(int));
    memcpy(mdl->label, label, in_mdl->nr_label*sizeof(int));
  } else mdl->label = (int*) NULL;
  // nSV
  const int * nSV = label + in_mdl->nr_label;
  if (in_mdl->nr_nSV > 0) {
    mdl->nSV = (int*) malloc(in_mdl->nr_nSV*sizeof(int));
    memcpy(mdl->nSV, nSV, in_mdl->nr_nSV*sizeof(int));
  } else mdl->nSV = (int*) NULL;
  // get prediction
  // first, determine number of answers
  int answers;
  if (output_request==1) { // values
    if (in_mdl->svm_type==ONE_CLASS
      ||in_mdl->svm_type==EPSILON_SVR
      ||in_mdl->svm_type==NU_SVR) answers=2;
    else answers = 1 + (in_mdl->k * (in_mdl->k-1)/2);
  } else if (output_request==2) { // probability
    switch (in_mdl->svm_type) {
      case C_SVC:
      case NU_SVC:
        if (probA && probB) answers = 1 + in_mdl->k;
        else answers = 1;
        break;
      case EPSILON_SVR:
      case NU_SVR:
        if (probA) answers = 2;
        else answers = 1;
        break;
      default:
        answers = 1;
        break;
    }
  } else answers=1;
  __lenResult = answers * sizeof(double);
  __result = rtlMalloc(__lenResult);
  double* rslt = (double*) __result;
  if (answers==1) rslt[0] = svm_predict(mdl, x);
  else if (output_request==1) rslt[0] = svm_predict_values(mdl, x, rslt+1);
  else rslt[0] = svm_predict_probability(mdl, x, rslt+1);
  // Free work areas
  if (mdl->label) free(mdl->label);
  //if (mdl->sv_indices) free(mdl->sv_indices);
  if (mdl->probB) free(mdl->probB);
  if (mdl->probA) free(mdl->probA);
  free(mdl->rho);
  for (int i=0; i<mdl->nr_class-1; i++) free(mdl->sv_coef[i]);
  free(mdl->sv_coef);
  free(mdl->SV);
  free(x_all);
  free(mdl);
  free(x);
  // all done
ENDC++;
