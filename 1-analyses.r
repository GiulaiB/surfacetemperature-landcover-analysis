library(sf)
library(tidyverse)

# Load the grid with all the data

grid_all <- st_read("data/new_version_data/grid_all.gpkg") %>% 
  dplyr::select(grid_id, temp, temp_stdv, 
                dgm, perc_artificial, 
                perc_agricultural, perc_forest_semi, 
                perc_wetlands, perc_water, perc_no_data)

df_lm <- grid_all %>% 
  st_drop_geometry() %>% # drop the geometry to avoid issues
  dplyr::filter(!is.na(dgm)) # remove rows where elevation (dgm) is NA

##### Correlation test (Pearson) #####
cor_test <- cor.test(df_lm$temp, df_lm$dgm, method = "pearson")  # simple linear correlation

cor_test          # prints correlation coefficient + p-value
cor_test$estimate # correlation coefficient r = -0.99 (negative correlation)
cor_test$p.value  # p-value <<< 0.05, so it's significant
