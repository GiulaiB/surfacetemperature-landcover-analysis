library(testthat)
library(terra)
library(sf)
library(tidyverse)
library(exactextractr)

# Load project functions
source("functions.R")

# source("0-data_preparation.R") # run "0-data_preparation.R" before this code
# source("1-data_analysis.R") # run "1-data_analysis.R" before this code


########## Testing the data preparation file ##########


##### Testing the pipeline #####

test_that("Austria clipping object exists and has one feature/row", {
  # GIVEN: austria object already created in the pipeline
  skip_if_not(exists("austria"))
  
  # WHEN: checking the number of features
  n <- nrow(sf::st_as_sf(austria))
  
  # THEN: exactly one country polygon exists
  expect_equal(n, 1)
})

test_that("Austria geometry is valid", {
  # GIVEN: austria object already created in the pipeline
  skip_if_not(exists("austria"))
  
  # WHEN: validating geometry
  valid <- terra::is.valid(austria)
  
  # THEN: geometry is valid
  expect_true(valid)
})

test_that("CRS matches between rasters and Austria polygon", {
  # GIVEN: austria, clc, temp, temp_stdv, dgm already created in the pipeline
  skip_if_not(exists("clc"))
  skip_if_not(exists("temp"))
  skip_if_not(exists("dgm"))
  
  # WHEN / THEN: CRS must match
  expect_true(terra::same.crs(clc, austria))
  expect_true(terra::same.crs(temp, austria))
  expect_true(terra::same.crs(dgm, austria))
})


##### Testing the shape of the clipped variables #####

# Custom function to compare two spatial extents with a tolerance
#
# 'expect_ext_equal_tol' is a 'testthat' helper that asserts two extents are
#equal within a numeric tolerance, by comparing their four bounding coordinates.
#
# PARAMETERS:
#   - left, right, bottom, and top boundaries
#   - e_out: observed extent (e.g., computed by the function under test)
#   - e_exp: expected/reference extent
#   - tol:   numeric tolerance passed to testthat::expect_equal()

expect_ext_equal_tol <- function(e_out, e_exp, tol) {
  expect_equal(e_out$xmin, e_exp$xmin, tolerance = tol)
  expect_equal(e_out$xmax, e_exp$xmax, tolerance = tol)
  expect_equal(e_out$ymin, e_exp$ymin, tolerance = tol)
  expect_equal(e_out$ymax, e_exp$ymax, tolerance = tol)
}

test_that("Clipped rasters keep original grid resolution", {
  # GIVEN: original rasters and their clipped versions exist
  skip_if_not(exists("clc")  && exists("clc_at"))
  skip_if_not(exists("temp") && exists("temp_at"))
  skip_if_not(exists("dgm")  && exists("dgm_at"))
  
  # WHEN: comparing resolutions
  # THEN: resolution of clipped rasters equals original rasters
  expect_equal(res(clc_at),  res(clc))
  expect_equal(res(temp_at), res(temp))
  expect_equal(res(dgm_at),  res(dgm))
})

test_that("Clipped extents align to Austria bbox snapped outward to each raster grid", {
  # GIVEN: austria + clipped rasters
  skip_if_not(exists("austria"))
  skip_if_not(exists("clc")  && exists("clc_at"))
  skip_if_not(exists("temp") && exists("temp_at"))
  skip_if_not(exists("dgm")  && exists("dgm_at"))
  
  # WHEN: computing expected aligned extents
  exp_clc  <- terra::align(ext(austria), clc,  snap = "out")
  exp_temp <- terra::align(ext(austria), temp, snap = "out")
  exp_dgm  <- terra::align(ext(austria), dgm,  snap = "out")
  
  # THEN: clipped extents match expectations within tolerance based on the file's resolution
  expect_ext_equal_tol(ext(clc_at),  exp_clc,  tol = min(res(clc)) * 1e-6)
  expect_ext_equal_tol(ext(temp_at), exp_temp, tol = min(res(temp)) * 1e-6)
  expect_ext_equal_tol(ext(dgm_at),  exp_dgm,  tol = min(res(dgm)) * 1e-6)
})



