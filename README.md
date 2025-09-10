Project Structure

├─ 1_data_preprocess/                   # Data preparation
│  ├─ 1_variable_data/                  # Raw and processed census variable data
│  │  ├─ 1_demographics/                
│  │  ├─ 2_socioeconomics/           
│  │  ├─ 3_health_conditions/        
│  │                
│  │
│  └─ 2_geography_data/                 # SA2 → LGA → LHD mapping tables
│
├─ 2_calculate_pop_size/                # Calculate population size
│  ├─ 1_nsw/
│  ├─ 2_wslhd/
│  ├─ 3_nsw_metropolitan_lhds/
│
├─ 3_collapse_variables/                # Collapse variables to counts & proportions based on processed data
│  ├─ 1_demographics/
│  ├─ 2_socioeconomics/
│  ├─ 3_health_conditions/
│  ├─ 4_merge/                          # Final integration → census_nsw_2021
│
├─ 4_eda/                               # EDA based on census_nsw_2021