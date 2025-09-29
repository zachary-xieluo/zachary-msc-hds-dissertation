## Project Structure

```
zachary-msc-hds-dissertation/
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
│ ├─ 1_eda/                         # Initially uploaded on 10 Sep
│ │
│ ├─ 2_cal_pop_growth_11_to_21/     # Updated on 16 Sep
│ │ ├─ 1_mapping_sa2/               # See here: Mapping SA2 from 2011 to 2021
│ │ ├─ 2_cal_pop_nsw_2011/          # See here: Calculating population growth
│ │ └─ 3_cal_pop_growth_nsw/
│ │ ├─ 4_cal_pop_growth_wslhd/          
│ │ └─ 5_cal_pop_growth_metro/      
│ │ 
│ ├─ 3_cultural_diversity           # Updated on 16 Sep
│ 
└─ 5_scroller_intro/                # Updated on 29 Sep     
│ │ 
│ ├─ data/                          # Processed data that is used for developing scrollytelling
│ ├─ images/                        # Images that are loaded in scrollytelling
│ ├─ create_map.qmd                 # Scripts to create map images
│ ├─ create_pop_figure.qmd          # Scripts to create the figures for population size
│ ├─ index.qmd                      # Scripts to develop scrollytelling format
│ ├─ index.html                     # Scrollytelling presentation

```
