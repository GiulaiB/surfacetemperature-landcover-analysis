# Austria Surface Temperature - Land Cover analysis

This project builds a reproducible R pipeline to study how **Land Cover** relates to **surface temperature** across different **elevations**, testing how much variation can be explained by Elevation and Land Cover composition (Artificial, Agricultural, Semi-natural). In particular, this repository uses CHELSA, Corine Land Cover (CLC) and Digital terrain Model (DGM) open source data to build a **1 km² grid over Austria** and run a small set of statistical analyses to explore relationships between:
- **Mean annual temperature** (`temp`; CHELSA bio01d, year 2018) 
- **Elevation** (`dgm`; Digital terrain model Austria)
- **Land cover composition** (`clc`; Corine Land Cover, year 2018)

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing script and a file containing the functions used. A brief description of all parts is given in the next paragraph. In addition, if you use `RStudio`, an RStudio project file called `software-project.Rproj` is included to ensure the scripts run correctly.

---
## Installation

### Software
- **R** (recent version recommended)
- (Optional but recommended) **RStudio**

### Install R packages
The following core packages are used across scripts:
- terra
- sf
- exactextractr
- rnaturalearth
- tidyverse
- broom
- rstatix
- testthat

To install, run this in **R**:

```r
install.packages(c(
  "tidyverse", "sf", "terra", "exactextractr", "rnaturalearth",
  "broom", "rstatix", "testthat", "readr"
))
```

(Optional) After installation, verify packages load:

```r
pkgs <- c("tidyverse","sf","terra","exactextractr","rnaturalearth","broom","rstatix","testthat","readr")
invisible(lapply(pkgs, require, character.only = TRUE))
```

## Setup

This repository does **not** include the raw input datasets (since they are large), so you need to create the local folder structure and place the downloaded files where the scripts expect them.

**Step 1:** Create these folders in the project root:
  - `data/` (raw inputs + generated `clean_data.gpkg`)
  - `outputs/` (saved graphs)

(Optional) Quick folder creation can be done by adding: `dir.create("data")` for `data/` and `dir.create("outputs")` for `outputs/`.

**Step 2:** Download the datasets listed in `DATA_SOURCES.md` and place them inside `data/` so that these paths exist:
  - `data/U2018_CLC2018_V2020_20u1.tif`
  - `data/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc`
  - `data/dhm_at_lamb_10m_2018.tif`

The pipeline expects **three rasters** in `data/`:

- **Corine Land Cover (CLC) 2018**  
   - File: `data/U2018_CLC2018_V2020_20u1.tif`  
   - Type: categorical raster (integer codes)
   - Used as categorical: it is reprojected using nearest-neighbor resampling 

- **CHELSA bio01d (2018)**  
   - File: `data/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc`  
   - Type: NetCDF raster
   - Values: stored as 0.1 Kelvin in the raw product, later converted to °C in the script

- **Digital Terrain Model (DGM) Austria**  
   - File: `data/dhm_at_lamb_10m_2018.tif`  
   - Type: continuous raster (elevation)
   - Used as continuous: it is reprojected using bilinear resampling

**NOTE:** If you prefer different filenames or a different folder layout, please update the `rast("...")` paths in `0-data_preparation.r`.

## How to run

**NOTE:** It's recommended to open the RStudio project (`software-project.Rproj`) so the working directory is the project root.

Then run the scripts in order:
- **0)** `0-data_preparation.r` builds the grid + extracts variables and writes `data/clean_data.gpkg`
- **1)** `source("1-data-analysis.r")` reads `data/clean_data.gpkg` and then runs statistics and model comparisons
- **2)** `2-plots.r` produces and saves graphs to `outputs/`

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
- `outputs/linear_model_Temperature-Elevation.jpeg`
- `outputs/boxplot_Land_Cover-Temperature.jpeg`
- `outputs/linear_model_Temperature-Elevation-Land_Cover.jpeg`
- `outputs/boxplot_Land_Cover-Temperature-Elevation.jpeg`

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

## Outputs

After running the full pipeline, you will find different files created:

**Data**
- `data/clean_data.gpkg`: contained in the `data` folder, is a 1 km² grid over Austria with extracted variables (`temp`, `dgm`, `clc` land-cover percentages)

**Tables**
- `outputs/tables/stats_t_lc.csv`: contained in the `outputs` folder, shows descriptive statistics of temperature by dominant land cover
- `outputs/tables/games_howell.csv`: Games–Howell post-hoc pairwise comparisons

**Report**
- `outputs/model_report.txt`: contained in the `outputs` folder, is a text file that shows correlation test, model summaries, Welch ANOVA, model comparison (nested ANOVA + AIC)

**Figures**
- `outputs/linear_model_Temperature-Elevation.png`
- `outputs/boxplot_Land_Cover-Temperature.png`
- `outputs/linear_model_Temperature-Elevation-Land_Cover.png`
- `outputs/boxplot_Land_Cover-Temperature-Elevation.png`

**NOTES:**
- The project uses CHELSA mean annual temperature (bio01d), which represents near-surface temperature patterns. Since it's at maximum 2m above the surface, we'll use it to track the land surface temperature.
- Results depend on the choice of the grid resolution (here 1 km²) and the threshold used for defining a dominant land-cover class ( here > 50%).
- Climate rasters represent gridded temperature fields at their native resolution; local microclimates are not resolved. Interpretation should also consider dataset limitations and resolution.
- Land cover (CLC) is simplified into macro-categories, finer CLC classes may reveal additional patterns.

### 1) Temperature vs Elevation relationship

**Figure:** `outputs/linear_model_Temperature-Elevation.png`

