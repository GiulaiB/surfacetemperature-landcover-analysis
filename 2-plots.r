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



##### Scatter plot + regression line T ∝ Elevation + Land Cover#####

# Second linear model between Temperature, Elevation, and Land Cover
# Creation of the regression line of the model for every Land Cover category (all parallel)
pred_grid <- tidyr::expand_grid(
  dgm = seq(min(df_lc3$dgm, na.rm = TRUE),
            max(df_lc3$dgm, na.rm = TRUE),
            length.out = 200),
  dominant_cover = levels(df_lc3$dominant_cover)
) %>%
  mutate(
    dominant_cover = factor(dominant_cover, levels = levels(df_lc3$dominant_cover)),
    pred_temp = predict(lm_telc, newdata = pick(dgm, dominant_cover))
  ) %>%
  arrange(dominant_cover, dgm)

# Plot
plot_lm2 <- ggplot() +
  geom_point(
    data = df_lc3,
    aes(x = dgm, y = temp),
    colour = "black", alpha = 0.25, shape = 20, size = 0.25
  ) +
  geom_line(
    data = pred_grid, linewidth = 1,
    aes(x = dgm, y = pred_temp, colour = dominant_cover)
  ) +
  facet_wrap(~ dominant_cover) +
  labs(
    x = "Elevation (m)",
    y = "Mean annual temperature (°C)",
    title = "Linear relationship: T ∝ Elevation + Land Cover",
    colour = "Land cover"
  ) +
  theme_bw() +
  theme(legend.position = "none")

plot_lm2

ggsave("outputs/linear_model_Temperature-Elevation-Land_Cover.png", 
       plot = plot_lm2, dpi = 300, width = 15, height = 6)



##### Box-plots: Temperature by Land Cover within each elevation range #####

min(df_lm$dgm) # min cell elevation m
max(df_lm$dgm) # max cell elevation m

# Elevation breaks every 500 m starting from the min elevation (100 m), until the max
elev_breaks <- seq(100, max(df_lm$dgm) + 500, by = 500)

# Add the elevation ranges at the dataframe
df_lc3 <- df_lc3 %>%
  mutate(
    elev_group = cut(
      dgm,
      breaks = elev_breaks,
      include.lowest = TRUE,
      right = FALSE
    )
  )

# Build the plot from df_lc3
boxplot2 <- ggplot(df_lc3, aes(x = dominant_cover, y = temp)) +
  geom_boxplot() +
  facet_wrap(~ elev_group) +
  labs(
    x = "Dominant Land Cover category",
    y = "Mean annual Temperature (°C)",
    title = "Box-plot: Land Cover - Temperature within elevation bands") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

boxplot2

ggsave("outputs/boxplot_Land_Cover-Temperature-Elevation.png",
       plot = boxplot2, dpi = 300, width = 6, height = 5)