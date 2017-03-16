IMPORT Std;
EXPORT Bundle := MODULE(Std.BundleBase)
 EXPORT Name := 'SVM';
 EXPORT Description := 'Support Vector Machines';
 EXPORT Authors := ['HPCCSystems'];
 EXPORT License := 'http://www.apache.org/licenses/LICENSE-2.0';
 EXPORT Copyright := 'Copyright (C) 2017 HPCC Systems';
 EXPORT DependsOn := ['ML_Core','PBblas'];
 EXPORT Version := '0.1';
 EXPORT PlatformVersion := '6.2.0';
END;