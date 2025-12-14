# --- Libraries -------------------------------------------------------------
library(readr)
library(dplyr)
library(sf)
library(strayr)
library(leaflet)
library(htmltools)
library(scales)

# --- Read age-specific population data --------------------
pop_age_wslhd_comp <- read.csv("data/age_nsw_compare.csv") %>%
  filter(in_wslhd_2021 == 1)

geo_nsw_2021 <- read_csv("data/sa2_lga_lhd_nsw_2021.csv",show_col_types = FALSE)

# --- Read SA2 & LGA maps ------------------------------------
sa2_map_2021 <- read_absmap("sa22021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  filter(!grepl("Lord Howe Island", sa2_name_2021, ignore.case = TRUE)) %>%
  st_make_valid()

lga_map_2021 <- read_absmap("lga2021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  st_make_valid()

# Attach LGA names to age dataset
pop_age_wslhd_comp <- pop_age_wslhd_comp %>%
  left_join(
    geo_nsw_2021 %>% select(sa2_name_2021, lga_name_2021),
    by = "sa2_name_2021"
  )

# --- Exclude known non-residential SA2s --------------------------------
exclude_sa2 <- c(
  "Prospect Reservoir",
  "Smithfield Industrial",
  "Yennora Industrial",
  "Rookwood Cemetery"
)

# --- WSLHD LGAs ---------------------------------------------------------
wslhd_lgas <- c("Blacktown", "Parramatta", "Cumberland", "The Hills Shire")

# --- All ages growth (all ages combined) -------------------------------
pop_all_ages <- pop_age_wslhd_comp %>%
  filter(!sa2_name_2021 %in% exclude_sa2) %>%
  group_by(sa2_name_2021, lga_name_2021) %>%
  summarise(
    n2011_as21 = round(sum(n2011_as21, na.rm = TRUE)),  
    n_2021     = sum(n_2021,     na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    growth_rate = if_else(
      n2011_as21 > 0,
      (n_2021 - n2011_as21) / n2011_as21,
      NA_real_
    ),
    age_band = "All ages"
  )

# --- Age-specific growth ----------------------------------------------
pop_age_bands <- pop_age_wslhd_comp %>%
  filter(!sa2_name_2021 %in% exclude_sa2) %>%  
  mutate(
    age_band = case_when(
      age_group %in% c("0_9", "10_19") ~ "0–19",
      age_group %in% c("20_29", "30_39") ~ "20–39",
      age_group %in% c("40_49", "50_59") ~ "40–59",
      age_group %in% c("60_69", "70_79", "80_89", "90_99", "100_plus") ~
        "60+",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(age_band))

age_growth <- pop_age_bands %>%
  group_by(sa2_name_2021, lga_name_2021, age_band) %>%
  summarise(
    n2011_as21 = round(sum(n2011_as21, na.rm = TRUE)),
    n_2021     = sum(n_2021,     na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    growth_rate = if_else(
      n2011_as21 > 0,
      (n_2021 - n2011_as21) / n2011_as21,
      NA_real_
    )
  )

# Combine All ages + age-specific
age_growth_all <- bind_rows(pop_all_ages, age_growth)

# --- Join to SA2 geometry -----------------------------------------------
map_age_growth <- sa2_map_2021 %>%
  inner_join(age_growth_all, by = "sa2_name_2021") %>%
  st_transform(4326)

map_lga_wslhd_age_2021 <- lga_map_2021 %>%
  filter(lga_name_2021 %in% wslhd_lgas) %>%
  st_transform(st_crs(map_age_growth))

# --- Binned palette for growth rate -------------------------------------
pal_growth_main <- colorNumeric(
  palette = "Blues",
  domain  = c(0, 1)
)

# special color:
col_neg  <- "#bdbdbd"  # <0%
col_gt1  <- "#d34549"  # >100%

caption_html <- '<div style="background:white; padding:6px 10px; font-size:12px;">
  Note: No colour areas in WSLHD represent non-residential zones.
</div>'

# --- Helper: build one Leaflet map -------------------------------------
make_age_map <- function(age_band_label) {
  dat <- map_age_growth %>%
    filter(age_band == age_band_label) %>%
    mutate(
      fill_col = case_when(
        is.na(growth_rate) ~ NA_character_,
        growth_rate < 0    ~ col_neg,                                       # <0%
        growth_rate > 1    ~ col_gt1,                                       # >100%
        TRUE               ~ pal_growth_main(pmin(pmax(growth_rate, 0), 1)) # 0–1 
      )
    )
  
  leaflet(dat, width = "100%", height = "650px") %>%
    addProviderTiles("CartoDB.Positron") %>%
    addPolygons(
      fillColor   = ~fill_col,
      fillOpacity = 0.8,
      color       = "#111827",
      weight      = 0.5,
      popup       = ~sprintf(
        "<strong>%s</strong><br/>
        LGA: %s<br/><br/>
        Age group: %s<br/><br/>
        2021 population: %s<br/>
        2011 population: %s<br/>
        Population change: %s<br/><br/>
        <strong>Growth rate: %s</strong>",
        sa2_name_2021,
        lga_name_2021,
        age_band,
        comma(n_2021),
        comma(n2011_as21),
        comma(n_2021 - n2011_as21, accuracy = 1,
              prefix = ifelse(n_2021 - n2011_as21 > 0, "+", "")),
        percent(growth_rate, accuracy = 0.1)
      ),
      highlightOptions = highlightOptions(
        weight = 2, color = "#111827", fillOpacity = 0.9, bringToFront = TRUE
      ),
      label = ~sa2_name_2021,
      labelOptions = labelOptions(
        style    = list("font-weight"="normal", padding="3px 8px"),
        textsize = "12px",
        direction = "auto"
      )
    ) %>%
    addPolylines(
      data   = map_lga_wslhd_age_2021,
      color  = "#111827",
      weight = 2, opacity = 1, fillOpacity = 0
    ) %>%
    
    # <0 and > 1
    addLegend(
      position = "bottomright",
      colors   = c(col_neg, col_gt1),
      labels   = c("<0%", ">100%"),
      title    = "",
      opacity  = 0.9
    ) %>%
    
    # 0-1
    addLegend(
      position = "bottomright",
      pal      = pal_growth_main,
      values   = c(0, 1),
      title    = "Growth Rate",
      labFormat = labelFormat(
        transform = function(x) x * 100, 
        suffix    = "%"
      ),
      opacity  = 0.9
    ) %>%
    
    addControl(
      html = caption_html,
      position = "bottomleft"
    )
}


# --- Create maps ------------------------------------------------------
map_all_ages  <- make_age_map("All ages")
map_age_child <- make_age_map("0–19")
map_age_young <- make_age_map("20–39")
map_age_mid   <- make_age_map("40–59")
map_age_older <- make_age_map("60+")

# --- Toggle widget with buttons on the right --------------------------
viz_age_growth <- tagList(
  tags$div(
    id = "age-viz-container",
    style = "position: relative; width: 100%; max-width: 1200px; margin: 0 auto;",
    
    # Buttons on the right
    tags$div(
      style = "display: flex; justify-content: flex-end; flex-wrap: wrap; gap: 8px; margin-bottom: 10px;",
      tags$button(
        id = "btn-all-ages",
        class = "age-view-toggle",
        onclick = "showAgeView('All ages')",
        style = "padding: 6px 14px; border: 2px solid #084081; border-radius: 6px;
                 background: #084081; color: white; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "All Ages"
      ),
      tags$button(
        id = "btn-age-child",
        class = "age-view-toggle",
        onclick = "showAgeView('child')",
        style = "padding: 6px 14px; border: 2px solid #084081; border-radius: 6px;
                 background: white; color: #084081; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "0–19"
      ),
      tags$button(
        id = "btn-age-young",
        class = "age-view-toggle",
        onclick = "showAgeView('young')",
        style = "padding: 6px 14px; border: 2px solid #084081; border-radius: 6px;
                 background: white; color: #084081; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "20–39"
      ),
      tags$button(
        id = "btn-age-mid",
        class = "age-view-toggle",
        onclick = "showAgeView('mid')",
        style = "padding: 6px 14px; border: 2px solid #084081; border-radius: 6px;
                 background: white; color: #084081; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "40–59"
      ),
      tags$button(
        id = "btn-age-older",
        class = "age-view-toggle",
        onclick = "showAgeView('older')",
        style = "padding: 6px 14px; border: 2px solid #084081; border-radius: 6px;
                 background: white; color: #084081; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "60+"
      )
    ),
    
    # Map containers wrapper
    tags$div(
      style = "position: relative; width: 100%; height: 650px;",
      
      tags$div(
        id = "age-All ages-view",
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 1; transition: opacity 0.5s ease-in-out;",
        map_all_ages
      ),
      tags$div(
        id = "age-child-view",
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 0; pointer-events: none;
                 transition: opacity 0.5s ease-in-out;",
        map_age_child
      ),
      tags$div(
        id = "age-young-view",
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 0; pointer-events: none;
                 transition: opacity 0.5s ease-in-out;",
        map_age_young
      ),
      tags$div(
        id = "age-mid-view",
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 0; pointer-events: none;
                 transition: opacity 0.5s ease-in-out;",
        map_age_mid
      ),
      tags$div(
        id = "age-older-view",
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 0; pointer-events: none;
                 transition: opacity 0.5s ease-in-out;",
        map_age_older
      )
    ),
    
    # JavaScript
    tags$script(HTML("
      function showAgeView(view) {
        const views = ['All ages', 'child', 'young', 'mid', 'older'];
        
        views.forEach(function(v) {
          const panel = document.getElementById('age-' + v + '-view');
          const btn = document.getElementById('btn-age-' + v);
          
          if (v === view) {
            panel.style.opacity = '1';
            panel.style.pointerEvents = 'auto';
            panel.style.zIndex = '10';
            btn.style.background = '#084081';
            btn.style.color = 'white';
          } else {
            panel.style.opacity = '0';
            panel.style.pointerEvents = 'none';
            panel.style.zIndex = '1';
            btn.style.background = 'white';
            btn.style.color = '#084081';
          }
        });
      }
      
      document.querySelectorAll('.age-view-toggle').forEach(btn => {
        btn.addEventListener('mouseenter', function() {
          if (this.style.background === 'white' || 
              this.style.background === 'rgb(255, 255, 255)') {
            this.style.background = '#e6f2ff';
          }
        });
        btn.addEventListener('mouseleave', function() {
          if (this.style.background === 'rgb(230, 242, 255)') {
            this.style.background = 'white';
          }
        });
      });
    "))
  )
)

viz_age_growth