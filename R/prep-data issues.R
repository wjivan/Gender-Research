library(here)
library(tidyverse)
library(haven)
library(DataExplorer)
library(compareDF)
library(rlist)
library(stringr)
library(stringi)

df_zeina <- read_dta(here('Input', 'clean_data_Oct2020.dta'))

# Missing outlet issue
nrow(df_zeina %>% filter((outlet=='' | is.na(outlet))))
missing <- df_zeina %>% filter((outlet=='' | is.na(outlet)))
missing_papers <- df_zeina %>% filter(title %in% 
                                        (missing %>% distinct(title) %>% pull())) %>% 
  arrange(title, clean_name)

# Fill in the missing outlet using title, paper_code and date
# Create the appropriate df to merge
filler <- missing_papers %>% select(outlet, title, date) %>% 
  filter(outlet != '') %>% 
  distinct() %>% 
  rename('outlet_filler'='outlet')

df_zeina <- df_zeina %>% 
  left_join(filler) %>% 
  mutate(outlet = ifelse((outlet=='' | is.na(outlet)), outlet_filler, outlet)) %>% 
  select(-outlet_filler) %>% 
  mutate(outlet = ifelse(is.na(outlet) & grepl('w', paper_code), 
                         'nber',
                         outlet)) %>% 
  mutate(indc = row_number())

# Create a function to clean strings
clean_string <- function(x){
  x = gsub('\\"','', x)
  x = gsub('\\.','',x)
  x = gsub("\\'", '', x)
  x = gsub("  ", ' ', x)
  x = str_to_title(x)
  x = str_trim(x)
  x = stri_trans_general(x, "Latin-ASCII")
return(x)
}




col_names <- c('outlet', 'title', 'date', 'original_name','paper_code')

# Check NBER
nber <- read_csv(here('Input/NBER/nber_winter_data.csv'))
min_date <- min(df_zeina %>% filter(outlet == 'nber') %>% pull(date))
max_date <- max(df_zeina %>% filter(outlet == 'nber') %>% pull(date))

nber_clean <- nber %>% 
  filter(issue_date>= min_date & issue_date<= max_date) %>% 
  mutate(outlet = 'nber') %>% 
  select(outlet, title, issue_date,name, paper) %>% 
  distinct() %>% 
  setNames(col_names)

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
  mutate(output = 'cepr') %>% 
  select(output, DiscussionPaper_Title, Date_of_Publication, Author, DP_Number) %>% 
  setNames(col_names) %>% 
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
  mutate(output = 'vox') %>% 
  select(output, Title, `Dat of Publication`, Author) %>% 
  group_by(Title) %>% 
  mutate(paper_code = paste0('vox', cur_group_id())) %>% 
  ungroup() %>% 
  setNames(col_names)

# Covid papers
covid_clean <- read_rds(here('Output/covid_complete.RDS'))
covid_clean <- covid_clean %>% 
  mutate(output = 'covid') %>% 
  group_by(title) %>% 
  mutate(paper_code = cur_group_id()) %>% 
  ungroup() %>% 
  mutate(paper_code = paste0('covid', paper_code)) %>% 
  select(output, title, date, author, paper_code) %>% 
  setNames(col_names)

# Combine all raw data
df_raw <- reduce(list(nber_clean,cepr_clean, vox_clean, covid_clean), bind_rows)
df_raw_clean <- df_raw %>%  
  # Filter missing
  drop_na() %>% 
  
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
  distinct(outlet, title_trans, clean_name, date, .keep_all = T)

  unique_titles <- df_raw_clean %>% select(outlet, date, title) %>% mutate(title = clean_string(title),
                                                       title = clean_string(title),
                                                       date = as.Date(date, format='%Y%m%d')) %>% 
  distinct()

# Full audit of all outputs currently in place
df_audit <- df_zeina %>% 
  select(outlet, title, date, original_name,paper_code, clean_name, first_name, indc) %>% 
  mutate(clean_name = clean_string(clean_name),
         title = clean_string(title),
         clean_name = paste(word(clean_name,1), word(clean_name,-1))) %>% 
  mutate(three_letters = str_extract(first_name, "^.{3}")) %>% 
  # find out the missing outlet
  left_join(unique_titles, by=c('title','date')) %>% 
  mutate(outlet.x = ifelse(is.na(outlet.x), outlet.y, outlet.x)) %>% 
  select(-outlet.y, outlet=outlet.x) %>% 
  distinct(outlet, title, date, clean_name, .keep_all = T)

