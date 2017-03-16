// Utilities for the implementation of ML (rather than the interface to it)
IMPORT ML_Core as ML;
IMPORT ML.Types AS Types;
IMPORT Std.Str;
IMPORT Std.system.Thorlib;
EXPORT Utils := MODULE

EXPORT Pi := 3.1415926535897932384626433;
EXPORT Base := 1000; // ID Base - all ids should be higher than this

EXPORT REAL8 Fac(UNSIGNED2 i) := BEGINC++
  double accum = 1.0;
  for ( int j = 2; j <= i; j++ )
    accum *= (double)j;
  return accum;
  ENDC++;

// The 'double' factorial is defined for ODD n and is the product of
// all the odd numbers up to and including that number.
// We are extending the meaning to even numbers to mean the product of
// the even numbers up to and including that number.
// Thus DoubleFac(8) = 8*6*4*2
// We also defend against i < 2 (returning 1.0)
EXPORT REAL8 DoubleFac(INTEGER2 i) := BEGINC++
  if ( i < 2 )
    return 1.0;
  double accum = (double)i;
  for ( int j = i-2; j > 1; j -= 2 )
    accum *= (double)j;
  return accum;
  ENDC++;

// N Choose K - finds the number of combinations of K elements out of a possible N
// Should eventually do this in a way to avoid the intermediates (such as Fac(N)) exploding
EXPORT REAL8 NCK(INTEGER2 N, INTEGER2 K) := Fac(N)/(Fac(K)*Fac(N-k));

// Evaluate a polynomial from a set of co-effs. Co-effs 1 is assumed to be the HIGH order of the equation
// Thus for ax^2+bx+c - the set would need to be Coef := [a,b,c];
EXPORT REAL8 Poly(REAL8 x, SET OF REAL8 Coeffs) := BEGINC++
  if (isAllCoeffs)
    return 0.0;
  int num = lenCoeffs / 8; // Note - REAL8 specified in prototype
  if ( num == 0 )
    return 0.0;
  const double * cp = (const double *)coeffs; // Will not work if sizeof(double) != 8
  double tot = *cp++;
  while ( --num )
    tot = tot * x + *cp++;
  return tot;
  ENDC++;

EXPORT stirlingFormula(real8 x) :=FUNCTION
   stirCoefs :=[7.87311395793093628397E-4,
                -2.29549961613378126380E-4,
                -2.68132617805781232825E-3,
                3.47222221605458667310E-3,
                8.33333333333482257126E-2];

    REAL8 stirmax := 143.01608;
    REAL8 w := 1.0/x;
    REAL8  y := exp(x);

    v := 1.0 + w * Poly(w, stirCoefs);

    z := IF(x > stirmax, POWER(x,0.5 * x - 0.25), //Avoid overflow in Math.pow()
                          POWER(x, x - 0.5)/y);
    u := IF(x > stirmax, z*(z/y), z);

    RETURN SQRT(PI)*u*v;
end;
/*
  return the value of gamma function of real number x
*/
EXPORT REAL8 gamma(REAL8 x) := BEGINC++
  #option pure
  #include <math.h>
  return tgamma(x);
ENDC++;

/*
  return the lower incomplete gamma value of two real numbers, x and y
*/
EXPORT REAL8 lowerGamma(REAL8 x, REAL8 y)  := BEGINC++
  #include <math.h>
  double n,r,s,ga,t,gin;
  int k;

  if ((x < 0.0) || (y < 0)) return 0;
  n = -y+x*log(y);

  if (y == 0.0) {
    gin = 0.0;
    return gin;
  }

  if (y <= 1.0+x) {
    s = 1.0/x;
    r = s;
    for (k=1;k<=100;k++) {
      r *= y/(x+k);
      s += r;
      if (fabs(r/s) < 1e-15) break;
    }

  gin = exp(n)*s;
  }
  else {
    t = 0.0;
    for (k=100;k>=1;k--) {
      t = (k-x)/(1.0+(k/(y+t)));
    }
    ga = tgamma(x);
    gin = ga-(exp(n)/(y+t));
  }
  return gin;
