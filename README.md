# Austria Surface Temperature - Land Cover analysis

This project builds a reproducible R pipeline to study how Land Cover relates to surface temperature across different elevations, testing how much variation can be explained by Elevation and Land Cover composition (Artificial, Agricultural, Semi-natural). In particular, this repository uses **CHELSA**, Corine Land Cover (CLC) and Digital terrain Model (DGM) open source data to build a **1 km² grid over Austria** and run a small set of statistical analyses to explore relationships between:
- **Mean annual temperature** (`temp`; CHELSA bio01d, year 2018) 
- **Elevation** (`dgm`; Digital terrain model Austria)
- **Land cover composition** (`clc`; Corine Land Cover, year 2018)

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing script and a `functions.r` file. A brief description of all parts is given in the next paragraph. In addition, if you use `RStudio`, an RStudio project file called `software-project.Rproj` is included to ensure the scripts run correctly.

---

## Setup

This repository does **not** include the raw input datasets (since they are large), so you need to create the local folder structure and place the downloaded files where the scripts expect them.

i) Create these folders in the project root:
- `data/` (raw inputs + generated `clean_data.gpkg`)
- `outputs/` (saved figures)

(Optional) To ensure `outputs/` exists you can create folders from R. Quick folder creation can be done by adding: `dir.create("data")` for `data/` and `dir.create("outputs")` for `outputs/`.

ii) Download the datasets listed in `DATA_SOURCES.md` and place  them inside `data/` so that these paths exist:
- `data/U2018_CLC2018_V2020_20u1.tif`
- `data/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc`
- `data/dhm_at_lamb_10m_2018.tif`

If you prefer different filenames or a different folder layout, please update the `rast("...")` paths in `0-data_preparation.r`.

## How to run

**NOTE:** It's recommended to open the RStudio project (`software-project.Rproj`) so the working directory is the project root.

Then run the scripts in order:
- **0)** Builds the grid + extracts variables and writes: `data/clean_data.gpkg`
source("0-data_preparation.r")

- **1)** Runs statistics and model comparisons (reads: `data/clean_data.gpkg`)
source("1-data-analysis.r")

- **2)** Produces and saves figures to `outputs/`
source("2-plots.r")

If you prefer running from the terminal:
```bash
Rscript 0-data_preparation.r
Rscript 1-data-analysis.r
Rscript 2-plots.r
```

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

The output is saved as:
- `data/clean_data.gpkg` (created locally in your `data/` folder)
**NOTE:** Reprojecting large rasters to EPSG:3035 can be slow and memory-intensive. Make sure you have enough patience!

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

The plots are saved into the `outputs/` folder as:
- `outputs/linear_model_Temperature-Elevation.png`
- `outputs/boxplot_Land_Cover-Temperature.png`
- `outputs/linear_model_Temperature-Elevation-Land_Cover.png`
- `outputs/boxplot_Land_Cover-Temperature-Elevation.png`

### 3) Testing (`testing.R`)

The file `testing.R` uses `testthat` to check the project workflow. In particular:
- Check that core spatial inputs exist and have valid geometry and shared CRS
- Verify clipped rasters keep expected resolution and extent
- Executes tests on `area_weighted_mean` and `clc_cover_df` functions
- Tests key analysis passages such as `dominant_cover` assignment and reference-level selection

### 4) Functions (`functions.R`)

The file `function.R` defines two functions used as summary functions inside `exact_extract` for raster–polygon extraction. The two functions are:

*`area_weighted_mean`*, that:
- Checks that `values` and `coverage_fraction` have the same length
- Keeps only valid pixels (finite value + finite weight + weight > 0)
- Computes the coverage-fraction-weighted mean: sum(values * weight) / sum(weight)

*`clc_cover_df`*, that:
- Builds a small data frame of CLC codes (`values`) and weights (`coverage_fraction`)
- Drops NA codes, returns a one-row NA result if no valid pixels or total weight is 0
-	Sums weighted cover for CLC macro-categories by code ranges: artificial (1–11), agricultural (12–22), semi-natural (23–34), wetlands (35–39), water (40–44), no-data (48)
-	Returns a one-row `data.frame` with the percentage of each macro-category in the polygon for every grid cell

---

## Requirements
The following core packages are used across scripts:
- terra
- sf
- exactextractr
- rnaturalearth
- tidyverse
- broom
- rstatix
- testthat


---

## Repository structure

Tracked files (added in the repository):
```txt
0-data_preparation.r
1-data_analysis.r
2-plots.r
functions.r
testing.r
software-project.Rproj
README.md
DATA_SOURCES.md
```

Local folders (need to be created):
```txt
data/
  U2018_CLC2018_V2020_20u1.tiff
  CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc
  dhm_at_lamb_10m_2018.tiff
  clean_data.gpkg

outputs/
  linear_model_Temperature-Elevation.png
  boxplot_Land_Cover-Temperature.png
  linear_model_Temperature-Elevation-Land_Cover.png
  boxplot_Land_Cover-Temperature-Elevation.png

```

*[1] EPSG:3035 (ETRS89 / LAEA Europe) is a projected CRS (specific Geographic Coordinate Reference System) widely used for pan-European environmental analysis, particularly for statistical analysis and environmental monitoring, because it uses the Lambert Azimuthal Equal-Area projection (LAEA) to accurately represent areas across the continent. It's based on the European Terrestrial Reference System 1989 (ETRS89) datum and is centered around 52°N, 10°E, providing true-to-scale area representation for pan-European data.*
