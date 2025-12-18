# Plot from '1-data_analysis.R' file
source("1-data_analysis.R") # file with the analyses



##### Scatter plot + regression line T ∝ Elevation #####

# First linear model between Temperature and Elevation
plot_lm1 <- ggplot(df_lm, aes(x = dgm, y = temp)) +
  geom_point(shape = 20, size = 0.25, alpha = 0.25, col = "black") +              # points
  geom_smooth(method = "lm", se = TRUE) + # regression line + Confidence Interval
  labs(
    x = "Elevation (m)",
    y = "Mean annual Temperature (°C)",
    title = "Linear relationship: T ∝ Elevation"
  ) +
  theme_bw()

plot_lm1

ggsave("outputs/linear_model_Temperature-Elevation.png", plot = plot_lm1, dpi = 300, width = 5, height = 6)



##### Box-plot of temperature by dominant cover #####

boxplot1 <- ggplot(df_dom, aes(x = dominant_cover, y = temp)) +
  geom_boxplot() +
  labs(
    x = "Dominant Land Cover category",
    y = "Mean annual Temperature (°C)",
    title = "Box-plot: Land Cover - Temperature") +
  theme_bw()

boxplot1

ggsave("outputs/boxplot_Land_Cover-Temperature.png", plot = boxplot1, dpi = 300, width = 6, height = 5)