ENDC++;
/*
  return the upper incomplete gamma value of two real numbers, x and y
*/
EXPORT REAL8 upperGamma(REAL8 x, REAL8 y)  := BEGINC++
  #include <math.h>
  double n,r,s,ga,t,gim;
  int k;

  if ((x < 0.0) || (y < 0)) return 0;
  n = -y+x*log(y);

  if (y == 0.0) {
    gim = tgamma(x);
    return gim;
  }

  if (y <= 1.0+x) {
    s = 1.0/x;
    r = s;
    for (k=1;k<=100;k++) {
      r *= y/(x+k);
      s += r;
      if (fabs(r/s) < 1e-15) break;
    }

  ga = tgamma(x);
  gim = ga-(exp(n)*s);
  }
  else {
    t = 0.0;
    for (k=100;k>=1;k--) {
      t = (k-x)/(1.0+(k/(y+t)));
    }
    gim = exp(n)/(y+t);
  }
  return gim;
ENDC++;
/*
  return the beta value of two real numbers, x and y
*/
EXPORT Beta(REAL8 x, REAL8 y) := FUNCTION
   absx := ABS(x);
   intx := (INTEGER) absx;
   isXRightInt := (absx-intx)<1.0e-9;
   isXLeftInt :=ABS((ROUND(absx)-absx))<1.0e-9;
   isXfail := absx<1.0e-9 OR (x<0 AND (isXRightInt OR isXLeftInt));

   absy := ABS(y);
   inty := (INTEGER) absy;
   isYRightInt := (absy-inty)<1.0e-9;
   isYLeftInt :=ABS((ROUND(absy)-absy))<1.0e-9;
   isYfail := absy<1.0e-9 OR (y<0 AND (isYRightInt OR isYLeftInt));

   bp := gamma(x)*gamma(y)/gamma(x+y);
   bn :=(x+y)*gamma(x+1)*gamma(y+1)/(x*y*gamma(x+y+1));

   b := MAP(
            x>0 AND y>0 => bp,
            isXfail OR isYfail => 9999, // failed because one of them negative integers or zero
            bn //when both x and y negative real numbers
           );

  RETURN b;
END;

// In constrast to the matrix function thin
// Will take a potentially sparse file d and fill in the blanks with value v
EXPORT Fat(DATASET(Types.NumericField) d0,Types.t_FieldReal v=0) := FUNCTION
  dn := DISTRIBUTE(d0,HASH(id)); // all the values for a given ID now on one node
  seeds := TABLE(dn,{id,m := MAX(GROUP,number)},id,LOCAL); // get the list of ids on each node (and get 'max' number for free
  mn := MAX(seeds,m); // The number of fields to fill in
  Types.NumericField bv(seeds le,UNSIGNED C) := TRANSFORM
    SELF.wi := 1;
    SELF.value := v;
    SELF.id := le.id;
    SELF.number := c;
  END;
  // turn n into a fully 'blank' matrix - distributed along with the 'real' data
  n := NORMALIZE(seeds,mn,bv(LEFT,COUNTER),LOCAL);
  // subtract from 'n' those values that already exist
  n1 := JOIN(n,dn,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,TRANSFORM(LEFT),LEFT ONLY,LOCAL);
  RETURN n1+dn;
END;

// Same function for discrete fields
EXPORT FatD(DATASET(Types.DiscreteField) d0,Types.t_Discrete v=0) := FUNCTION
  dn := DISTRIBUTE(d0,HASH(id)); // all the values for a given ID now on one node
  seeds := TABLE(dn,{id,m := MAX(GROUP,number)},id,LOCAL); // get the list of ids on each node (and get 'max' number for free
  mn := MAX(seeds,m); // The number of fields to fill in
  Types.DiscreteField bv(seeds le,UNSIGNED C) := TRANSFORM
    SELF.wi := 1;
    SELF.value := v;
    SELF.id := le.id;
    SELF.number := c;
  END;
  // turn n into a fully 'blank' matrix - distributed along with the 'real' data
  n := NORMALIZE(seeds,mn,bv(LEFT,COUNTER),LOCAL);
  // subtract from 'n' those values that already exist
  n1 := JOIN(n,dn,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,TRANSFORM(LEFT),LEFT ONLY,LOCAL);
  RETURN n1+dn;
