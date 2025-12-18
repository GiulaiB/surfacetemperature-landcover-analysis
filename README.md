# Austria Surface Temperature - Land Cover analysis

This project builds a fully reproducible R pipeline to study how Land Cover relates to surface temperature across different elevations, testing how much variation can be explained by Elevation and Land Cover composition (Artificial, Agricultural, Semi-natural). In particular, this repository uses CHELSEA, Corine Land Cover (clc) and Digital terrain model (dgm) open source data to build a **1 km² grid over Austria** and run a small set of statistical analyses to explore relationships between:
- **Mean annual temperature** (`temp`; CHELSA bio01d, year 2018)
- **Elevation** (`dgm`; Digital terrain model Austria)
- **Land cover composition** (`clc`; Corine Land Cover 2018)

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing and a function script. A brief description is given in the next paragraph.

---

## Project workflow

### 0) Data preparation (`0-data_preparation.R`)
The file `0-data_preparation.R` contains:
- Loads and reprojects all rasters to **EPSG:3035 (ETRS89 / LAEA Europe)** *[1]*
- Clips rasters to **Austria** borders
- Creates a **1 km² grid**, clipped to the Austria boundaries
- Computes, for each grid cell:
  - area-weighted mean **temperature** (`temp`)
  - area-weighted mean **elevation** (`dgm`)
  - % cover of Corine Land Cover (`clc`) macro-categories: Artificial, Agricultural, Semi-natural, Wetlands, Water and No Data

The output of the first file is saved to:
- `data/clean_data.gpkg`
You can find it in the data folder in this repository.

**IMPORTANT:** Reprojecting large rasters to EPSG:3035 can be slow and heavy. Make sure you have enough pacience!

### 1) Data analysis (`1-data_analysis.R`)
The file `1-data_analysis.R` contains:
- Pearson correlation test between Temperature and Elevation
- Linear model: `temp ~ dgm`
- Dominant land-cover classification (dominant class > 50%)
- Welch ANOVA: Temperature differences across dominant land-cover classes
- Games–Howell post-hoc test
- Model comparison:
  - base model: `temp ~ dgm`
  - added variable model: `temp ~ dgm + dominant_cover` (with “Semi-natural” as reference)
  - nested-model F-test + AIC comparison

### 2) Plots (`2-plots.R`)
The file `2-plots.R` produces:
- Scatter plot: Temperature vs Elevation (+ regression line)
- Boxplot: Temperature by dominant Land Cover category
- Scatter plot: Temperature vs Elevation and Land Cover
- Boxplot: Temperature by dominant Land Cover category by Elevation ranges

The plots are saved and can be found into the `outputs` folder:
- `linear_model_Temperature-Elevation.png`
- `boxplot_Land_Cover-Temperature.png`
- `linear_model_Temperature-Elevation-Land_Cover.png`
- `boxplot_Land_Cover-Temperature-Elevation.png`

### 3) Testing (`testing.R`)

The file `testing.R` checks:
- Austria mask geometry validity + CRS consistency across inputs
- Clipping does not resample rasters (resolution preserved)
- Clipped extents match the Austria bbox snapped to each raster grid
- Property-based checks: sampled non-NA masked cells intersect Austria; downscaled means fall within per-cell min/max; land-cover percentages are within [0, 100] and sum to ~100 when defined.

### 4) Functions (`functions.R`)

The code whithin `function.R` defines the helper `clc_cover_df()` used by `exact_extract()` to convert CLC numeric codes into macro-category cover percentages (Artificial/Agricultural/Forest-Seminatural/Wetlands/Water/No Data), handling NA/empty cases and using `coverage_fraction` weights.

---

## Requirements
The following core packages are used across scripts:
- terra, sf, exactextractr
- tidyverse
- rnaturalearth
- broom, rstatix
- testthat
- exactextractr

---

## Repository structure (DA COMPLETARE)

```txt
  0-data_manipulation.R
  1-data_analyses.R
  2-plots.R
  function.R
  testing.R

data/
  CorineLandCover2018/...
  CHELSA/...
  austria-dgm/...
  clean_data.gpkg

outputs/
... # TODO            

```

You must download the required datasets using the information given in `DATA_SOURCES.md`. After the download, you need to place the files in a `data` folder. If your filenames differ or you want to change them, please update the rast("...") paths in `0-data_manipulation.R`.

*[1] EPSG:3035 (ETRS89 / LAEA Europe) is a specific Geographic Coordinate Reference System (CRS) used for mapping Europe, particularly for statistical analysis and environmental monitoring, because it uses the Lambert Azimuthal Equal-Area (LAEA) projection to accurately represent areas across the continent. It's based on the European Terrestrial Reference System 1989 (ETRS89) datum and is centered around 52°N, 10°E, providing true-to-scale area representation for pan-European data.*  
