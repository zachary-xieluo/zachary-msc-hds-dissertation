library(readr)
library(dplyr)
library(sf)
library(strayr)
library(leaflet)
library(htmltools)
library(scales)

# --- Read population data  -----
pop_wslhd_comp <- read.csv("data/pop_size_nsw_compare.csv") %>%
  filter(in_wslhd_2021 == 1)

geo_nsw_2021 <- read_csv("data/sa2_lga_lhd_nsw_2021.csv", show_col_types = FALSE)

# --- Read SA2 & LGA maps -----------------------------------------------
sa2_map_2021 <- read_absmap("sa22021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  filter(!grepl("Lord Howe Island", sa2_name_2021, ignore.case = TRUE)) %>%
  st_make_valid()

lga_map_2021 <- read_absmap("lga2021") %>%
  filter(state_name_2021 == "New South Wales") %>%
  st_make_valid()

# Attach LGA names to SA2-level population dataset
pop_wslhd_comp <- pop_wslhd_comp %>%
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

# --- Filter to valid SA2s and keep original pop + growth_rate ----------
pop_wslhd_comp <- pop_wslhd_comp %>%
  filter(!sa2_name_2021 %in% exclude_sa2) %>%
  mutate(
    pop2011_as21 = round(pop2011_as21)
  )

# --- Join to SA2 geometry (All ages, SA2-level) ------------------------
map_pop_growth <- sa2_map_2021 %>%
  inner_join(pop_wslhd_comp, by = "sa2_name_2021") %>%
  st_transform(4326)

map_lga_wslhd_2021 <- lga_map_2021 %>%
  filter(lga_name_2021 %in% wslhd_lgas) %>%
  st_transform(st_crs(map_pop_growth))

# --- Palette for growth rate -------------------------------------------
pal_growth_main <- colorNumeric(
  palette = "Blues",
  domain  = c(0, 1)
)

# Special colours
col_neg <- "#bdbdbd"  # <0%
col_gt1 <- "#d34549"  # >100%

caption_html <- '<div style="background:white; padding:6px 10px; font-size:12px;">
  Note: No colour areas in WSLHD represent non-residential zones.
</div>'

# --- Build Leaflet map for Population Growth (All ages, SA2-level) -----
make_pop_growth_map <- function() {
  dat <- map_pop_growth %>%
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
        2021 population: %s<br/>
        2011 population: %s<br/>
        Population change: %s<br/><br/>
        <strong>Growth rate: %s</strong>",
        sa2_name_2021,
        lga_name_2021,
        comma(pop_2021),
        comma(pop2011_as21),
        comma(
          pop_2021 - pop2011_as21, accuracy = 1,
          prefix = ifelse(pop_2021 - pop2011_as21 > 0, "+", "")
        ),
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
      data   = map_lga_wslhd_2021,
      color  = "#111827",
      weight = 2, opacity = 1, fillOpacity = 0
    ) %>%
    # <0 and >1
    addLegend(
      position = "bottomright",
      colors   = c(col_neg, col_gt1),
      labels   = c("<0%", ">100%"),
      title    = "",
      opacity  = 0.9
    ) %>%
    # 0–1
    addLegend(
      position = "bottomright",
      pal      = pal_growth_main,
      values   = c(0, 1),
      title    = "Growth rate",
      labFormat = labelFormat(
        transform = function(x) x * 100,
        suffix    = "%"
      ),
      opacity = 0.9
    ) %>%
    addControl(
      html = caption_html,
      position = "bottomleft"
    )
}

map_pop_growth_leaflet <- make_pop_growth_map()

# --- Wrap as a single 'sheet' called Population Growth -----------------
viz_pop_growth <- tagList(
  tags$div(
    id    = "pop-growth-container",
    style = "position: relative; width: 100%; max-width: 1200px; margin: 0 auto;",
    
    # Top button bar
    tags$div(
      style = "display: flex; justify-content: flex-end; flex-wrap: wrap; 
               gap: 8px; margin-bottom: 10px;",
      tags$button(
        id    = "btn-pop-growth",
        class = "age-view-toggle",
        style = "padding: 6px 14px; border: 2px solid #4279b0; border-radius: 6px;
                 background: #4279b0; color: white; cursor: default; font-weight: 600;
                 transition: all 0.3s;",
        "📈 Population Growth"
      )
    ),
    
    # Map container
    tags$div(
      style = "width: 100%; height: 650px;",
      map_pop_growth_leaflet
    )
  )
)

viz_pop_growth