library(dplyr)
library(ggplot2)
library(ggrepel)
library(purrr)
library(readr)
library(stringr)
library(tidyr)
library(xtable)

options(dplyr.summarise.inform = FALSE)
colors_10 <- c('#0c71ff', '#ca2800', '#ff28ba', '#000096', '#86e300', '#1c5951', '#20d2ff', '#20ae86', '#590000', '#65008e')
soundClasses <- c('backness', 'height', 'roundedness', 'extreme',  'voicing', 
                  'extreme_roundedness','manner', 'manner_voicing', 'position',
                  'position_voicing')

myfiles <- paste0(soundClasses, '.csv')
df <- map_df(myfiles, ~ {
  new_file <- paste0('posterior_draws/', .x)
  if (file.exists(new_file)) {
    temp <- read_csv(
      new_file, show_col_types=F, col_types=cols_only(
        concept='c', category='c', mean='?', sd='?', lwr='?', upr='?'))
    temp$myvar <- gsub('\\.csv$', '', .x)
    return(temp)
  }})

upr_thresh <- log(1.25)
lwr_thresh <- log(1/1.25)

# Pre-Process dataframes
orig <- read_tsv('original_results_mapped.csv',  show_col_types=F) %>% 
  select(word, group, fit, lwr, upr, topCardinal, myvar) %>% 
  rename(mean=fit, category=group, concept=word) %>% 
  mutate(result='Original Results', sd=NA,
         category=str_replace(category, '-voice', '-unvoiced'),
         category=str_replace(category, '\\+voice', '-voiced'),
         # Outcome is Strong if HPDI outside of ROPE
         # Outcome is Weak if Mean outside of ROPE and HPDI doesn't include 0
         # Outcome is Absent if HPDI fully inside ROPE
         outcome=ifelse((lwr>upr_thresh | upr < lwr_thresh), 'Strong', ifelse(
           (lwr > -lwr_thresh & upr < upr_thresh), 'No', ifelse(
             ((lwr > 0 & mean > upr_thresh) | (upr < 0 & mean < lwr_thresh)), 'Weak', 'Doubtful'))),
         label=ifelse(outcome=='Strong', paste0(toupper(concept), ' [', category, ']'), NA)
  )

combined_full <- df %>% 
  mutate(
    result='New Results', topCardinal='',
    label=paste0(toupper(concept), ' [', category, ']'),
    outcome=ifelse((lwr>upr_thresh | upr < lwr_thresh), 'Strong', ifelse(
      (lwr > -lwr_thresh & upr < upr_thresh), 'No', ifelse(
        ((lwr > 0 & mean > upr_thresh) | (upr < 0 & mean < lwr_thresh)), 'Weak', 'Doubtful')
      ))) %>%
  rbind(orig) %>% 
  mutate(
    concept=toupper(concept),
    result=factor(result, levels=c("Original Results","New Results")),
    new_label=paste0(concept, ' [', category, ']')
    ) %>% 
  filter(myvar!='vowelConsonant', category!='unrounded', category!='unvoiced')


wide_data <- combined_full %>% 
  # Remove negative values of binary categories
  select(new_label, category, concept, result, mean, myvar) %>%
  pivot_wider(names_from=result, values_from=mean) %>%
  rename(old='Original Results', new='New Results') %>%
  # Filter out wrong category of 7 entries
  filter(category!='NA-unvoiced') %>% 
  mutate(m_label=paste0(myvar, '_', category, '_', concept)) %>% 
  # drop [vibrant-unvoiced], [nasal-unvoiced], [lateral-unvoiced]
  # They are not present in the data
  drop_na(old, new)


pearson_corr <- cor.test(wide_data$old, wide_data$new, method="pearson")

p_value_corr <- ifelse(identical(pearson_corr$p.value, 0), '2.2e-16', pearson_corr$p.value)
corr_label <- paste("Pearson's r=", round(pearson_corr$estimate, 2),
                    "\np-value < ", p_value_corr)

model <- lm(new ~ splines::bs(old, 3), data = wide_data)
coef(model)

correlation_plot <- ggplot(wide_data, aes(x=old, y=new)) +
  geom_point(aes(fill=myvar), alpha=0.6, size=2, shape=21) +
  geom_smooth(method = lm, formula = y ~ splines::bs(x, 3), color="red", fill="gray", se=TRUE, linewidth=1.5, alpha=0.5) +
  geom_abline(slope=1, intercept=0, color="black", linetype="dashed", linewidth=1.5) +
  theme_bw() +
  scale_fill_manual(values=colors_10) +
  scale_y_continuous(breaks=c(-0.6, -0.3, 0, 0.3, 0.6)) +
  scale_x_continuous(breaks=c(-0.6, -0.3, 0, 0.3, 0.6, 0.9)) +
  labs(
    x='Old Results',
    y='New Results'
  ) +
  theme( 
    legend.position="bottom",
    legend.title=element_blank(),
    panel.grid.major.x=element_blank(),
    panel.grid.minor.x=element_blank(),
   panel.grid.minor.y=element_blank()
  ) +
  annotate("text", x=-0.75, y=0.7, label=corr_label, color="black", size=4, hjust=0) +
  guides(fill=guide_legend(override.aes=list(size=5, alpha=0.7)))

