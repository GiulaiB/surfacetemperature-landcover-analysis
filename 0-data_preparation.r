##### 00 - data manipulation

# Packages
library(tidyverse)
library(sf)
library(terra)
library(rnaturalearth)
library(exactextractr)


##### Import data #####
# Corine Land Cover (clc) 2018 - Land Cover map across all EU, 100 m resolution
clc <- rast("data/CorineLandCover2018/DATA/U2018_CLC2018_V2020_20u1.tif") %>% 
  project(clc, "EPSG:3035") # change to ETRS89 / LAEA Europe (EPSG:3035)

# CHELSA bio01d 2018 - Mean annual Temperature (0.1 Kelvin)
temp_raw <- rast("data/CHELSA/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc") %>% 
  project(temp_raw, "EPSG:3035")

# Conversion to °C = (values * 0.1 K) - 273.15
temp <- (temp_raw * 0.1) - 273.15


# CHELSA bio04d 2018 - Temperature seasonality (standard deviation of the monthly temperature * 100)
temp_stdv <- rast("data/CHELSA/CHELSA_EUR11_obs_bio04d_2018_V.2.1.nc") %>% 
  project(temp_stdv, "EPSG:3035")


# High resolution Digital Terrain Model (DGM) of Austria
dgm <- rast("data/austria-dgm/dhm_at_lamb_10m_2018.tif") %>% 
  project(dgm, "EPSG:3035")


# Natural Earth package - worldwide countries borders
world <- ne_countries(scale = "medium", returnclass = "sf") %>% 
  st_transform(world, crs = 3035)



##### Austria clipping #####

# Filtering Austria polygon 
austria <- world %>% 
  filter(admin == "Austria" | name == "Austria") %>% 
  vect() # conversion in SpatVector for "terra"

# Corine Land Cover (clc) clipped to Austria
clc_at <- clc %>%
  crop(austria) %>% # reduce the extension to the Austrian's bounding box
  mask(austria)     # remove the pixels that have center out of Austria polygon

# Mean annual Temperature clipped to Austria
temp_at <- temp %>%
  crop(austria) %>%
  mask(austria)

# Temperature seasonality clipped to Austria
temp_stdv_at <- temp_stdv %>%
  crop(austria) %>%
  mask(austria)

# Digital Terrain Model (DGM) clipped to Austria (from Natural Earth)
dgm_at <- dgm %>%
  crop(austria) %>%
  mask(austria)



##### Grid section #####
### Grid creation
austria_sf <- austria %>% st_as_sf()

# 1 km² grid over the extent of Austria. "grid_id" as ID column
grid_1km_sf <- st_make_grid(
  austria_sf,
  cellsize = 1000,   # 1 km
  square   = TRUE) %>%
  st_sf(grid_id = seq_along(.), geometry = .)

# Clip grid to Austria border
grid_1km_sf <- st_intersection(grid_1km_sf, austria_sf)



### Data downscale = weighted mean of the variables in the cells
# Temperature: area-weighted mean per grid cell
grid_1km_sf$temp <- exact_extract(  
  temp_at[[1]], # first layer of temp
  grid_1km_sf,
  function(values, coverage_fraction) {
    # coverage_fraction is the proportion of each cell inside the polygon (0-1)
    weighted.mean(values, coverage_fraction, na.rm = TRUE)
  }
)

grid_1km_sf %>% str()

# Temperature seasonality: area-weighted mean per grid cell
grid_1km_sf$temp_stdv <- exact_extract(
  temp_stdv_at[[1]],
  grid_1km_sf,
  function(values, coverage_fraction) {
    weighted.mean(values, coverage_fraction, na.rm = TRUE)
  }
)

# DGM: area-weighted mean per grid cell
grid_1km_sf$dgm <- exact_extract(
  dgm_at[[1]],
  grid_1km_sf,
  function(values, coverage_fraction) {
    weighted.mean(values, coverage_fraction, na.rm = TRUE)
  }
)




##### Corine land Cover #####
# Underlying numeric codes for CLC (drop factor behaviour)
clc_codes <- as.int(clc_at)

# Custom function: compute % cover of each macro-category in one grid cell
# Custom function: returns one-row data.frame with % cover per macro-category
clc_cover_df <- function(values, coverage_fraction) {
  df <- data.frame(code = values, w = coverage_fraction)
  
  # Drop NA and "No Data" category (48) - from the manual of Corine Land Cover
  df <- df %>%
    filter(!is.na(code))
  
  # If no valid pixels, return NA row
  if (nrow(df) == 0) {
    return(data.frame(perc_artificial   = NA_real_, perc_agricultural = NA_real_,
                      perc_forest_semi  = NA_real_, perc_wetlands     = NA_real_,
                      perc_water        = NA_real_, perc_no_data      = NA_real_))
  }
  
  # Total cover weight. If it is 0, return NA
  total_w <- sum(df$w)
  if (total_w == 0) {
    return(data.frame(perc_artificial   = NA_real_, perc_agricultural = NA_real_,
                      perc_forest_semi  = NA_real_, perc_wetlands     = NA_real_,
                      perc_water        = NA_real_, perc_no_data      = NA_real_))
  }
  
  # Grouping Land Cover values into macro-categories (from the manual of Corine Land Cover)
  # Still using the weights
  art_w <- sum(df$w[df$code >=  1 & df$code <= 11])
  agr_w <- sum(df$w[df$code >= 12 & df$code <= 22])
  for_w <- sum(df$w[df$code >= 23 & df$code <= 34])
  wet_w <- sum(df$w[df$code >= 35 & df$code <= 39])
  wat_w <- sum(df$w[df$code >= 40 & df$code <= 44])
  nod_w <- sum(df$w[df$code == 48]) # no data
  
  # Conversion from weights to percentages for each grid cell
  data.frame(perc_artificial   = art_w / total_w * 100,
             perc_agricultural = agr_w / total_w * 100,
             perc_forest_semi  = for_w / total_w * 100,
             perc_wetlands     = wet_w / total_w * 100,
             perc_water        = wat_w / total_w * 100,
             perc_no_data      = nod_w / total_w * 100)
}

clc_props <- exact_extract(clc_codes, 
                           grid_1km_sf,
                           clc_cover_df) # function previously created

# Conversion in tibble format 
clc_props <- as_tibble(clc_props, .name_repair = "unique")

# Final grid with environmental variables and CLC cover percentages
# Bind the tibble with the rest
grid_all <- bind_cols(grid_1km_sf, clc_props)

# Check
grid_all %>% 
  dplyr::select(grid_id, temp, temp_stdv, 
                dgm, perc_artificial, 
                perc_agricultural, perc_forest_semi, 
                perc_wetlands, perc_water) %>%
  summary()



##### Save the grid #####
saveRDS(grid_all, "data/new_version_data/grid_all.rds")