##### Testing 'area_weighted_mean' function #####

test_that("'area_weighted_mean' computes the correct weighted mean", {
  # GIVEN: valid values and valid positive weights
  values <- c(10, 20)
  weights <- c(0.25, 0.75)
  
  # WHEN: computing the area-weighted mean
  res <- area_weighted_mean(values, weights)
  
  # THEN: it matches manual computation
  expect_equal(res, 17.5)
})

test_that("'area_weighted_mean' ignores invalid values (NA/Inf) and invalid weights", {
  # GIVEN: a mix of valid and invalid pairs
  values <- c(10, NA, 30, Inf)
  weights <- c(0.2, 0.5, 0.3, 0.9)
  
  # WHEN: computing the area-weighted mean
  res <- area_weighted_mean(values, weights)
  
  # THEN: only valid pairs are used
  expect_equal(res, 22)
})



##### Testing the values of downscaled variables ##### 

test_that("Grid downscaled values stay within the clipped raster global min/max", {
  # GIVEN: the pipeline objects exist
  skip_if_not(exists("grid_1km_sf"))
  skip_if_not(exists("temp_at") && exists("dgm_at"))
  
  tol <- 1e-6
  
  # Temperature
  # WHEN: we compute global min/max of raster and grid column
  r_min <- terra::global(temp_at[[1]], "min", na.rm = TRUE)[1, 1]
  r_max <- terra::global(temp_at[[1]], "max", na.rm = TRUE)[1, 1]
  g_min <- min(grid_1km_sf$temp, na.rm = TRUE)
  g_max <- max(grid_1km_sf$temp, na.rm = TRUE)
  
  # THEN: grid range must be inside raster range
  expect_gte(g_min, r_min - tol)
  expect_lte(g_max, r_max + tol)
  
  # Elevation 
  r_min <- terra::global(dgm_at[[1]], "min", na.rm = TRUE)[1, 1]
  r_max <- terra::global(dgm_at[[1]], "max", na.rm = TRUE)[1, 1]
  g_min <- min(grid_1km_sf$dgm, na.rm = TRUE)
  g_max <- max(grid_1km_sf$dgm, na.rm = TRUE)
  
  expect_gte(g_min, r_min - tol)
  expect_lte(g_max, r_max + tol)
})



##### Testing 'clc_cover_df' function #####

test_that("'clc_cover_df' returns correct percentages for a simple known case", {
  # GIVEN: 4 pixels each contributing equally (0.25)
  # codes map to: artificial (1), agricultural (12), forest/semi (23), wetlands (35)
  codes <- c(1, 12, 23, 35)
  w <- c(0.25, 0.25, 0.25, 0.25)
  
  # WHEN: computing the macro-category composition
  out <- clc_cover_df(codes, w)
  
  # THEN: each relevant category is 25%
  expect_equal(out$perc_artificial,   25)
  expect_equal(out$perc_agricultural, 25)
  expect_equal(out$perc_forest_semi,  25)
  expect_equal(out$perc_wetlands,     25)
  expect_equal(out$perc_water,         0)
  expect_equal(out$perc_no_data,       0)
})

test_that("'clc_cover_df' returns NA row when no valid pixels remain", {
  # GIVEN: all codes are NA
  codes <- c(NA, NA, NA)
  w <- c(0.2, 0.3, 0.5)
  
  # WHEN: computing macro-category composition
  out <- clc_cover_df(codes, w)
  
  # THEN: all percentage outputs are NA
  expect_true(all(is.na(out)))
})

test_that("'clc_cover_df' macro percentages sum to 100", {
  # GIVEN: random recognized codes and positive weights
  set.seed(75)
  
  for (i in 1:100) {
    n <- sample(10:300, 1)
    codes <- sample(c(1:44, 48), size = n, replace = TRUE)
    w <- runif(n, min = 0.001, max = 1)
    
    # WHEN: computing macro-category composition
    out <- clc_cover_df(codes, w)
    
    # THEN: sum should be 100 (within floating-point tolerance)
    expect_equal(sum(unlist(out)), 100, tolerance = 1e-10)
  }
})



