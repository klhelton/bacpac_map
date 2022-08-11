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
    JOBNAME:         STRESN_to_STRESC

    JOB DESCRIPTION: The goal of this SAS job is to be able to read in the 
                     specifications files and dataset files and map numeric (STRESN) 
                     values from the dataset files to corresponding character
                     values (STRESC) in the specifications files. This way the user will 
                     not have to manually enter/code the character values from the 
                     code lists in specifications files. If no codelist exists for 
                     a specific TESTCD-STRESN pair, the **SAS format** provided on the 
                     valuelevel sheet is used. If no format exists on valuelevel 
                     sheet the STRESN value is converted to character with the 
                     best. format.

                     **SAS format** if the format provided on the valuelevel sheet
                     is not an existing SAS format, create the desired SAS format and
                     make it available to this program. The exception is ISO8601, which 
                     can be spec'd and added below if desired.  

    LANGUAGE/VER:    SAS - Ver 9.4

    HISTORY (PROG):  STRESN_to_STRESC -- klh5225 220718

    RELATED:         BP0001

    PROGRAM NOTES:   This program assumes:
                        1. all input data files exist in the same directory
                        2. all spec files exist in the same directory 
                        3. spec files are .xlsx files and follow the 
                           guidelines and naming conventions in the 
                           "Required Documentation Guide for  
                           BACPAC Modified SDTM Standard"
                        4. <>STRESC variable exists and has appropriate length 
                           from Variables sheet but is blank (or can be overwritten)
                           for rows with non-missing <>STRESN. Datasets without 
                           <>STRESC are output as is. 

-----------------------------------------------------------------------
    INPUT FILES:     list of SAS datafiles, list of spec files
 
    OUTPUT FILES:    <data>_upd.sas7bdat --> full, input dataset 
                     with <>STRESC values mapped from <>STRESN
                     values

***********************************************************************;
options nodate LS=150 PS=58 center formchar='|----|+|---+=|-/\<>' mergenoby=error mprint 
compress=no minoperator;


**********************************************************************
                       LINES TO UPDATE EACH RUN
*********************************************************************;

%let OUTPUT = J:\BACPAC\SC\klh5225\BP0004\STRESN_STRESC\220802;  /*location of output datasets*/

%let ds = dm_nomiss sc_nomiss qsmd_nomiss qsop_nomiss ex_nomiss ft_nomiss;       /*space-separated list of datasets, order does not matter*/

%let INPUT = J:\BACPAC\SC\klh5225\BP0004\Missing_Check\220802;  /*location of input datasets*/

/*location of spec files*/
%let spec_loc = J:\BACPAC\Statistics\Data_Standards\Standard_Specifications; 

/*list of spec filenames separated by pipes, order does not matter*/
%let spec_list = STDSPECS_MinimumDataset|STDSPECS_OtherPROs|STDSPECS_EX|STDSPECS_FT_Combined_FTDataset;


/*
If any STRESC values need to use ISO8601 formatting, provide the info below by replacing the 
$$$$ with TESTCD values and #### with the appropriate formatting.
Create as many IF statements (or other DATA step code) as needed.  
Example provided below.

all macro variables will resolve at runtime to:
&varname = <>TESTCD
&varc = <>STRESC
&varn = <>STRESN

These macro variables do not need to be edited or hardcoded.
*/
%macro iso8601; 
/*if &varname = "$$$$" then &varc = ####; */

/*EXAMPLE for simulated QSMD data: <>STRESN is number of hours, <>STRESC is duration in ISO8601 */
if &varname = "PSQI4" then &varc = "PT"||strip(put(int(&varn),8.))||"H"||strip(put(  mod(&varn*60,60),8.) )||"M"; 

%mend; 

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