END;

EXPORT SparseARFFfileToDiscreteField(STRING fileName) := FUNCTION
/*  This FUNCTION was created in order to read a Sparse ARFF file and return a DATASET(ML.Types.DiscreteField) with only the non default values.
    Example for default value = 0:
    //ARFF file               | //Sparse ARFF file       | //Sparse Types.DiscreteField DS
                              | attr index starts in 0   | attr index starts in 1
    @data                     | @data                    | //defValue:= 0, posclass:=1 , negclass:= 0
    0, 0, 1, 0, 0, posclass   | {2 1, 5 posclass}        | DATASET([{1, 3, 1}, {1, 6, 1},
    2, 0, 0, 0, 1, posclass   | {0 2, 4 1, 5 posclass}   |          {2, 1, 2}, {2, 5, 1}, {2, 6, 1},
    0, 0, 0, 0, 2, negclass   | {4 2, 5 negclass}        |          {3, 5, 2}, {3, 6, 0}], Types.DiscreteField);
*/
// Based on Richard Taylor's SparseARFF.ConvertFlatFile and John Holt's suggestions
  InDS    := DATASET(fileName, {STRING Line}, CSV(SEPARATOR([])));
  ParseDS := PROJECT(InDS, TRANSFORM({UNSIGNED RecID, STRING Line}, SELF.RecID:= ((COUNTER-1)* Thorlib.nodes())+ Thorlib.node()+ 1, SELF := LEFT), LOCAL);
  //Parse the fields and values out
  PATTERN ws       := ' ';
  PATTERN RecStart := '{';
  PATTERN ValEnd   := '}' | ',';
  PATTERN FldNum   := PATTERN('[0-9]')+;
  PATTERN DataQ    := '"' PATTERN('[ a-zA-Z0-9]')+ '"';
  PATTERN DataNQ   := PATTERN('[a-zA-Z0-9]')+;
  PATTERN DataVal  := DataQ | DataNQ;
  PATTERN FldVal   := OPT(RecStart) FldNum ws DataVal ValEnd;
  OutRec := RECORD
    UNSIGNED RecID;
    STRING   FldName;
    STRING   FldVal;
  END;
  Types.DiscreteField XF(ParseDS L) := TRANSFORM
    SELF.wi     := 1;
    SELF.id     := L.RecID;
    SELF.number := (TYPEOF(SELF.number))MATCHTEXT(FldNum) + 1;
    SELF.value  := (TYPEOF(SELF.value))MATCHTEXT(DataVal);
  END;
  RETURN PARSE(ParseDS, Line, FldVal, XF(LEFT));
END;
EXPORT SparseARFFfileToDiscreteFieldCounted(STRING fileName) := FUNCTION
  attDS:= SparseARFFfileToDiscreteField(fileName);
  // Assuming that the last attribute is the dependent class and dependent is complete, the number of independent per instance is COUNT - 1.
  cntDS := PROJECT(TABLE(attDS, {id, cnt:= COUNT(GROUP) -1}, id, MERGE), TRANSFORM(Types.DiscreteField, SELF.wi:=1, SELF.number:=0, SELF.value:=LEFT.cnt, SELF:=LEFT));
  totDS := DISTRIBUTE(cntDS + attDS, HASH32(id));
  RETURN SORT(totDS, id, number, LOCAL);
END;

