%macro oversample(n);


%do i=1 %to &n;
      
data heart;
  set sashelp.heart;

  /*define dependent variable*/
  dead = 0;
  if DeathCause in ('Coronary Heart Disease') then dead = 1;

  /* keep less than 12% of the 0's, and all of the 1's */
  if (ranuni(&i.) < 0.12 and dead=0) or dead=1; output;

run;

proc means data=heart;
  var dead;
run;

*ods trace on/listing; /*prints ods table with listing output table*/
proc logistic data=heart;
  class Sex Weight_Status Smoking_Status / param=ref;
  model dead(event='1')=Sex Cholesterol 
                      Diastolic Systolic Diastolic*Systolic
                      Sex*Diastolic
                      Sex*Systolic
                      Sex*Diastolic*Systolic
                      MRW ;
  ods output Association=assoc&i.;
run; 
*ods trace off;


%if &i. = 1 %then %do;
    
    /*initialize assocall with the first table */
    data assocall;
     set assoc&i.(keep=Label2 nValue2);
     modelrun = &i.;
    run;
 %end;
 %else %do;
 
    /* append subsequent assoc tables */
    data assoc&i.;
     set assoc&i.(keep=Label2 nValue2);
     modelrun = &i.;
    run;
    
    proc append data=assoc&i.
                base=assocall;
    run;
  
 %end;

/* clean up - delete the temp dataset */
proc datasets nolist;
  delete assoc&i.;
run;

   %end;
%mend oversample;

/* suppress output while the macro runs */
ods _all_ close;
ods graphics off;
ods exclude all;
ods noresults;

%oversample(300);

/*turn the output back on */
ods graphics on;
ods exclude none;
ods results;

/* need this sorted for by group processing in sgplot*/
proc sort data=work.assocall;
  by Label2;
run;

/* plot the results */
proc univariate data=assocall noprint;
  by Label2;
  histogram nValue2;
  inset P5 P95;
run;
