library(here)
library(tidyverse)
library(stringi)
library(lubridate)

file = 'covid paper info for Elisa_clean.xlsx'
sheets = c('1st data set', '2nd data set', '3rd dataset', '4th dataset')
output_file = paste0('covid', 1:4, '.RDS')

clean_covid_sheet <- function(filename, sheetname, outputname){

    # Read in dataset
    df <- readxl::read_xlsx(here('Input', 'COVID', filename), sheet = sheetname)
    
    colnames(df) <- c('gender', 'first_name', 'last_name', 'affiliation',
                      'title', 'coauthors', 'date', 'decision')
    
    max_authors = max(df %>% 
                        # Check number of authors
                        mutate(n_authors = str_count(`coauthors`, pattern = ",")) %>% 
                        pull(n_authors), na.rm=TRUE)+1
    
    df_clean <- df %>% 
      # replace and
      mutate(coauthors = str_replace_all(coauthors, ' and', ',')) %>% 
      mutate(coauthors = str_replace_all(coauthors, ';', ',')) %>% 
      # split authors by ,
      separate(coauthors, paste0('authors',1:max_authors), sep=',') %>% 
      # set lead author as author100
      mutate(author100 = paste(first_name, last_name)) %>% 
      # pivot longer
      pivot_longer(cols=starts_with('author'), values_to = 'author') %>% 
      filter(!is.na(author)) %>% 
      # set lead author descriptions
      select(-first_name, -last_name) %>% 
      mutate(gender = ifelse(name=='author100', gender, NA),
             affiliation = ifelse(name=='author100', affiliation, NA)) %>% 
      # copy out extra affiliations in brackets
      mutate(affiliation = ifelse(grepl('\\(', author), str_extract(author, '\\([a-zA-Z\\- ]+\\)'),
                                  affiliation),
             affiliation = gsub('[()]', '', affiliation)) %>% 
      # clean up names
      mutate(author = str_replace(author, "\\([a-zA-Z\\- ]+\\)", ''),
             author = str_trim(author), 
             author = str_to_title(author), 
             author = stri_trans_general(author, "Latin-ASCII")) %>% 
      # drop any blanks
      filter(author != '') %>% 
      select(-name) %>% 
      # create first and last name
      mutate(first_name = word(author, start = 1 , end = 1),
             last_name = word(author, start=-1, end=-1)) %>% 
      # format date
      mutate(date = ymd(date)) %>% 
      # format gender
      mutate(gender = ifelse(gender == 'M', 'Male',
                             ifelse(gender == 'F', 'Female', NA)))
    
    write_rds(df_clean, here('Output', outputname))

}

read_covid <- function(myfile, mysheets, my_output_file){

    for(i in 1:length(sheets)){
      clean_covid_sheet(myfile, mysheets[i], my_output_file[i])
    }
    
    covid_files = list.files(here('Output'), pattern = 'covid*', full.names=TRUE)
    df_list = lapply(covid_files, read_rds)
    df_merge = reduce(df_list, bind_rows)
    
    # Clean out duplicates
    df_clean = df_merge %>% 
      group_by(title, first_name, last_name, date) %>% 
      mutate(gender = gender[which(!is.na(gender))[1]],
             affiliation = affiliation[which(!is.na(affiliation))[1]]) %>% 
      ungroup() %>% 
      distinct()
    
    return(df_clean)
}