// Creates a file of pivot/target pairs with a Gini impurity value
EXPORT Gini(infile,pivot,target) := FUNCTIONMACRO
  // First count up the values of each target for each pivot
    agg := TABLE(infile,{pivot,target,Cnt := COUNT(GROUP)},pivot,target,MERGE);
  // Now compute the total number for each pivot
    aggc := TABLE(agg,{pivot,TCnt := SUM(GROUP,Cnt)},pivot,MERGE);
    r := RECORD
      agg;
      REAL4 Prop; // Proportion pertaining to this dependant value
    END;
    // Now on each row we have the proportion of the node that is that dependant value
    prop := JOIN(agg,aggc,LEFT.pivot=RIGHT.pivot,
                 TRANSFORM(r, SELF.Prop := LEFT.Cnt/RIGHT.Tcnt, SELF := LEFT),HASH);
    // Compute 1-gini coefficient for each node for each field for each value
    RETURN TABLE(prop,{pivot,TotalCnt := SUM(GROUP,Cnt),Gini := 1-SUM(GROUP,Prop*Prop)},pivot);
  ENDMACRO;


// Given a file which is sorted by INFIELD (and possibly other values), add sequence numbers within the range of each infield
// Slighly elaborate code is to avoid having to partition the data to one value of infield per node
EXPORT mac_SequenceInField(infile,infield,seq,outfile) := MACRO

#uniquename(add_rank)
TYPEOF(infile) %add_rank%(infile le,UNSIGNED c) := TRANSFORM
  SELF.seq := c;
  SELF := le;
  END;

#uniquename(P)
%P% := PROJECT(infile,%add_rank%(LEFT,COUNTER));

#uniquename(RS)
%RS% := RECORD
  __Seq := MIN(GROUP,%P%.seq);
  %P%.infield;
  END;

#uniquename(Splits)
%Splits% := TABLE(%P%,%RS%,infield,FEW);

#uniquename(to_1)
TYPEOF(infile) %to_1%(%P% le,%Splits% ri) := TRANSFORM
  SELF.Seq := 1+le.Seq - ri.__Seq;
  SELF := le;
  END;

outfile := JOIN(%P%,%Splits%,LEFT.InField=RIGHT.InField,%to_1%(LEFT,RIGHT),LOOKUP);

ENDMACRO;

// Shift the column-numbers of a file of discretefields so that the left-most column is now new_lowval
// Can move colums left or right (or not at all)
EXPORT RebaseDiscrete(DATASET(Types.DiscreteField) cl,Types.t_FieldNumber new_lowval) := FUNCTION
  CurrentBase := MIN(cl,number);
  INTEGER Delta := new_lowval-CurrentBase;
  RETURN PROJECT(cl,TRANSFORM(Types.DiscreteField,SELF.number := LEFT.number+Delta,SELF := LEFT));
  END;

EXPORT RebaseNumericField(DATASET(Types.NumericField) cl) := MODULE
  SHARED MapRec:=RECORD
    Types.t_FieldNumber old;
    Types.t_FieldNumber new;
  END;
  olds := TABLE(cl, {cl.number,COUNT(GROUP)}, number, FEW);

  EXPORT Mapping(Types.t_FieldNumber new_lowval=1) := FUNCTION
  MapRec mapthem(olds le, UNSIGNED c) := TRANSFORM
    SELF.old := le.number;
    SELF.new := c-1+new_lowval;
  END;
    RETURN PROJECT(olds, mapthem(LEFT, COUNTER));
  END;

  EXPORT ToNew(DATASET(MapRec) MapTable) := FUNCTION
     RETURN JOIN(cl,MapTable,LEFT.number=RIGHT.old,TRANSFORM(Types.NumericField, SELF.number := RIGHT.new, SELF:=LEFT),LOOKUP);
  END;

  EXPORT ToOld(DATASET(Types.NumericField) cl, DATASET(MapRec) MapTable) := FUNCTION
     RETURN JOIN(cl,MapTable,LEFT.number=RIGHT.new,TRANSFORM(Types.NumericField, SELF.number := RIGHT.old, SELF:=LEFT),LOOKUP);
  END;

    EXPORT ToOldFromElemToPart(DATASET(Types.NumericField) cl, DATASET(MapRec) MapTable) := FUNCTION
     RETURN JOIN(cl,MapTable,LEFT.id=RIGHT.new,TRANSFORM(Types.NumericField, SELF.id := RIGHT.old, SELF.number:=LEFT.number,SELF:=LEFT),LOOKUP);
  END;

  END;

