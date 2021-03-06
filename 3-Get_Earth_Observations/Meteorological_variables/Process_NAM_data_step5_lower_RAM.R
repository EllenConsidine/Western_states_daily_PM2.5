# Process_NAM_data_step5.R - take 24-hr summaries of NAM weather data

#### Clear variables and sinks; define working directory ####
rm(list  =  ls()) # clear all variables
options(warn  =  2) # throw an error when there's a warning and stop the code from running further
if (max(dev.cur())>1) { # make sure it isn't outputting to any figure files
  dev.off(which  =  dev.cur())
} # if (max(dev.cur())>1) {
while (sink.number()>0) { # close any sink files
  sink()
} # while (sink.number()>0) {
working.directory  <-  "/home/rstudio" # define working directory
setwd(working.directory) # set working directory

#### Call Packages (Library) ####
library(parallel) # see http://gforge.se/2015/02/how-to-go-parallel-in-r-basics-tips/
library(lubridate) # https://cran.r-project.org/web/packages/lubridate/lubridate.pdf

#### Source functions I've written ####
source(file.path("estimate-pm25","General_Project_Functions","general_project_functions.R"))
functions_list <-c("replace_character_in_string.fn","define_file_paths.fn") # put functions in a vector to be exported to cluster

#### Define Constants ####
NAM_folder <- "NAM_data" # define folder for NAM data
input_sub_folder <- "NAM_Step4" # define location of input files
input_sub_sub_folder <- "NAM_Step4_Intermediary_Files" # define subfolder location
output_sub_folder <- "NAM_Step5" # define location for output files
output_file_name <- paste("NAM_Step5_processed_",Sys.Date(),sep = "") # define name of output file
this_batch_date <- define_study_constants.fn("NAM_batch_date") # get batch date
output_sub_sub_folder <- paste("NAM_Step5_batch",this_batch_date,sep = "") # define output sub-sub-folder
  
# create NAM_Step5 folder if it doesn't already exist
if(dir.exists(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder)) == FALSE) { # create directory if it doesn't already exist
  dir.create(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder))
} # if(exists(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder)) == FALSE) { # create directory if it doesn't already exist

# create NAM_Step5 sub-folder if it doesn't already exist
if(dir.exists(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder)) == FALSE) { # create directory if it doesn't already exist
  dir.create(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder))
} # if(exists(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder)) == FALSE) { # create directory if it doesn't already exist

#### Load and Process Data ####
# Step 4 intermediary files
file_name_pattern <- "\\.csv$" # only looking for .csv files (don't want to pick up the sub-folder)
step4_file_list <- list.files(path = file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,input_sub_folder,input_sub_sub_folder,"."), pattern = file_name_pattern, all.files = FALSE,
                             full.names = FALSE, recursive = FALSE,
                             ignore.case = FALSE, include.dirs = FALSE, no.. = FALSE) # get list of all .csv file in this folder
print(paste("There are ",length(step4_file_list),"files for NAM Step 4 data (Intermediary files)")) # optional output statement
date_list <- unlist(lapply(step4_file_list, function(x){ # start lapply and start defining function used in lapply
  data_date <- substr(x,nchar(x)-35,nchar(x)-39) # identify the time stamp for the file in this iteration
  return(data_date) # return the new file name so a new list of files can be created
}))
print(paste("there are",length(step4_file_list),"NAM Step4 files to be processed"))

# load information about meteo variables
this_source_file <- paste("MeteoVariablesNAM.csv")
MeteoVarsMultiType <- read.csv(file.path(define_file_paths.fn("NAM_Code.directory"),this_source_file))
# grab the list of relevant meteo variables for this file type from MeteoVars
which_meteo <- which(MeteoVarsMultiType$file_type == "grib2") # get grib2 files because grib1 files will be converted to grib2
MeteoVars <- MeteoVarsMultiType[which_meteo,] # matrix with just the relevant rows

all_dates <- seq(as.Date(define_study_constants.fn("start_date")), as.Date(define_study_constants.fn("end_date")), by="days")#unique(Step4_NAM_data$Local.Date)

#### Set up for parallel processing ####
n_cores <- detectCores() - 1 # Calculate the number of cores
print(paste(n_cores,"cores available for parallel processing",sep = " "))
this_cluster <- makeCluster(n_cores) # # Initiate cluster
clusterExport(cl = this_cluster, varlist = c("this_batch_date","step4_file_list","all_dates","NAM_folder","input_sub_folder","input_sub_sub_folder","output_sub_folder","output_sub_sub_folder","step4_file_list","MeteoVars",functions_list), envir = .GlobalEnv) # export functions and variables to parallel clusters (libaries handled with clusterEvalQ)

