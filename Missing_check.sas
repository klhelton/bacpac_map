***********************************************************************
    COLLABORATIVE STUDIES COORDINATING CENTER

    REQUEST NUMBER:  BP0004

    REQUEST TITLE:   SAS Program Templates for Consortium

    REQUEST DESCR:   Develop template SAS programs for common tasks related 
                     to the BACPAC Data Portal activities. Our goal is to
                     provide programs that consortium can utilize when (1)
                     preparing data for transfer to the BACPAC Data Portal or 
                    (2) analyzing data on the BACPAC Data Portal. 

    STUDY:           BACPAC 

    MANUSCRIPT #:    BPC-003

    PROGRAMMER:      Kinsey Helton
    
    REQUESTOR:       Micah McCumber
    
    SUBMITTED BY:    Anna Batorsky
    
    DATE:            07/18/2022
----------------------------------------------------------------------
    JOBNAME:         Missing_check

    JOB DESCRIPTION: The goal of this SAS job is to be able to read in the specifications files 
                     and dataset files and make sure that there are no rows missing both –STRESC 
                     and –STRESN values or EXTRT (EX dataset only). 
                     The exception is if FTSTAT=”Not done” in the FT dataset – in this case 
                     –STRESC and –STRESN are allowed to be missing.    

    LANGUAGE/VER:    SAS - Ver 9.4

    HISTORY (PROG):  Missing_check -- klh5225 220718

    RELATED:         BP0001, STRESN_to_STRESC.sas, Codelist_check.sas

    PROGRAM NOTES:   This program assumes:
                        1. all input data files exist in the same directory

-----------------------------------------------------------------------
    INPUT FILES:     list of SAS dataset files, 
 
    OUTPUT FILES:    <data>_miss.sas7bdat --> subset of input dataset,
                     only rows missing both <>STRESN and <>STRESC or 
                     missing EXTRT for the ex data are included 

                     <data>_nomiss.sas7bdat --> subset of input dataset,
                     only rows NOT (missing both <>STRESN and <>STRESC or 
                     missing EXTRT for the ex data) are included 

***********************************************************************;
options nodate LS=150 PS=58 center formchar='|----|+|---+=|-/\<>' mergenoby=error mprint 
compress=no minoperator;


**********************************************************************
                       LINES TO UPDATE EACH RUN
*********************************************************************;

%let OUTPUT = J:\BACPAC\SC\klh5225\BP0004\Missing_Check\220802;  /*location of output datasets*/

%let ds = dm sc qsmd qsop ex ft;  /*space-separated list of datasets, order does not matter*/

%let INPUT = J:\BACPAC\SC\klh5225\BP0004\input;  /*location of input datasets*/

**********************************************************************
                             END OF UPDATE
*********************************************************************;

libname data "&input";
libname out "&output"; 

****create work versions of data; 
%macro work_vers; 
%let i = 1; 
%do %until (%scan(&ds,&i)=); 
    %let dt = %scan(&ds,&i);

    data &dt; 
        set data.&dt; 
    run; 

    %let i = %eval(&i + 1); 
%end; 
%mend; 
%work_vers;

****loop through datasets, checking for unacceptably missing values; 
%macro by_dataset; 

%let j = 1; 
%do %until (%scan(&ds,&j)=); 
    %let data = %scan(&ds,&j);

        %put &data;

%let varname=; %let varc=; %let varn=; %let ftstat_exist=;
proc sql noprint; 
    /*find TESTCD, STRESC, and STRESN variable name*/
    select name into :varname trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"TESTCD") > 0;  %put &varname; 
    select name into :varc trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"STRESC") > 0;   
    select name into :varn trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"STRESN") > 0;  

    /*check to see if variable FTSTAT exists in current dataset/iteration (allows for dataset to be named something other than "FT")*/
    select upcase(name) into :ftstat_exist trimmed from dictionary.columns where upcase(memname)=upcase("&data") and upcase(name) = "FTSTAT"; 
quit; 

%if &varname ^= and &varc ^= and &varn^= %then %do; 
    data &data._upd0 &data._miss0; 
        set &data; 

        if (missing(&varc) or strip(&varc) = ".") and missing(&varn) then flag = 1;
        
        %if &ftstat_exist = FTSTAT %then %do; 
            if upcase(FTSTAT) = "NOT DONE" and flag = 1 then flag = .; 
        %end; 

        if flag = 1 then output &data._miss0;
        else output &data._upd0;
    run; 

    proc sql noprint; 
        create table out.&data._nomiss (drop=flag) as
            select * from &data._upd0; 
        create table out.&data._miss (drop=flag) as
            select * from &data._miss0; 
    quit; 
%end;
%else %if &data = ex %then %do; 
    data &data._upd0 &data._miss0; 
        set &data; 

        if missing(extrt) then flag = 1; 

        if flag = 1 then output &data._miss0;
        else output &data._upd0;
    run; 

    proc sql noprint; 
        create table out.&data._nomiss (drop=flag) as
            select * from &data._upd0; 
        create table out.&data._miss (drop=flag) as
            select * from &data._miss0; 
    quit; 
%end; 
%else %do; 
     %put ***************************;
     %put Dataset &data does not contain <>STRESC or <>STRESN, or is not the ex dataset;
     %put ***************************;

     data out.&data._nomiss; 
        set &data; 
     run; 
%end; 


    %let j = %eval(&j + 1);
%end; 
%mend; 
    
%by_dataset;
