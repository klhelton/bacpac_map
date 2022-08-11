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
    JOBNAME:         Codelist_check

    JOB DESCRIPTION: The goal of this SAS job is to be able to read in the specifications 
                     files and dataset files and make sure that, for any code lists with
                     only character values, the character values take one of the specified 
                     options from the code lists. The exception is for the FT dataset, where
                     missing values are acceptable for FTSTRESC and FTSTRESN if FTSTAT=”Not done”.  

    LANGUAGE/VER:    SAS - Ver 9.4

    HISTORY (PROG):  Codelist_check -- klh5225 220718

    RELATED:         BP0001, STRESN_to_STRESC.sas

    PROGRAM NOTES:   This program assumes:
                        1. all input data files exist in the same directory
                        2. all spec files exist in the same directory 
                        3. spec files are .xlsx files and follow the 
                           guidelines and naming conventions in the 
                           "Required Documentation Guide for  
                           BACPAC Modified SDTM Standard"

-----------------------------------------------------------------------
    INPUT FILES:     list of SAS datafiles, list of spec files
 
    OUTPUT FILES:    <data>_chk.sas7bdat --> subset of input dataset 
                     supplemented with ALERT variables to indicate values
                     that stray from the standard specs. Only rows with 
                     at least one "alert" are included in the output.

***********************************************************************;
options nodate LS=150 PS=58 center formchar='|----|+|---+=|-/\<>' mergenoby=error mprint 
compress=no minoperator;


**********************************************************************
                       LINES TO UPDATE EACH RUN
*********************************************************************;

%let OUTPUT = J:\BACPAC\SC\klh5225\BP0004\Codelist_Check\220802;  /*location of output datasets*/

%let ds = dm_nomiss_upd sc_nomiss_upd qsmd_nomiss_upd qsop_nomiss_upd ex_nomiss_upd ft_nomiss_upd;  /*space-separated list of datasets, order does not matter*/

%let INPUT = J:\BACPAC\SC\klh5225\BP0004\STRESN_STRESC\220802;   /*location of input datasets*/

/*location of spec files*/
%let spec_loc = J:\BACPAC\Statistics\Data_Standards\Standard_Specifications; 

/*list of spec filenames separated by pipes, order does not matter*/
%let spec_list = STDSPECS_MinimumDataset|STDSPECS_OtherPROs|STDSPECS_EX|STDSPECS_FT_Combined_FTDataset;


**********************************************************************
                             END OF UPDATE
*********************************************************************;

libname data "&input";
libname out "&output"; 

****create work versions of data (additional assurance original files are not overwritten); 
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

****import specs files and restrict to data_type ^= "Integer"; 
%macro import_specs; 
%let i = 1; 
%do %until (%scan(&spec_list,&i,%str(|))=); 
    %let file = %scan(&spec_list,&i,%str(|)); 
            %put &file; 

        data codelist whereclause valuelevel; set _null_; run; 

        libname temp xlsx "&spec_loc\&file..xlsx";
        /*** read sheet codelist ***/
                data codelist(keep=id term decoded_value data_type);
                     set temp.codelists;
                     if ^missing(id) and upcase(data_type) ^= "INTEGER"; 
                run;
        /*** read sheet whereclauses ***/
                data whereclause(keep=id term);
                     set temp.whereclauses;
                     
                     n = count(value,',')+1;
                     do i = 1 to n;
                        term=strip(scan(value,i,','));
                        output;
                        end;
                run;
        /*** read sheet valuelevel ***/
                data valuelevel(keep=variable where_clause codelist);
                     set temp.valuelevel;
                run;
        libname temp clear;

        proc sql noprint; 
            create table match (rename=(term=testcd)) as
                select a.*, b.*
                from whereclause as a, valuelevel as b
                where a.id=b.where_clause; 

             create table specs&i as 
                select a.*, b.*
                from codelist as a
                     left join match (drop=id) as b
                     on a.id=b.codelist; 
        quit; 

    %let i = %eval(&i + 1); 
%end; 
%mend; 
%import_specs; 

****identify appropriate values for LENGTH and FORMAT statements below;
proc sql noprint;   
    create table lengths as 
        select upcase(name) as name, max(length) as length, 
               strip(calculated name)||" $"||strip(put(calculated length,best.)) as len_list,
               strip(calculated name)||" $"||strip(put(calculated length,best.))||"." as fmt_list
            from dictionary.columns where substr(upcase(memname),1,5) = "SPECS" and upcase(name) in("ID" "TERM" "DECODED_VALUE" "TESTCD")
        group by calculated name;
    select len_list into :length_list separated by " " from lengths; 
        %put &length_list; 
    select fmt_list into :format_list separated by " " from lengths; 
        %put &format_list; 
quit;

/*stack matched specs files*/
data specs; 
length &length_list; 
format &format_list; 
    set specs:; 
run; proc sort OUT=specs_ID nodupkey; by ID Term; run; 


****loop through each ID for specs and create a format for each; 
%macro make_formats; 
proc sql noprint; 
    select distinct(ID) into :var_list separated by " " from specs; 
    select max(countw(term)) into :dim trimmed from specs; 
quit; 

