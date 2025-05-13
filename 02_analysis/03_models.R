library(readr)
library(tidyr)
library(brms)
library(ggplot2)
library(cmdstanr)
library(tidybayes)
library(dplyr)
library(matrixcalc) # check positive-definiteness

# What levels are we modeling?
myvar <- 'extreme_roundedness'

# 2: voicing, roundedness
# 3: height, backness
# 4: extreme
# 5: position, manner
# 7: manner_voicing
# 8: extreme_roundedness
# 10: position_voicing

folder_posterior_draws <- 'posterior_draws'

# 25% increase/decrease of odds expressed as log-odd s ratio
upr_thresh <- log(1.25)
lwr_thresh <- log(1/1.25)

#############################
### Functions             ###
#############################
odds <- function(x) {return(x / (1 - x))}

#############################
### Load data             ###
#############################
data <- read_rds(paste0('data/processed_', myvar, '.rds', na=c('')))

phylo_vcv <- read.csv('../01_preprocessing/data/vcv_phylo.csv', row.names=1) %>% as.matrix()
isSymmetric.matrix(phylo_vcv)

geo_vcv <- read.csv('../01_preprocessing/data/vcv_geo.csv', row.names=1) %>% as.matrix()
is.positive.definite(geo_vcv)

data2 <-  list(
  phylo_vcv=phylo_vcv,
  geo_vcv=geo_vcv
)

myPropVars <- read_csv('../01_preprocessing/data/data.csv', na=c('')) %>%
  mutate(
    extreme_roundedness=ifelse(!is.na(extreme), paste(extreme, roundedness, sep='-'), NA),
    manner_voicing=ifelse(!is.na(voicing), paste(manner, voicing, sep='-'), NA),
    position_voicing=ifelse(!is.na(voicing), paste(position, voicing, sep='-'), NA)
    ) %>% 
  mutate_if(is.character, factor) %>% 
  pull(myvar) %>% levels()

n_levels <- length(myPropVars)


#############################
### Priors                ###
#############################
priors_in <- list(
  intercepts=lapply(2:n_levels, function(i) {
    prior(normal(0, 0.5), class=Intercept, dpar='Intercept')}),
  sd=lapply(2:n_levels, function(i) {
    prior(gamma(3, 40), class=sd, dpar='sd')})
)

priors <- c(prior(gamma(1, 1), class=phi))
for (l in 1:length(priors_in)) {
  list <- priors_in[[l]]
  for (i in 1:length(list)) {
    j <- i + 1
    list[[i]]$dpar <- paste0('mu', j)
    priors <- c(priors, list[[i]])
  }
}

# get_prior(
#   data=data,
#   data2=data2,
#   family='dirichlet',
#   formula=respDir ~ 1 + (1|concept) +
#     (1 | gr(family, cov=phylo_vcv)) +
#     (1 | gr(language, cov=geo_vcv))
# )

#############################
### Model                 ###
#############################
mod <- data %>%
  mutate(spatial_id=language, phylo_id=language) %>% 
  brm(
   data2=data2,
   family='dirichlet',
   formula=
     respDir ~ 1 + (1|concept) + 
     (1 | gr(phylo_id, cov=phylo_vcv)) +
     (1 | gr(spatial_id, cov=geo_vcv)
      ),
   prior=priors,
   silent=0,
   backend='cmdstanr',
   control=list(adapt_delta=0.85, max_treedepth=10),
   file=paste0('models/lb2_large_', myvar, '.rds'),
   threads=threading(4),
   iter=7500, warmup=2500, chains=4, cores=4
   )

#############################
### Posterior predictions ###
#############################
new_data <- data %>% distinct(concept)
new_data <- tibble(concept=unique(data$concept), family='a', language='a')
fit_name <- paste0(folder_posterior_draws, '/fit_', myvar, '.rds')
if (file.exists(fit_name)) {
  predictions <- readRDS(file=fit_name)
} else{
  print('Sorry, the file does not yet exist. This may take some time.')
  predictions <- add_epred_draws(newdata=new_data, mod, allow_new_levels=T) 
  saveRDS(predictions, file=fit_name)
}

# Compute odds ratio for all fits based on odds for each category
preds_or <- predictions %>% group_by(.category) %>%
  mutate(
    OR_cat=odds(mean(.epred)),
    OR_word=log(odds(.epred)/OR_cat)
    ) %>% 
  ungroup() %>% 
  mutate(category=myPropVars[.category]) %>% 
  group_by(concept, category) %>% 
  # Summarise per word in each category
  summarise(mean=mean(OR_word), sd=sd(OR_word)) %>% 
  mutate(lwr=mean-2*sd, upr=mean+2*sd) %>%
  # Add Label for words above/below threshold
  mutate(word_dim=ifelse((lwr > upr_thresh | upr < lwr_thresh), toupper(as.character(concept)), ''))

#############################
### Plotting              ###
#############################
epred_plot <- preds_or %>%
  ggplot(aes(x=concept, y=mean, ymin=lwr, ymax=upr, label=word_dim)) +
  geom_point() +
  geom_errorbar(width=0) +
  geom_text(size=3, nudge_x=3) +
  geom_point(aes(x=concept, y=mean), shape=4) +
  scale_x_discrete(labels=NULL, expand=c(0.02, 0.02)) +
  xlab('Concept') +
  ylab('Proportion, %') +
  coord_flip() +
  facet_wrap(~category, ncol=n_levels) +
  theme_bw() +
  theme(panel.grid=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks.y=element_blank(),
        legend.position='none')

write_csv(preds_or, paste0(folder_posterior_draws, '/', myvar, '.csv'))

