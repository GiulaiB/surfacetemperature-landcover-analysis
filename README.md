# Austria Surface Temperature - Land Cover analysis

This repository provides a reproducible R workflow to explore how **surface temperature** relates to **elevation** and **land cover** across Austria. In particular, this repository uses CHELSA, Corine Land Cover (CLC) and Digital terrain Model (DGM) open source data to build a **1 km² grid over Austria** and run a small set of statistical analyses to explore relationships between:
- **mean annual temperature** (`temp`; CHELSA bio01d, year 2018),
- **elevation** (`dgm`; Digital terrain model Austria),
- **land cover composition** (`clc`; Corine Land Cover, year 2018).

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing script and a `functions.r` file.  
A brief description of all parts is given in the next paragraph. In addition, if you use `RStudio`, an RStudio project file called `software-project.Rproj` is included to ensure the scripts run correctly.

---


## Requirements

### Software
- **R** (recent version recommended)
- **RStudio**

### R packages
Used across scripts: tidyverse, sf, terra, exactextractr, rnaturalearth, broom, rstatix, yaml, testthat, beepr (optional “done” sound).

To install:
```r
install.packages(c(
  "tidyverse", "sf", "terra", "exactextractr", "rnaturalearth",
  "broom", "rstatix", "yaml", "testthat", "beepr"
))
```


## Setup

This repository does **not** include the raw input datasets (since they are large), so you need to create the local folder structure and place the downloaded files where the scripts expect them.

### 1) Create these folders

In the project root, create:
  - `data/` (raw inputs + generated `clean_data.gpkg`)
  - `outputs/` (saved plots)


### 2) Download the datasets

The pipeline expects **three rasters** in `data/`:

- **Corine Land Cover (CLC) 2018**  
   - file: `data/U2018_CLC2018_V2020_20u1.tif`  
   - type: categorical raster (integer codes)

- **CHELSA bio01d (2018)**  
   - file: `data/CHELSA_EUR11_obs_bio01d_2018_V.2.1.nc`  
   - type: NetCDF raster, stored as 10 Kelvin in the raw product

- **Digital Terrain Model (DGM) Austria**  
   - file: `data/dhm_at_lamb_10m_2018.tif`  
   - type: continuous raster (elevation)

The datasets are listed in `DOWNLOAD_INSTRUCTIONS.md`. See the file for the official download pages and licensing. After downloading, place them inside the `data/` folder.


### 3) Input file configuration (`data_sources.yml`)

The pipeline reads `data_sources.yml` to locate the input rasters using filename patterns for each dataset (CLC, CHELSA, DGM).  This makes the workflow easier to reproduce across machines without hard-coded local paths.  
The default file names already work. If you pattern differs, update the file `data_sources.yml` (no need to edit the scripts).


## How to run

Open the RStudio project (`software-project.Rproj`) so the working directory is the project root. Then, run scripts in order:
- `0-data_preparation.r` creates a file with ready-to-use data called `data/clean_data.gpkg`,
- `1-data_analysis.r` reads `data/clean_data.gpkg` and then runs statistics and model comparisons,
- `2-plots.r` produces and saves figures into `outputs/` folder.


## Project workflow/ Brief scripts description


### 0) Data preparation (`0-data_preparation.r`)

Main steps:
- reads `data_sources.yml` and configures the three inputs (CLC, CHELSA temperature, DGM)
- reprojects rasters to **EPSG:3035 (ETRS89 / LAEA Europe)**,
- clips all rasters to the Austria polygon (from Natural Earth),
- creates a **1 km² grid** and clips it to Austria borders,
- extracts per-cell:
  - area-weighted mean **temperature** (`temp`),
  - area-weighted mean **elevation** (`dgm`),
  - land-cover macro-category composition (%) from CLC codes: `perc_artificial`, `perc_agricultural`, `perc_forest_semi`, `perc_wetlands`, & `perc_water`.

The output is saved as:  
`data/clean_data.gpkg` (created locally in your `data/` folder).

>**Note:**
- Reprojecting large rasters to EPSG:3035 can be slow and memory-intensive. Make sure you have enough space and patience!
- EPSG:3035 (ETRS89 / LAEA Europe) is a projected CRS (specific Geographic Coordinate Reference System) widely used for pan-European environmental analysis, particularly for statistical analysis and environmental monitoring, because it uses the Lambert Azimuthal Equal-Area projection (LAEA) to accurately represent areas across the continent. It's based on the European Terrestrial Reference System 1989 (ETRS89) datum and is centered around 52°N, 10°E, providing true-to-scale area representation for pan-European data.

