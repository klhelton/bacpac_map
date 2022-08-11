# bacpac_map

The purpose of these SAS programs is to aid in the creation of the BACPAC minimum dataset, specifically in the mapping of STRESN* values to STRESC* and checking for inappropriate character or missing values. These programs can be run individually or in succession. Below are brief descriptions of each program, followed by a summary of how they could be run in succession. 

*Note: For the remainder of this text, STRESC will refer to the character standardized result value of any domain (variable name: < domain >STRESC) and STRESN will refer to the numeric standardized result value of any domain (variable name: < domain >STRESN). 

# Missing_check.sas 
### **Assumptions**
-	All input datasets exist in the same directory
### **Required input**
-	Location of input datasets
-	List of input datasets
-	Location for output datasets

### **Description**
This program loops through all input datasets listed and checks for unacceptably missing values. Currently, “unacceptably missing” refers to:
1.	missing both STRESC and STRESN, for datasets containing these variables with one exception. If FTSTAT=”Not done” in the FT dataset, STRESC and STRESN are allowed to be missing.
2.	missing EXTRT in the EX dataset
  
Rows with unacceptably missing values are saved permanently as < data >_miss.sas7bdat in the output location provided by the user. The remaining rows are saved permanently as < data >_nomiss.sas7bdat in the output location provided by the user. If the input dataset is not the EX dataset and does not contain STRESC/STRESN variables, the dataset is saved in full as < data >_nomiss.sas7bdat (aids in successive running).

# STRESN_to_STRESC.sas 
### **Assumptions**
-	All input datasets exist in the same directory
-	All standard specifications files needed for the input datasets exist in the same directory
-	All standard specifications files are .xlsx files and follow the guidelines and naming conventions in the "Required Documentation Guide for BACPAC Modified SDTM Standard"
-	STRESC variable exists and has appropriate length from _variables_ sheet, but is blank (or can be overwritten) for rows with non-missing STRESN. 
    -	OR if domain does not include a STRESC/STRESN variable, the dataset will be output as-is (aids in successive running). 

### **Required input**
-	Location of input datasets
-	List of input datasets
-	Location for output datasets
-	List of standard specifications files
-	Location of standard specifications files
### **Optional input**
-	Conditional IF statements to provide specific formatting desired for STRESN values that should follow ISO8601 formatting when mapped to STRESC
-	User defined format definitions for formats that are listed in the _valuelevel_ sheet (use PROC FORMAT, %INCLUDE, or other methods for making the user defined format available to the program at runtime)

### **Description**
This program fills in STRESC values where STRESN is not missing. To do so, the TESTCD values for each respective STRESC-STRESN pair are processed in the following steps:

1.	If the TESTCD value has corresponding rows on a _codelist_ sheet where TERM is numeric and DECODED_VALUE not missing, then the DECODED_VALUE is mapped to STRESC. The result will be text-based values for STRESC such as 0 => No and 1 = > Yes.
2.	If the TESTCD value has a corresponding row on the _valuelevel_ sheet where the format column is not missing, the numeric SAS format provided in the format column will be used to convert STRESN to STRESC. The result will be a SAS formatted value for STRESC such as STRESN = 12.3333 to STRESC= 12.33 for format=5.2.
    -	If the provided format on the _valuelevel_ sheet is ISO8601 (which can refer to intervals, durations, datetimes, etc.), the user should add appropriate IF statements for each TESTCD value in the %ISO8601 macro definition at the top of the program. An example is provided for TESTCD = "PSQI4", which was needed to convert the exact number of hours (xx.xxxx) to hour and minute duration in ISO8601 (PTxxHxxM):
  
        -	if &varname = "PSQI4" then &varc = "PT"||strip(put(int(&varn),8.))||"H"||strip(put(  mod(&varn*60,60),8.) )||"M"; 
  
    - Any number of IF statements can be added following the structure seen above. Only “PSQI4” and the definition of &varc need to be updated. The macro variables &varname, &varc, and &varn will resolve correctly at runtime to TESTCD, STRESC, and STRESN, respectively.
    -	If the provided format is not ISO8601 and is not a SAS-defined format, be sure to make the user-defined format available to this program at runtime or include the format as IF-ELSE statements within the ISO8601 macro definition. 