correlation_plot
ggsave('figures/correlation.pdf', correlation_plot, width=7, height=6, dpi=500)

#####################################
# Manhattan plot
highest_new <- wide_data %>% arrange(-abs(new)) %>% head(n=5) %>% pull(new_label)
highest_old <- wide_data %>% arrange(-abs(old)) %>% head(n=3) %>% pull(new_label)

manhattan_style <- wide_data %>% 
  ggplot(aes(x=m_label)) +
  geom_point(aes(y=old), fill="black", size=2, alpha=0.5, shape=24) +
  geom_point(aes(y=new, fill=myvar), size=2, alpha=0.5, shape=21) +
  geom_label_repel(data=subset(wide_data, new_label %in% highest_new), aes(y=new, label=new_label),
                   size=2, seed=161, box.padding=0.5) +
  scale_x_discrete(expand=c(.01, .01)) +
  scale_fill_manual(values=colors_10) +
  annotate('rect', xmin=0, xmax=Inf, ymin=lwr_thresh, ymax=upr_thresh, alpha=.5) +
  theme_bw() +
  labs(
    x='Phonetic features per concept',
    y='log-odds'
  ) +
  theme( 
    legend.position="bottom",
    legend.title=element_blank(),
    axis.ticks.x=element_blank(),
    axis.text.x=element_blank(),
    panel.border=element_blank(),
    panel.grid.major.x=element_blank(),
    panel.grid.minor.x=element_blank()
  ) +
  guides(alpha = "none") +
  guides(fill=guide_legend(override.aes=list(size=5, alpha=0.7)))

manhattan_style
ggsave('figures/manhattan.pdf', manhattan_style, width=10, height=6, dpi=500)


##############
# Strong results
strong <- combined_full %>% 
  filter(outcome %in% c('Strong'))


compare_strong <- combined_full %>% filter(concept %in% strong$concept) %>%
  select(concept, category, mean, myvar, result, outcome) %>% 
  arrange(concept, category, result)

combined_full %>% filter(myvar=='extreme_roundedness', result=='New Results', outcome!='Doubtful') %>% group_by(category) %>% count()
combined_full %>% filter(myvar=='extreme_roundedness', result=='Original Results', outcome!='Doubtful') %>% group_by(category) %>% count()
combined_full %>% filter(concept=='BREAST', result=='New Results', myvar=='manner_voicing')

################################################################################################
# Table stuff for paper
combined_full %>% select(-topCardinal) %>% write_csv(, file='data/final_results.csv')

results_table <- combined_full %>% 
  filter(outcome!='Doubtful') %>% 
  group_by(myvar, result, outcome) %>% 
  summarise(n=n()) %>% 
  ungroup() %>% 
  pivot_wider(names_from=c(result, outcome), values_from=n, values_fill=0)

colnames(results_table) <- c("Category", "Original_strong", "Original_weak", "New_weak", 'New_strong')
results_table <- results_table %>%
  select(Category, Original_strong, New_strong, Original_weak, New_weak) %>% 
  add_row(Category="Total", summarise(., across(where(is.numeric), sum)))

print(xtable(results_table), type="latex", include.rownames=FALSE)


################################
# Plot for each sound class
for (sc in soundClasses) {
  test <- combined_full %>%
    filter(myvar == sc, outcome !='Doubtful') %>% 
    ggplot(aes(
      x=mean, y=new_label,
      xmin=lwr, xmax=upr,
      color=outcome
      )) +
    geom_errorbar(linewidth=1.5, width=0) +
    geom_point(aes(fill=outcome, size=outcome), shape=21) +
    geom_vline(xintercept=0, color='black', linetype="dashed") +
    annotate('rect', xmin=lwr_thresh, xmax=upr_thresh, ymin=0, ymax=Inf, alpha=.1) +
    facet_wrap( ~ result, ncol=2, drop=F) +
    scale_x_continuous(
      name=NULL,
      limits=c(-1.4, 1.4),
      breaks=seq(-1, 1, by=0.5),
      labels=seq(-1, 1, by=0.5)) +
    scale_y_discrete(name=NULL, position = "right") +
    scale_size_manual(name='', values=c(5, 3)) +
    scale_color_manual(name='', values=c('Weak'=colors_10[1], 'Strong'=colors_10[2]))+
    scale_fill_manual(name='', values=c('Weak'=colors_10[1], 'Strong'=colors_10[2]))+
    theme_bw() +
    theme(
      panel.spacing=unit(0.2, "lines"),
      panel.grid.minor.x=element_blank() ,
      axis.text.x= element_text(size=10),
      strip.text.x=element_text(size=16),
      legend.position='none'
      )
  ggsave(filename=paste0('figures/summary_', sc, '.pdf'), dpi=500, height=15, width=7)
}
