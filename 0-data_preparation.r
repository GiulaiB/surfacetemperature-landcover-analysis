# Uncomment to install the packages. If not needed, skip
# install.packages("beepr")
# install.packages("tidyverse")
# install.packages("sf")
# install.packages("terra")
# install.packages("rnaturalearth")
# install.packages("exactextractr")

library(tidyverse)
library(sf)
library(terra)
library(rnaturalearth)
library(exactextractr)
library(yaml)
library(beepr)

# Load reusable project functions
source("functions.R")

##### Config-driven file discovery #####

cfg <- yaml::read_yaml("data_sources.yml")

data_dir <- if (!is.null(cfg$data_dir)) cfg$data_dir else "data"
recursive <- isTRUE(cfg$recursive)

data_files <- list.files(
  path = data_dir,
  full.names = TRUE,
  recursive = recursive
)



##### Import data #####

# Corine Land Cover (CLC) 2018
# CLC is categorical -> use nearest-neighbor resampling when reprojecting
clc_matches <- data_files[stringr::str_detect(data_files, cfg$sources$clc$pattern)]
if (length(clc_matches) == 0) {
  stop(paste0("No CLC file found using pattern: ", cfg$sources$clc$pattern), call. = FALSE)
}
if (length(clc_matches) > 1) {
  stop(
    paste0(
      "Multiple CLC files found.\nPattern: ", cfg$sources$clc$pattern,
      "\nMatches:\n- ", paste(clc_matches, collapse = "\n- ")
    ),
    call. = FALSE
  )
}
clc_path <- clc_matches[[1]]

clc <- rast(clc_path) %>%
  terra::project("EPSG:3035", method = "near")

# CHELSA bio01d 2018 (Mean annual temperature, stored as 0.1 Kelvin)
# Temperature is continuous -> use bilinear resampling
temp_matches <- data_files[stringr::str_detect(data_files, cfg$sources$temp$pattern)]
if (length(temp_matches) == 0) {
  stop(paste0("No TEMP file found using pattern: ", cfg$sources$temp$pattern), call. = FALSE)
}
if (length(temp_matches) > 1) {
  stop(
    paste0(
      "Multiple TEMP files found.\nPattern: ", cfg$sources$temp$pattern,
      "\nMatches:\n- ", paste(temp_matches, collapse = "\n- ")
    ),
    call. = FALSE
  )
}
temp_path <- temp_matches[[1]]

temp_raw <- rast(temp_path) %>%
  terra::project("EPSG:3035", method = "bilinear")

# Convert to °C (CHELSA: 0.1 K -> K -> °C)
temp <- (temp_raw * 0.1) - 273.15

# Digital Terrain Model (DGM) of Austria
dgm_matches <- data_files[stringr::str_detect(data_files, cfg$sources$dgm$pattern)]
if (length(dgm_matches) == 0) {
  stop(paste0("No DGM file found using pattern: ", cfg$sources$dgm$pattern), call. = FALSE)
}
if (length(dgm_matches) > 1) {
  stop(
    paste0(
      "Multiple DGM files found.\nPattern: ", cfg$sources$dgm$pattern,
      "\nMatches:\n- ", paste(dgm_matches, collapse = "\n- ")
    ),
    call. = FALSE
  )
}
dgm_path <- dgm_matches[[1]]

dgm <- rast(dgm_path) %>%
  terra::project("EPSG:3035", method = "bilinear")

# Natural Earth - worldwide country borders
world <- ne_countries(scale = "medium", returnclass = "sf") %>% 
  st_transform(3035)



##### Austria clipping #####

# Select Austria polygon and convert to terra SpatVector for crop/mask
austria <- world %>%
  filter(name == "Austria") %>%
  vect()

# Corine Land Cover (clc) clipped to Austria (from Natural Earth)
clc_at <- clc %>%
  crop(austria) %>% # reduce the extension to the Austrian's bounding box
  mask(austria)     # remove the pixels that have center out of Austria polygon

# Mean annual Temperature clipped to Austria
temp_at <- temp %>%
  crop(austria) %>%
  mask(austria)

# Digital Terrain Model (DGM) clipped to Austria
dgm_at <- dgm %>%
  crop(austria) %>%
  mask(austria)


##### Downscaling Temperature and Elevation (continuous variables) #####

### Creating the grid

# Convert back to sf for grid creation
austria_sf <- austria %>% st_as_sf()

# Grid over the extent of Austria. "grid_id" as ID column
grid_1km_sf <- st_make_grid(
  austria_sf,
  cellsize = 1000, # set cell dimension
  square = TRUE) %>%
  st_sf(grid_id = seq_along(.), geometry = .)

# Clip grid to Austria borders (keep only the portion within Austria)
grid_1km_sf <- st_intersection(grid_1km_sf, austria_sf)


### Weighted mean of the variables in the cells

# Temperature: area-weighted mean per grid cell
grid_1km_sf$temp <- exact_extract(
  temp_at[[1]],
  grid_1km_sf,
  area_weighted_mean) # custom function

grid_1km_sf$dgm <- exact_extract(
  dgm_at[[1]],
  grid_1km_sf,
  area_weighted_mean)



##### Corine Land Cover aggregation #####
# Underlying numeric codes for CLC (drop factor behaviour)
clc_codes <- as.int(clc_at)

# Compute macro-category % cover per grid cell using the reusable function.
# exact_extract() will return one row per polygon; clc_cover_df() returns a 1-row data.frame.
clc_props <- exact_extract(
  clc_codes,
  grid_1km_sf,
  clc_cover_df
) %>%  # custom function
  as_tibble(.name_repair = "unique")

# Final grid with environmental variables and CLC cover percentages
grid_all <- bind_cols(grid_1km_sf, clc_props)



##### Save the grid #####
st_write(grid_all, "data/clean_data.gpkg")
beep(1)