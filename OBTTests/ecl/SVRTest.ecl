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

// Get dataset
Content := HS.content;

ML_Core.ToField(content, NF);

Independent := NF(number != 1);
Dependent := NF(number = 1);

SVR := SV.SVR(Independent, Dependent);

Model := SVR.GetModel;

ConvertedModel := SV.Converted.ToModel(Model);
ExpectedSVS := 137;

OUTPUT(GetResult(ExpectedSVS, ConvertedModel[1].L), NAMED('Test1'));

Tune := SVR.Tune();
LowCorrects := COUNT(Tune(Correct < 50));

OUTPUT(IF(LowCorrects = 0, 'Pass', 'Fail: ' + LowCorrects + ' Rows under 50 correctness'), NAMED('Test2'));

// Testing cross validation with a different number of folds
CV1 := SVR.CrossValidate(10);
CV2 := SVR.CrossValidate(30);
CV3 := SVR.CrossValidate(50);

CorrectThreshold := 80;

CV1Correct := CV1[1].Correct;
OUTPUT(IF(CV1Correct >= CorrectThreshold, 'Pass', 'Fail: Correct - ' + CV1Correct), NAMED('Test3A'));

CV2Correct := CV2[1].Correct;
OUTPUT(IF(CV2Correct >= CorrectThreshold, 'Pass', 'Fail: Correct - ' + CV2Correct), NAMED('Test3B'));

CV3Correct := CV3[1].Correct;
OUTPUT(IF(CV3Correct >= CorrectThreshold, 'Pass', 'Fail: Correct - ' + CV3Correct), NAMED('Test3C'));
