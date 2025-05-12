library(readr)
library(dplyr)
library(tidyr)
library(tibble)
library(forcats)

myvar <- 'extreme_roundedness'
# What levels are we modeling?
# 2: voicing, roundedness
# 3: height, backness
# 4: extreme
# 5: position, manner
# 7: manner_voicing
# 8: extreme_roundedness
# 10: position_voicing

#############################
### Functions             ###
#############################
odds <- function(x) {return(x / (1 - x))}

countBy <- function(groupingVar, normBy, dataSource) {
  # Transform counts to proportionsŋ
  out <- dataSource %>%
    drop_na(groupingVar) %>% 
    # changing across() to all_of, lets see if this breaks things
    group_by(wd_id, language, word, concept, family, macroarea, latitude, longitude, across(all_of(groupingVar)), across(all_of(normBy))) %>%
    count() %>% ungroup() %>%
    mutate(prop=n/c_across(all_of(normBy)), vars=c_across(all_of(groupingVar))) %>% 
    select(language, wd_id, word, concept, family, macroarea, latitude, longitude, vars, prop) %>%
    pivot_wider(names_from=vars, values_from=prop)
  
  # Note: Since we are calculating proportions, this is reasonable!
  # Right now, NA is created when no phoneme for the grouping variable is present
  # But we actually want a 0 in those cases, to represent the proportion --> 0
  # And since Dirichlet needs response above 0, we need to modify slightly
  out[is.na(out)] <- 0.001
  
  # Make sure rows sum up to 1  
  for(i in 1:nrow(out)) {
    row <- out[i, 9:ncol(out)]
    m <- which.max(row[,])
    row[m] <- 1 - sum(row[-m])
    out[i,] <- cbind(out[i, 1:8], row)
  }
  
  # Create matrix for brms
  respDir <- as.matrix(out[, myPropVars])
  colnames(respDir) <- 1:ncol(respDir)
  out$respDir <- respDir
  out <- out[, c('language', 'concept', 'wd_id', 'word', 'family', 'macroarea', 'latitude', 'longitude', 'respDir')]
  
  return(out)
}

#############################
### Load data             ###
#############################
df <- read_csv('../01_preprocessing/data/data.csv', na=c(''), show_col_types = F) %>%
  mutate_if(is.character, factor) %>%
  mutate(
    vowelConsonant=ifelse(!is.na(height), 'vowel', 'consonant'),
    family=fct_na_value_to_level(family, 'Isolate'),
    extreme_roundedness=factor(ifelse(!is.na(extreme), paste(extreme, roundedness, sep='-'), NA)),
    manner_voicing=factor(ifelse(!is.na(voicing), paste(manner, voicing, sep='-'), NA)),
    position_voicing=factor(ifelse(!is.na(voicing), paste(position, voicing, sep='-'), NA)),
    macroarea = as.character(macroarea)
  )

# 
df %>% group_by(extreme_roundedness) %>% count()


# Words that are uncommonly long/short
avg_length <- df %>% group_by(concept) %>% summarise(mean=mean(nPhonemesPerWord))
avg_length %>% arrange(mean)
avg_length %>% arrange(-mean)

# Coverage
unique(df[c('concept', 'language')]) %>% group_by(concept) %>% count() %>% arrange(n)

# Subset data: for vowel features, focus only on vowels; etc.
if (myvar %in% c('manner', 'manner_voicing', 'position', 'position_voicing', 'voicing')) {
  mySounds <- 'consonants'
  df1 <- df %>% filter(vowelConsonant == 'consonant') %>% 
    group_by(wd_id) %>% 
    mutate(nConsPerWord=n()) %>% 
    ungroup()%>%
    droplevels()
  mv <- 'nConsPerWord'
} else if (myvar %in% c('height', 'backness', 'roundedness', 'extreme', 'extreme_roundedness')) {
  mySounds='vowels'
  df1 <- df %>% filter(vowelConsonant == 'vowel') %>% 
    group_by(wd_id) %>% 
    mutate(nVowelsPerWord=n()) %>% 
    ungroup() %>%
    droplevels()
  mv <- 'nVowelsPerWord'
}

length(unique(df1$language))
length(unique(df1$family))
df1 %>% filter(family=='Isolate') %>% group_by(language) %>% count()

myPropVars <- df1 %>% pull(myvar) %>% levels()
n_levels <- length(myPropVars)

data <- countBy(groupingVar=myvar, normBy=mv, dataSource=df1)
write_rds(data, paste0('data/processed_', myvar, '.rds'))
