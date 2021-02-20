library(here)
library(tidyverse)
library(haven)
library(DataExplorer)
library(compareDF)
library(rlist)
library(stringr)
library(stringi)
library(reticulate)
use_virtualenv("zeina")

noissue <- read_rds(here('Output/df_combined_noissue.rds'))
min_date <- min(noissue$date)
max_date <- max(noissue$date)

# Read NBER
source_python(here('Python/prep-read_nber.py'))
nber_raw <- read_nber()

# Cleaning NBER
nber_clean <- nber_raw %>% 
  mutate(paper_link = paste0('https://www.nber.org/papers/', paper)) %>% 
  mutate(issue_date = as.Date(issue_date, format = '%Y%m%d')) %>% 
  select(outlet, 
         title, 
         date = issue_date,
         original_name = name, 
         paper_code = paper,
         jel = jel_combined,
         prog_areas = prog_combined) %>% 
  distinct() %>% 
  arrange(desc(date), title, original_name) %>% 
  filter(date>=min_date) %>% 
  mutate(original_name = unlist(original_name),
         jel = unlist(jel),
         prog_areas = unlist(prog_areas))


# CEPR
sheets = c('DPs 2004-2010','DPs 2011-2015','DPs 2016-today')
df_list = list()

for(s in sheets){
  
  df <- readxl::read_xlsx(here('Input/CEPR/Data2004-2020.xlsx'), sheet =s )
  df_list <- list.append(df_list, df)
}

cepr_clean <- reduce(df_list, bind_rows)

df2 <- readxl::read_xlsx(here('Input/CEPR/cepr_DataMaytoSept2020.xlsx'), sheet = 'DPs 21 May - 31 Aug')
df2 <- df2 %>% 
  setNames(colnames(cepr_clean))

df3 <- readxl::read_xlsx(here('Input/CEPR/DataSeptt0Oct2020.xlsx'), sheet = 'DPs 1 Sept to 31 Oct')
df3 <- df3 %>% 
  setNames(names(cepr_clean))

cepr_clean <- cepr_clean %>% bind_rows(df2) %>% bind_rows(df3) %>% 
  distinct() %>% 
  mutate(outlet = 'cepr') %>% 
  select(outlet, 
         title = DiscussionPaper_Title, 
         date = Date_of_Publication, 
         original_name = Author, 
         paper_code = DP_Number, 
         affiliation_raw = Affiliation,
         jel = codes,
         prog_areas = ProgAreas) %>% 
  mutate(paper_code = as.character(paper_code))


# Check VOX
sheets = c('Vox 2007-2010','Vox 2011 - 2015','Vox 2016-today')
df_list = list()

for(s in sheets){
  
  df <- readxl::read_xlsx(here('Input/CEPR/Data2004-2020.xlsx'), sheet =s )
  df_list <- list.append(df_list, df)
}

vox_clean <- reduce(df_list, bind_rows)

df2 <- readxl::read_xlsx(here('Input/CEPR/cepr_DataMaytoSept2020.xlsx'), sheet = 'Vox 21 May - 31 Aug')
df2 <- df2 %>% 
  setNames(colnames(vox_clean))

df3 <- readxl::read_xlsx(here('Input/CEPR/DataSeptt0Oct2020.xlsx'), sheet = 'Vox 1 Sept - 31 Oct')
df3 <- df3 %>% 
  setNames(names(vox_clean))

vox_clean <- vox_clean %>% bind_rows(df2) %>% bind_rows(df3) %>% 
  distinct() %>% 
  mutate(outlet = 'vox') %>% 
  select(outlet, 
         title = Title, 
         date = `Dat of Publication`, 
         original_name = Author,
         affiliation_raw = Affiliation) %>% 
  group_by(title) %>% 
  mutate(paper_code = paste0('vox', cur_group_id())) %>% 
  ungroup()

# Covid papers
source(here('R/calc-redo covid.R'))
covid_clean <- read_covid(file, sheets, output_file)
covid_clean <- covid_clean %>% 
  mutate(outlet = 'covid') %>% 
  group_by(title) %>% 
  mutate(paper_code = cur_group_id()) %>% 
  ungroup() %>% 
  mutate(paper_code = paste0('covid', paper_code)) %>% 
  select(outlet, title, date, 
         original_name = author, 
         paper_code,
         covid_decision = decision,
         sex = gender,
         affiliation_raw = affiliation) 

df_combined = reduce(list(covid_clean, nber_clean, cepr_clean, vox_clean), bind_rows)

# Combine all raw data
vars <- c('outlet', 'title', 'date', 'original_name','paper_code')
df_raw_clean <- df_combined %>%  
  
  # Filter missing
  drop_na(any_of(vars)) %>% 
  
  # Cleaning strings
  mutate(title_trans = clean_string(title))%>%
  mutate(date = as.Date(date, format='%Y%m%d')) %>%
  mutate(name_trans = clean_string(original_name),
         name_trans = clean_string(original_name )) %>% # Not sure why you need to do this twice to clear '
  
  # Get clean name to reverse first & second name order if , is present
  mutate(clean_name = ifelse(grepl(',',name_trans), paste(word(name_trans, 2, sep=","), 
                                                          word(name_trans, 1, sep=",")),
                             name_trans),
         clean_name = str_trim(clean_name),
         clean_name = paste(word(clean_name,1), word(clean_name,-1))) %>% 
  mutate(first_name = word(clean_name, 1)) %>% 
  mutate(three_letters = str_extract(first_name, "^.{3}")) %>% 
  
  # Ensure cleaning yet again
  mutate(title_trans = clean_string(title_trans),
         clean_name = clean_string(clean_name)) %>% 
  
  # De-duplication
  distinct(outlet, title_trans, clean_name, date, .keep_all = T) %>% 
  
  # Add row numbers
  mutate(raw_indc = row_number())



write_rds(df_raw_clean, here('Output/df_raw_clean.rds'))
