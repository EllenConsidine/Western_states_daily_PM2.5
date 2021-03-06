# CARB_Mobile_specific_functions.R

drag_values_to_next_value.fn <- function(df_in, col_interest){
  # fill in column values to all of the rows (when raw data only shows value at the beginning of a sequence of observations)
  which_val <- which(!is.na(df_in[ , col_interest])) # which rows of data have lat/lon information?
  if (length(which_val) > 0) { # check that there is data to drag down
    for (counter_i in 1:length(which_val)) { # cycle through the rows with lat/lon obs and fill in the rest of the rows
      obs_row_i <- which_val[counter_i] # get the row number of a lat/lon obs
      if (counter_i < length(which_val)) { # if-statement to handle end of file slightly different
        counter_i_plus_1 <- counter_i + 1 # count up to find the next lat/lon obs row
        next_obs_row <- which_val[counter_i_plus_1] # get the row number of the next lat/lon observation - to avoid over-writing it
      } else { # handle end of file slightly different
        counter_i_plus_1 <- NA # not needed for end of file
        next_obs_row <- dim(df_in)[1]+1 # find last row number in file and add one so that the code below works whether or not it's on the last lat/lon obs
      } # if (counter_i < length(which_val)) { # if-statement to handle end of file slightly different
      rm(counter_i_plus_1)
      # fill in rows of data with missing lat/lon data
      df_in[(obs_row_i+1):(next_obs_row-1),col_interest] <- df_in[obs_row_i,col_interest] # fill in column of interest
    } # for (counter_i in 1:length(which_val)) { # cycle through the rows with lat/lon obs and fill in the rest of the rows
  } # if (length(which_val) > 0) { # check that there is data to drag down
  return(df_in)
} # end of drag_values_to_next_value.fn function

# Change class of various columns, e.g., get it to recognize dates as dates, etc
CARB_Mobile_change_data_classes.fn <- function(Merged_CARB_Mobile) {
  options(warn  =  1) # don't throw an error when there's a warning and stop the code from running further
  Merged_CARB_Mobile$ConcHr <- as.numeric(Merged_CARB_Mobile$ConcHr)
  Merged_CARB_Mobile$Latitude <- as.numeric(Merged_CARB_Mobile$Latitude)
  Merged_CARB_Mobile$Longitude <- as.numeric(Merged_CARB_Mobile$Longitude)
  Merged_CARB_Mobile$Sys..Volts <- as.numeric(Merged_CARB_Mobile$Sys..Volts)
  Merged_CARB_Mobile$Flow <- as.numeric(Merged_CARB_Mobile$Flow)
  Merged_CARB_Mobile$RHi <- as.numeric(Merged_CARB_Mobile$RHi)
  Merged_CARB_Mobile$RHx <- as.numeric(Merged_CARB_Mobile$RHx)
  options(warn  =  2) # throw an error when there's a warning and stop the code from running further
  return(Merged_CARB_Mobile)
} # end of CARB_Mobile_change_data_classes.fn function