### 1) Data analysis (`1-data_analysis.r`)

Main steps:
- loads `data/clean_data.gpkg` and drops geometry for tabular analyses,
- **Pearson correlation**: `cor.test(temp, dgm)` between temperature and elevation,
- **linear model**: `lm(temp ~ dgm)`,
- assigns a **dominant land cover** class when a macro-category cover is > 50%,
- focuses analyses on the three dominant classes with enough data: Artificial, Agricultural, Seminatural,
- **tests** temperature differences across land-cover categories using:
  - Welch’s ANOVA (robust to unequal variances / sample sizes),
  - Games–Howell post-hoc comparisons,
- **fits** and **compares**:
  - baseline model: `temp ~ dgm`,
  - extended model: `temp ~ dgm + dominant_cover` (with Seminatural as reference level),
  - nested-model F-test + AIC comparison


### 2) Plots (`2-plots.r`)

Creates and saves the following figures in `outputs/`:
- Scatter plot Temperature vs Elevation + regression line (`linear_model_Temperature-Elevation.png`),
- Boxplot Temperature by dominant Land Cover category (`boxplot_Land_Cover-Temperature.png`)
- Scatter plot Temperature vs Elevation and Land Cover (`linear_model_Temperature-Elevation-Land_Cover.png`),
- Boxplot Temperature by dominant Land Cover category by Elevation ranges (`boxplot_Land_Cover-Temperature-Elevation.png`).


### 3) Functions (`functions.r`)

The file defines two functions used in the previous codes:

*`area_weighted_mean(values, coverage_fraction)`*
- checks that `values` and `coverage_fraction` have the same length,
- keeps only valid pairs (finite value + finite weight + weight > 0),
- computes the coverage-fraction-weighted mean: `sum(values * weight) / sum(weight)`.

*`clc_cover_df(values, coverage_fraction)`*
- builds a small data frame of CLC codes (`values`) and weights (`coverage_fraction`),
- drops NA codes, returns a one-row NA result if no valid pixels or total weight is 0,
-	sums weighted cover for CLC macro-categories by code ranges: artificial (1–11), agricultural (12–22), semi-natural (23–34), wetlands (35–39), water (40–44), no-data (48),
-	returns a one-row `data.frame` with the percentage of each macro-category in the polygon for every grid cell.


### Testing (`testing.r`)

The file contains `testthat` checks for the key reusable pieces of the workflow. In particular:
- defines a function (`expect_ext_equal_tol`) to compare spatial extents with a numeric tolerance,
- tests the extraction helpers in `functions.r`:
  - `area_weighted_mean()` (correct weighted mean, robustness to invalid values, and error on length mismatch),
  - `clc_cover_df()` (correct percentages attribution, NA handling, macro-categories sum to 100, zero-weight handling),
- tests key outputs of the project by checking the `dominant_cover` (threshold > 50% and unique maximum) and the reference level (Seminatural if present, otherwise the most frequent class).



## Repository structure

Files (in the repository):
```txt
0-data_preparation.r
1-data_analysis.r
2-plots.r
functions.r
testing.r
data_sources.yml
DOWNLOAD_INSTRUCTIONS.md
README.md
software-project.Rproj
```

Local folders (created by the user):
```txt
data/
  (raw inputs: CLC, CHELSA, DGM)
  clean_data.gpkg

outputs/
  linear_model_Temperature-Elevation.png
  boxplot_Land_Cover-Temperature.png
  linear_model_Temperature-Elevation-Land_Cover.png
  boxplot_Land_Cover-Temperature-Elevation.png

```

## Outputs

After running the full pipeline, you will find different files created:
- a clean dataset (`data/clean_data.gpkg`) that is a 1 km² grid over Austria with extracted variables (`temp`, `dgm`, `clc` % composition),
- figures that are listed below (saved in `outputs/` folders).


### 1) Temperature vs Elevation relationship

[<img src="outputs/linear_model_Temperature-Elevation.png" width="450">](outputs/linear_model_Temperature-Elevation.png)

**File:** `outputs/linear_model_Temperature-Elevation.png`

This scatter plot shows the relationship between **elevation** (x-axis, meters) and **mean annual temperature** (y-axis, °C) for all 1 km grid cells,  
Each dot represents one grid cell and the blue line is the fitted linear regression (`temp ~ dgm`).

Observations:
- The points form a very **narrow diagonal band**, indicating a strong and almost linear **decrease of temperature with elevation** at this spatial scale,
- The **vertical spread** around the line reflects influences not included in the model (regional gradients, local topography aspect, and important limitations due to dataset resolution),

