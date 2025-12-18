library(sf)
library(tidyverse)
library(broom)
library(rstatix)

# Load the grid with the cleaned data
grid_all <- st_read("data/clean_data.gpkg") %>% 
  dplyr::select(grid_id, temp, dgm, perc_artificial, 
                perc_agricultural, perc_forest_semi, 
                perc_wetlands, perc_water, perc_no_data) %>% 
  st_drop_geometry() %>%     # drop the geometry to avoid issues
  dplyr::filter(!is.na(dgm)) # remove rows where elevation (dgm) is NA



##### Correlation test (Pearson) T - Elevation ##### 

cor_test <- cor.test(grid_all$temp, grid_all$dgm, method = "pearson") # simple linear correlation

cor_test
cor_test$estimate # prints correlation coefficient
cor_test$p.value  # prints p-value 



##### Linear model T ∝ Elevation ##### 

lm_temp_dgm <- lm(temp ~ dgm, data = grid_all) 

summary(lm_temp_dgm)
summary(lm_temp_dgm)$adj.r.squared # prints adj R²
summary(lm_temp_dgm)$coefficients[,"Pr(>|t|)"] # prints p-value 

# Extract indicators for predictiveness
# Model indicators
broom::glance(lm_temp_dgm)



##### Dominant Land Cover categories #####

# Build one dataset with dominant land-cover class (> 50%)
df_dom <- grid_all %>% 
  mutate(
    # New column max_perc = the maximum value of land-cover percentage in each cell
    max_perc = pmax(             # pmax() returns the max value in the row across these columns
      perc_artificial, perc_agricultural, perc_forest_semi, 
      perc_wetlands, perc_water, perc_no_data),
    # Dominant class > 50%
    dominant_cover = case_when(                      # check if one of the conditions is true
      max_perc < 50                 ~ NA_character_, # max value < 50% = NA
      max_perc == perc_artificial   ~ "Artificial",
      max_perc == perc_agricultural ~ "Agricultural",
      max_perc == perc_forest_semi  ~ "Seminatural",
      max_perc == perc_wetlands     ~ "Wetlands",
      max_perc == perc_water        ~ "Water",
      max_perc == perc_no_data      ~ "No Data",
      TRUE                          ~ NA_character_)) %>% # no match = NA
  as_tibble() %>%
  filter(!is.na(dominant_cover)) # remove NAs from dominant cover column

nrow(grid_all) - nrow(df_dom) # no. of cells removed after the selection of cover > 50%

# Statistics table of Temperature by Land Cover category
stats_t_lc <- df_dom %>%
  group_by(dominant_cover) %>%
  summarise(n       = n(),
            mean    = mean(temp),
            sd      = sd(temp),
            min     = min(temp),
            q25     = quantile(temp, 0.25),
            median  = median(temp),
            q75     = quantile(temp, 0.75),
            max     = max(temp),
            .groups = "drop")

stats_t_lc



##### Test T in each Land Cover category #####

# Number of cells for each dominant Land Cover category
df_dom %>% count(dominant_cover)

# Consider only Agricultural, Artificial and Semi-natural
# Water and Wetland have too few cells
df_lc3 <- df_dom %>% 
  filter(dominant_cover %in% c("Agricultural", "Artificial", "Seminatural")) %>% 
  droplevels() # remove the values without cells from the levels (Water and Wetlands). Needed for plotting

### Welch’s ANOVA: Temperature between Land-Cover
# This method allows for unequal variances and unequal sample sizes
welch_anova <- oneway.test(temp ~ dominant_cover,
                           data      = df_lc3,
                           var.equal = FALSE)

welch_anova$statistic # prints F
welch_anova$p.value # prints p-value


### Games–Howell post-hoc test
# Pairwise comparisons between Land Cover categories even with unequal variances and no. of occurrences
games_howell <- games_howell_test(df_lc3, temp ~ dominant_cover)

# Print the summary table with tested variables, mean differences, p-values...
games_howell

##### Linear model T ∝ Land Cover + Elevation ##### 

## Baseline model
# Copy of the first linear model with the sub-dataset 
# linear model temperature ~ elevation = lm_te
lm_te <- lm(temp ~ dgm, data = df_lc3)

summary(lm_te)
summary(lm_te)$adj.r.squared # prints adj R²
summary(lm_te)$coefficients[,"Pr(>|t|)"] # prints p-value 

## Additive model including Land Cover to compare with the first
# Make "Seminatural" as the baseline category (and compare to the other two)

# Convert dominant_cover to an unordered factor (to use 'relevel' later)
df_lc3$dominant_cover <- factor(df_lc3$dominant_cover)

# Set "Seminatural" as the reference level
df_lc3$dominant_cover <- relevel(df_lc3$dominant_cover, ref = "Seminatural")

# Linear model temperature ~ elevation + land cover = lm_telc
lm_telc <- lm(temp ~ dgm + dominant_cover, data = df_lc3)

summary(lm_telc)
summary(lm_telc)$adj.r.squared # prints adj R²
summary(lm_telc)$coefficients[, "Pr(>|t|)"] # prints p-value 

# Comparison between the adj R² of the two linear models (new > old)
summary(lm_telc)$adj.r.squared > summary(lm_te)$adj.r.squared


##### Compare the linear models #####

### Anova

# Comparison of the two models -> Does Land Cover improve the previous model?
# = Does Land Cover influence the T?
anova(lm_te, lm_telc)

# Print the Residual Sum of Squares = how much variation is left unexplained
anova(lm_te, lm_telc)$RSS 

# Calculate the improvement of the residual variance by the model (if any)
# RSS of the first linear model minus RSS of the second one, divided by the first RSS, times 100 to have %
(anova(lm_te, lm_telc)$RSS[1] - anova(lm_te, lm_telc)$RSS[2]) / anova(lm_te, lm_telc)$RSS[1] * 100

# Print F and p-value
anova(lm_te, lm_telc)[[2, "F"]]
anova(lm_te, lm_telc)[[2, "Pr(>F)"]]


### AIC (Akaike Information Criterion) comparison

AIC(lm_te, lm_telc)

# Comparison between the AIC of the firs model vs the second one
AIC(lm_te, lm_telc)$AIC[1] > AIC(lm_te, lm_telc)$AIC[2]