########## Testing the analysis file ##########


##### Testing the dominant cover attribution #####

test_that("dominant_cover is NA when the maximum Land Cover percentage is below the threshold", {
  # GIVEN: a single row where the maximum percentage is < 50
  dom_threshold <- 50
  
  df_lm <- tibble(
    temp = 5,
    dgm  = 1000,
    perc_artificial   = 10,
    perc_agricultural = 20,
    perc_forest_semi  = 49,  # max is 49 (< 50)
    perc_wetlands     = 1,
    perc_water        = 0,
    perc_no_data      = 20
  )
  
  lc_cols <- c(
    "perc_artificial", "perc_agricultural", "perc_forest_semi",
    "perc_wetlands", "perc_water", "perc_no_data"
  )
  
  # WHEN: we compute max_perc, n_max, and dominant_cover (same logic as 1-data_analyses.R)
  out <- df_lm %>%
    mutate(
      max_perc = pmax(!!!syms(lc_cols), na.rm = TRUE),
      n_max = rowSums(across(all_of(lc_cols), ~ dplyr::near(.x, max_perc)), na.rm = TRUE),
      dominant_cover = case_when(
        max_perc < dom_threshold ~ NA_character_,
        n_max != 1 ~ NA_character_,
        dplyr::near(max_perc, perc_artificial)   ~ "Artificial",
        dplyr::near(max_perc, perc_agricultural) ~ "Agricultural",
        dplyr::near(max_perc, perc_forest_semi)  ~ "Seminatural",
        dplyr::near(max_perc, perc_wetlands)     ~ "Wetlands",
        dplyr::near(max_perc, perc_water)        ~ "Water",
        dplyr::near(max_perc, perc_no_data)      ~ "No Data",
        TRUE ~ NA_character_
      )
    )
  
  # THEN: dominant cover is NA because it does not pass the threshold
  expect_true(is.na(out$dominant_cover))
  expect_equal(out$max_perc, 49)
})

test_that("dominant_cover assigns the correct label when there is a unique maximum >= threshold", {
  # GIVEN: a single row with a unique max >= 50
  dom_threshold <- 50
  
  df_lm <- tibble(
    temp = 5,
    dgm  = 1000,
    perc_artificial   = 60, # unique max
    perc_agricultural = 20,
    perc_forest_semi  = 10,
    perc_wetlands     = 5,
    perc_water        = 0,
    perc_no_data      = 5
  )
  
  lc_cols <- c(
    "perc_artificial", "perc_agricultural", "perc_forest_semi",
    "perc_wetlands", "perc_water", "perc_no_data"
  )
  
  # WHEN: we compute dominant_cover
  out <- df_lm %>%
    mutate(
      max_perc = pmax(!!!syms(lc_cols), na.rm = TRUE),
      n_max = rowSums(across(all_of(lc_cols), ~ dplyr::near(.x, max_perc)), na.rm = TRUE),
      dominant_cover = case_when(
        max_perc < dom_threshold ~ NA_character_,
        n_max != 1 ~ NA_character_,
        dplyr::near(max_perc, perc_artificial)   ~ "Artificial",
        dplyr::near(max_perc, perc_agricultural) ~ "Agricultural",
        dplyr::near(max_perc, perc_forest_semi)  ~ "Seminatural",
        dplyr::near(max_perc, perc_wetlands)     ~ "Wetlands",
        dplyr::near(max_perc, perc_water)        ~ "Water",
        dplyr::near(max_perc, perc_no_data)      ~ "No Data",
        TRUE ~ NA_character_
      )
    )
  
  # THEN: the dominant cover is correctly identified
  expect_equal(out$max_perc, 60)
  expect_equal(out$n_max, 1)
  expect_equal(out$dominant_cover, "Artificial")
})