****import specs files and restrict to all-digit TERM values and nonmissing DECODED_VALUE; 
%macro import_specs; 
%let i = 1; 
%do %until (%scan(&spec_list,&i,%str(|))=); 
    %let file = %scan(&spec_list,&i,%str(|)); 
            %put &file; 

        data codelist whereclause valuelevel match; set _null_; run; 

        libname temp xlsx "&spec_loc\&file..xlsx";
        /*** read sheet codelist ***/
                data codelist(keep=id term decoded_value);
                     set temp.codelists;
                     if ^missing(id) and notdigit(strip(term))=0 and ^missing(decoded_value); 
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
                data valuelevel(keep=variable where_clause codelist format);
                     set temp.valuelevel;
                run;
        /*** read sheet variables ***/
                data variable&i;
                     set temp.variables;
                     where ^missing(dataset); 
                     keep dataset variable label data_type length format; 
                run;
        libname temp clear;

        proc sql noprint; 
            create table match (rename=(term=testcd)) as
                select a.*, b.*
                from whereclause as a, valuelevel as b
                where a.id=b.where_clause; 

             create table specs&i as 
                select a.*, b.*
                from codelist as a, match (drop=id format) as b
                where a.id=b.codelist; 
        quit; 

        data match_&i; /*store format list for digit-only STRESC values (for example: STRESC = put(STRESN,5.1))*/ 
            set match (rename=(format=format2));
            where ^missing(format2) and index(upcase(variable),"STRESC") > 0; 
            drop id where_clause codelist; 
        
            type = vtype(format2); 
            call symputx('type',type); 
        run; 

        data match_&i; 
            set match_&i; 

            %if &type = C %then %do; 
                format = format2;
            %end; 
            %else %if &type = N %then %do; 
                format = strip(put(format2,best.));
            %end; 

            drop format2 type; 
        run; 

    %let i = %eval(&i + 1); 
%end; 
%mend; 
%import_specs; 

****identify appropriate values for LENGTH and FORMAT statements below when stacking sheets from different spec files;
proc sql noprint;   
/*SPECS*/
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


/*VARIABLES*/
    create table lengths_v as 
        select upcase(name) as name, max(length) as length, 
               strip(calculated name)||" $"||strip(put(calculated length,best.)) as len_list,
               strip(calculated name)||" $"||strip(put(calculated length,best.))||"." as fmt_list
            from dictionary.columns where substr(upcase(memname),1,8) = "VARIABLE" and upcase(name) in("VARIABLE" "LABEL" "DATA_TYPE" "FORMAT")
        group by calculated name;
    select len_list into :length_list_v separated by " " from lengths_v; 
        %put &length_list_v; 
    select fmt_list into :format_list_v separated by " " from lengths_v; 
        %put &format_list_v; 

/*NUMERIC FORMATS*/
    create table lengths_n as 
        select upcase(name) as name, max(length) as length, 
               strip(calculated name)||" $"||strip(put(calculated length,best.)) as len_list,
               strip(calculated name)||" $"||strip(put(calculated length,best.))||"." as fmt_list
            from dictionary.columns where substr(upcase(memname),1,6) = "MATCH_" and upcase(name) in("TESTCD" "VARIABLE" "FORMAT")
        group by calculated name;
    select len_list into :length_list_n separated by " " from lengths_n; 
        %put &length_list_n; 
    select fmt_list into :format_list_n separated by " " from lengths_n; 
        %put &format_list_n; 
quit;

/*stack matched specs files*/
data specs; 
length &length_list; 
format &format_list; 
    set specs:; 
run; proc sort OUT=specs_ID nodupkey; by ID Term Decoded_Value; run; 

****stack variable sheets together; 
data variable; 
length &length_list_v Length 8; 
format &format_list_v; 
    set variable:; 
run; 

****stack numeric formats together; 
data num_formats; 
length &length_list_n; 
format &format_list_n; 
    set match_:; 

    if index(format,".") = 0 then format= strip(format)||'.'; 
run; 