EXPORT RebaseNumericFieldID(DATASET(Types.NumericField) cl) := MODULE
  SHARED MapRec:=RECORD
    Types.t_RecordID old;
    Types.t_RecordID new;
  END;
  olds := TABLE(cl, {cl.id,COUNT(GROUP)}, id, FEW);

  EXPORT MappingID(Types.t_FieldNumber new_lowval=1) := FUNCTION
  MapRec mapthem(olds le, UNSIGNED c) := TRANSFORM
    SELF.old := le.id;
    SELF.new := c-1+new_lowval;
  END;
    RETURN PROJECT(olds, mapthem(LEFT, COUNTER));
  END;



  EXPORT ToNew(DATASET(MapRec) MapTable) := FUNCTION
     RETURN JOIN(cl,MapTable,LEFT.id=RIGHT.old,TRANSFORM(Types.NumericField, SELF.id := RIGHT.new, SELF:=LEFT),LOOKUP);
  END;

  EXPORT ToOld(DATASET(Types.NumericField) cl, DATASET(MapRec) MapTable) := FUNCTION
     RETURN JOIN(cl,MapTable,LEFT.id=RIGHT.new,TRANSFORM(Types.NumericField, SELF.id := RIGHT.old, SELF:=LEFT),LOOKUP);
  END;

  END;

// Service functions and support pattern
EXPORT  NotFirst(STRING S) := IF(Str.FindCount(S,' ')=0,'',S[Str.Find(S,' ',1)+1..]);
EXPORT  NotLast(STRING S) := IF(Str.FindCount(S,' ')=0,'',S[1..Str.Find(S,' ',Str.FindCount(S,' '))-1]);
EXPORT  NotNN(STRING S,UNSIGNED2 NN) := MAP( NN = 1 => NotFirst(S),
                                             NN = Str.WordCount(S) => NotLast(S),
                                             S[1..Str.Find(S,' ',NN-1)]+S[Str.Find(S,' ',NN)+1..] );
EXPORT  LastN(STRING S) := Str.GetNthWord(S,Str.WordCount(S));

// Choose K (ascending element) permutations out of string of '1 2 3 ... N'  elements
// E.g. KoutofN(2,3) = '1 2', '2 3'
EXPORT  NchooseK(UNSIGNED1 N, UNSIGNED1 K) := FUNCTION
// generate string sample txt '1 2 3 ... N' to choose K elements from
rec := {UNSIGNED1 num};
seed := DATASET([{0}], rec);
txt := Str.CombineWords(SET(NORMALIZE(seed, N, TRANSFORM(rec, SELF.num := COUNTER)), (STRING2)num), ' ' );

R := RECORD
  STRING Kperm ;
  STRING From ;
END;
Init := DATASET([{'',txt}],R);
R Permutate(DATASET(R) infile) := FUNCTION
R TakeOne(R le, UNSIGNED1 c) := TRANSFORM
  SELF.Kperm := IF( (INTEGER1)Str.GetNthWord(le.from,c)> (INTEGER1)LastN(le.Kperm),le.Kperm + ' '+Str.GetNthWord(le.From, c),SKIP);
  SELF.From := NotNN(le.From,c);
END;
RETURN NORMALIZE(infile,Str.WordCount(LEFT.From),TakeOne(LEFT,COUNTER));
END;

RETURN TABLE(LOOP(Init,K,Permutate(ROWS(LEFT))), {Kperm});

END;


END;