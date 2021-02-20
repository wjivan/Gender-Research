# Given a list of names, find the appropriate gender and affiliation

library(here)
library(tidyverse)
library(haven)
library(DataExplorer)
library(compareDF)
library(rlist)
library(stringr)
library(stringi)

missing_papers <- read_csv(here('Output/missing_from_output.csv')) %>% select(-X1)
current_database <- read_rds(here('Output/df_combined_noissue.rds'))
latest_indc <- max(current_database$indc)
missing_papers <- missing_papers %>% 
  mutate(indc = row_number()+latest_indc)

# Get raw information
df_raw_clean <- read_rds(here('Output/df_raw_clean.rds'))
missing_df <- missing_papers %>% 
  select(ID:clean_name, clean_paper_code) %>% 
  left_join(df_raw_clean)