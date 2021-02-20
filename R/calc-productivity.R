library(tidyverse)
library(here)
library(DataExplorer)
library(lubridate)

df <- read_rds(here('Output/df_combined_noissue_clean.rds'))
plot_missing(df)

# For each academic, using Y1 - Ymax, count number of publications
# For each publication, show whether it is all male, all female or mixed

df_clean <- df %>% 
    # Sort publications
    arrange(outlet, clean_title, clean_name, date) %>% 
    
    # Remove duplication among outlet
    distinct(clean_title, clean_name, .keep_all = T) %>% 
    
    # Classify each publication by collaboration type
    group_by(clean_title) %>% 
    mutate(count_male = sum(ifelse(sex == 'male', 1, 0)), 
           count_female = sum(ifelse(sex == 'female', 1, 0)), 
           count_total = n(), 
           collaboration_gender = ifelse(count_total == count_male, 'All male',
                                         ifelse(count_total == count_female, 'All female',
                                                'Mixed'))) %>% 
    select(clean_title, clean_name, collaboration_gender, sex, pub_position_clean, date) %>% 
    
    # Find the experience level of each of the authors
    ungroup() %>% 
    mutate(year = year(date)) %>% 
    group_by(clean_name) %>% 
    mutate(latest_date = max(year), 
           oldest_date = min(year),
           experience = year - oldest_date) %>% 
    ungroup()
    
    # Trace the trajectory of newbies 
    # These are people that did not publish at all in 5 years between
    # 2004 - 2009
    
start_year = 2009
    
  df_newbies <- df_clean %>% 
      filter(oldest_date==start_year) %>% 
      filter(sex != '') %>% 
      filter(pub_position_clean != 'professional economists') %>% 
      arrange(clean_name, sex) %>% 
      
      
      # Trace the number of publications they produce each year till 2019
      group_by(clean_name, sex, year) %>% 
      summarise(counts_all_male = sum(ifelse(collaboration_gender == 'All male',1,0)),
             counts_all_female = sum(ifelse(collaboration_gender == 'All female',1,0)),
             counts_mixed = sum(ifelse(collaboration_gender == 'Mixed',1,0)),
             total_counts = n()) %>% 
      group_by(clean_name) %>% 
      mutate(total_output = sum(total_counts)) %>% 
      arrange(sex, desc(total_output)) %>% 
      
      # drop people who only published once in 2009
      mutate(mean_year = mean(year)) %>% 
      filter(mean_year != start_year) %>% 
    
      # counts by collaboration type
      pivot_longer(cols = starts_with('counts'), names_to = 'collaboration_type',
                   values_to = 'collaboration_counts')
    
    ordering <- df_newbies %>% select(clean_name) %>% distinct() %>% pull()
    
    # Check no gender misclassification
    check <- df_newbies %>% 
      distinct(clean_name, sex) %>% 
      group_by(clean_name) %>% 
      mutate(counts = n())
    check2 <- df_newbies %>% 
      distinct(clean_name)
    nrow(check) == nrow(check2)
    
    # Gender split
    table(check$sex)
    # About 20% of the cohort are female
    
    # Check position
    df_position <- df_newbies %>% 
      left_join(df_clean %>%
                  filter(year==start_year) %>% 
                  filter(sex != '') %>%
                  select(clean_name, sex, year, pub_position_clean)) %>% 
      select(clean_name, pub_position_clean) %>% 
      distinct()
    
    table(df_position$pub_position_clean)
    
    # Plot average productivity over the 10 years
    df_average <- df_newbies %>% group_by(sex, year) %>% 
      summarise(counts = mean(total_counts)) %>% 
      group_by(sex) %>% 
      mutate(cumsum = cumsum(counts))
    
    ggplot(df_average) +
      geom_line(aes(x=year, y = counts, colour = sex))+
      ylab('Average publications per person')+
      xlab('Year')+
      labs(color='Gender')+
      ggtitle('Gender productivity gap for\n one cohort of economist 2009-2020')
    
    

    
    # Plot average productivity over the 10 years
    df_average <- df_newbies %>% group_by(collaboration_type, year) %>% 
      summarise(counts = sum(collaboration_counts)) %>% 
      group_by(collaboration_type)
    
    g <- ggplot(df_average) +
      geom_line(aes(x=year, y = counts, color = collaboration_type))
    
    print(g)


    # PLOT all cohorts
