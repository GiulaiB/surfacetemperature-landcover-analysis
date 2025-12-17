# Austria Surface Temperature vs Land Cover (CHELSA + CLC) — 1 km grid analysis in R

This repository uses CHELSEA, Corine Land Cover (clc) and Digital terrain model (dgm) open source data to build a **1 km² grid over Austria**, downscale multiple raster layers to the grid (area-weighted), and run a small set of statistical analyses to explore relationships between:

- **Mean annual temperature** (CHELSA bio01d, year 2018)
- **Temperature seasonality** (CHELSA bio04d, year 2018)
- **Elevation** (dgm)
- **Land cover composition** (clc 2018, aggregated into macro-categories)

The workflow is split into three scripts: **data preparation → analyses → plots**, plus a testing script.

---

## Project workflow

### 0) Data preparation (`0-data_manipulation.R`)
- Loads and reprojects all rasters to **EPSG:3035 (ETRS89 / LAEA Europe)** *[1]*.
- Clips rasters to **Austria** (Natural Earth borders).
- Creates a **1 km² grid**, clipped to the Austria boundary.
- Computes, for each grid cell:
  - area-weighted mean **temperature**
  - area-weighted mean **temperature seasonality**
  - area-weighted mean **elevation**
  - % cover of CLC macro-categories: Artificial, Agricultural, Forest/Seminatural, Wetlands, Water and No Data

Outputs are saved to:
- `data/new_version_data/grid_all.rds`
- `data/new_version_data/grid_all.gpkg`

---

### 1) Analyses (`1-data_analyses.R`)
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

---

### 2) Plots (`2-plots.R`)
The outputs can be also seen in the plots. The file `2-plots.R` produces:
- Scatter plot: Elevation vs Temperature (+ regression line)
- Boxplot: Temperature by dominant land-cover category

The plots are saved and can be found into:
- 

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
