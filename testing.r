library(testthat)
library(terra)
library(sf)
library(tidyverse)
library(exactextractr)

# Load project functions (adjust path if needed)
source("functions.R")
# source("0-data_preparation.R") # run "0-data_preparation.R" before this code
# source("1-data_analysis.R") # run "1-data_analysis.R" before this code



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
# 'expect_ext_equal_tol' is a *testthat* helper that asserts two extents are
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



cat("All tests in testing.r completed.\n")