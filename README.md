## Project Structure

```
zachary-msc-hds-dissertation/
├─ 1_data_preprocess/
│ ├─ 1_variable_data/          # Raw & processed census variable data
│ │ ├─ 1_demographics/
│ │ ├─ 2_socioeconomics/
│ │ └─ 3_health_conditions/
│ └─ 2_geography_data/         # SA2 → LGA → LHD mapping tables
│ 
├─ 2_calculate_pop_size/
│ ├─ 1_nsw/
│ ├─ 2_wslhd/
│ └─ 3_nsw_metropolitan_lhds/
│ 
├─ 3_collapse_variables/      # Collapse to counts & proportions
│ ├─ 1_demographics/
│ ├─ 2_socioeconomics/
│ ├─ 3_health_conditions/
│ └─ 4_merge/                 # Final integration → census_nsw_2021
│ 
└─ 4_eda/                     # EDA based on census_nsw_2021
```