library(readr)    
library(dplyr)     
library(sf)         
library(strayr) 
library(biscale)  
library(scales) 
library(leaflet)  
library(plotly)    
library(htmltools)
# =========================
# 1) Read & join data
# =========================

# Input tables (produced in your preprocessing step)
cen_nsw_2021  <- read_csv("data/cencus_nsw_2021.csv", show_col_types = FALSE)
geo_nsw_2021  <- read_csv("data/sa2_lga_lhd_nsw_2021.csv", show_col_types = FALSE)
irsd_nsw_2021 <- read_csv("data/irsd_nsw_2021.csv",  show_col_types = FALSE)

# SA2 map (NSW only) — remove offshore; ensure validity
sa2_map_2021 <- read_absmap("sa22021") |>
  filter(state_name_2021 == "New South Wales") |>
  filter(!grepl("Lord Howe Island", sa2_name_2021, ignore.case = TRUE)) |>
  st_make_valid()

# LGA map (NSW only)
lga_map_2021 <- read_absmap("lga2021") |>
  filter(state_name_2021 == "New South Wales") |>
  st_make_valid()

# Join IRSD + geography keys to census slice
cen_nsw_2021 <- cen_nsw_2021 |>
  left_join(geo_nsw_2021,  by = "sa2_name_2021") |>
  left_join(irsd_nsw_2021, by = "sa2_name_2021")

# WSLHD subset
sem_wslhd_2021 <- cen_nsw_2021 |> filter(in_wslhd == 1)

# =========================
# 2) Health burden index
# =========================

top4 <- c("prop_arthritis", "prop_asthma", "prop_diabetes", "prop_mental_health")

heal_burden <- sem_wslhd_2021 |>
  mutate(across(all_of(top4), as.numeric)) |>
  # z-score per condition (higher z = worse)
  mutate(across(all_of(top4), ~ as.numeric(scale(.x)), .names = "{.col}_z")) |>
  # mean z across the four conditions (higher = worse)
  mutate(burden_zmean = rowMeans(across(ends_with("_z")), na.rm = TRUE)) |>
  # 0–100 index (higher = worse)
  mutate(
    health_burden_0_100      = rescale(burden_zmean, to = c(0, 100)),
    health_burden_decile     = ntile(health_burden_0_100, 10),
    health_burden_percentile = round(percent_rank(health_burden_0_100) * 100, 0)
  )

# Remove known non-residential SA2s
exclude_sa2 <- c("Prospect Reservoir", "Smithfield Industrial",
                 "Yennora Industrial", "Rookwood Cemetery")

# LGA focus for WSLHD
wslhd_lgas <- c("Blacktown","Parramatta","Cumberland","The Hills Shire")

# Join health burden onto SA2 map (WSLHD subset)
map_heal_burden_wslhd <- sa2_map_2021 |>
  inner_join(heal_burden |> filter(!sa2_name_2021 %in% exclude_sa2),
             by = "sa2_name_2021")

# LGA boundaries (same CRS as SA2 map)
map_lga_wslhd_2021 <- lga_map_2021 |>
  filter(lga_name_2021 %in% wslhd_lgas) |>
  st_transform(st_crs(map_heal_burden_wslhd))

# =========================
# 3) Bivariate classes for map
# =========================

biv_sem_health <- map_heal_burden_wslhd |>
  transmute(
    sa2_name_2021, lga_name_2021, pop_size,
    prop_arthritis, prop_asthma, prop_diabetes, prop_mental_health,
    geometry,
    irsd_percentile,
    health_burden_percentile,
    # reverse IRSD percentile so higher = more deprived
    deprivation_percentile = 100 - irsd_percentile
  ) |>
  bi_class(
    x = deprivation_percentile,
    y = health_burden_percentile,
    style = "quantile", dim = 3
  )

# WGS84 for Leaflet
biv_df_wgs84              <- st_transform(biv_sem_health, 4326)
map_lga_wslhd_2021_wgs84  <- st_transform(map_lga_wslhd_2021, 4326)

# 3×3 palette (bivariate)
pal9 <- c(
  "1-1"="#d3d3d3","2-1"="#ba8890","3-1"="#9e3547",
  "1-2"="#8aa6c2","2-2"="#7a6b84","3-2"="#682a41",
  "1-3"="#4279b0","2-3"="#3a4e78","3-3"="#311e3b"
)

