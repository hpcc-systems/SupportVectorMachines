IMPORT ML_Core.Types AS Core_Types;
IMPORT $ as SVM;

/**
 * Generate human-readable summary of SVM models.
 * @param model Trained SVM models in Layout_Model format.
 * @return A single-column dataset which contains human-readable information
 * about the SVM models.
 */
EXPORT DATASET({UNSIGNED4 r, STRING60 txt}) ModelSummary(
  DATASET(Core_Types.Layout_Model) model
) := FUNCTION

    svmMdls := SVM.Converted.ToModel(model);

    SummaryRec := RECORD
      UNSIGNED4 r;
      STRING60 txt;
    END;
    SummaryStruct := RECORD
      DATASET(SummaryRec) Summary;
    END;

    SummaryStruct GetSummaryStruct(SVM.Types.Model m, INTEGER c) := TRANSFORM
      SummaryBase := DATASET(
      [
        {1 + 13 * (c-1), '============================================================'},
        {2 + 13 * (c-1), 'Model summary for model ' + (STRING) m.id + ' trained on work ID ' + (STRING) m.wi + '.'},
        {3 + 13 * (c-1), ' '},
        {4 + 13 * (c-1), 'SVM Type:                  '
          + MAP(
          m.svmType = 0 => 'C_SVC',
          m.svmType = 1 => 'NU_SVC',
          m.svmType = 2 => 'ONE_CLASS',
          m.svmType = 3 => 'EPSILON_SVR',
          m.svmType = 4 => 'NU_SVR',
          (STRING33) m.svmType)},
        {5 + 13 * (c-1), 'Kernel Type:               '
          + MAP(
          m.kernelType = 0 => 'LINEAR',
          m.kernelType = 1 => 'POLY',
          m.kernelType = 2 => 'RBF',
          m.kernelType = 3 => 'SIGMOID',
          m.kernelType = 4 => 'PRECOMPUTED',
          (STRING33) m.svmType)},
        {6 + 13 * (c-1), 'Degree:                    ' + (STRING) m.degree},
        {7 + 13 * (c-1), 'Gamma:                     ' + (STRING) m.gamma},
        {8 + 13 * (c-1), 'Kernel parameter:          ' + (STRING) m.coef0},
        {9 + 13 * (c-1), 'Scale:                     ' + IF(m.scale, 'TRUE', 'FALSE')},
        {10 + 13 * (c-1), 'Number of classes:         ' + (STRING) m.k},
        {11 + 13 * (c-1), 'Number of support vectors: ' + (STRING) m.l},
        {12 + 13 * (c-1), ' '},
        {13 + 13 * (c-1), '============================================================'}
      ],
      SummaryRec);

      SELF.Summary := SummaryBase;
    END;

    SummaryRec CombineSummaries(SummaryRec line) := TRANSFORM
      SELF := line;
    END;

    mdlSummaries := PROJECT(svmMdls, GetSummaryStruct(LEFT, COUNTER));
    mdlSummary := NORMALIZE(mdlSummaries, LEFT.Summary, CombineSummaries(RIGHT)) +
        DATASET(
        [
          {1000000000, ' '},
          {1000000001, 'NOTE: Use "SupportVectorMachines.Converted.ToModel(model)"'},
          {1000000002, '      to convert the model to a structured format.'}
        ], SummaryRec);

  RETURN SORT(mdlSummary,r);
END;