3.	If no text-based format exists in the _codelist_ sheet in the specs and no numeric format exists on the _valuelevel_ sheet, STRESC is set to the exact value of STRESN. For instance, if STRESN = 12.3333 but no format exists, STRESC = 12.3333. If this direct STRESN=STRESC conversion is not the desired behavior, be sure to provide a format on the _valuelevel_ sheet or add the required rows to the _codelist_ sheet. 


Once the formats are applied to STRESC, the dataset is output to the requested location as < data >_upd.sas7bdat. If STRESC and STRESN do not exist for a dataset listed as input to this program, the dataset is output as-is but also named < data >_upd.sas7bdat (aids in successive running).

 
# Codelist_check.sas 
### **Assumptions**
-	All input datasets exist in the same directory
-	All standard specifications files needed for the input datasets exist in the same directory
-	All standard specifications files are .xlsx files and follow the guidelines and naming conventions in the "Required Documentation Guide for BACPAC Modified SDTM Standard"

### **Required input**
-	Location of input datasets
-	List of input datasets
-	Location for output datasets
-	List of standard specifications files
-	Location of standard specifications files

### **Description**
This program uses the specifications files to determine "how close" the STRESC values or other non-STRESC character variable values (other variables in data that have character specs to check, like RACE, ETHNIC, etc.) are to a possible value according to the specs. Currently "how close" refers to a perfect match, a match only if case is not considered, or a match only if case and spacing are not considered. To record this, a variable ALERT is added to the dataset for STRESC values, and ALERT_< varname > is added for non-STRESC variables that appeared in the specs. ALERT is currently coded as follows:
-	0 = perfect match
-	1 = problem with capitalization
-	2 = problem with spacing and maybe also capitalization
-	3 = value is missing
-	4 = larger problem exists with value 
  
Only rows with at least one alert > 0 are output as < data >_chk.sas7bdat. If all rows have all alerts = 0, the output dataset will be empty. 

# Successive runs 
If the user is only interested in one of these tasks, the programs can be run individually. To use all three programs, I recommend the following:
1.	Existing datasets should contain all expected variables set to appropriate lengths as specified in a _variables_ sheet in the specifications files, though STRESC will be blank if not missing STRESN. STRESC will be non missing for TESTCDs that do not record a STRESN value (as seen in the simulated SC dataset). 
2.	Missing_Check.sas removes rows with unacceptably missing values, outputting the original dataset as two datasets: < data >_miss.sas7bdat and < data >_nomiss.sas7bdat.
3.	STRESN_to_STRESC.sas fills in STRESC values where STRESN is not missing. As input, use all < data >_nomiss.sas7bdat files output from Missing_Check.sas. Output files will be named < data >_nomiss_upd.sas7bdat.
4.	Codelist_check.sas then checks STRESC values and other character values to make sure the values match one of the options provided in the specification files. As input, use all < data >_nomiss_upd.sas7bdat files. Rows with incorrect values are output as < data >_nomiss_upd_chk.sas7bdat with newly added ALERT variables briefly explaining the discrepancy. 
  
The dataset names do not need to be strictly the domain names, as seen above. The programs accept any input datafile names, including < data >_nomiss and < data >_nomiss_upd. (Though short names are best since “_nomiss_upd_chk” adds 15 characters to the original dataset name.) Additionally, if the program is not relevant for a particular dataset, the dataset is output as-is with the updated name so that each output folder can contain all datasets you are working on. For example, the simulated DM dataset does not contain a STRESC nor STRESN variable. However, the DM dataset can still be run with the other simulated datasets through both Missing_Check.sas and STRESN_to_STRESC.sas, meaning it will be available in the same folder as the STRESN_to_STRESC.sas output with the same naming convention as the other outputs (dm_nomiss_upd.sas7bdat). Then the entire contents of the output folder for STRESN_to_STRESC.sas can be listed as input in Codelist_check.sas.