# Fill color per SA2 (NA → white to match caption)
biv_df_wgs84$fill_color <- ifelse(
  is.na(biv_df_wgs84$bi_class), "#ffffff",
  pal9[as.character(biv_df_wgs84$bi_class)]
)

# Popup (compact)
biv_df_wgs84 <- biv_df_wgs84 |>
  mutate(
    popup_content = sprintf(
      "<strong>%s</strong><br/>
       LGA: %s<br/>
       Population: %s<br/><br/>
       
       <strong>Health condition proportions:</strong><br/>
       Arthritis: %.1f%% | Asthma: %.1f%%<br/>
       Diabetes: %.1f%% | Mental: %.1f%%<br/><br/>
       
       <strong>Deprivation percentile group: %d</strong><br/>
       <small>1st is least deprived and 100th is most deprived</small><br/>
       <small><em>Derived by reversing IRSD percentile</em></small><br/><br/>
       
       <strong>Health burden percentile group: %d</strong><br/>
       <small>1st is best and 100th is worst</small><br/>
       <small><em>Includes the top 4 health conditions</em></small>",
      
      sa2_name_2021, lga_name_2021, format(pop_size, big.mark = ","),
      prop_arthritis * 100, prop_asthma * 100,
      prop_diabetes * 100, prop_mental_health * 100,
      deprivation_percentile, health_burden_percentile
    )
  )

# Legend + caption
legend_html <- '
<div style="padding:10px;">
  <div style="display:flex;align-items:center;gap:8px;">
    <!-- Y-axis label on the left, pointing up -->
    
    <div style="writing-mode:vertical-rl; transform:rotate(180deg); text-align:center; font-size:10px;">
      Health burden (L→H) 
    </div>

    <!-- 3x3 color grid (top row = high Y; left->right = low→high X) -->
    <table style="border-collapse:collapse;">
      <tr>
        <td style="width:30px;height:30px;background-color:#4279b0;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#3a4e78;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#311e3b;border:1px solid white;"></td>
      </tr>
      <tr>
        <td style="width:30px;height:30px;background-color:#8aa6c2;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#7a6b84;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#682a41;border:1px solid white;"></td>
      </tr>
      <tr>
        <td style="width:30px;height:30px;background-color:#d3d3d3;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#ba8890;border:1px solid white;"></td>
        <td style="width:30px;height:30px;background-color:#9e3547;border:1px solid white;"></td>
      </tr>
      <tr>
        <td colspan="3" style="text-align:center;padding-top:5px; font-size:10px;">
          Deprived (L→H) 
        </td>
      </tr>
    </table>
  </div>
</div>
'

caption_html <- '<div style="background:white; padding:6px 10px; font-size:12px;">
  Note: No colour areas in WSLHD represent non-residentials
</div>'

# =========================
# 4) Leaflet map widget
# =========================
map_widget <- leaflet(biv_df_wgs84, width = "100%", height = "650px") |>
  addProviderTiles("CartoDB.Positron") |>
  addPolygons(
    fillColor = ~fill_color, fillOpacity = 0.7,
    color = "white", weight = 0.5,
    popup = ~popup_content,
    highlightOptions = highlightOptions(weight = 2, color = "#111827",
                                        fillOpacity = 0.9, bringToFront = TRUE),
    label = ~sa2_name_2021,
    labelOptions = labelOptions(
      style = list("font-weight"="normal", padding="3px 8px"),
      textsize = "12px", direction = "auto")
  ) |>
  addPolylines(
    data = map_lga_wslhd_2021_wgs84,
    color = "#111827", weight = 2, opacity = 1, fillOpacity = 0
  ) |>
  addControl(html = legend_html,  position = "bottomright") |>
  addControl(html = caption_html, position = "bottomleft")

# =========================
# 5) Plotly bubble scatter
# =========================
scatter_data <- biv_sem_health |>
  st_drop_geometry() |>
  transmute(
    sa2_name_2021, lga_name_2021,
    deprivation_percentile   = as.numeric(deprivation_percentile),
    health_burden_percentile = as.numeric(health_burden_percentile),
    pop_size = as.numeric(pop_size),
    bi_class = as.character(bi_class),
    prop_arthritis, prop_asthma, prop_diabetes, prop_mental_health
  ) |>
  filter(is.finite(deprivation_percentile),
         is.finite(health_burden_percentile),
         is.finite(pop_size))

# color + size
col_vec <- pal9[scatter_data$bi_class]; col_vec[is.na(col_vec)] <- "#bdbdbd"
size_px <- rescale(scatter_data$pop_size, to = c(20, 60))