#### call parallel function ####
print("start parLapply function")
# X = 1:length(all_dates)
par_output <- parLapply(this_cluster,X = 1:length(all_dates), fun = function(x){ # call parallel function
  this_date <- all_dates[x] # get the date to be processed in this iteration
  this_next_day <- this_date+1 # get the date after the date to be processed
  print(paste("Processing NAM data for",this_date))
  new_file_name <- paste("NAM_Step5_",this_date,"_batch",this_batch_date,".csv",sep = "") # name of file to be output
  if (file.exists(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder,new_file_name))) { # does this file already exist?
    print(paste(new_file_name,"already exists and will not be processed again"))
  } else { # file does not exist # if (file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder,new_file_name)) { # does this file already exist?
    print(paste(new_file_name,"does not yet exist and needs to be processed"))
  # list all files that could have data for this date (depends on daylight savings and time zone)
  files_to_check <- c(paste("Step4_NAM_Step2_",this_date,"_00UTC_batch",this_batch_date,"_time.csv",sep = ""),
                      paste("Step4_NAM_Step2_",this_date,"_06UTC_batch",this_batch_date,"_time.csv",sep = ""),
                     paste("Step4_NAM_Step2_",this_date,"_12UTC_batch",this_batch_date,"_time.csv",sep = ""),
                     paste("Step4_NAM_Step2_",this_date,"_18UTC_batch",this_batch_date,"_time.csv",sep = ""),
                     paste("Step4_NAM_Step2_",this_next_day,"_00UTC_batch",this_batch_date,"_time.csv",sep = ""),
                     paste("Step4_NAM_Step2_",this_next_day,"_06UTC_batch",this_batch_date,"_time.csv",sep = ""))
  which_files_present <- which(files_to_check %in% step4_file_list) # which of the files listed exist?
  if (length(which_files_present) > 0) { # only try to process data if there is data to process
  files_to_process <- files_to_check[which_files_present] # list of the files that exist that could have data for this local date
  
  # Merge all of the files that could have data for this date into one data frame
  NAM_data_date_step <- lapply(1:length(files_to_process), function(z){ # start of lapply to open each file
    this_file_data <- read.csv(file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,input_sub_folder,input_sub_sub_folder,files_to_process[z])) # open file
  }) # end of lapply - NAM_data_date_step <- lapply(1:length(files_to_process), function(z){ 
  NAM_data_date_step <- do.call("rbind",NAM_data_date_step) # merge files into one data frame
  
  NAM_data_date_step$Latitude <- round(NAM_data_date_step$Latitude,5) # round latitude to 5 digits
  NAM_data_date_step$Longitude <- round(NAM_data_date_step$Longitude,5) # round longitude to 5 digits
  NAM_data_date_step$Local.Date <- as.Date(NAM_data_date_step$Local.Date) # recognize dates as dates
  NAM_data_date_step$Local.Date.Time <- as.Date(NAM_data_date_step$Local.Date.Time) # recognize datetime as such
  NAM_data_date_step$TimeZone <- as.character(NAM_data_date_step$TimeZone) # recognize times zones as characters
  
  print(paste("x = ",x,"date = ",this_date))
  # isolate all data for this date
  which_this_date <- which(NAM_data_date_step$Local.Date == this_date) # which rows have data for this local date?
  NAM_data_date <- NAM_data_date_step[which_this_date, ] # data frame with data for just this local date
  rm(NAM_data_date_step) # clear variable

  All_date_loc <- unique(NAM_data_date[ ,c("Latitude","Longitude")]) # get a list of dates/locations
  # cycle through all locations on this date
  Step5_NAM_date_list <- lapply(X = 1:dim(All_date_loc)[1], FUN = function(y){ # start lapply and start defining function used in lapply
    #print(paste("location y_i =",y))
    # find all data points with this date/loc
    which_this_date_loc <- which(NAM_data_date$Latitude == All_date_loc[y, c("Latitude")] & NAM_data_date$Longitude == All_date_loc[y, c("Longitude")])
    this_date_loc_step <- NAM_data_date[which_this_date_loc, ] # data frame with data for this location on this date (of this iteration)
    rm(which_this_date_loc)
    drop_cols <- c("State_FIPS", "County_FIPS","Tract_code","ZCTA5_code")
    this_date_loc_step2 <- this_date_loc_step[ , !(names(this_date_loc_step) %in% drop_cols)] # drop columns from data frame
    rm(this_date_loc_step) # clear variable
    this_date_loc <- this_date_loc_step2[!duplicated(this_date_loc_step2), ]
    rm(this_date_loc_step2)
    # can have 5 on the daylight savings switchover, but there should never be more than 5 rows
    if (dim(this_date_loc)[1]>5) {stop(paste("Check code and data - should not have more than 5 NAM data points for given day/location. date = ",all_dates[x]," x=",x," y=",y))}
    
    Step5_NAM_row <- data.frame(matrix(NA,nrow=1,ncol=length(colnames(NAM_data_date)))) # create data frame for input_mat1
    names(Step5_NAM_row) <- colnames(NAM_data_date) # assign the header to input_mat1
    # drop extraneous columns that don't apply to 24-hr data
    drop_cols <- c("Time.UTC","Date","Local.Date.Time","UTC.Date.Time") # define unnecessary columns
    Step5_NAM_row <- Step5_NAM_row[ , !(names(Step5_NAM_row) %in% drop_cols)] # drop unnecessary columns
    Step5_NAM_row[1, c("Latitude","Longitude",  "TimeZone")] <- unique(this_date_loc[ , c("Latitude","Longitude",  "TimeZone")]) # input meta data into step 5
    Step5_NAM_row$Local.Date <- unique(this_date_loc$Local.Date) # input dates
  
    for (meteo_var_counter in 1:dim(MeteoVars)[1]) { # cycle through variables(levels) of interest
    #print(meteo_var_counter)
    thisMeteo_var_Name <- MeteoVars[meteo_var_counter,c("VariableName")] # get variable full name
    thisMeteo_variable <- MeteoVars[meteo_var_counter,c("VariableCode")] # get variable coded name
    thisMeteo_level <- MeteoVars[meteo_var_counter,c("AtmosLevelCode")] # get variable level name
    thisMeteo_units <- MeteoVars[meteo_var_counter,c("Units")] # get variable units
    thisMeteo_24_summary <- MeteoVars[meteo_var_counter,c("X24.hr.summary")]
    this_col_name_step <- as.character(paste(thisMeteo_variable,".",thisMeteo_level,sep = ""))
    this_col_name <- replace_character_in_string.fn(input_char = this_col_name_step,char2replace = " ",replacement_char = ".") 
    #print(this_col_name)
    if (thisMeteo_24_summary == "max") {
      this_meteo_value <- max(this_date_loc[ , this_col_name]) # what is the value for this variable at this level?
    } else if (thisMeteo_24_summary == "mean") {
      this_meteo_value <- mean(this_date_loc[ , this_col_name]) # what is the value for this variable at this level?
    } else if (thisMeteo_24_summary == "sum") {
      this_meteo_value <- sum(this_date_loc[ , this_col_name]) # what is the value for this variable at this level?
    }
    Step5_NAM_row[1, this_col_name] <- this_meteo_value
  } # for (meteo_var_counter in 1:dim(MeteoVars)[1]) { # cycle through variables(levels) of interest
    return(Step5_NAM_row)
    }) # end of lapply function # Step5_NAM_date_list <- lapply(X = 1:dim(All_date_loc)[1], FUN = function(y){ # start lapply and start defining function used in lapply
    Step5_NAM_date <- do.call("rbind", Step5_NAM_date_list) # re-combine data for all locations for this date
    #new_file_name <- paste("NAM_Step5_",this_date,"_batch",this_batch_date,".csv",sep = "")
    write.csv(Step5_NAM_date,file = file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder,new_file_name),row.names = FALSE) # write data for this date to file
    } # if (length(which_files_present) > 0) { # only try to process data if there is data to process
  } # if (file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,output_sub_sub_folder,new_file_name)) { # does this file already exist?
  return(1) # output from function  #(Step5_NAM_date)
} ) # call parallel function

# #### Combine output from parLapply/lapply ####
#print("combine output from parLapply")
# #NAM_data <- do.call("rbind", par_output) #concatinate the output from each iteration

# # write step 5 data to csv file
# print("Write Step 5 data to file")
# write.csv(NAM_data,file = file.path(define_file_paths.fn("ProcessedData.directory"),NAM_folder,output_sub_folder,paste(output_file_name,".csv",sep = "")),row.names = FALSE) # write data to file

#### End use of parallel computing #####
stopCluster(this_cluster) # stop the cluster
rm(this_cluster,par_output)

# clear variables
rm(NAM_folder,input_sub_folder,output_sub_folder,output_file_name,working.directory) # NAM_data,
rm(MeteoVars,MeteoVarsMultiType)#,Step4_NAM_data)
print(paste("Process_NAM_data_step5.R completed at",Sys.time(),sep = " ")) # print time of completion to sink file
