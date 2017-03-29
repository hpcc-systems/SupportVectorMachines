// Create a model from training data
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM.Types;
IMPORT SVM.LibSVM.Constants;
IMPORT SVM.LibSVM.Converted;
// aliases
ECL_LibSVM_Model := Types.ECL_LibSVM_Model;
Problem := Types.ECL_LibSVM_Problem;
SVM_Parms := Types.ECL_LibSVM_Train_Param;
ErrCode := Constants.LibSVM_BadParm;
DATA svm_train_d(SVM_Parms prm,
                 Problem prb,
                 UNSIGNED4 err_code=ErrCode) := BEGINC++
  extern "C" {
    #include <libsvm/svm.h>
  }
  #if (LIBSVM_VERSION < 300 || LIBSVM_VERSION > 399)
  #error Installed LibSVM version not known to be compatible
  #endif
  #ifndef ECL_LIBSVM_TRAIN_PARAM
  #define ECL_LIBSVM_TRAIN_PARAM
    typedef struct __attribute__ ((__packed__)) ecl_svm_parameter {
      unsigned short svm_type;
      unsigned short kernel_type;
      int degree;
      double gamma;
      double coef0;
      double cache_size;
      double eps;
      double C;
      double nu;
      double p;
      int nr_weight;
      unsigned short shrinking;
      unsigned short prob_est;   // array of int and array of double follows
    };
  #endif
  #ifndef ECL_SVM_PROBLEM
  #define ECL_SVM_PROBLEM
    typedef struct __attribute__ ((__packed__)) ecl_svm_problem {
      unsigned int elements;
      int entries;
      unsigned int features;
      double max_value;  // array of double and array of svm_node follow
    };
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
    struct __attribute__ ((__packed__)) Packed_SVM_Model {
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
  // convert ecl problem into svm problem structures
  const ecl_svm_problem* ecl_problem = (ecl_svm_problem*) prb;
  size_t len_base = sizeof(ecl_svm_problem);
  const double * ecl_problem_y = (double*)(prb+len_base);
  size_t len_y = ecl_problem->entries*sizeof(double);
  const Packed_SVM_Node* in_nodes = (Packed_SVM_Node*)(prb+len_y+len_base);
  size_t len_x_nodes = ecl_problem->elements*sizeof(svm_node);
  struct svm_problem problem;
  problem.l = ecl_problem->entries;
  problem.y = (double*) rtlMalloc(len_y);
  memcpy(problem.y, ecl_problem_y, len_y);
  problem.x = (svm_node**) rtlMalloc(problem.l*sizeof(svm_node*));
  svm_node* all_x = (svm_node*)rtlMalloc(len_x_nodes);
  for (uint32_t i=0; i<ecl_problem->elements; i++) {
    all_x[i].index = in_nodes[i].indx;
    all_x[i].value = in_nodes[i].value;
  }
  uint32_t next_node = 0;
  for (int32_t k=0; k<problem.l; k++) {
    problem.x[k] = &(all_x[next_node]);
    while (next_node<ecl_problem->elements && all_x[next_node++].index != -1);
  }
  //
  // Convert ecl parameter block to svm_parameter
  const ecl_svm_parameter* ecl_parms = (ecl_svm_parameter*) prm;
  struct svm_parameter parameter;
  parameter.svm_type = ecl_parms->svm_type;
  parameter.kernel_type = ecl_parms->kernel_type;
  parameter.degree = ecl_parms->degree;
  parameter.gamma = (ecl_parms->gamma==0.0 && ecl_problem->features>0)
                  ? 1.0/ecl_problem->features
                  : ecl_parms->gamma;
  parameter.coef0 = ecl_parms->coef0;
  parameter.cache_size = ecl_parms->cache_size;
  parameter.eps = ecl_parms->eps;
  parameter.C = ecl_parms->C;
  parameter.nr_weight = ecl_parms->nr_weight;
  parameter.nu = ecl_parms->nu;
  parameter.p = ecl_parms->p;
  parameter.shrinking = ecl_parms->shrinking;
  parameter.probability = ecl_parms->prob_est;
  size_t len_weight_labels = ecl_parms->nr_weight*sizeof(int);
  parameter.weight_label = (int*) rtlMalloc(len_weight_labels);
  const byte* prm_weight_labels = prm+sizeof(ecl_svm_problem);
  memcpy(parameter.weight_label, prm_weight_labels,len_weight_labels);
  size_t len_weights = ecl_parms->nr_weight * sizeof(double);
  parameter.weight = (double*) rtlMalloc(len_weights);
  const byte* prm_weights = prm_weight_labels + len_weight_labels;
  memcpy(parameter.weight, prm_weights, len_weights);
  //
  // check parameters
  const char * err_msg = svm_check_parameter(&problem, &parameter);
  if (err_msg) rtlFail(err_code, err_msg);
  //
  // determine model
  struct svm_model* model;
  model = svm_train(&problem, &parameter);
  //
  // Setup results
  size_t elements = 0;
  if (model->param.kernel_type == PRECOMPUTED) elements = 2*model->l;
  else for (int i=0; i<model->l; i++) {
    svm_node* p = model->SV[i];
    int j = 0;
    elements++; // account for the -1 entry
    while (p[j++].index != -1) elements++;
  }
  size_t num_coef = (model->nr_class-1) * model->l;
  size_t num_pairs = model->nr_class * (model->nr_class-1)/2;//rho
  size_t num_probA = (model->probA) ? num_pairs  : 0;
  size_t num_probB = (model->probB) ? num_pairs  : 0;
  size_t num_doubles = num_coef + num_pairs + num_probA + num_probB;
  size_t num_nSV = (model->nSV) ? model->nr_class  : 0;
  size_t num_label = (model->label) ? model->nr_class : 0;
  size_t num_ints = num_nSV + num_label;
  size_t sz = num_doubles*sizeof(double) + elements*sizeof(Packed_SVM_Node)
            + num_ints*sizeof(int) + sizeof(Packed_SVM_Model);
  __lenResult = sz;
  __result = rtlMalloc(sz);
  Packed_SVM_Model* outModel = (Packed_SVM_Model*) __result;
  outModel->svm_type = model->param.svm_type;
  outModel->kernel_type = model->param.kernel_type;
  outModel->degree = model->param.degree;
  outModel->gamma = model->param.gamma;
  outModel->coef0 = model->param.coef0;
  outModel->k = model->nr_class;
  outModel->l = model->l;
  outModel->elements = elements;
  outModel->pairs_A = num_probA;
  outModel->pairs_B = num_probB;
  outModel->nr_label = num_label;
  outModel->nr_nSV = num_nSV;
  Packed_SVM_Node* sv_array = (Packed_SVM_Node*) (outModel+1);
  int sv_pos = 0;
  for (int i=0; i<model->l; i++) {
    if (model->param.kernel_type == PRECOMPUTED) {
      sv_array[sv_pos].indx  = 0;
      sv_array[sv_pos].value = (int) model->SV[i][0].value;
      sv_pos++;
    } else {
      for (int j=0; model->SV[i][j].index>0; j++) {
        sv_array[sv_pos].indx  = model->SV[i][j].index;
        sv_array[sv_pos].value = model->SV[i][j].value;
        sv_pos++;
      }
    }
    sv_array[sv_pos].indx = -1;
    sv_array[sv_pos].value = 0.0;
    sv_pos++;
  }
  double* sv_coef = (double*) (sv_array + elements);
  for (int i=0; i<model->nr_class-1; i++) {
    for (int j=0; j<model->l; j++) {
      sv_coef[((model->l)*i)+j] = model->sv_coef[i][j];
    }
   }
  //
  double* rho = sv_coef + num_coef;
  memcpy(rho, model->rho, num_pairs*sizeof(double));
  //
  double* probA = rho + num_pairs;
  memcpy(probA, model->probA, num_probA * sizeof(double));
  //
  double* probB = probA + num_probA;
  memcpy(probB, model->probB, num_probB * sizeof(double));
  //
  int * label = (int*) (probB + num_probB);
  memcpy(label, model->label, num_label * sizeof(int));
  //
  int* nSV = label + num_label;
  memcpy(nSV, model->nSV, num_nSV * sizeof(int));
  //
  //free work areas and return
  svm_free_and_destroy_model(&model);
  svm_destroy_param(&parameter);  // frees weight data
  free(problem.y);
  free(problem.x);
  free(all_x);
ENDC++;

EXPORT ECL_LibSVM_Model SVMTrain(SVM_Parms prm, Problem prb)
            := TRANSFER(svm_train_d(prm, prb), ECL_LibSVM_Model);
