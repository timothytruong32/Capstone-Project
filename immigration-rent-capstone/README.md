# Immigration Flows and Rental Housing Costs: Evidence from U.S. Metropolitan Areas

Economics capstone project (ECON 490, California State University, Fullerton, Spring 2026) by Timothy Truong.

This project tests whether U.S. metropolitan areas with higher rates of foreign-born arrivals from abroad (2010-2014) experienced faster real rent growth (2014-2019), and whether that relationship differs across Census regions and divisions. The analysis covers 332 metropolitan statistical areas (MSAs) using OLS regressions with region, division, and state fixed effects and HC1 heteroskedasticity-robust standard errors.

## Repository structure

```
immigration-rent-capstone/
├── immigration-rent-capstone.Rproj
├── README.md
├── data/        <- place the four NHGIS CSV files here (see below)
├── code/
│   └── capstone_analysis.R
└── output/      <- figures are saved here
```

## Getting the data

The data come from IPUMS NHGIS. Downloads are free but require an account. Each extract takes about 10 minutes to set up.

### Step 1: Create an account

Register at https://www.nhgis.org and sign in.

### Step 2: Start a new extract

Click "Get Data" to open the data finder.

### Step 3: Set the filters

| Filter | Selection |
|---|---|
| Geographic level | Core Based Statistical Area (CBSA), shown as Metropolitan/Micropolitan Statistical Area |
| Years | 2010-2014 and 2015-2019 |
| Dataset | American Community Survey 5-year data (see table below) |

### Step 4: Select these tables

NHGIS splits each ACS 5-year release into several datasets. The tables below come from two of them per period: "a" (Block Groups & Larger Areas) and "b" (Tracts & Larger Areas).

| Census table | Description | 2010-2014 dataset | 2015-2019 dataset |
|---|---|---|---|
| B01003 | Total population | 2010_2014_ACS5a | 2015_2019_ACS5a |
| B19013 | Median household income | 2010_2014_ACS5a | not needed |
| B23025 | Employment status (labor force, unemployed) | 2010_2014_ACS5a | 2015_2019_ACS5a |
| B25003 | Tenure (renter-occupied units) | 2010_2014_ACS5a | not needed |
| B25004 | Vacancy status (vacant for rent) | 2010_2014_ACS5a | not needed |
| B25064 | Median gross rent | 2010_2014_ACS5a | 2015_2019_ACS5a |
| B07007 | Geographical mobility by citizenship status | 2010_2014_ACS5b | 2015_2019_ACS5b |

Add each table to your data cart. If a table appears in more than one dataset, choose the one listed above so the variable codes match the script.

### Step 5: Choose the file format

At checkout:

- Choose comma-delimited (CSV) format.
- Leave "Include additional descriptive header row" unchecked. The script expects a single header row.
- Either "estimates only" or "estimates and margins of error" works. The script selects columns by name.

Submit the extract. NHGIS will email you when it is ready (usually within minutes).

### Step 6: Rename and move the files

The download is a ZIP file containing one CSV per dataset. NHGIS names files using your personal extract number (for example, `nhgis0012_ds206_20145_cbsa.csv`). Remove the extract number so the files match the script. For example, `nhgis0012_ds206_20145_cbsa.csv` becomes `nhgis_ds206_20145_cbsa.csv`:

| Dataset | Required file name |
|---|---|
| 2010_2014_ACS5a | `nhgis_ds206_20145_cbsa.csv` |
| 2010_2014_ACS5b | `nhgis_ds207_20145_cbsa.csv` |
| 2015_2019_ACS5a | `nhgis_ds244_20195_cbsa.csv` |
| 2015_2019_ACS5b | `nhgis_ds245_20195_cbsa.csv` |

Place all four files in the `data/` folder.

The ZIP also contains a codebook (.txt) for each dataset. These list every NHGIS variable code (for example, `ABA1E001` = total population, 2010-2014) and are useful for checking the column names used in the script.

## Running the analysis

1. Install the required packages:

   ```r
   install.packages(c("tidyverse", "estimatr", "patchwork", "here"))
   ```

2. Open `immigration-rent-capstone.Rproj` in RStudio.
3. Run `code/capstone_analysis.R`.

The script prints data checks and regression results to the console and saves figures to `output/`. If any data file is missing, the script stops with a message pointing back to this README.

## Data citation

Schroeder, Jonathan, David Van Riper, Steven Manson, Katherine Knowles, Tracy Kugler, Finn Roberts, and Steven Ruggles. 2025. IPUMS National Historical Geographic Information System: Version 20.0 [dataset]. Minneapolis, MN: IPUMS. http://doi.org/10.18128/D050.V20.0

Datasets used (U.S. Census Bureau, American Community Survey 5-Year Summary Files, accessed through IPUMS NHGIS):

| NHGIS dataset | NHGIS code | Coverage |
|---|---|---|
| 2010_2014_ACS5a | ds206 | 2010-2014 ACS 5-year, Block Groups & Larger Areas |
| 2010_2014_ACS5b | ds207 | 2010-2014 ACS 5-year, Tracts & Larger Areas |
| 2015_2019_ACS5a | ds244 | 2015-2019 ACS 5-year, Block Groups & Larger Areas |
| 2015_2019_ACS5b | ds245 | 2015-2019 ACS 5-year, Tracts & Larger Areas |

CPI-U values (2014 = 236.7, 2019 = 255.7) are from the U.S. Bureau of Labor Statistics, https://www.bls.gov/cpi/.