test_that("With a unique strict maximum >= threshold, dominant_cover matches the argmax class", {
  # GIVEN: random rows where we force a strict unique maximum above threshold
  set.seed(75)
  dom_threshold <- 50
  
  lc_cols <- c(
    "perc_artificial", "perc_agricultural", "perc_forest_semi",
    "perc_wetlands", "perc_water", "perc_no_data"
  )
  
  labels <- c("Artificial", "Agricultural", "Seminatural", "Wetlands", "Water", "No Data")
  
  for (i in 1:150) {
    # Start with random values below 50
    x <- runif(6, min = 0, max = 49)
    
    # Choose a winner and force it to be > 50, and strictly larger than all others
    winner <- sample(1:6, 1)
    x[winner] <- runif(1, min = dom_threshold + 1, max = 100)
    
    df_lm <- tibble(
      temp = 5,
      dgm  = 1000,
      perc_artificial   = x[1],
      perc_agricultural = x[2],
      perc_forest_semi  = x[3],
      perc_wetlands     = x[4],
      perc_water        = x[5],
      perc_no_data      = x[6]
    )
    
    # WHEN: we compute dominant_cover
    out <- df_lm %>%
      mutate(
        max_perc = pmax(!!!syms(lc_cols), na.rm = TRUE),
        n_max = rowSums(across(all_of(lc_cols), ~ dplyr::near(.x, max_perc)), na.rm = TRUE),
        dominant_cover = case_when(
          max_perc < dom_threshold ~ NA_character_,
          n_max != 1 ~ NA_character_,
          dplyr::near(max_perc, perc_artificial)   ~ "Artificial",
          dplyr::near(max_perc, perc_agricultural) ~ "Agricultural",
          dplyr::near(max_perc, perc_forest_semi)  ~ "Seminatural",
          dplyr::near(max_perc, perc_wetlands)     ~ "Wetlands",
          dplyr::near(max_perc, perc_water)        ~ "Water",
          dplyr::near(max_perc, perc_no_data)      ~ "No Data",
          TRUE ~ NA_character_
        )
      )
    
    # THEN: classification matches the forced winner
    expect_equal(out$n_max, 1)
    expect_equal(out$dominant_cover, labels[winner])
  }
})

##### Testing the reference level change ##### 

test_that("reference level selection uses Seminatural if present, otherwise the most frequent category", {
  # GIVEN: a dataset where Seminatural exists among the included levels
  df1 <- tibble(
    dominant_cover = factor(c(rep("Artificial", 10), rep("Seminatural", 8), rep("Agricultural", 6))),
    temp = rnorm(24),
    dgm  = runif(24, 0, 3000)
  )
  
  # WHEN: we apply the reference selection logic
  if ("Seminatural" %in% levels(df1$dominant_cover)) {
    df1$dominant_cover <- relevel(df1$dominant_cover, ref = "Seminatural")
  } else {
    ref_level <- names(which.max(table(df1$dominant_cover)))
    df1$dominant_cover <- relevel(df1$dominant_cover, ref = ref_level)
  }
  
  # THEN: Seminatural is the reference (first level)
  expect_equal(levels(df1$dominant_cover)[1], "Seminatural")
  
  # GIVEN: a dataset where Seminatural is NOT present
  df2 <- tibble(
    dominant_cover = factor(c(rep("Artificial", 12), rep("Agricultural", 7), rep("Water", 3))),
    temp = rnorm(22),
    dgm  = runif(22, 0, 3000)
  )
  
  # WHEN: we apply the same logic
  if ("Seminatural" %in% levels(df2$dominant_cover)) {
    df2$dominant_cover <- relevel(df2$dominant_cover, ref = "Seminatural")
  } else {
    ref_level <- names(which.max(table(df2$dominant_cover)))
    df2$dominant_cover <- relevel(df2$dominant_cover, ref = ref_level)
  }
  
  # THEN: the most frequent category is the reference
  expect_equal(levels(df2$dominant_cover)[1], "Artificial")
})

cat("All tests in testing.r completed.\n")