# hover text (plain HTML)
hover_txt <- paste0(
  "<b>", scatter_data$sa2_name_2021, "</b><br>",
  "LGA: ", scatter_data$lga_name_2021, "<br>",
  "Population: ", comma(scatter_data$pop_size), 
  
  "<br><br>",
  
  "Health condition proportions:<br>",
  "Arthritis: ", percent(scatter_data$prop_arthritis, 0.1), " | ",
  "Asthma: ",   percent(scatter_data$prop_asthma,   0.1), " | ",
  "Diabetes: ", percent(scatter_data$prop_diabetes, 0.1), " | ",
  "Mental health: ", percent(scatter_data$prop_mental_health, 0.1), 
  
  "<br><br>",
  
  "Deprivation percentile group: ", round(scatter_data$deprivation_percentile), 
  "<br>1st least deprived → 100th most deprived",
  "<br>Deprivation percentile is derived by reversing the IRSD percentile<br><br>",
  
  "Health burden percentile group: ", round(scatter_data$health_burden_percentile), 
  "<br>1st best → 100th worst",
  "<br>Health burden includes the top 4 health conditions"
)

scatter_widget <- plot_ly(
  type = "scatter", mode = "markers",
  x = scatter_data$deprivation_percentile,
  y = scatter_data$health_burden_percentile,
  text = hover_txt, hovertemplate = "%{text}<extra></extra>",
  marker = list(size = size_px, color = col_vec,
                line = list(color = "white", width = 0.6),
                opacity = 0.85),
  showlegend = FALSE, height = 650
) |>
  layout(
    xaxis = list(title = "Deprivation Percentile", zeroline = FALSE, range = c(-5, 105)),
    yaxis = list(title = "Health Burden Percentile", zeroline = FALSE, range = c(-5, 105)),
    hovermode = "closest",
    hoverlabel = list(align = "left"),
    plot_bgcolor = "#ffffff", paper_bgcolor = "#ffffff",
    margin = list(l = 10, r = 10, t = 10, b = 10),
    autosize = TRUE
  ) |>
  config(displayModeBar = FALSE)

# =========================
# 6) Simple view switch (Map ↔ Scatter)
# =========================
visualization <- tagList(
  tags$div(
    id    = "viz-container",
    style = "position: relative; width: 100%; max-width: 1200px; margin: 0 auto;",
    # buttons
    tags$div(
      style = "display:flex; justify-content:flex-end; margin-bottom:10px; gap:10px;",
      tags$button(
        id = "btn-show-map",
        onclick = "toggleView('map')",
        style = "padding:8px 16px; border:2px solid #4279b0; border-radius:6px;
                 background:#4279b0; color:#fff; cursor:pointer; font-weight:600;",
        "📍 Map View"
      ),
      tags$button(
        id = "btn-show-scatter",
        onclick = "toggleView('scatter')",
        style = "padding:8px 16px; border:2px solid #4279b0; border-radius:6px;
                 background:#fff; color:#4279b0; cursor:pointer; font-weight:600;",
        "📊 Scatter View"
      )
    ),
    # containers
    tags$div(id = "map-view",
             style = "display:block; opacity:1; transition:opacity .5s;",
             map_widget),
    tags$div(id = "scatter-view",
             style = "display:none; opacity:0; transition:opacity .5s;",
             scatter_widget),
    # toggle script
    tags$script(HTML("
      function toggleView(view){
        const mapView = document.getElementById('map-view');
        const scView  = document.getElementById('scatter-view');
        const bMap    = document.getElementById('btn-show-map');
        const bSc     = document.getElementById('btn-show-scatter');

        if(view === 'map'){
          scView.style.opacity = '0';
          setTimeout(()=>{ scView.style.display='none'; mapView.style.display='block';
                           setTimeout(()=>{ mapView.style.opacity='1'; }, 50); }, 500);
          bMap.style.background='#4279b0'; bMap.style.color='#fff';
          bSc.style.background='#fff';     bSc.style.color='#4279b0';
        }else{
          mapView.style.opacity='0';
          setTimeout(()=>{ mapView.style.display='none'; scView.style.display='block';
                           setTimeout(()=>{ scView.style.opacity='1'; }, 50); }, 500);
          bSc.style.background='#4279b0'; bSc.style.color='#fff';
          bMap.style.background='#fff';    bMap.style.color='#4279b0';
        }
      }
    "))
  )
)

# Render
visualization