First of all we wanted to study if the mean annual temperature is associated with elevation across Austria. This plot shows a strong negative relationship between **mean annual temperature** and **elevation** across the 1 km² grid cells.  
The regression line summarizes the average decrease in temperature with altitude. 

[lo aggiungo?] In this products the **Pearson test** reports correlation strength and a p-value. A significant result indicates that temperature and elevation are linearly associated. The **linear model** `temp ~ dgm` estimates the expected temperature change per unit elevation (slope). A **negative slope** is consistent with the typical decrease of temperature with altitude.

An exaple of what you can expect, is shown below. In particular, we can see that:
- The dense diagonal band indicates that elevation is a dominant driver of temperature at this spatial scale
- The vertical scatter around the line reflects other influences (regional climate gradients, aspect, local effects, dataset resolution, ...)

[<img src="outputs/linear_model_Temperature-Elevation.png" width="450">](outputs/linear_model_Temperature-Elevation.png)

This first analisy provides a baseline for our work, showing that elevation alone explains an important fraction of temperature variability.


### 2) Dominant land cover classes and temperature differences

**Figure:** `outputs/boxplot_Land_Cover-Temperature.png`  
**Tables:** `outputs/tables/stats_t_lc.csv`, `outputs/tables/games_howell.csv`

Each grid cell is assigned a **dominant land-cover macro-category** when one category covers **> 50%** of the cell (as we can see in `1-data-analysis.r`). The analysis focuses on the three most informative dominant categories:
- Artificial
- Agricultural
- Semi-natural
This boxplot compares the temperature distributions across dominant categories.

An exaple of what you can expect, is shown below. In particular, we can see that:
- Medians and spreads show how temperature varies by dominant cover
- Outliers are expected because the grid spans wide elevation ranges and climates
- Categories such as Wetlands/Water are exluded since we are studing the land-cover (?????)

[<img src="outputs/boxplot_Land_Cover-Temperature.png" alt="Land cover vs Temperature (boxplot)" width="450">](outputs/boxplot_Land_Cover-Temperature.png)

[Da tenere?] The table contained in `stats_t_lc.csv` shows descriptive statistics (mean, sd, min/max, etc.) of `temp` by dominant cover. Welch ANOVA tests whether mean temperatures differ across dominant classes (Welch is used because it is robust to unequal variances). If Welch ANOVA is significant, Games–Howell identifies *which pairs* differ (e.g., Artificial vs Semi-natural), while remaining robust to unequal variances and sample sizes.


### 3) Improving predictions by studying how dominant land cover classes relate to temperature differences

**Figure:** `outputs/linear_model_Temperature-Elevation-Land_Cover.png`  
**Report:** `outputs/model_report.txt` (Model comparison section)

The next step tests whether land cover adds explanatory power beyond elevation. Here we fit two models on cells belonging to the three main dominant categories (Artificial, Agricultural, Semi-natural):
- Baseline model: `temp ~ dgm`
- Extended model: `temp ~ dgm + dominant_cover` (Semi-natural as reference)

The plot shows predicted temperature–elevation lines **by land cover** from the extended model (slopes are parallel because no interaction is included).

An exaple of what you can expect, is shown below. In particular, we can see that:
- If the colored lines differ vertically at the same elevation, it suggests a land-cover-related offset **after controlling for elevation**.
- The formal evidence comes from:
  - nested-model ANOVA (`anova(lm_te, lm_telc)`) tests whether the extended model significantly improves fit compared to the baseline
  - AIC (`AIC(lm_te, lm_telc)`) compares models balancing fit and complexity: a lower AIC suggests a better tradeoff. Coefficients for `dominant_cover` quantify the expected temperature offset associated with a given dominant cover after controlling for elevation.
  - In some land-cover classes (especially Artificial), observations may exist mainly at low elevations, so lines shown at high elevations can be extrapolations. Interpret offsets within the elevation range where each class has data.

[<img src="outputs/linear_model_Temperature-Elevation-Land_Cover.png" alt="Model predictions by land cover" width="450">](outputs/linear_model_Temperature-Elevation-Land_Cover.png)


### 4) Land cover differences within elevation bands

**Figure:** `outputs/boxplot_Land_Cover-Temperature-Elevation.png`

In the end, we wanted to know if temperature differences between dominant land-cover classes are similar across different elevation ranges.
This plot stratifies the data into elevation bands (every 500 m) and compares temperature across land-cover categories **within each band**. It helps assess whether land-cover differences are consistent at low vs high elevations, or whether they mainly reflect elevation distribution differences.

An exaple of what you can expect, is shown below. In particular, we can see that:
- If differences between land-cover classes persist within the same elevation band, that supports an association not explained only by elevation.
- At high elevation bands, some land-cover categories may be absent (e.g., very few Artificial cells), so conclusions are limited by sample size.

[<img src="outputs/boxplot_Land_Cover-Temperature-Elevation.png" alt="Temperature by land cover within elevation bands" width="450">](outputs/boxplot_Land_Cover-Temperature-Elevation.png)


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
  linear_model_Temperature-Elevation.jpeg
  boxplot_Land_Cover-Temperature.jpeg
  linear_model_Temperature-Elevation-Land_Cover.jpeg
  boxplot_Land_Cover-Temperature-Elevation.jpeg

```

---

*[1] EPSG:3035 (ETRS89 / LAEA Europe) is a projected CRS (specific Geographic Coordinate Reference System) widely used for pan-European environmental analysis, particularly for statistical analysis and environmental monitoring, because it uses the Lambert Azimuthal Equal-Area projection (LAEA) to accurately represent areas across the continent. It's based on the European Terrestrial Reference System 1989 (ETRS89) datum and is centered around 52°N, 10°E, providing true-to-scale area representation for pan-European data.*
