## Project Structure

```
zachary-msc-hds-dissertation/
│ 
├─ 1_data_preprocess/
│ ├─ 1_variable_data/               # Raw & processed census variable data
│ │ ├─ 1_demographics/
│ │ ├─ 2_socioeconomics/
│ │ └─ 3_health_conditions/
│ └─ 2_geography_data/              # SA2 → LGA → LHD mapping tables
│ 
├─ 2_calculate_pop_size/
│ ├─ 1_nsw/
│ ├─ 2_wslhd/
│ └─ 3_nsw_metropolitan_lhds/
│ 
├─ 3_collapse_variables/            # Collapse to counts & proportions
│ ├─ 1_demographics/
│ ├─ 2_socioeconomics/
│ ├─ 3_health_conditions/
│ └─ 4_merge/                       # Final integration → census_nsw_2021
│ 
└─ 4_eda/                     
│ ├─ 1_initial/                     # Initial EDA
│ │
│ ├─ 2_cal_pop_growth_11_to_21/     # Updated on 16 Sep
│ │ ├─ 1_mapping_sa2/               # See here: Mapping SA2 from 2011 to 2021
│ │ ├─ 2_cal_pop_nsw_2011/          # See here: Calculating population growth
│ │ └─ 3_cal_pop_growth_nsw/
│ │ ├─ 4_cal_pop_growth_wslhd/          
│ │ └─ 5_cal_pop_growth_metro/      
│ │ 
│ ├─ 3_cultural_diversity           # Deep dive into cultural diversity
│ │ 
│ ├─ 4_age_structure                # Compute changes from 2011 to 2021 by 4 age groups 
│ 
└─ 5_scroller_analysis/             # Final runnable folder (updated on 3 Nov)
│ │
│ ├─ _extensions/                   # Quarto extensions
│ │
│ ├─ assets/                        # All front-end resources for scrollytelling
│ │  ├─ main.js                     # JavaScript to enable scroll-triggered effects & interactions
│ │  ├─ scripts.html                # Embedded HTML scripts (libraries, triggers, or custom tags)
│ │  └─ styles.css                  # Custom CSS styles for layout, typography, and visual design
│ │
│ ├─ data/                          # Processed datasets used to generate figures, charts, or maps
│ │                                 # (Clean and ready-to-use data)
│ │
│ ├─ images/                        # Static images loaded in the scrollytelling story (e.g. charts, maps, icons)
│ │
│ ├─ R/                             # R scripts for creating images  (maps, plots, interactive elements) to scroller
│ │
│ ├─ index.qmd                      # Main Quarto source file: Develop the narrative and embeds visualisations
│ ├─ index.html                     # Rendered scrollytelling website (output from index.qmd)

```

## Note

1) `1_data_preprocess`, `2_calculate_pop_size`, `3_collapse_variables`, `4_eda`  
   These folders document the data-processing and exploration workflow (cleaning, transformation, feature preparation, EDA) used to prepare the scrollytelling project. 
   They are **not required** to run the final site and are provided mainly for reproducibility and checking.

2) To run the scrollytelling website locally, use **`5_scroller_analysis`** only.