This plot is mainly a **baseline** and shows how much structure is already explained by elevation before introducing land cover.


### 2) Dominant land cover classes and temperature differences

[<img src="outputs/boxplot_Land_Cover-Temperature.png" alt="Land cover vs Temperature (boxplot)" width="450">](outputs/boxplot_Land_Cover-Temperature.png)

**File:** `outputs/boxplot_Land_Cover-Temperature.png`  

The boxplot compares the **temperature distribution across dominant categories**.  
Each grid cell is assigned a dominant land-cover macro-category when one category covers > 50% of the cell. Two things to know:
- The **median line** in each box gives the typical temperature for that land-cover class.
- The **box height** captures variability within the middle 50% of cells, whereas whiskers and dots show more extreme values and "outliers".

Observations:
- Seminatural cells show a **much lower** median and a wider spread than Agricultural/Artificial,
- Agricultural and Artificial have **relatively high medians** and **tighter boxes**,
- differencies between land-cover categories can be effects of the land cover themselves and/or derive from different elevation distributions across classes (e.g., seminatural occurring more often at higher altitude).


### 3) Improving predictions by studying the relation between land cover classes and temperature

[<img src="outputs/linear_model_Temperature-Elevation-Land_Cover.png" alt="Model predictions by land cover" width="450">](outputs/linear_model_Temperature-Elevation-Land_Cover.png)

**File:** `outputs/linear_model_Temperature-Elevation-Land_Cover.png`

This figure focuses on the three main dominant classes with sufficient amount of data: **Seminatural**, **Agricultural**, **Artificial**.  
Each dot represents one grid cell and the colored line is the fitted model prediction from:
- baseline: `temp ~ dgm`
- extended: `temp ~ dgm + dominant_cover` (Seminatural as reference)

Observations:
- differences between classes appear as a **vertical shift** (different intercepts) at the same elevation,
- the model is **additive**, so the **slope with elevation is the same** for all classes, and the differencies between classes appear as vertical shifts of the regression lines,
- if one line tends to sit above another at comparable elevations, it suggests a systematic offset associated with that land cover after controlling for elevation.


### 4) Land cover differences within elevation bands

[<img src="outputs/boxplot_Land_Cover-Temperature-Elevation.png" alt="Temperature by land cover within elevation bands" width="450">](outputs/boxplot_Land_Cover-Temperature-Elevation.png)

**File:** `outputs/boxplot_Land_Cover-Temperature-Elevation.png`

This plot stratifies the data into **500 m elevation bands** (facets) and comparing land-cover categories **within each band**.

Observations:
- as elevation increases (as showed in the first linear model) the temperature distributions **shift downward** (as expected),
- Seminatural category is **consistently colder** than the other two categories when all three occour,
- at mid/high elevations, some classes disappear (e.g., Agricultural becomes rare/absent), and Seminatural dominates the remaining bands,



## Conclusion

Overall, the results confirm that elevation is the dominant driver of mean annual temperature at 1 km resolution in Austria, and they also suggest that dominant land-cover classes are associated with systematic temperature differences. While part of the land-cover signal reflects the different elevation ranges where each class occurs, the additive modelling and the elevation-band comparison indicate that land cover contributes additionally, even if the contribute is less important than the elevation one:

- **Elevation is the main driver of temperature at 1 km scale:** the Temperature–Elevation scatter shows a very strong, clean negative relationship, confirming that the pipeline captures the expected climatic gradient across Austria.

- **Dominant land-cover classes capture meaningful spatial structure:** the boxplots show systematic temperature differences among dominant categories (Seminatural vs Agricultural/Artificial), consistent with how these covers are distributed across the Austrian landscape.

- **Land cover adds explanatory power beyond elevation:** in the additive model (`temp ~ dgm + dominant_cover`), the predicted lines show vertical offsets between classes, showing land-cover associated differences after controlling for elevation.


## Limitations

- **Grid resolution dependence:** results depend on the choice of the grid resolution (here 1 km²) and the threshold used for defining a dominant land-cover class ( here > 50%),

- **Uneven class coverage across elevation:** Agricultural/Artificial cells are concentrated at low elevations, so predictions at high elevations are effectively extrapolations.  

- **Macro-categories simplification:** land cover (CLC) is simplified into macro-categories, finer CLC classes may reveal additional patterns.

Despite these limitations, the analysis provides a consistent baseline and a clear framework for extending the model.
