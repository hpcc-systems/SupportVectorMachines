//Generate a set of models in a grid search to establish C and gamma
IMPORT $ as SVM;
IMPORT $.Types;
IMPORT std.system.Thorlib;
//Aliases
G_Result := Types.GridSearch_Result;
Grid_Plan := Types.SVM_Grid_Plan;
Grid_Args := Types.SVM_Grid_Args;
T_Base := Types.Training_Base;
T_Parm := Types.Training_Parameters;
Inst := Types.SVM_Instance;
EXPORT grid_search(Grid_Plan plan, T_Base base, DATASET(Inst) d) := FUNCTION
  MyNodes := Thorlib.nodes();
  //only 1 step, use all the nodes, or use all nodes several times
  // FLOOR(((range_of_interest/max_incr)+nodes-1) DIV nodes) * nodes
  StepsNeeded(Grid_Args arg) :=
      MAP(arg.start=arg.stop      => 1,
          arg.max_incr=0.0        => (arg.stop-arg.start) DIV MyNodes,
          ((((arg.stop-arg.start)/arg.max_incr)+MyNodes-1) DIV MyNodes)*MyNodes);
  IncrNeeded(Grid_Args arg, UNSIGNED steps) := (arg.stop-arg.start) / steps;
  C_steps := StepsNeeded(plan.log2_C);
  C_Incr := IncrNeeded(plan.log2_C, C_steps);
  gamma_steps := StepsNeeded(plan.log2_gamma);
  gamma_incr := IncrNeeded(plan.log2_gamma, gamma_steps);
  search_steps := C_steps * gamma_steps;
  T_Parm makeParm(Grid_Plan plan, T_Base base, UNSIGNED c) := TRANSFORM
    SELF.id := c;
    SELF.C := POWER(2,plan.log2_C.start + (((c-1) DIV gamma_steps)*C_incr));
    SELF.gamma := POWER(2,plan.log2_gamma.start+(((c-1)%gamma_steps)*gamma_incr));
    SELF := base;
  END;
  parms := DATASET(search_steps, makeParm(plan, base, COUNTER), DISTRIBUTED);
  rslt := SVM.cross_validate(parms, d, plan.folds);
  RETURN rslt;
END;