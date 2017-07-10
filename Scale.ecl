IMPORT $ as SVM;
IMPORT SVM.Types;
IMPORT SVM.LibSVM;
IMPORT SVM.LibSVM.Types AS LibSVM_Types;
IMPORT ML_Core.Types as ML_Types;

Problem := LibSVM_Types.ECL_LibSVM_Problem;
LibSVM_Node := LibSVM_Types.LibSVM_Node;
FeatureStats := Types.FeatureStats;
Layout_Model := ML_Types.Layout_Model;

/**
 * Scaling and column statistics for datasets in problem format.
 * @param prob Dataset in problem format.
 * @param Scale Optional boolean value indicating whether or not data should be centered and scaled (default: true).
 */
EXPORT Scale(
  Problem prob,
  BOOLEAN Scale = true) := MODULE

  SHARED xIDRec := RECORD(LibSVM_Node)
    UNSIGNED8 rid;
  END;

  xIDRec addRowID(LibSVM_Node l, INTEGER c) := TRANSFORM
    SELF.indx := l.indx;
    SELF.value := l.value;
    SELF.rid := c;
  END;
  SHARED xID := PROJECT(prob.x, addRowID(LEFT,COUNTER));

  SHARED xID_grp := GROUP(SORT(xID, indx), indx);

  SHARED FeatureStats getStats(xIDRec firstRow, DATASET(xIDRec) grp) := TRANSFORM
    SELF.indx := firstRow.indx;
    countX := COUNT(grp);
    meanX := IF(Scale AND firstRow.indx > 1, AVE(grp, value), 0);
    varX := IF(Scale AND firstRow.indx > 1, SUM(grp, POWER(value - meanX, 2)) / (countX - 1), 1);
    SELF.mean := meanX;
    SELF.sd := SQRT(varX);
  END;

  /**
   * Get means and standard deviations for a set of predictors.
   * @return Dataset with one row per predictor with columns for the
   * mean and standard deviation of each. This can be passed later to
   * "problemScaled" to standardize data appropriately.
   */
  EXPORT stats := ROLLUP(xID_grp, GROUP, getStats(LEFT, ROWS(LEFT)));

  xIDRec doScale(xIDRec xID, FeatureStats stats) := TRANSFORM
    SELF.indx := xID.indx;
    SELF.value := (xID.value - stats.mean) / stats.sd;
    SELF.rid := xID.rid;
  END;

  xIDScaled := JOIN(xID, stats, LEFT.indx = RIGHT.indx, doScale(LEFT, RIGHT));

  SHARED xScaled := PROJECT(SORT(xIDScaled, rid), LibSVM_Node);

  Problem createProb(Problem p) := TRANSFORM
    SELF.elements := p.elements;
    SELF.entries := p.entries;
    SELF.features := p.features;
    SELF.max_value := p.max_value;
    SELF.y := p.y;
    SELF.x := xScaled;
  END;

  /**
   * Standardize (center and scale) dataset in problem data format.
   * @return A standardized replica of the input problem dataset.
   */
  EXPORT problemScaled := PROJECT(prob, createProb(LEFT));
END;