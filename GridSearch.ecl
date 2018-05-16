// Generate a set of models in a grid search to establish C and gamma
IMPORT $ as SVM;
IMPORT SVM.Types;
IMPORT std.system.Thorlib;
IMPORT ML_Core.Types as ML_Types;

// Aliases
G_Result := Types.GridSearch_Result;
XV_Result := Types.CrossValidate_Result;
Grid_Plan := Types.SVM_Grid_Plan;
Grid_Args := Types.SVM_Grid_Args;
T_Base := Types.Training_Base;
T_Parm := Types.Training_Parameters;
Instance := Types.SVM_Instance;

/**
  * Perform grid search over parameters gamma and C. The grid resolution is increased
  * automatically to utilize any otherwise idle nodes.
  * For a single given set of model parameters, models can be tuned to a number of datasets
  * by concatenating multiple datasets into single 'observations' and 'actuals'
  * datasets, with separate datasets being identified by a work ID column, 'wi'.
  *
  * @internal
  * @param plan A structure defining preferences for the grid resolution and number of CV
  * folds used in evaluation of candidate models.  In SVM_Grid_Plan format.
  * @param base The fixed model parameters (those other than gamma and C) in Training_Base
  *             format.
  * @param observations The observed explanatory values in NumericField format.
  * @param actuals The observed dependent varible(s) used to build the model(s) in NumericField
  *                format.
  * @return Dataset with sets of model parameters and corresponding cross-validated scores in
  *         GridSearch_Result format.
  * @see Types.SVM_Grid_Plan
  * @see Types.Training_Base
  * @see ML_Core.Types.NumericField
  * @see Types.GridSearch_Result
  */
EXPORT GridSearch(
  Grid_Plan plan  = Types.SVM_Grid_Plan_Default,
  T_Base base     = Types.Training_Base_Default,
  DATASET(ML_Types.NumericField) observations,
  DATASET(ML_Types.NumericField) actuals) := FUNCTION
  MyNodes := Thorlib.nodes();

  // Get base number of steps
  StepsInitial(Grid_Args args) := MAP(
    args.start = args.stop  => 1,
    args.max_incr = 0.0    => 10,
    ROUNDUP((args.stop - args.start) / args.max_incr + 1)
  );
  C_steps_ini := StepsInitial(plan.log2_C);
  gamma_steps_ini := StepsInitial(plan.log2_gamma);

  // Get the optimal number of grid points we want to send to each node
  pointsPerNode_opt := ROUNDUP(C_steps_ini * gamma_steps_ini / MyNodes);

  // Calculate the first approximately optimal step number for each dimension
  C_steps_opt1 := TRUNCATE(SQRT(pointsPerNode_opt * MyNodes * C_steps_ini / gamma_steps_ini));
  gamma_steps_opt1 := TRUNCATE(pointsPerNode_opt * MyNodes / C_steps_opt1);

  // Round step numbers down to get integers and find number of utilised nodes
  NodesUsed_opt1 := C_steps_opt1 * gamma_steps_opt1;

  // Determine how best to fill remaining nodes by incrementing steps.
  // We know that +1 to both steps is too much as it will exceed the next
  // multiple of the number of nodes.
  // So we can either:
  //   - do nothing if incrementing either steps exceeds the
  //     next multiple of the number of nodes
  //   - add one to the smaller of stepsC and stepsG (this increases
  //     the number of utilized nodes by the size of the larger of
  //     stepsC and stepsG)
  //   - Add n to the larger of stepsC and stepsG, where n is 1 or
  //     higher (this will increase the number of utilized nodes by
  //     n times the size of the smaller of stepsC and stepsG)

  // Can we do anything better?
  FreeNodes := pointsPerNode_opt * MyNodes - NodesUsed_opt1; // how many nodes are unaccounted for?

  // Check if we can increment either steps without exceeding max number of nodes
  CanIncrease_gamma := FreeNodes >= C_steps_opt1;
  CanIncrease_C := FreeNodes >= gamma_steps_opt1;

  steps_opt2 := MAP(
    // If we can increase either stepsC or stepsG without exceeding, increase the one
    // which has been increased by the least as a proportion of its initial value.
    CanIncrease_gamma AND CanIncrease_C AND ((C_steps_opt1 / C_steps_ini) < (gamma_steps_opt1 / gamma_steps_ini)) =>
      [TRUNCATE(FreeNodes / gamma_steps_opt1) + C_steps_opt1, gamma_steps_opt1],
    CanIncrease_gamma =>
      [C_steps_opt1, TRUNCATE(FreeNodes / C_steps_opt1) + gamma_steps_opt1],
    CanIncrease_C =>
      [TRUNCATE(FreeNodes / gamma_steps_opt1) + C_steps_opt1, gamma_steps_opt1],
      [C_steps_opt1, gamma_steps_opt1]
  );
  C_steps_opt2 := steps_opt2[1];
  gamma_steps_opt2 := steps_opt2[2];

  // Get optimal increment size
  IncrNeeded(Grid_Args arg, UNSIGNED steps) := (arg.stop-arg.start) / (steps - 1);
  C_incr_opt2 := IncrNeeded(plan.log2_C, C_steps_opt2);
  gamma_incr_opt2 := IncrNeeded(plan.log2_gamma, gamma_steps_opt2);

  // Create grid search training parameters
  search_steps := C_steps_opt2 * gamma_steps_opt2;
  T_Parm initParm(Grid_Plan plan, T_Base base, UNSIGNED c) := TRANSFORM
    SELF.id := c;
    SELF.wi := 0;
    SELF.C := POWER(2,plan.log2_C.start + (TRUNCATE((c-1)/gamma_steps_opt2)*C_incr_opt2));
    SELF.gamma := POWER(2,plan.log2_gamma.start+(((c-1)%gamma_steps_opt2)*gamma_incr_opt2));
    SELF := base;
  END;
  parmsInit := DATASET(search_steps, initParm(plan, base, COUNTER), DISTRIBUTED);

  {UNSIGNED2 wi} distinctWI(ML_Types.NumericField firstRow, DATASET(ML_Types.NumericField) grp):=TRANSFORM
    SELF.wi := firstRow.wi;
  END;
  act_grpd := GROUP(SORT(actuals, wi), wi);
  WIs := ROLLUP(act_grpd, GROUP, distinctWI(LEFT, ROWS(LEFT)));

  T_Parm makeParm(T_Parm p, {UNSIGNED2 wi} WIs) := TRANSFORM
    SELF.wi := WIs.wi;
    SELF := p;
  END;
  parms := JOIN(parmsInit, WIs, TRUE, makeParm(LEFT, RIGHT), ALL);

  // Run distributed cross-validation to evaluate model at grid points
  rslt := SVM.CrossValidate(parms, observations, actuals, plan.folds);

  G_Result getGridResult(T_Parm p, XV_Result cv) := TRANSFORM
    SELF := p;
    SELF := cv;
  END;

  rslt_parms := JOIN(parms, rslt, LEFT.wi = RIGHT.wi AND LEFT.id = RIGHT.id,
    getGridResult(LEFT, RIGHT));
  RETURN SORT(rslt_parms,wi,id,gamma,C);
END;