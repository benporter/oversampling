
%macro oversample(nruns);

%do reduction=1 %to 10 %by 1;
%do i=1 %to &nruns;

data heart;
  set sashelp.heart;

  /*define dependent variable*/
  dead = 0;
  if DeathCause in ('Coronary Heart Disease') then dead = 1;
   
run;

data heart1;
 set heart;
 /* subset to just the dependent variable */
 if ranuni(&i.) < &reduction./10 and dead = 1; 
 output;
run;

data _NULL_;
	if 0 then set work.heart1 nobs=n;
	call symputx('nrows',n);
	stop;
run;
%put nobs=&nrows;

data heart0;
  set heart;
  if dead = 0;
  randnum=ranuni(&i.*7);   
run;

proc sort data=heart0;
  by randnum; 
run;

data heart0;
  set heart0(drop=randnum);
  
  /* keep the top X rows*/
  if _N_ le &nrows; 
run; 

proc append data=heart0
            base=heart1;
run;


proc means data=heart1;
  var dead;
run;

*ods trace on/listing; /*prints ods table with listing output table*/
proc logistic data=heart1;
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

/* THIS WILL GET OVERWRITTEN FOR each reduction level */
%if &i. = 1 and &reduction.=1 %then %do;
    
    /*initialize assocall with the first table */
    data assocall;
     set assoc&i.(keep=Label2 nValue2);
     modelrun = &i.;
     reductionlevel = &reduction./10;
    run;
 %end;
 %else %do;
 
    /* append subsequent assoc tables */
    data assoc&i.;
     set assoc&i.(keep=Label2 nValue2);
     modelrun = &i.;
     reductionlevel = &reduction./10;
    run;
    
    proc append data=assoc&i.
                base=assocall;
    run;
  
 %end;

/* clean up - delete the temp dataset */
proc datasets nolist;
  delete assoc&i.;
run;

%end; /* ends i loop */
%end; /* end reduction loop */
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
  by Label2 reductionlevel;
  histogram nValue2;
  inset P5 P95;
run;

proc sgpanel data=assocall;
/*proc sgplot data=assocall; */
  title "Fit Statistics";
  panelby Label2 reductionlevel /columns=5 rows=2;
  histogram nValue2;
  /*by Label2 reductionlevel; */
run;

proc boxplot data=assocall;
   plot nValue2*reductionlevel / BOXCONNECT=mean;
   label nValue2 = 'Fit Statistic';
   insetgroup Q1 mean Q3  / 
        header = 'Fit Statistics By Reduction Level'
        pos=top;
   by Label2;
run;