# Loop through days to create data frame of 24-hr averages (used in CARB_Mobile_1_file_to_small_input_mat.fn below)
CARB_Mobile_daily_averages.fn <- function(Merged_CARB_Mobile_w_neg, this_plotting_color, this_Datum, Data_Source_Name_Display, Data_Source_Name_Short, data_set_counter) {
  # note in sink file that negative hours are removed prior to creating daily values
  which_pos <- which(Merged_CARB_Mobile_w_neg$ConcHr_mug_m3 >= 0)
  N_rows_neg <- dim(Merged_CARB_Mobile_w_neg)[1] - length(which_pos)
  #which_neg <- which(Merged_CARB_Mobile_w_neg$ConcHr_mug_m3 < 0) # find which hourly observations have negative concentrations
  print(paste(N_rows_neg," hourly observations with negative concentrations are removed prior to calculating daily values",sep = "")) # comment in sink file
  Merged_CARB_Mobile <- Merged_CARB_Mobile_w_neg[which_pos, ] # data frame with only positive concentrations
  rm(which_pos, N_rows_neg, Merged_CARB_Mobile_w_neg) # clear variables
  dates_unique <- sort(unique(Merged_CARB_Mobile$Date.Local)) # what dates are in the data
  print(paste("CARB_Mobile data spans ",length(dates_unique) ," dates between ",min(dates_unique)," -- ",max(dates_unique),sep = ""))
  outer_lapply_output <- lapply(1:length(dates_unique), function(this_date_i) { # start lapply function - cycle through all dates
    this_date <- dates_unique[this_date_i] # get the date
    which_this_date <- which(Merged_CARB_Mobile$Date.Local == this_date) # which rows are from this_date?
    this_date_data <- Merged_CARB_Mobile[which_this_date, ] # isolate data for this date
    rm(which_this_date) # clear variable
    unique_monitors <- unique(this_date_data$FileName) # get list of all monitors in the data
    #print(paste("There were ",length(unique_monitors)," monitors operating on ",this_date," (date # ",this_date_i,"/",length(dates_unique),").",sep = ""))
    
    # cycle through monitors within a date
    inner_lapply_output <- lapply(1:length(unique_monitors), function(this_mon_i) { # start lapply function - cycle through all dates
      #print(this_mon_i)
      this_monitor <- unique_monitors[this_mon_i]
      #print(paste(this_date,"--",this_monitor))
      which_this_monitor <- which(this_date_data$FileName == this_monitor) # which rows are for this_monitor?
      this_monitor_day_data_step <- this_date_data[which_this_monitor, ] # isolate data for this monitor (on this date)

      # note in sink file that hours with voltage outside set thresholds are removed prior to creating daily values. 
      # The data for the other hours of that day are flagged.
      which_in_thresholds <- which(this_monitor_day_data_step$Sys..Volts >= voltage_threshold_lower & this_monitor_day_data_step$Sys..Volts <= voltage_threshold_upper)
      N_rows_outside_thresholds <- dim(this_monitor_day_data_step)[1] - length(which_in_thresholds)
      if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
      print(paste(N_rows_outside_thresholds," hourly observations with voltage outside quality thresholds are removed prior to calculating daily values. ",
                  this_date," ",this_monitor,sep = "")) # comment in sink file
        Voltage_flag <- 1#paste(as.character(min(this_monitor_day_data_step$Sys..Volts)), as.character(max(this_monitor_day_data_step$Sys..Volts)))
      } else {
        Voltage_flag <- 0 #"" # blank value if there is no issue with the Voltage
      }# if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
      this_monitor_day_data_step2 <- this_monitor_day_data_step[which_in_thresholds, ] # data frame with only positive concentrations
      rm(which_in_thresholds, N_rows_outside_thresholds, this_monitor_day_data_step) # clear variables
      
      # note in sink file that hours with flow outside set thresholds are removed prior to creating daily values. 
      # The data for the other hours of that day are flagged.
      which_in_thresholds <- which(this_monitor_day_data_step2$Flow >= define_study_constants.fn("CARB_Mobile_flow_threshold_lower") 
                                   & this_monitor_day_data_step2$Flow <= define_study_constants.fn("CARB_Mobile_flow_threshold_upper"))
      N_rows_outside_thresholds <- dim(this_monitor_day_data_step2)[1] - length(which_in_thresholds)
      if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
        print(paste(N_rows_outside_thresholds," hourly observations with flow outside quality thresholds are removed prior to calculating daily values. ",
                    this_date," ",this_monitor,sep = "")) # comment in sink file
        Flow_flag <- 1#paste(as.character(min(this_monitor_day_data_step2$Flow)), as.character(max(this_monitor_day_data_step2$Flow)))
      } else {
        Flow_flag <- 0 #"" # blank value if there is no issue with the Voltage
      }# if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
      this_monitor_day_data_step3 <- this_monitor_day_data_step2[which_in_thresholds, ] # data frame with only positive concentrations
      rm(which_in_thresholds, N_rows_outside_thresholds, this_monitor_day_data_step2) # clear variables
      
      # note in sink file that hours with RHi outside set thresholds are removed prior to creating daily values. 
      # The data for the other hours of that day are flagged.
      which_in_thresholds <- which(this_monitor_day_data_step3$RHi <= define_study_constants.fn("RHi_threshold_upper"))
      N_rows_outside_thresholds <- dim(this_monitor_day_data_step3)[1] - length(which_in_thresholds)
      if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
        print(paste(N_rows_outside_thresholds," hourly observations with RHi outside quality thresholds are removed prior to calculating daily values. ",
                    this_date," ",this_monitor,sep = "")) # comment in sink file
        RHi_flag <- 1#paste(as.character(min(this_monitor_day_data_step2$Flow)), as.character(max(this_monitor_day_data_step2$Flow)))
      } else {
        RHi_flag <- 0 #"" # blank value if there is no issue with the Voltage
      }# if (N_rows_outside_thresholds > 0) { # output statement and flag if any hours have voltage outside of set thresholds
      this_monitor_day_data_step4 <- this_monitor_day_data_step3[which_in_thresholds, ] # data frame with only positive concentrations
      rm(which_in_thresholds, N_rows_outside_thresholds, this_monitor_day_data_step3) # clear variables
      
      
      
      if (dim(this_monitor_day_data_step4)[1] > 0) { # can only compile data if there is data there (number of rows greater than zero)
      this_monitor_day_data <- make_unique_hours_obs.fn(this_monitor_day_data_step4) # sometimes there is more than 1 observation within an hour - merge these together
      rm(this_monitor_day_data_step4) # clear variable
      if (dim(this_monitor_day_data)[1] > 25) {stop("25 observations can happen due to daylight savings time, instead of the usual 24. More than 25 rows of data for a given day/monitor should not happen. Investigate.")} 
      
      # initialize data frame for output row of data
      this_day_mon_ave <- data.frame(matrix(NA,nrow=1,ncol=length(input_header))) # create data frame for this_day_mon_ave
      names(this_day_mon_ave) <- input_header # assign the header to this_day_mon_ave
      this_day_mon_ave <- input_mat_change_data_classes.fn(this_day_mon_ave)
      
      this_day_mon_ave[ ,"PM2.5_Obs"] <- mean(this_monitor_day_data$ConcHr_mug_m3) # PM2.5 concentration
      this_day_mon_ave[ ,"PM2.5_Lat"] <- mean(this_monitor_day_data$Latitude) # Latitude       
      this_day_mon_ave[ ,"PM2.5_Lon"] <- mean(this_monitor_day_data$Longitude) # Longitude              
      this_day_mon_ave[ ,"Datum"] <- this_Datum # datum
      this_day_mon_ave[ ,"Date_Local"] <- unique(this_monitor_day_data$Date.Local) # local date             
      this_day_mon_ave[ ,"Year"] <- year(unique(this_monitor_day_data$Date.Local))                     
      this_day_mon_ave[ ,"Month"] <- month(unique(this_monitor_day_data$Date.Local))     
      this_day_mon_ave[ ,"Day"] <-  day(unique(this_monitor_day_data$Date.Local))                  
      #this_day_mon_ave[ ,"State_Code"] <-                
      #this_day_mon_ave[ ,"County_Code"] <-               
      #this_day_mon_ave[ ,"Site_Num"] <-                  
      #this_day_mon_ave[ ,"Parameter_Code"] <-           
      #this_day_mon_ave[ ,"POC"] <-                       
      #this_day_mon_ave[ ,"Parameter_Name"] <-            
      this_day_mon_ave[ ,"Sample_Duration"] <- "1 HOUR"       
      #this_day_mon_ave[ ,"Pollutant_Standard"] <-       
      this_day_mon_ave[ ,"Units_of_Measure"] <- "ug/m3"      
      #this_day_mon_ave[ ,"Event_Type"] <-                
      this_day_mon_ave[ ,"Observation_Count"] <- dim(this_monitor_day_data)[1]       
      this_day_mon_ave[ ,"Observation_Percent"] <- dim(this_monitor_day_data)[1]/24*100  
      #this_day_mon_ave[ ,"1st_Max_Value"] <-             
      #this_day_mon_ave[ ,"1st_Max_Hour"] <-              
      #this_day_mon_ave[ ,"AQI"] <-                       
      #this_day_mon_ave[ ,"Method_Code"] <-              
      #this_day_mon_ave[ ,"Method_Name"] <-               
      this_day_mon_ave[ ,"PM25_Station_Name"] <- unique(this_monitor_day_data$Alias)
      #this_day_mon_ave[ ,"Address"] <-                   
      #this_day_mon_ave[ ,"State_Name"] <- "California" # some data appears to be outside of CA              
      #this_day_mon_ave[ ,"County_Name"] <-               
      #this_day_mon_ave[ ,"City_Name"] <-                 
      #this_day_mon_ave[ ,"CBSA_Name"] <-                 
      #this_day_mon_ave[ ,"Date_of_Last_Change"] <-      
      #this_day_mon_ave[ ,"State_Abbrev"] <- "CA" # some data appears to be outside of CA
      #this_day_mon_ave[ ,"Winter"] <-                    
      this_day_mon_ave[ ,"Data_Source_Name_Display"] <- Data_Source_Name_Display
      this_day_mon_ave[ ,"Data_Source_Name_Short"] <- Data_Source_Name_Short
      this_day_mon_ave[ ,"Data_Source_Counter"] <- data_set_counter    
      this_day_mon_ave[ ,"Source_File"] <-  unique(this_monitor_day_data$FileName)         
      this_day_mon_ave[ ,"Composite_of_N_rows"] <- sum(this_monitor_day_data$N_composite_rows) #dim(this_monitor_day_data)[1]  
        #which_neg_obs <- which(this_monitor_day_data$ConcHr_mug_m3 < 0)
      this_day_mon_ave[ ,"N_Negative_Obs"] <- sum(this_monitor_day_data$N_neg_obs) #length(which_neg_obs)         
        if (sum(this_monitor_day_data$N_neg_obs) > 0) {
          stop("CARB_Mobile_daily_averages.fn: all of the negative PM2.5 concentrations should have been removed by this point in the code")
        }
       # rm(which_neg_obs)
      #this_day_mon_ave[ ,"flg.Lat"] <-                   
      #this_day_mon_ave[ ,"flg.Lon"] <-                   
      #this_day_mon_ave[ ,"Type"] <-                      
      #this_day_mon_ave[ ,"flg.Type"] <-                 
      #this_day_mon_ave[ ,"flg.Site_Num"] <-              
      #this_day_mon_ave[ ,"flg.PM25_Obs"] <-              
      this_day_mon_ave[ ,"l/m Ave. Air Flw"] <- mean(this_monitor_day_data$Flow)       
      #this_day_mon_ave[ ,"flg.AirFlw"] <- "0 0" # set all to zero, initially
        which_flow_out_bounds <- which(this_monitor_day_data$Flow < define_study_constants.fn("CARB_Mobile_flow_threshold_lower") |
                                         this_monitor_day_data$Flow > define_study_constants.fn("CARB_Mobile_flow_threshold_upper"))
        if (length(which_flow_out_bounds) > 0) { # put in flags if flow was out of bounds
          this_day_mon_ave[ ,"flg.AirFlw"] <- as.character(paste(min(this_monitor_day_data$Flow)," ",max(this_monitor_day_data$Flow),sep = ""))
        } else {
          this_day_mon_ave[ ,"flg.AirFlw"] <- "OK" #"0 0" # # flag indicating data is ok - needs to be consistent with DRI data since these data sets are treated the same for quality checking (step 2)
        } # if (length(which_flow_out_bounds) > 0) { # put in flags if flow was out of bounds
        rm(which_flow_out_bounds)
        this_day_mon_ave[ ,"FlowFlag"] <- Flow_flag
      #this_day_mon_ave[ ,"Deg C Av Air Temp"] <-         
      #this_day_mon_ave[ ,"flg.AirTemp"] <-               
      this_day_mon_ave[ ,"% Rel Humidty"] <- mean(this_monitor_day_data$RHx)            
      #which_RHx_out_bounds <- which(this_monitor_day_data$RHi >= define_study_constants.fn("RHi_threshold_upper"))
      #if (length(which_RHi_out_bounds) > 0) { # put in flags if relative humidity was out of bounds
      #  this_day_mon_ave[ ,"flg.RelHumid"] <- as.character(max(this_monitor_day_data$RHi))
      #} else {
      #  this_day_mon_ave[ ,"flg.RelHumid"] <- "OK" #"0 0" # flag indicating data is ok
      #}# if (length(which_RHi_out_bounds) > 0) { # put in flags if relative humidity was out of bounds
      #this_day_mon_ave[ ,"mbar Barom Press"] <-          
      #this_day_mon_ave[ ,"flg.Barom Press"] <-           
      #this_day_mon_ave[ ,"deg C Sensor  Int AT"] <-      
      #this_day_mon_ave[ ,"flg.deg C Sensor Int AT"] <-  
      #this_day_mon_ave[ ,"% Sensor Int RH"] <-           
      #this_day_mon_ave[ ,"flg.%SensorIntRH"] <- 
      
      this_day_mon_ave[ ,"% Sensor Int RH"] <- mean(this_monitor_day_data$RHi)            
      which_RHi_out_bounds <- which(this_monitor_day_data$RHi >= define_study_constants.fn("RHi_threshold_upper"))
      if (length(which_RHi_out_bounds) > 0) { # put in flags if relative humidity was out of bounds
        this_day_mon_ave[ ,"flg.%SensorIntRH"] <- as.character(max(this_monitor_day_data$RHi))
      } else {
        this_day_mon_ave[ ,"flg.%SensorIntRH"] <- "OK" #"0 0" # flag indicating data is ok
      }# if (length(which_RHi_out_bounds) > 0) { # put in flags if relative humidity was out of bounds
      this_day_mon_ave[ ,"RHiFlag"] <- RHi_flag
      
      #this_day_mon_ave[ ,"flg.WindSpeed"] <-            
      this_day_mon_ave[ ,"Battery Voltage volts"] <- mean(this_monitor_day_data$Sys..Volts)
      if (max(this_monitor_day_data$Sys..Volts) > voltage_threshold_upper | min(this_monitor_day_data$Sys..Volts) < voltage_threshold_lower) {
        this_day_mon_ave[ ,"flg.BatteryVoltage"] <- paste(as.character(min(this_monitor_day_data$Sys..Volts)), as.character(max(this_monitor_day_data$Sys..Volts)))
      } else {
        this_day_mon_ave[ ,"flg.BatteryVoltage"] <- "0 0" #0
      }
      this_day_mon_ave[ ,"VoltageFlag"] <- Voltage_flag
      #this_day_mon_ave[ ,"Alarm"] <-                     
      #this_day_mon_ave[ ,"flg.Alarm"] <-                
      this_day_mon_ave[ ,"InDayLatDiff"] <- max(this_monitor_day_data$Latitude) - min(this_monitor_day_data$Latitude)            
      this_day_mon_ave[ ,"InDayLonDiff"] <- max(this_monitor_day_data$Longitude) - min(this_monitor_day_data$Longitude)
      this_day_mon_ave[ ,"PlottingColor"] <- this_plotting_color           
      #this_day_mon_ave[ ,"SerialNumber"] <- 
    } else { # no rows of data left
      this_day_mon_ave <- this_monitor_day_data_step4
    } # if (dim(this_monitor_day_data_step2)[1] > 0) { # can only compile data if there is data there (number of rows greater than zero)
      return(this_day_mon_ave) # return processed data
    }) # end lapply function
    One_Day_all_monitors <- do.call("rbind", inner_lapply_output) #concatinate the output from each iteration  
    rm(inner_lapply_output)  
    #stop_time <- Sys.time() -start_time
    #print(stop_time)
    return(One_Day_all_monitors) # return processed data
  }) # end lapply function
  Daily_CARB_Mobile <- do.call("rbind", outer_lapply_output) #concatinate the output from each iteration
  
  return(Daily_CARB_Mobile)
} # end of CARB_Mobile_daily_averages.fn function

