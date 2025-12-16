# Testing file
library(testthat)
library(terra)
library(sf)
library(tidyverse)
library(exactextractr)


# Test the clipping file "austria"
stopifnot(nrow(sf::st_as_sf(austria)) == 1) # one country filtered
stopifnot(terra::is.valid(austria)) # valid geometry

# Test the match of the CRS for all the data with the clipping file
stopifnot(terra::same.crs(clc, austria))
stopifnot(terra::same.crs(temp, austria))
stopifnot(terra::same.crs(temp_stdv, austria))
stopifnot(terra::same.crs(dgm, austria))




# Testing the shape of the clipped variables
# UNIT TEST RESULTING SHAPE VS MASK POLYGON
# Compare extents with a tolerance (meters) 
expect_ext_equal_tol <- function(e_out, e_exp, tol) {
  expect_equal(e_out$xmin, e_exp$xmin, tolerance = tol)
  expect_equal(e_out$xmax, e_exp$xmax, tolerance = tol)
  expect_equal(e_out$ymin, e_exp$ymin, tolerance = tol)
  expect_equal(e_out$ymax, e_exp$ymax, tolerance = tol)
}

test_that("Clipped rasters keep original grid (no resampling)", {
  # crop/mask should NOT change resolution
  expect_equal(res(clc_at),       res(clc))
  expect_equal(res(temp_at),      res(temp))
  expect_equal(res(temp_stdv_at), res(temp_stdv))
  expect_equal(res(dgm_at),       res(dgm_austria))
})

test_that("Clipped extents are the Austria bbox aligned outward to each raster grid", {
  # align() gives the bbox snapped to the raster grid; snap='out' matches "keep touching pixels"
  exp_clc  <- terra::align(ext(austria), clc,         snap = "out")
  exp_temp <- terra::align(ext(austria), temp,        snap = "out")
  exp_tsdv <- terra::align(ext(austria), temp_stdv,   snap = "out")
  exp_dgm  <- terra::align(ext(austria), dgm_austria, snap = "out")
  
  # tolerance: a fraction of the cell size (floating point + projections)
  expect_ext_equal_tol(ext(clc_at),       exp_clc,  tol = min(res(clc)) * 1e-6)
  expect_ext_equal_tol(ext(temp_at),      exp_temp, tol = min(res(temp)) * 1e-6)
  expect_ext_equal_tol(ext(temp_stdv_at), exp_tsdv, tol = min(res(temp_stdv)) * 1e-6)
  expect_ext_equal_tol(ext(dgm_at),       exp_dgm,  tol = min(res(dgm_austria)) * 1e-6)
})



# PROPERTY BASED TEST: Every non-NA cell in temp_at has its center inside the Austria polygon.
test_that("temp_at non-NA cells intersect the Austria mask", {
  # Austria polygon in sf format (mask geometry)
  austria_sf <- austria %>% st_as_sf()
  
  # Work on the first layer of temp_at (mean annual temperature for 2018)
  r <- temp_at[[1]]
  
  # Values of all cells (NA included)
  vals <- terra::values(r, na.rm = FALSE)
  
  # Indices of cells that survived the mask (non-NA)
  valid_cells <- which(!is.na(vals))
  
  # Sanity check: there is at least one non-NA cell
  expect_true(length(valid_cells) > 0)
  
  # Randomly sample up to 1000 valid cells
  set.seed(123)  # reproducibility
  n_sample <- min(1000L, length(valid_cells))
  sample_cells <- sample(valid_cells, size = n_sample)
  
  # Build polygons for the sampled raster cells
  cells_poly <- terra::as.polygons(r, cells = sample_cells)
  cells_sf   <- st_as_sf(cells_poly)
  
  # For each cell polygon, check if it intersects the Austria polygon
  intersects_mat <- st_intersects(cells_sf, austria_sf, sparse = FALSE)
  intersects_any <- apply(intersects_mat, 1L, any)
  
  # Property-based check:
  # every sampled non-NA cell polygon must intersect the Austria mask
  expect_true(all(intersects_any))
})



# Test data ranges after the downscaling
# Property-based test: per-cell mean must lie in that cell’s min/max
expect_mean_within_cell_minmax <- function(mean_vec, r, polygons, tol = 1e-10) {
  cell_min <- exact_extract(r, polygons, "min")
  cell_max <- exact_extract(r, polygons, "max")
  
  ok <- is.na(mean_vec) | is.nan(mean_vec) |
    (mean_vec >= (cell_min - tol) & mean_vec <= (cell_max + tol))
  
  expect_true(all(ok))
  invisible(TRUE)
}

test_that("Downscaled weighted means are within per-cell raster min/max (property test)", {
  expect_mean_within_cell_minmax(grid_1km_sf$temp,      temp_at[[1]],      grid_1km_sf)
  expect_mean_within_cell_minmax(grid_1km_sf$temp_stdv, temp_stdv_at[[1]], grid_1km_sf)
  expect_mean_within_cell_minmax(grid_1km_sf$dgm,       dgm_at[[1]],       grid_1km_sf)
})



# Test Corine Land Cover data after the downscaling
# Does clc_props contains 6 columns?
# Are all the values between 0 and 100 (percentages)?

test_that("clc_props has 6 columns and percentages within [0, 100]", {
  
  # Structure: exactly 6 columns with expected names
  expect_equal(ncol(clc_props), 6)
  
  expect_named(
    clc_props,
    c("perc_artificial", "perc_agricultural", "perc_forest_semi",
      "perc_wetlands", "perc_water", "perc_no_data")
  )
  
  # Values: all non-NA values must be between 0 and 100
  # (This is a property-based check: percentages can't be negative or > 100)
  m <- as.matrix(clc_props)
  
  ok <- is.na(m) | (m >= 0 & m <= 100)
  expect_true(all(ok))
  
  # if a row is fully defined (no NA), its percentages should sum to ~100
  # This catches bugs in total_w or category boundaries.
  row_ok <- rowSums(is.na(m)) == 0
  if (any(row_ok)) {
    expect_equal(rowSums(m[row_ok, , drop = FALSE]), rep(100, sum(row_ok)), tolerance = 1e-6)
  }
})
