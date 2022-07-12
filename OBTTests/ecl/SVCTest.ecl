/*##############################################################################
    
    HPCC SYSTEMS software Copyright (C) 2022 HPCC Systems®.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0
       
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
############################################################################## */

IMPORT SupportVectorMachines AS SV;
IMPORT SupportVectorMachines.Datasets.HeartScale AS HS;
IMPORT ML_CORE;

// Helper function

STRING GetResult(INTEGER Expected, INTEGER Result) := FUNCTION
  RETURN IF(Expected = Result, 'Pass', 'Expected Support Vectors: ' + Expected + ' Actual Support Vectors: ' + Result);
END;

SVC := SV.SVC();

// Get dataset
Content := HS.content;

ML_Core.ToField(content, NF);

Dependent := NF(number = 1);
DF := ML_Core.Discretize.ByRounding(Dependent);

Model := SVC.GetModel(NF, DF);
Classification := SVC.Classify(Model, NF);

// All rows with confidence > 0.5 should have a value of 1
// and those with confidence < 0.5 should have a value of -1

IncorrectNeg1 := COUNT(Classification(conf > 0.5 AND value = -1));
OUTPUT(IF(IncorrectNeg1 = 0, 'Pass', 'Fail: ' + IncorrectNeg1 + ' incorrect instances where the value should be 1'), NAMED('Test1A'));

IncorrectPos1 := COUNT(Classification(conf < 0.5 AND value = 1));
OUTPUT(IF(IncorrectPos1 = 0, 'Pass', 'Fail: ' + IncorrectPos1 + ' incorrect instances where the value should be -1'), NAMED('Test1B'));

Tune := SVC.Tune(Observations := NF, Classifications := DF);
LowCorrect := COUNT(Tune(correct < 50));
OUTPUT(IF(LowCorrect = 0, 'Pass', 'Fail: ' + LowCorrect + 'incorrect rows'), NAMED('Test2'));

StructuredModel := SV.Converted.ToModel(Model);

TunedModel := SVC.GetTunedModel(Tune, NF, DF);
StructuredTunedModel := SV.Converted.ToModel(TunedModel);

ExpectedSVs1 := 95;
ActualSVs1 := StructuredModel[1].L;
OUTPUT(GetResult(ExpectedSVs1, ActualSVs1), NAMED('Test3A'));

ExpectedSVs2 := 128;
ActualSVs2 := StructuredTunedModel[1].L;
OUTPUT(GetResult(ExpectedSVs2, ActualSVs2), NAMED('Test3B'));
