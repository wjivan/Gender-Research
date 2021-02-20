# system
library(here)
library(parallel)
# data wrangling
library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)
# visualization
library(ggplot2)
# dealing with text
library(textclean)
library(tm)
library(SnowballC)
library(stringr)
# topic model
library(tidytext)
library(topicmodels)
library(textmineR)
library(readr)
library(qdapDictionaries)
library(quanteda)
library(ldatuning)

# Read file
# Load stop words
data("stop_words")
# Load english words
data("GradyAugmented")


read_cleaner <- function(filename){
  x <- read_file(filename)
  x <- as.character(x)
  
  x <- x %>%
    str_to_lower() %>%  # convert all the string to low alphabet
    replace_contraction() %>% # replace contraction to their multi-word forms
    replace_internet_slang() %>% # replace internet slang to normal words
    replace_emoji() %>% # replace emoji to words
    replace_emoticon() %>% # replace emoticon to words
    replace_hash(replacement = "") %>% # remove hashtag
    replace_word_elongation() %>% # replace informal writing with known semantic replacements
    replace_number(remove = T) %>% # remove number
    replace_date(replacement = "") %>% # remove date
    replace_time(replacement = "") %>% # remove time
    str_remove_all(pattern = "[[:punct:]]") %>% # remove punctuation
    str_remove_all(pattern = "[^\\s]*[0-9][^\\s]*") %>% # remove mixed string n number
    str_squish() %>% # reduces repeated whitespace inside a string.
    str_trim() %>%  # removes whitespace from start and end of string
    str_replace_all('\n', '') #remove line skips
  
  return(x)
}

convert_tokens <- function(textstring, label) {
  text_df <- tibble(text = textstring) %>%
    # Make into words and drop punctuations
    unnest_tokens(output = word, input = text) %>%
    # Extract only english alphabets
    mutate(word = str_extract(string = word, pattern = "[a-z']+")) %>%
    # Remove stop words
    anti_join(stop_words, by = 'word') %>%
    # Remove non-English words
    filter(word %in% GradyAugmented) %>%
    # Identifier
    mutate(title = label)
}

filenames = list.files(path = here('Input/NBER/texts/'), pattern = '.txt', 
           full.names = T, recursive = T)

df <- map(as.list(filenames), read_nber ) %>% 
  map2(as.list(filenames), convert_tokens) %>% 
  reduce(bind_rows)%>% 
  mutate(title = str_remove(string = title, pattern = paste0(here('Input/NBER/texts/'), '/')), 
         title = str_remove(title, '.txt')) %>% 
  count(title, word, sort=T)

# Perform tfidf analysis
df_top <- df %>% 
  # Perform tf-idf
  bind_tf_idf(word, title, n) %>% 
  group_by(title) %>% 
  slice_max(order_by = tf_idf, n=1)

# LDA topic modeling
# Cast into DTM
df_lda <- df %>% 
  # Make into DFM format
  cast_dfm(document = title, term = word, value=n) %>% 
  # Perform LDA
  LDA(k=2, control = list(seed=1234))

df_topics <- tidy(df_lda, matrix = 'beta') %>% 
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

# LDA tuning
core_num <- detectCores()-1
dt_dfm <- df %>% cast_dfm(document = title, term = word, value=n)
result <- FindTopicsNumber(
  dt_dfm,
  topics = c(2,4,8,16,32,64,128,256,512),
  metrics = c("CaoJuan2009", "Deveaud2014"),
  method = "Gibbs",
  control = list(
    seed=123
  ),
  mc.cores = core_num,
  verbose = TRUE
)

FindTopicsNumber_plot(result)