sum(is.na(df_audit$outlet))

# set up a getmode function without NAs
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv <- uniqv[!is.na(uniqv)]
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

getmode_var <- function(...){
  ans <- getmode(c(...))
  return(ans)
}

df_check <- df_raw_clean  %>% 

  left_join(df_audit) %>%
  left_join(df_audit %>% select(date, title, original_name,indc),
            by=c('title_trans'='title','date'='date', 'original_name'='original_name')) %>%
  left_join(df_audit %>% select(date, title, original_name,indc),
            by=c('title'='title','date'='date', 'name_trans'='original_name')) %>%
  left_join(df_audit %>% select(date, title, original_name,indc),
            by=c('title_trans'='title','date'='date', 'name_trans'='original_name')) %>%
  
  left_join(df_audit %>% select(date, paper_code, clean_name,indc),
            by=c('paper_code','date', 'clean_name')) %>%
  left_join(df_audit %>% select(paper_code, clean_name,indc),
            by=c('paper_code', 'clean_name')) %>%
  left_join(df_audit %>% select(date, title, clean_name,indc),
            by=c('title_trans'='title','date', 'clean_name'))%>% 
  left_join(df_audit %>% select(paper_code, three_letters,indc) %>% distinct(),
            by=c('paper_code', 'three_letters'))%>%
  left_join(df_audit %>% select(outlet,date, clean_name,indc) %>% distinct(),
            by=c('outlet','date','clean_name'))%>% 
  rowwise() %>%
  mutate(indicator=getmode_var(indc,indc.x, indc.y,indc.x.x, 
                               indc.y.y, indc.x.x.x, 
                               indc.y.y.y,indc.x.x.x.x, indc.y.y.y.y))

df_final <- df_check %>% 
  select(-starts_with('indc')) %>% 
  distinct() %>% 
  group_by(title, clean_name, date) %>% 
  mutate(counts = n()) %>% 
  ungroup() %>% 
  arrange(desc(counts), title, clean_name) %>% 
  select(indicator, outlet, paper_code, title_trans, clean_name, original_name) %>% 
  setNames(c('indc','outlet', 'clean_paper_code', 'clean_title', 'clean_name', 'original_name')) %>% 
  left_join(df_zeina, by=c('indc')) %>% 
  select(-paper_code, -clean_name.y, -first_name, -last_name, -outlet.y, -original_name.y, -title) %>% 
  mutate(first_name = word(clean_name.x,1),
         last_name = word(clean_name.x,-1)) %>% 
  #filter(outlet.x != 'covid') %>% 
  select(ID, indc, outlet=outlet.x, clean_title,
         original_name = original_name.x, clean_name=clean_name.x,
         date, everything()) %>% 
  arrange(outlet, date, clean_title, clean_name)

df_noissue <- df_final %>% 
  filter(!is.na(indc))

missing_from_output <- df_final %>% 
  filter(is.na(indc))

missing_from_raw <- df_audit %>% 
  filter(!indc %in% unique(df_noissue$indc)) %>% 
  #filter(outlet != 'covid') %>% 
  select(indc) %>% 
  left_join(df_zeina) %>% 
  # drop first paper that's wrong
  filter(indc != 1945)

# Manual matching
write.csv(missing_from_output, here('Output/missing_from_output.csv'))
write.csv(missing_from_raw, here('Output/missing_from_raw.csv'))

missing_from_output <- read_csv(here('Output/manual_match_missing_output.csv'))
missing_from_output <- missing_from_output %>% 
  filter(is.na(indc)) %>% 
  select(-X1)

# Add in missing from raw
to_add <- missing_from_raw %>% 
  select(indc) %>% 
  left_join(df_zeina) %>% 
  mutate(clean_title = clean_string(title)) %>% 
  mutate(clean_title = ifelse(clean_title == 'Icelands Programme With The Imf 200811',
                              'Icelands Programme With The Imf 2008-11',
                              clean_title)) %>% 
  left_join(df_raw_clean %>% select(title_trans, paper_code) %>% distinct() %>% 
              rename('clean_paper_code'='paper_code'),
            by=c('clean_title'='title_trans')) %>% 
  select(-title, -paper_code)

df_combined_noissue <- df_noissue %>% 
  bind_rows(to_add)

covid_noissue <- df_combined_noissue %>% filter(outlet=='covid')
write.csv(df_combined_noissue, here('Output/database_noissue_06022021.csv'))
write_rds(df_combined_noissue, here('Output/df_combined_noissue.rds'))