**macro to apply numeric format based on value of <>TESTCD;
%macro apply_num_formats; 
%if &num_testcd ^= %then %do; 
    %let k = 1; 
    %do %until (%scan(&num_testcd,&k,%str( ))=); 
        %let num_form = %scan(&num_format,&k,%str( ));
        %let num_test = %scan(&num_testcd,&k,%str( ));

            if &varname = "&num_test" then &varc = strip(put(&varn,&num_form)); 

        %let k = %eval(&k + 1); 
    %end; 
%end;
%mend; 

****loop through each ID from specs and create a format for each; 
%macro make_formats; 
proc sql noprint; 
    select distinct(ID) into :var_list separated by " " from specs; 
quit; 

%let i = 1; 
%do %until (%scan(&var_list,&i)=); 
    %let var = %upcase(%scan(&var_list,&i)); 

        data fmt; set _null_; run; 
        data fmt; 
            set specs_ID (keep=ID term decoded_value rename=(decoded_value=label)); 
            where upcase(id) = "&var"; 
            retain fmtname "&var"; 

            start = input(term,best.);
        run; 
        proc format cntlin=fmt; run;

    %let i = %eval(&i + 1); 
%end; 
%mend; 
%make_formats; 

**macro to apply format for decoded_value based on value of <>TESTCD;
%macro apply_formats; 
%let i = 1; 
%do %until (%scan(&f_list,&i)=); 
    %let format = %scan(&f_list,&i);
    %let test = %scan(&t_list,&i);

        if &varname = "&test" then &varc = strip(put(&varn,&format..)); 

    %let i = %eval(&i + 1); 
%end; 
%mend; 

***no duplicates version of specs by testcd -- used to make lists to loop through;
proc sort data=specs out=specs_nodup nodupkey; by testcd; run; 

%macro by_dataset; 

%let j = 1; 
%do %until (%scan(&ds,&j)=); 
    %let data = %scan(&ds,&j);

        %put &data;

/*find TESTCD, STRESN, STRESC variable name*/
%let varname=; %let varc=; %let varn=; %let lengthc =; %let t_list=; %let f_list=; %let num_testcd=; %let num_format=;
proc sql noprint; 
    select name into :varname trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"TESTCD") > 0;  %put &varname; 
    select name into :varc trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"STRESC") > 0;   
    select name into :varn trimmed from dictionary.columns where upcase(memname)=upcase("&data") and
        index(upcase(name),"STRESN") > 0;   

    select TESTCD, ID into :t_list separated by " ", :f_list separated by " "
        from specs_nodup; 

    %if &varc ^= %then %do; 
        /*pull in numeric formats*/
        select TESTCD, format into :num_testcd separated by " ", :num_format separated by " " 
            from num_formats where upcase(variable) = upcase("&varc") and format ^= "ISO8601.";
    %end; 
    
quit; 
%put formats=&f_list; 
%put tests=&t_list; 

%if &varname= or &varc= or &varn= %then %do; 
    %put ****************;
    %put &data not updated as it does not contain <>TESTCD, <>STRESC, or <>STRESN; 
    %put ****************;

    data out.&data._upd; 
        set &data; 
    run; 
%end; 
%else %do; 
    data &data._upd0; 
        set &data; 
        
        %apply_formats; 

        if missing(&varc) and ^missing(&varn) then do;  
            %apply_num_formats;             /*set STRESC values with no applicable decoded_value in specs, but have a desired SAS format*/
            %iso8601;         /*apply formats specified for ISO8601 variables*/
            if missing(&varc) then &varc=strip(put(&varn,best.)); /*if still missing STRESC, set to STRESN value with best. format*/
        end;
    run; 

    proc sql noprint; 
        select name into :final_list separated by ", " from dictionary.columns 
            where upcase(memname)=upcase("&data") and upcase(libname)=upcase("WORK"); 

        create table out.&data._upd as
            select &final_list from &data._upd0; 
    quit; 
%end;
 

    %let j = %eval(&j + 1);
%end; 
%mend; 
    
%by_dataset;
