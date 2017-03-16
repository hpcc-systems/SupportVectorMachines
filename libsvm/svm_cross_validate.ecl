//
IMPORT $.^ as SVM;
IMPORT SVM.LibSVM.Types;
IMPORT SVM.LibSVM.Constants;
IMPORT SVM.LibSVM.Converted;
// aliases
Result := Types.CrossValidate_Result;
Problem := Types.ECL_LibSVM_Problem;
SVM_Parms := Types.ECL_LibSVM_Train_Param;
ErrCode := Constants.LibSVM_BadParm;
EXPORT Result svm_cross_validate(SVM_Parms prm,
                                 Problem prb,
                                 UNSIGNED2 nr_fold,
                                 UNSIGNED4 err_code=ErrCode) := BEGINC++
    extern "C" {
      #include <libsvm/svm.h>
    }
    #if (LIBSVM_VERSION < 300 || LIBSVM_VERSION > 399)
    #error Installed LibSVM version not known to be compatible
    #endif
    #ifndef ECL_LIBSVM_TRAIN_PARAM
    #define ECL_LIBSVM_TRAIN_PARAM
      struct __attribute__ ((__packed__)) ecl_svm_parameter {
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
      struct __attribute__ ((__packed__)) ecl_svm_problem {
        unsigned int elements;
        int entries;
        unsigned int features;
        double max_value;  // array of double and array of svm_node follow
      };
    #endif
    #ifndef ECL_SVM_NODE
    #define ECL_SVM_NODE
      struct __attribute__ ((__packed__))  Packed_SVM_Node {
        int indx;
        double value;
      };
    #endif
    #ifndef ECL_CROSSVALIDATE_RESULT
    #define ECL_CROSSVALIDATE_RESULT
      struct CrossValidate_Result {
        double mse;
        double r_sq;
        double correct;
      };
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
    // Setup results
    CrossValidate_Result *p = (CrossValidate_Result*) __result;
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
    // check parameters
    const char * err_msg = svm_check_parameter(&problem, &parameter);
    if (err_msg) rtlFail(err_code, err_msg);
    // call LibSVM cross validate and summarize results
    int total_correct = 0;
    double tot_sq_err = 0.0;
    double* target = (double*) rtlMalloc(ecl_problem->entries*sizeof(double));
    double sumv = 0.0, sumy = 0.0, sumvv = 0.0, sumyy = 0.0, sumvy = 0.0;
    svm_cross_validation(&problem,&parameter,nr_fold,target);
    for (int i=0; i<problem.l; i++) {
      if (target[i]==ecl_problem_y[i]) total_correct++;
      tot_sq_err += (target[i]-ecl_problem_y[i])*(target[i]-ecl_problem_y[i]);
      sumv += target[i];
      sumy += ecl_problem_y[i];
      sumvv += target[i]*target[i];
      sumyy += ecl_problem_y[i]*ecl_problem_y[i];
      sumvy += target[i]*ecl_problem_y[i];
    }
    p->correct = 100.0 * total_correct / problem.l;
    p->mse = tot_sq_err / problem.l;
    p->r_sq = ((problem.l*sumvy-sumv*sumy)*(problem.l*sumvy-sumv*sumy))
            / ((problem.l*sumvv-sumv*sumv)*(problem.l*sumyy-sumy*sumy));
    //
    //free work areas and return
    svm_destroy_param(&parameter);  // frees weight data
    free(target);
    free(problem.y);
    free(problem.x);
    free(all_x);
  ENDC++;
