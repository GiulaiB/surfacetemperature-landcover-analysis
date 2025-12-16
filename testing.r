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
