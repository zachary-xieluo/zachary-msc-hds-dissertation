library(dplyr)
library(readr)
library(sf)
library(strayr)
library(leaflet)
library(htmltools)
library(scales)

# ----------------------------------------------------------
# 1. Read datasets
# ----------------------------------------------------------
cd_wslhd_2021 <- read_csv("data/cd_nsw_2021.csv", show_col_types = FALSE) %>%
  filter(in_wslhd == 1)

geo_nsw_2021 <- read_csv("data/sa2_lga_lhd_nsw_2021.csv", show_col_types = FALSE)

cd_wslhd_2021 <- cd_wslhd_2021 %>%
  left_join(geo_nsw_2021, by = "sa2_name_2021")

sa2_map_2021 <- read_absmap("sa22021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  filter(!grepl("Lord Howe Island", sa2_name_2021, ignore.case = TRUE)) %>%
  st_make_valid()

lga_map_2021 <- read_absmap("lga2021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  st_make_valid()

# ----------------------------------------------------------
# 2. Clean names
# ----------------------------------------------------------
cd_wslhd_2021 <- cd_wslhd_2021 %>%
  rename(australia = australia_total)

# ----------------------------------------------------------
# 3. Compute Proportions
# ----------------------------------------------------------
cd_wslhd_2021 <- cd_wslhd_2021 %>%
  mutate(
    prop_australia       = australia/pop_size, 
    prop_overseas        = overseas/pop_size,
    prop_not_stated_cob  = not_stated_cob/pop_size,
    prop_english         = english / pop_size,
    prop_nonenglish      = non_english / pop_size,
    prop_not_stated_lang = not_stated_lang / pop_size
  )

# ----------------------------------------------------------
# 4. Load Maps
# ----------------------------------------------------------
exclude_sa2 <- c(
  "Prospect Reservoir",
  "Smithfield Industrial",
  "Yennora Industrial",
  "Rookwood Cemetery"
)

map_cd_wslhd_2021 <- sa2_map_2021 %>%
  filter(!sa2_name_2021 %in% exclude_sa2) %>% 
  inner_join(
    cd_wslhd_2021 %>% filter(!sa2_name_2021 %in% exclude_sa2),
    by = "sa2_name_2021"
  ) %>%
  st_transform(4326)

map_lga_wslhd <- lga_map_2021 %>%
  filter(lga_name_2021 %in% c("Blacktown","Parramatta","Cumberland","The Hills Shire")) %>%
  st_transform(st_crs(map_cd_wslhd_2021))

# ----------------------------------------------------------
# 5. Color Palettes
# ----------------------------------------------------------
pal_overseas <- colorNumeric(
  palette = "Blues",
  domain = c(0,1)
)

pal_nonenglish <- colorNumeric(
  palette = "Reds",
  domain = c(0,1)
)

# ----------------------------------------------------------
# 6. Popup Template
# ----------------------------------------------------------
popup_template <- function(df) {
  sprintf(
    "<strong>%s</strong><br/>
     LGA: %s<br/><br/>
     <strong>Country of Birth</strong><br/>
     Australia: %s (%s)<br/>
     Overseas: %s (%s)<br/>
     Not stated: %s (%s)<br/><br/>
     <strong>Language Used at Home</strong><br/>
     English: %s (%s)<br/>
     Non-English: %s (%s)<br/>
     Not stated: %s (%s)",
    df$sa2_name_2021,
    df$lga_name_2021,
    comma(df$australia),
    percent(df$prop_australia, accuracy = 0.1),
    comma(df$overseas),
    percent(df$prop_overseas, accuracy = 0.1),
    comma(df$not_stated_cob),
    percent(df$prop_not_stated_cob, accuracy = 0.1),
    comma(df$english),
    percent(df$prop_english, accuracy = 0.1),
    comma(df$non_english),
    percent(df$prop_nonenglish, accuracy = 0.1),
    comma(df$not_stated_lang),
    percent(df$prop_not_stated_lang, accuracy = 0.1)
  )
}

map_cd_wslhd_2021$popup_cd <- popup_template(map_cd_wslhd_2021)

# ----------------------------------------------------------
# 7. Build Two Leaflet Maps
# ----------------------------------------------------------
caption_html <- '<div style="background:white; padding:6px 10px; font-size:12px;">
  Note: No colour areas in WSLHD represent non-residential zones.
</div>'

map_birth <- leaflet(map_cd_wslhd_2021, width = "100%", height = "650px") %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(
    fillColor   = ~pal_overseas(prop_overseas),
    fillOpacity = 0.8,
    color       = "#111827",
    weight      = 0.5,
    popup       = ~popup_cd,
    highlightOptions = highlightOptions(
      weight = 2, color = "#111827", fillOpacity = 0.9, bringToFront = TRUE
    )
  ) %>%
  addPolylines(
    data  = map_lga_wslhd,
    color = "#111827", weight = 2, opacity = 1
  ) %>%
  addLegend(
    position = "bottomright",
    pal      = pal_overseas,
    values   = c(0,1),
    title    = "Overseas-born proportion",
    labFormat = labelFormat(
      transform = function(x) x * 100, 
      suffix    = "%"
    ),
    opacity  = 0.8
  ) %>%
  addControl(
    html = caption_html,
    position = "bottomleft"
  )

map_lang <- leaflet(map_cd_wslhd_2021, width = "100%", height = "650px") %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(
    fillColor   = ~pal_nonenglish(prop_nonenglish),
    fillOpacity = 0.8,
    color       = "#111827",
    weight      = 0.5,
    popup       = ~popup_cd,
    highlightOptions = highlightOptions(
      weight = 2, color = "#111827", fillOpacity = 0.9, bringToFront = TRUE
    )
  ) %>%
  addPolylines(
    data  = map_lga_wslhd,
    color = "#111827", weight = 2, opacity = 1
  ) %>%
  addLegend(
    position = "bottomright",
    pal      = pal_nonenglish,
    values   = c(0,1),
    title    = "Non-English proportion",
    labFormat = labelFormat(
      transform = function(x) x * 100,
      suffix    = "%"
    ),
    opacity  = 0.8
  ) %>%
  addControl(
    html = caption_html,
    position = "bottomleft"
  )

# ----------------------------------------------------------
# 8. Toggle container with fixed overlay
# ----------------------------------------------------------
viz_culture <- tagList(
  tags$div(
    id = "cd-container",
    style = "position: relative; width: 100%; max-width: 1200px; margin: 0 auto;",
    
    # Toggle buttons
    tags$div(
      style = "display: flex; justify-content: flex-end; margin-bottom: 10px; gap: 10px;",
      tags$button(
        id = "btn-cob", 
        class = "view-toggle",
        onclick = "toggleCD('birth')",
        style = "padding: 8px 16px; border: 2px solid #4279b0; border-radius: 6px; 
                 background: #4279b0; color: white; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "🌍 Country of Birth"
      ),
      tags$button(
        id = "btn-lang", 
        class = "view-toggle",
        onclick = "toggleCD('lang')",
        style = "padding: 8px 16px; border: 2px solid #9e3547; border-radius: 6px;
                 background: white; color: #9e3547; cursor: pointer; font-weight: 600;
                 transition: all 0.3s;",
        "🗣️ Language Used at Home"
      )
    ),
    
    # Map container wrapper
    tags$div(
      style = "position: relative; width: 100%; height: 650px;",
      
      # Map A: Country of Birth (initially visible)
      tags$div(
        id = "cd-birth-view", 
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 1; transition: opacity 0.5s ease-in-out;",
        map_birth
      ),
      
      # Map B: Language (initially hidden)
      tags$div(
        id = "cd-lang-view", 
        style = "position: absolute; top: 0; left: 0; width: 100%; height: 100%;
                 display: block; opacity: 0; pointer-events: none;
                 transition: opacity 0.5s ease-in-out;",
        map_lang
      )
    ),
    
    # JavaScript toggle
    tags$script(HTML("
      function toggleCD(view) {
        const birth = document.getElementById('cd-birth-view');
        const lang = document.getElementById('cd-lang-view');
        const btnA = document.getElementById('btn-cob');
        const btnB = document.getElementById('btn-lang');

        if (view === 'birth') {
          // Show Country of Birth
          birth.style.opacity = '1';
          birth.style.pointerEvents = 'auto';
          birth.style.zIndex = '10';
          
          // Hide Language
          lang.style.opacity = '0';
          lang.style.pointerEvents = 'none';
          lang.style.zIndex = '1';

          // Update button styles
          btnA.style.background = '#4279b0';
          btnA.style.color = 'white';
          btnB.style.background = 'white';
          btnB.style.color = '#9e3547';

        } else {
          // Hide Country of Birth
          birth.style.opacity = '0';
          birth.style.pointerEvents = 'none';
          birth.style.zIndex = '1';
          
          // Show Language
          lang.style.opacity = '1';
          lang.style.pointerEvents = 'auto';
          lang.style.zIndex = '10';

          // Update button styles
          btnA.style.background = 'white';
          btnA.style.color = '#4279b0';
          btnB.style.background = '#9e3547';
          btnB.style.color = 'white';
        }
      }
      
      // Hover effects
      document.querySelectorAll('#btn-cob, #btn-lang').forEach(btn => {
        btn.addEventListener('mouseenter', function() {
          if (this.style.background === 'white' || 
              this.style.background === 'rgb(255, 255, 255)') {
            this.style.background = '#f3f4f6';
          }
        });
        btn.addEventListener('mouseleave', function() {
          if (this.style.background === 'rgb(243, 244, 246)') {
            this.style.background = 'white';
          }
        });
      });
    "))
  )
)

viz_culture