make_unique_hours_obs.fn <- function(this_monitor_day_data_step) {
  unique_times <- unique((this_monitor_day_data_step$Date.Time.Local))
  if (length(unique_times) == dim(this_monitor_day_data_step)[1]) { # don't waste computational time on monitor/days that don't have any repeated hours
    this_monitor_day_data <- this_monitor_day_data_step
    this_monitor_day_data$N_composite_rows <- 1
    this_monitor_day_data$N_neg_obs <- 0
    which_neg_obs <- which(this_monitor_day_data_step$ConcHr_mug_m3 < 0)
    this_monitor_day_data[which_neg_obs, c("N_neg_obs")] <- 1
  } else {
  lapply_output_hours <- lapply(1:length(unique_times), function(x){
    this_time <- unique_times[x]
    which_this_time <- which(this_monitor_day_data_step$Date.Time.Local == this_time)
    #print(paste(unique(this_monitor_day_data_step$Alias),"has",length(which_this_time),"observations at",this_time," These will be merged into 1 observation.")) 
    if (length(which_this_time) == 1) {
      this_monitor_hour <- this_monitor_day_data_step[which_this_time, ]
      if (this_monitor_hour$ConcHr_mug_m3 < 0) {
        this_monitor_hour$N_neg_obs <- 1
      } else {
        this_monitor_hour$N_neg_obs <- 0
      }
    } else {
      cat(paste(unique(this_monitor_day_data_step$Alias),"has",length(which_this_time),"observations during hour: ",this_time,". These will be merged into 1 observation. \n")) 
      this_monitor_hour_step <- this_monitor_day_data_step[which_this_time, ]
      this_monitor_hour <- data.frame(matrix(data = NA,nrow = 1,ncol = length(names(this_monitor_day_data_step))))
      names(this_monitor_hour) <- names(this_monitor_day_data_step)
      this_monitor_hour$MasterTable_ID <- mean(this_monitor_hour_step$MasterTable_ID)
      this_monitor_hour$Alias <- unique(this_monitor_hour_step$Alias)
      this_monitor_hour$Latitude <- mean(this_monitor_hour_step$Latitude)              
      this_monitor_hour$Longitude <- mean(this_monitor_hour_step$Longitude)           
      this_monitor_hour$Date.Time.GMT <- unique(this_monitor_hour_step$Date.Time.GMT)      
      this_monitor_hour$Start.Date.Time..GMT. <- unique(this_monitor_hour_step$Start.Date.Time..GMT.)
      this_monitor_hour$COncRT <- mean(as.numeric(as.character(this_monitor_hour_step$COncRT)))
      this_monitor_hour$ConcHr <- mean(this_monitor_hour_step$ConcHr)       
      this_monitor_hour$Flow <- mean(as.numeric(as.character(this_monitor_hour_step$Flow)))
      this_monitor_hour$W.S <- mean(as.numeric(as.character(this_monitor_hour_step$W.S)))
      this_monitor_hour$W.D <- mean(as.numeric(as.character(this_monitor_hour_step$W.D)))
      this_monitor_hour$AT <- mean(as.numeric(as.character(this_monitor_hour_step$AT)))         
      this_monitor_hour$RHx <- mean(as.numeric(as.character(this_monitor_hour_step$RHx)))
      this_monitor_hour$RHi <- mean(as.numeric(as.character(this_monitor_hour_step$RHi)))
      this_monitor_hour$BV <- mean(as.numeric(as.character(this_monitor_hour_step$BV)))
      this_monitor_hour$FT <- mean(as.numeric(as.character(this_monitor_hour_step$FT)))                
      this_monitor_hour$Alarm <- mean(as.numeric(as.character(this_monitor_hour_step$Alarm)))
      this_monitor_hour$Type <- unique(this_monitor_hour_step$Type)
      this_monitor_hour$Serial.Number <- mean(as.numeric(as.character(this_monitor_hour_step$Serial.Number)))
      this_monitor_hour$Version <- mean(as.numeric(as.character(this_monitor_hour_step$Version)))
      this_monitor_hour$Sys..Volts <- mean(as.numeric(as.character(this_monitor_hour_step$Sys..Volts)))
      this_monitor_hour$TimeStamp <- paste(as.character(this_monitor_hour_step$TimeStamp), collapse = "; ")
      this_monitor_hour$PDate <- paste(as.character(this_monitor_hour_step$PDate), collapse = "; ")
      this_monitor_hour$FileName <- unique(this_monitor_hour_step$FileName)
      this_monitor_hour$TimeStampParsed <- mean(this_monitor_hour_step$TimeStampParsed)
      this_monitor_hour$TimeStampTruncated <- unique(this_monitor_hour_step$TimeStampTruncated)
      this_monitor_hour$TimeStampLocal <- unique(this_monitor_hour_step$TimeStampLocal)
      this_monitor_hour$Date.Local <- unique(this_monitor_hour_step$Date.Local)
      this_monitor_hour$Date.Time.GMT.Parsed <- unique(this_monitor_hour_step$Date.Time.GMT.Parsed)
      this_monitor_hour$Date.Time.Local <- unique(this_monitor_hour_step$Date.Time.Local)
      this_monitor_hour$ConcHr_mug_m3 <- mean(this_monitor_hour_step$ConcHr_mug_m3)
      which_neg_obs <- which(this_monitor_hour_step$ConcHr_mug_m3 < 0)
      this_monitor_hour$N_neg_obs <- length(which_neg_obs)
    }
    this_monitor_hour$N_composite_rows <- length(which_this_time)
    return(this_monitor_hour)  
  })
  this_monitor_day_data <- do.call("rbind",lapply_output_hours)
  } # if (length(unique_times) == dim(this_monitor_day_data_step)[1]) {
  return(this_monitor_day_data)
} # end of reduce_more_than_24_obs.fn function
