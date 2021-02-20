library(tidyverse)
library(here)
library(DataExplorer)
library(lubridate)

df <- read_rds(here('Output/df_combined_noissue.rds'))

positions <- unique(
  c(unique(df$pub_position, df$curr_position))
  )

df_positions <- data.frame(position_names = positions) %>% 
  mutate(position_names = str_trim(position_names),
         position_names = str_to_lower(position_names)) %>% 
  filter(position_names != '') %>% 
  mutate(titles = ifelse(grepl('assistant prof', position_names), 'assistant professor',
           ifelse(grepl('prof', position_names), 'professor',
                         ifelse(grepl('postdoc', position_names), 'postdoc',
                                ifelse(grepl('chair |fellow|reader', position_names), 'professor',
                                       ifelse(grepl('student|phd|research|candidate|scholar', position_names), 'junior research',
                                              'professional economists'))))))

df_clean <- df %>% 
  mutate(curr_position = str_to_lower(str_trim(curr_position)),
         pub_position = str_to_lower(str_trim(pub_position))) %>% 
  left_join(df_positions, by=c('curr_position'='position_names')) %>% 
  left_join(df_positions, by=c('pub_position'='position_names')) %>% 
  rename('curr_position_clean'='titles.x',
         'pub_position_clean'='titles.y')

write_rds(df_clean,here('Output/df_combined_noissue_clean.rds'))
