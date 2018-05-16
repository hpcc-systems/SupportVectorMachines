IMPORT ML_Core.Types AS Core_Types;

// Aliases
DiscreteField     := Core_Types.DiscreteField;
Confusion_Detail  := Core_Types.Confusion_Detail;

/**
  * Generate the confusion matrix, to compare actual versus predicted response
  * variable values.
  *
  * @internal
  * @param dependents the original response values.
  * @param predicts the predicted responses.
  * @return confusion matrix in Confusion_Detail format.
  * @see ML_Core.Types.Confusion_Detail
  */
EXPORT DATASET(Confusion_Detail)
       Confusion(DATASET(DiscreteField) dependents,
                 DATASET(DiscreteField) predicts) := FUNCTION
  //
  Confusion_Detail score(DiscreteField y, DiscreteField p) := TRANSFORM
    SELF.classifier := y.number;
    SELF.actual_class := y.value;
    SELF.predict_class := p.value;
    SELF.occurs := 1;
    SELF.correct := y.value = p.value;
    SELF := y;
  END;
  scored := JOIN(dependents, predicts,
                 LEFT.wi=RIGHT.wi AND LEFT.id=RIGHT.id
                 AND LEFT.number=RIGHT.number,
                 score(LEFT, RIGHT));
  srt_dtl := SORT(scored, wi, classifier, actual_class, predict_class);
  grp_dtl := GROUP(srt_dtl, wi, classifier, actual_class, predict_class);
  rolled := ROLLUP(grp_dtl, GROUP,
                   TRANSFORM(Confusion_Detail,
                             SELF.occurs := SUM(ROWS(LEFT), occurs),
                             SELF:=LEFT));
  RETURN rolled;
END;