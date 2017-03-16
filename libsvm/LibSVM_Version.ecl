// The version from LibSVM
INTEGER4 getVersion() := BEGINC++
extern "C" {
  #include <libsvm/svm.h>
}
#option library svm
#option pure
#body
  return libsvm_version;
ENDC++;

EXPORT LibSVM_Version := getVersion();
