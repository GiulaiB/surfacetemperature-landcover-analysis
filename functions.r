##### First function: Area-weighted mean #####

# 'area_weighted_mean' computes an area-weighted mean of raster values extracted under a polygon
# Designed to be passed as the summary function (FUN) to exactextractr::exact_extract()
# 
# PARAMETERS:
#   - 'values' = raster pixel values intersecting the polygon
#   - 'coverage_fraction' = per-pixel area fraction inside the polygon (0..1)
# 
# RETURN:
#   - sum(values * weights) / sum(weights), or NA if nothing is valid 

area_weighted_mean <- function(values, coverage_fraction) {
  
  # Input validation
  # exactextractr should provide vectors of identical length
  if (length(values) != length(coverage_fraction)) {
    stop(
      "Length mismatch between values (", length(values),
      ") and coverage_fraction (", length(coverage_fraction),
      ")."
    )
  }
  
  # Keep only valid pairs (value, weight)
  ok <- is.finite(values) & is.finite(coverage_fraction) & coverage_fraction > 0
  if (!any(ok)) return(NA_real_)
  
  v <- values[ok]
  w <- coverage_fraction[ok] # coverage_fraction is the proportion of each pixel inside the grid cell (0-1)
  
  # Weighted mean
  sw <- sum(w)
  if (sw == 0) return(NA_real_)
  
  sum(v * w) / sw
}



##### Second function: Corine Land Cover (CLC) macro-category composition per polygon #####

# 'clc_cover_df' computes the percentage cover of CLC macro-categories within one polygon
#using cell coverage fractions as weights
# Designed for use with exactextractr::exact_extract(clc_codes, polygons, clc_cover_df)
# 
# Categories of Corile Land Cover (CLC codes):
#   - Artificial surfaces:   1  – 11
#   - Agricultural areas:    12 – 22
#   - Forest & semi-natural: 23 – 34
#   - Wetlands:              35 – 39
#   - Water bodies:          40 – 44
#   - No Data:               48
#   
# PARAMETERS:
#   - 'values' = raster pixel values of Corine Land Cover inside each grid cell
#   - 'coverage_fraction' = per-pixel area fraction inside the cell (0..1)
# 
# RETURN:
#   - one-row data.frame with 6 percentage columns

clc_cover_df <- function(values, coverage_fraction) {
  df <- data.frame(code = values, w = coverage_fraction)
  
  # Drop NA and "No Data" category (48) - from the manual of Corine Land Cover
  df <- df %>%
    filter(!is.na(code))
  
  # If no valid pixels, return NA row
  if (nrow(df) == 0) {
    return(data.frame(perc_artificial   = NA_real_, perc_agricultural = NA_real_,
                      perc_forest_semi  = NA_real_, perc_wetlands     = NA_real_,
                      perc_water        = NA_real_, perc_no_data      = NA_real_))
  }
  
  # Total cover weight. If it is 0, return NA
  total_w <- sum(df$w)
  if (total_w == 0) {
    return(data.frame(perc_artificial   = NA_real_, perc_agricultural = NA_real_,
                      perc_forest_semi  = NA_real_, perc_wetlands     = NA_real_,
                      perc_water        = NA_real_, perc_no_data      = NA_real_))
  }
  
  # Grouping Land Cover values into macro-categories (from the manual of Corine Land Cover)
  # Still using the weights
  art_w <- sum(df$w[df$code >=  1 & df$code <= 11])
  agr_w <- sum(df$w[df$code >= 12 & df$code <= 22])
  for_w <- sum(df$w[df$code >= 23 & df$code <= 34])
  wet_w <- sum(df$w[df$code >= 35 & df$code <= 39])
  wat_w <- sum(df$w[df$code >= 40 & df$code <= 44])
  nod_w <- sum(df$w[df$code == 48]) # no data
  
  # Conversion from weights to percentages for each grid cell
  data.frame(perc_artificial   = art_w / total_w * 100,
             perc_agricultural = agr_w / total_w * 100,
             perc_forest_semi  = for_w / total_w * 100,
             perc_wetlands     = wet_w / total_w * 100,
             perc_water        = wat_w / total_w * 100,
             perc_no_data      = nod_w / total_w * 100)
}