generate_cohorts <- function(df_clean, start_year){
    
  df_newbies <- df_clean %>% 
      filter(oldest_date==start_year) %>% 
      filter(sex != '') %>% 
      filter(pub_position_clean != 'professional economists') %>% 
      arrange(clean_name, sex) %>% 
      
      
      # Trace the number of publications they produce each year till 2019
      group_by(clean_name, sex, year) %>% 
      summarise(counts_all_male = sum(ifelse(collaboration_gender == 'All male',1,0)),
                counts_all_female = sum(ifelse(collaboration_gender == 'All female',1,0)),
                counts_mixed = sum(ifelse(collaboration_gender == 'Mixed',1,0)),
                total_counts = n()) %>% 
      group_by(clean_name) %>% 
      mutate(total_output = sum(total_counts)) %>% 
      arrange(sex, desc(total_output)) %>% 
      
      # drop people who only published once in 2009
      mutate(mean_year = mean(year)) %>% 
      filter(mean_year != start_year) %>% 
      
      # add cohort
      mutate(cohort = start_year)
  
  return(df_newbies)
  
    }

cohort_years = as.list(2009:2015)
cohort_dfs = rep(list(df_clean), length(cohort_years))
cohort_list = map2(.x=cohort_dfs, .y=cohort_years, generate_cohorts)
cohort = reduce(cohort_list, bind_rows)
cohort_average = cohort  %>% 
  mutate(cohort_no = year - cohort) %>% 
  group_by(cohort, cohort_no, sex) %>% 
  summarise(counts = mean(total_counts))

ggplot(cohort_average, aes(x=cohort_no, y=counts, color = sex))+
  stat_smooth(method='loess', mapping=aes(fill=cohort_no))+
  ylab('Average number of papers published')+
  xlab('Year since first publication')+
  labs(color = 'Gender')+
  ggtitle('Gender productivity gap comparing 6 cohorts\n of academic economist publications')

# Dot plot
df_newbies %>% group_by(clean_name) %>% 
  arrange(year) %>% mutate(cumsum = cumsum(total_counts)) %>% 
  ggplot()+
  geom_line(aes(x=year, y=cumsum, group=clean_name, color=sex,
                alpha = sex))+
  scale_alpha_manual(name='category', values=c(0.5,0.5))+
  scale_color_manual(values=c('red','blue'))+
  facet_grid(cols=vars(sex))+
  theme_classic()

# Segment plots
df_segment <- df_newbies %>% 
  arrange(clean_name, year) %>% 
  group_by(clean_name) %>% 
  mutate(next_year = lead(year),
         next_year = ifelse(is.na(next_year), year, next_year)) %>% 
  filter(year != next_year) %>% 
  filter(year == next_year -1 ) %>% 
  pivot_longer(cols=starts_with('counts'), values_to='counts') %>% 
  filter(counts !=0) %>% 
  select(clean_name, sex, year, next_year, name, counts) %>% 
  filter(sex=='female')

ggplot(df_segment, aes(x=year, 
                       y=factor(clean_name, levels = ordering),
                       color = name)) + 
  geom_point(size=0.05) +  
  geom_segment(aes(x=year,
                   xend=next_year,
                   y=factor(clean_name, levels = ordering),
                   yend=factor(clean_name, levels = ordering)))+
  xlab('Year')+
  theme(axis.title.y=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks.y=element_blank())


