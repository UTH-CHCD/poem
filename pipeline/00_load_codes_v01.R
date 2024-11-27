if (!require("pacman")) install.packages("pacman")
pacman::p_load(RPostgres, DBI, keyring,janitor, tidyverse, readxl, stringr)

##################################
#### SETUP PATHS AND VERSIONS ####
# For versioning of the Excel report of DX
# version <- "v01"
greenplum_user = "jwozny" #this is for keyring to go get your password info so you don't have to write it in the file

# Set Paths 
current.path <- here::here()
poem.path <- dirname(dirname(current.path))
codeset.path <- file.path(poem.path,"poem", "data","ancillary")


########## Load Pregnany Codes 
excel.path <- file.path(codeset.path,"Data Harmonization Tracker_20241127.xlsx")


#### LOAD AND CLEAN DATA ####

#  Function to find weird characters that cause problems later on
find_funky_characters <- function(df) {
  funky_chars <- lapply(df, function(column) {
    if (is.character(column)) {
      # Combine all text into a single string
      all_text <- paste(column, collapse = "")

      # Identify unique non-printable or non-ASCII characters
      unique_chars <- unique(strsplit(all_text, split = "")[[1]])
      funky <- unique_chars[!grepl("^[[:print:]]$", unique_chars)] # Non-printable
      return(funky)
    } else {
      return(NULL)
    }
  })

  # Filter out NULL entries (non-character columns)
  funky_chars <- funky_chars[!sapply(funky_chars, is.null)]

  # Return funky characters by column
  return(funky_chars)
}


##### Birth Codes #####

# Read Data
covariates <- read_excel(excel.path, sheet = 9) %>% clean_names() 


# Check encoding
find_funky_characters(covariates)

# Correct encoding
covariates[] <- lapply(covariates, function(x) {
  if (is.character(x)) iconv(x, from = "UTF-8", to = "latin1//TRANSLIT")
  else x
})

# Check encoding again (should be fixed)
find_funky_characters(covariates)

################################
#### Load Data to SPC ####
################################

# Connect to Greenplum (note: this requires having set up keyring. it will get your key info based on the greenplum_user variable)
spc <- dbConnect(odbc::odbc(),
                 dsn = "SPC")

# Write the raw id table to the database

# Name of the table
table_name <- "poem_covariates"

# Check if the table exists and drop it if it does
if (dbExistsTable(spc, table_name)) {
  dbRemoveTable(spc, table_name)
}

# Write raw table to database 
dbWriteTable(spc, table_name, covariates, overwrite=TRUE)

# Close the connection
dbDisconnect(spc)


