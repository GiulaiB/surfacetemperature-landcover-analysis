# Austria Surface Temperature - Land Cover analysis

This project builds a fully reproducible R pipeline to study how land cover relates to surface temperature across different elevations, testing how much variation can be explained by topography (elevation) and land-cover composition (e.g., artificial, agricultural, forest/semi-natural, wetlands, water). In particular, this repository uses CHELSEA, Corine Land Cover (clc) and Digital terrain model (dgm) open source data to build a **1 km² grid over Austria** and run a small set of statistical analyses to explore relationships between:
- **Mean annual temperature** (`temp`; CHELSA bio01d, year 2018)
- **Temperature seasonality** (`temp_stdv`; CHELSA bio04d, year 2018)
- **Elevation** (`dgm`; Digital terrain model Austria)
- **Land cover composition** (`clc`; Corine Land Cover 2018)

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing and a function script. A brief description is given in the next paragraph.

---

## Project workflow

### 0) Data preparation (`0-data_manipulation.R`)
The code contained within `0-data_manipulation.R`:
- Loads and reprojects all rasters to **EPSG:3035 (ETRS89 / LAEA Europe)** *[1]*.
- Clips rasters to **Austria** (Natural Earth borders).
- Creates a **1 km² grid**, clipped to the Austria boundary.
- Computes, for each grid cell:
  - area-weighted mean **temperature** (`temp`)
  - area-weighted mean **temperature seasonality** (`temp_stdv`)
  - area-weighted mean **elevation** (`dgm`)
  - % cover of Corine Land Cover (`clc`) macro-categories: Artificial, Agricultural, Forest/Seminatural, Wetlands, Water and No Data.

Outputs are saved to:
- `data/new_version_data/grid_all.rds`
- `data/new_version_data/grid_all.gpkg`

**IMPORTANT:** Reprojection cost: reprojecting large rasters to EPSG:3035 can be slow and heavy. Make sure you have enough disk space and memory.

### 1) Analyses (`1-data_analyses.R`)
The code contained within `1-data_analyses.R`:
- **Pearson correlation test** (Temperature vs Elevation) *[2]*
- Linear model: `temp ~ dgm`
- Dominant land-cover classification (dominant class > 50%)
- Welch ANOVA: Temperature differences across dominant land-cover classes
- Games–Howell post-hoc test
- Model comparison:
  - baseline: `temp ~ dgm`
  - additive: `temp ~ dgm + dominant_cover` (with “Seminatural” as reference)
  - nested-model F-test + AIC comparison

Outputs are saved to:
- ????

### 2) Plots (`2-plots.R`)
The outputs can be also seen in the plots. The file `2-plots.R` produces:
- Scatter plot: Elevation vs Temperature (+ regression line)
- Boxplot: Temperature by dominant land-cover category

The plots are saved and can be found into:

The other files are:

**Testing**

The code contained within `testing.R` checks:
- Austria mask geometry validity + CRS consistency across inputs
- Clipping does not resample rasters (resolution preserved)
- Clipped extents match the Austria bbox snapped to each raster grid
- Property-based checks: sampled non-NA masked cells intersect Austria; downscaled means fall within per-cell min/max; land-cover percentages are within [0, 100] and sum to ~100 when defined.

**Function**

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

## Data sources
You must download the required datasets using the information given in `DATA_SOURCES.md`. After the download, you need to place the data in the paths expected by the scripts:

Corine Land Cover 2018 GeoTIFF:
- `data/CorineLandCover2018/DATA/U2018_CLC2018_V2020_20u1.tif`

CHELSA netCDF (bio01d and bio04d for 2018):
- `data/CHELSA/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc`
- `data/CHELSA/CHELSA_EUR11_obs_bio04d_2018_V.2.1.nc`

Austria DGM GeoTIFF:
- `data/austria-dgm/dhm_at_lamb_10m_2018.tif`

If your filenames differ or you want to change them, please update the rast("...") paths in `0-data_manipulation.R`.

---

## Repository structure (DA COMPLETARE)

```txt
my-scripts/
  0-data_manipulation.R
  1-data_analyses.R
  2-plots.R
  function.R
  testing.R

data/
  CorineLandCover2018/...
  CHELSA/...
  austria-dgm/...
  new_version_data/

images/
... # TODO            

```

*[1] EPSG:3035 (ETRS89 / LAEA Europe) is a specific Geographic Coordinate Reference System (CRS) used for mapping Europe, particularly for statistical analysis and environmental monitoring, because it uses the Lambert Azimuthal Equal-Area (LAEA) projection to accurately represent areas across the continent. It's based on the European Terrestrial Reference System 1989 (ETRS89) datum and is centered around 52°N, 10°E, providing true-to-scale area representation for pan-European data.*  
*[2] In statistics, the Pearson correlation coefficient (PCC) is a correlation coefficient that measures linear correlation between two sets of data. It is the ratio between the covariance of two variables and the product of their standard deviations; thus, it is essentially a normalized measurement of the covariance, such that the result always has a value between −1 and 1.*