%let i = 1; 
%do %until (%scan(&var_list,&i)=); 
    %let var = %upcase(%scan(&var_list,&i)); 

        data fmt; set _null_; run; 
        data fmt (keep=ID start fmtname label); 
            set specs_ID (keep=ID term rename=(term=start)); 
            where upcase(id) = "&var"; 
            retain fmtname "$&var."; 

            label = 0; /*match = 0*/
                output; 

            start=upcase(start); 
            label = 1; /*capitalization issue = 1 */
                output; 

            start=compress(start); 
            label = 2; /*spacing issue and possibly capitalization = 2*/
                output; 

        run; proc sort nodupkey; by id start; run; 

        data fmt; 
            set fmt end=eof; 
            HLO = " "; 
                output; 
            if eof then do; 
                start = "OTHER"; 
                label = .; 
                HLO = "O"; 
                    output; 
            end;
         run;     

        proc format cntlin=fmt; run;

    %let i = %eval(&i + 1); 
%end; 
%mend; 
%make_formats; 


%macro apply_formats; 

/*STRESC variables*/
%if &varc^= %then %do; 
        %let i = 1; 
        %do %until (%scan(&f_list,&i)=); 
            %let format = %scan(&f_list,&i);
            %let test = %scan(&t_list,&i);

                if &varname = "&test" then do; 
                    alert = input(put(&varc,$&format..),best.);
                    if missing(alert) then alert = input(put(upcase(&varc),$&format..),best.);
                    if missing(alert) then alert = input(put(compress(upcase(&varc)),$&format..),best.);
                    if missing(alert) and (missing(&varc) or strip(&varc) = ".") then alert = 3; 
                    if missing(alert) then alert = 4; 
                end; 
 
            %let i = %eval(&i + 1); 
        %end; 

    label alert = "Alert: 0=perfect match, 1=check capitalization, 2=check spacing and possibly capitalization, 3=value is missing, 4=larger problem exists, .=no value to check for that row";
%end; 

/*non-STRESC vars*/
%let n = 1; 
%do %until (%scan(&fv_list,&n)=); 
    %let var = %scan(&fv_list,&n);

                alert_&var = input(put(&var,$&var..),best.);
                if missing(alert_&var) then alert_&var = input(put(upcase(&var),$&var..),best.);
                if missing(alert_&var) then alert_&var = input(put(compress(upcase(&var)),$&var..),best.);
                if missing(alert_&var) and (missing(&var) or strip(&var) = ".") then alert_&var = 3; 
                if missing(alert_&var) then alert_&var = 4; 
        
                label alert_&var = "Alert_&var.: 0=perfect match, 1=check capitalization, 2=check spacing and possibly capitalization, 3=value is missing, 4=larger problem exists"; 
    %let n = %eval(&n + 1); 
%end; 
%mend; 

***split specs into <>TRESC variables and other character variables;
data specs_tresc specs_var; 
    set specs; 

    if index(variable,"STRESC")=0 then output specs_var; 
    else output specs_tresc; 
run; 
proc sort data=specs_tresc out=specs_nodup nodupkey; by ID testcd; run; 
proc sort data=specs_var out=var_nodup nodupkey; by ID term; run; 

%macro by_dataset; 

%let j = 1; 
%do %until (%scan(&ds,&j)=); 
    %let data = %scan(&ds,&j);

        %put &data;

%let varname=; %let varc=; 
%let t_list = ; 
%let f_list = ; 
%let fv_list = ; 
%let ftstat_exist=;

proc sql noprint; 
    /*find TESTCD, STRESC variable name*/
    select name into :varname trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"TESTCD") > 0;  %put &varname; 
    select name into :varc trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"STRESC") > 0;    

    /*loop lists for STRESC vars-- TESTCD and matching ID(format)*/
    select TESTCD, ID into :t_list separated by " ", :f_list separated by " "
        from specs_nodup; 
    /*loop list for non -STRESC vars-- character variables in dataset that exist in specs*/
    select distinct(a.name) into :fv_list separated by " "
        from dictionary.columns as a, var_nodup as b
        where upcase(a.name)=upcase(b.id) and upcase(a.memname)= upcase("&data"); 

    /*check to see if variable FTSTAT exists in current dataset/iteration (allows for dataset to be named something other than "FT")*/
    select upcase(name) into :ftstat_exist trimmed from dictionary.columns where upcase(memname)=upcase("&data") and upcase(name) = "FTSTAT"; 

quit; 
%put formats=&f_list; 
%put tests=&t_list; 


    data &data._upd0; 
        set &data; 
        
        %apply_formats; 

        %if &ftstat_exist = FTSTAT %then %do; 
            if upcase(FTSTAT) = "NOT DONE" and alert = 3 then alert = 0; 
        %end; 

        flag = 0; 
        array keep[*] alert:; 
        do i = 1 to dim(keep); 
            if keep[i] > 0 then flag = 1; 
        end; drop i; 

        if flag = 1;
    run; 

    proc sql noprint; 
        select name into :final_list separated by ", " from dictionary.columns 
            where upcase(memname)=upcase("&data") and upcase(libname)=upcase("WORK"); 
        select name into :alert_list separated by ", " from dictionary.columns 
            where upcase(memname)=upcase("&data._UPD0") and substr(upcase(name),1,5)="ALERT"; 
        create table out.&data._chk as
            select &final_list, &alert_list from &data._upd0; 
    quit; 
 

    %let j = %eval(&j + 1);
%end; 
%mend; 
    
%by_dataset;
