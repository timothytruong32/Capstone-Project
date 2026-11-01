# Immigration Flow & Rent Growth Analysis
# Data: IPUMS NHGIS ACS 5-Year Estimates (see README.md for download steps)
# Periods: 2010-2014 (baseline) and 2015-2019 (outcome)
# Unit of observation: Metropolitan Statistical Areas (MSAs)

library(here)
dir.create(here("output"), showWarnings = FALSE)
library(tidyverse)
library(estimatr)
library(patchwork)
library(stringr)


# STEP 1: Load all four files and keep only needed columns
# with names matching the codebook

data_files <- here("data", c(
  "nhgis_ds206_20145_cbsa.csv",
  "nhgis_ds207_20145_cbsa.csv",
  "nhgis_ds244_20195_cbsa.csv",
  "nhgis_ds245_20195_cbsa.csv"
))

if (!all(file.exists(data_files))) {
  stop("Missing data files. See README.md for download instructions.")
}

# Period 1 main: population, income, employment, vacancy,
# tenure, and rent (2010-2014)
# Codebook: nhgis_ds206_20145
p1_main <- read_csv(here("data", "nhgis_ds206_20145_cbsa.csv")) %>%
  select(
    msa_code          = CBSAA,       # MSA identifier (merge key)
    msa_name          = NAME_E,      # MSA name
    total_pop         = ABA1E001,    # B01003: Total population
    median_hh_income  = ABDPE001,    # B19013: Median household income (2014 dollars)
    civilian_lf       = ABGFE003,    # B23025: Civilian labor force
    unemployed        = ABGFE005,    # B23025: Unemployed
    renter_occupied   = ABGXE003,    # B25003: Renter-occupied housing units
    vacant_for_rent   = ABG7E002,    # B25004: Vacant housing units for rent
    median_gross_rent = ABIHE001     # B25064: Median gross rent (2014 dollars)
  )

# Period 1 mobility: geographical mobility by citizenship (2010-2014)
# Codebook: nhgis_ds207_20145
p1_mob <- read_csv(here("data", "nhgis_ds207_20145_cbsa.csv")) %>%
  select(
    msa_code                = CBSAA,       # MSA identifier (merge key)
    fb_moved_abroad         = ABNXE028,    # B07007: Foreign born moved from abroad
    native_moved_diff_state = ABNXE022     # B07007: Native born moved from different state
  )

# Period 2 main: population, employment, and rent (2015-2019)
# Includes 2019 unemployment variables for making unemp_rate_change
# Codebook: nhgis_ds244_20195
p2_main <- read_csv(here("data","nhgis_ds244_20195_cbsa.csv")) %>%
  select(
    msa_code          = CBSAA,       # MSA identifier (merge key)
    total_pop         = ALUBE001,    # B01003: Total population
    civilian_lf_2019  = ALY3E003,   # B23025: Civilian labor force 2019
    unemployed_2019   = ALY3E005,   # B23025: Unemployed 2019
    median_gross_rent = AL05E001     # B25064: Median gross rent (2019 dollars)
  )

# Period 2 mobility: geographical mobility by citizenship (2015-2019)
# Codebook: nhgis_ds245_20195
p2_mob <- read_csv(here("data","nhgis_ds245_20195_cbsa.csv")) %>%
  select(
    msa_code        = CBSAA,       # MSA identifier (merge key)
    fb_moved_abroad = AL7FE028     # B07007: Foreign born moved from abroad
  )

# STEP 2: CPI-U adjustment constants
# Source: BLS CPI-U annual averages
# Base year: 2019 (all dollar values expressed in 2019 dollars)
# Applied to 2010-2014 income and rent level controls only.
# rent_growth (% change) needs no CPI adjustment because
# the baseline rent is CPI-adjusted before dividing, so the
# resulting proportion is already expressed in real terms.

cpi_2014          <- 236.7
cpi_2019          <- 255.7
cpi_adjust_factor <- cpi_2019 / cpi_2014   # = 1.0803

# STEP 3: Geographic crosswalks
#
# Two crosswalks built from the state abbreviation extracted
# from each MSA name:
#
# (a) Census region crosswalk (4 groups):
#     Used in Stage 1a baseline and Stage 2b main interaction model.
#
# (b) Census division crosswalk (9 groups):
#     Used in Stage 1c and Stage 2c as a robustness check. 
#     Provides finer geographic granularity.
#
# Source: U.S. Census Bureau regional and division definitions


region_crosswalk <- tribble(
  ~state_abbr, ~census_region,
  # Northeast
  "CT", "Northeast", "ME", "Northeast", "MA", "Northeast",
  "NH", "Northeast", "NJ", "Northeast", "NY", "Northeast",
  "PA", "Northeast", "RI", "Northeast", "VT", "Northeast",
  # Midwest
  "IL", "Midwest", "IN", "Midwest", "IA", "Midwest",
  "KS", "Midwest", "MI", "Midwest", "MN", "Midwest",
  "MO", "Midwest", "NE", "Midwest", "ND", "Midwest",
  "OH", "Midwest", "SD", "Midwest", "WI", "Midwest",
  # South
  "AL", "South", "AR", "South", "DE", "South",
  "DC", "South", "FL", "South", "GA", "South",
  "KY", "South", "LA", "South", "MD", "South",
  "MS", "South", "NC", "South", "OK", "South",
  "SC", "South", "TN", "South", "TX", "South",
  "VA", "South", "WV", "South",
  # West
  "AK", "West", "AZ", "West", "CA", "West",
  "CO", "West", "HI", "West", "ID", "West",
  "MT", "West", "NV", "West", "NM", "West",
  "OR", "West", "UT", "West", "WA", "West",
  "WY", "West"
)

division_crosswalk <- tribble(
  ~state_abbr, ~census_division,
  # New England
  "CT", "New England", "ME", "New England", "MA", "New England",
  "NH", "New England", "RI", "New England", "VT", "New England",
  # Middle Atlantic
  "NJ", "Middle Atlantic", "NY", "Middle Atlantic", "PA", "Middle Atlantic",
  # East North Central
  "IL", "East North Central", "IN", "East North Central",
  "MI", "East North Central", "OH", "East North Central",
  "WI", "East North Central",
  # West North Central
  "IA", "West North Central", "KS", "West North Central",
  "MN", "West North Central", "MO", "West North Central",
  "NE", "West North Central", "ND", "West North Central",
  "SD", "West North Central",
  # South Atlantic
  "DE", "South Atlantic", "DC", "South Atlantic", "FL", "South Atlantic",
  "GA", "South Atlantic", "MD", "South Atlantic", "NC", "South Atlantic",
  "SC", "South Atlantic", "VA", "South Atlantic", "WV", "South Atlantic",
  # East South Central
  "AL", "East South Central", "KY", "East South Central",
  "MS", "East South Central", "TN", "East South Central",
  # West South Central
  "AR", "West South Central", "LA", "West South Central",
  "OK", "West South Central", "TX", "West South Central",
  # Mountain
  "AZ", "Mountain", "CO", "Mountain", "ID", "Mountain",
  "MT", "Mountain", "NV", "Mountain", "NM", "Mountain",
  "UT", "Mountain", "WY", "Mountain",
  # Pacific
  "AK", "Pacific", "CA", "Pacific", "HI", "Pacific",
  "OR", "Pacific", "WA", "Pacific"
)

# STEP 4: Build Period 1 (2010-2014) dataset
# Join mobility data, derive additional variables,
# apply CPI adjustment, express dollar controls in thousands,
# and attach all geographic identifiers

period1 <- p1_main %>%
  left_join(p1_mob, by = "msa_code") %>%
  mutate(
    # Unemployment rate: unemployed / civilian labor force
    unemp_rate              = unemployed / civilian_lf,
    
    # Immigration flow rate: foreign-born arrivals from abroad / total population
    # Captures average annual rate of new international arrivals (2010-2014)
    imm_flow_rate           = fb_moved_abroad / total_pop,
    
    # Domestic migration rate: native-born interstate migrants / total population
    # Controls for domestic population movement to isolate the international
    # immigration effect on rent growth
    domestic_migration_rate = native_moved_diff_state / total_pop,
    
    # Rental vacancy rate: vacant-for-rent units as a share of
    # total rental housing stock (vacant + renter-occupied).
    # A value of 0.05 means 5 out of every 100 rental
    # units are unoccupied and available.
    rental_vacancy_rate     = vacant_for_rent /
      (vacant_for_rent + renter_occupied),
    
    # CPI-adjusted rent in full 2019 dollars — used ONLY for constructing
    # rent_growth in Step 6. Kept separate from the thousands-scaled version
    # to avoid collinearity between the outcome and the regression control.
    median_gross_rent_2014_real = median_gross_rent * cpi_adjust_factor,
    
    # Dollar controls expressed in thousands of 2019 dollars.
    # Interpreted as the effect of a $1,000 increase.
    median_hh_income_real   = (median_hh_income * cpi_adjust_factor) / 1000,
    median_gross_rent_real  = (median_gross_rent * cpi_adjust_factor) / 1000,
    
    # Extract primary state abbreviation from MSA name.
    # Used for state FE in Stage 1b, region join, and division join.
    # e.g. "Abilene, TX Metro Area" -> "TX"
    state_abbr              = str_extract(msa_name, "(?<=, )[A-Z]{2}(?= )")
  ) %>%
  left_join(region_crosswalk,   by = "state_abbr") %>%
  left_join(division_crosswalk, by = "state_abbr")

# STEP 5: Build Period 2 (2015-2019) dataset
# Rename columns to distinguish from Period 1 before merging

period2 <- p2_main %>%
  rename(
    total_pop_2019         = total_pop,
    median_gross_rent_2019 = median_gross_rent
    # civilian_lf_2019 and unemployed_2019 retain their names
    # and are used in Step 6 to construct unemp_rate_change
  )

# STEP 6: Merge and construct final analysis dataset

merged <- period1 %>%
  inner_join(period2, by = "msa_code") %>%
  mutate(
    # Outcome: real % change in median gross rent 2014 -> 2019.
    # Uses median_gross_rent_2014_real (full 2019 dollars) as the
    # denominator — NOT the thousands-scaled regression control.
    # This prevents collinearity between the outcome and the control
    # that caused NaN standard errors in earlier specifications.
    rent_growth = (median_gross_rent_2019 - median_gross_rent_2014_real) /
      median_gross_rent_2014_real,
    
    # Control: overall population growth rate
    pop_growth  = (total_pop_2019 - total_pop) / total_pop,
    
    # Within-period unemployment change: captures local economic
    # trajectories during the 2014-2019 outcome window rather than
    # just the baseline level. A negative value indicates a metro
    # whose labor market improved during the period (consistent with
    # tech boom metros); a positive value indicates deterioration
    # (consistent with oil collapse and deindustrialization metros).
    # This partially addresses the omitted variable bias from
    # within-period economic shocks identified in the residuals analysis.
    unemp_rate_2019   = unemployed_2019 / civilian_lf_2019,
    unemp_rate_change = unemp_rate_2019 - unemp_rate
  ) %>%
  # Restrict to metropolitan statistical areas only (exclude micropolitan)
  filter(str_detect(msa_name, "Metro Area")) %>%
  # Drop rows with missing values on key variables
  drop_na(rent_growth, imm_flow_rate, domestic_migration_rate,
          rental_vacancy_rate, median_hh_income_real, unemp_rate,
          unemp_rate_change, pop_growth, median_gross_rent_real,
          state_abbr, census_region, census_division)

# STEP 7: Data checks. Run these to check data before any regression

cat("=== DATA CHECKS ===\n")
cat("Number of MSAs after cleaning:", nrow(merged), "\n\n")

cat("--- Census region distribution ---\n")
merged %>% count(census_region) %>% print()

cat("\n--- Census division distribution (sorted by count) ---\n")
merged %>% count(census_division) %>% arrange(n) %>% print()

cat("\n--- rent_growth ---\n")
print(summary(merged$rent_growth))

cat("\n--- imm_flow_rate ---\n")
print(summary(merged$imm_flow_rate))

cat("\n--- domestic_migration_rate ---\n")
print(summary(merged$domestic_migration_rate))

cat("\n--- rental_vacancy_rate (conventional: vacant / rental stock) ---\n")
print(summary(merged$rental_vacancy_rate))

cat("\n--- median_hh_income_real (thousands of 2019 dollars) ---\n")
print(summary(merged$median_hh_income_real))

cat("\n--- median_gross_rent_real (thousands of 2019 dollars) ---\n")
print(summary(merged$median_gross_rent_real))

cat("\n--- unemp_rate (baseline 2010-2014) ---\n")
print(summary(merged$unemp_rate))

cat("\n--- unemp_rate_change (2019 minus 2014 rate) ---\n")
print(summary(merged$unemp_rate_change))

cat("\n--- Missing value counts on key variables ---\n")
merged %>%
  select(rent_growth, imm_flow_rate, domestic_migration_rate,
         rental_vacancy_rate, pop_growth, median_gross_rent_real,
         median_hh_income_real, unemp_rate, unemp_rate_change,
         state_abbr, census_region, census_division) %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  print()

# STEP 7b: Stage 1 baseline — No geographic fixed effects
#
# Serves as the baseline comparison for the robustness table. 
# Shows the raw immigration-rent correlation after controlling 
# for demographics and economics variables
# but before absorbing any geographic variation.
# The difference between this coefficient and the region/division/
# state FE coefficients reveals how much of the immigration-rent
# correlation is explained by geographic confounding at each level.

model1_noFE <- lm_robust(
  rent_growth ~ imm_flow_rate + domestic_migration_rate +
    rental_vacancy_rate + pop_growth +
    median_gross_rent_real + median_hh_income_real +
    unemp_rate + unemp_rate_change,
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 1 BASELINE: NO GEOGRAPHIC FIXED EFFECTS ===\n")
summary(model1_noFE)

# STEP 8: Stage 1a — Baseline regression with Census region FE
#
# Outcome:       rent_growth (real % change in median gross rent,
#                2014-2019)
# Key regressor: imm_flow_rate (foreign-born arrivals from abroad
#                as share of MSA population, measured 2010-2014)
# Controls:      domestic_migration_rate, rental_vacancy_rate,
#                pop_growth, median_gross_rent_real (thousands),
#                median_hh_income_real (thousands), unemp_rate,
#                unemp_rate_change (within-period labor market
#                proxy control), Census region fixed effects (4 groups)
# SE type: HC1 heteroskedasticity-robust standard errors.
#   HC1 used in place of HC2 because states with a single MSA
#   produce leverage = 1, which causes HC2 division by zero.


model1a <- lm_robust(
  rent_growth ~ imm_flow_rate + domestic_migration_rate +
    rental_vacancy_rate + pop_growth +
    median_gross_rent_real + median_hh_income_real +
    unemp_rate + unemp_rate_change +
    factor(census_region),
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 1a: BASELINE REGRESSION — CENSUS REGION FE ===\n")
summary(model1a)

# STEP 9: Stage 1b — Baseline regression with state FE
#
# Identical specification to Stage 1a but replaces Census region
# dummies with state fixed effects (49 dummies, Alaska omitted
# as reference category). Absorbs all time-invariant state-level
# differences in housing regulation, zoning, and economic structure.
# Used as robustness check to confirm immigration coefficient is
# stable across geographic specifications.

model1b <- lm_robust(
  rent_growth ~ imm_flow_rate + domestic_migration_rate +
    rental_vacancy_rate + pop_growth +
    median_gross_rent_real + median_hh_income_real +
    unemp_rate + unemp_rate_change +
    factor(state_abbr),
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 1b: BASELINE REGRESSION — STATE FE ===\n")
summary(model1b)

# STEP 9b: Stage 1c — Baseline regression with division FE
#
# Identical specification to Stage 1a and 1b but uses Census
# division fixed effects (9 groups, 8 dummies with East North
# Central as reference category). Pairs with Stage 2c division
# interaction model. Confirms immigration coefficient is stable
# at the division level before interpreting division interactions.

model1c <- lm_robust(
  rent_growth ~ imm_flow_rate + domestic_migration_rate +
    rental_vacancy_rate + pop_growth +
    median_gross_rent_real + median_hh_income_real +
    unemp_rate + unemp_rate_change +
    factor(census_division),
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 1c: BASELINE REGRESSION — CENSUS DIVISION FE ===\n")
summary(model1c)

# STEP 10: Stage 2a — Residuals analysis
#
# Uses the state FE model (model1b) as the basis for residuals —
# the more precise geographic specification produces cleaner
# residuals by absorbing state-level confounders first.
# Over-performers: MSAs where rent grew faster than predicted.
# Under-performers: MSAs where rent grew slower than predicted.

merged <- merged %>%
  mutate(
    fitted   = fitted(model1b),
    residual = rent_growth - fitted
  )

cat("\n=== STAGE 2a: RESIDUALS ANALYSIS (based on state FE model) ===\n")

cat("\n--- Top 15 over-performers (rent grew faster than model predicts) ---\n")
merged %>%
  arrange(desc(residual)) %>%
  select(msa_name, rent_growth, fitted, residual) %>%
  mutate(across(where(is.numeric), ~round(., 4))) %>%
  head(15) %>%
  print()

cat("\n--- Bottom 15 under-performers (rent grew slower than model predicts) ---\n")
merged %>%
  arrange(residual) %>%
  select(msa_name, rent_growth, fitted, residual) %>%
  mutate(across(where(is.numeric), ~round(., 4))) %>%
  head(15) %>%
  print()

# STEP 11: Stage 2b — Region interaction regression (main)
#
# Tests whether the immigration flow - rent growth relationship
# differs across Census regions (Northeast, Midwest, South, West).
# Midwest is the reference category (alphabetically first).
# Produces 3 interaction terms — interpretable with 332 obs.
#
# Interpretation:
# - imm_flow_rate        = slope for Midwest metros only
# - imm_flow_rate:region = difference in slope vs Midwest
# - Total slope for region = imm_flow_rate + interaction term
#
# Note: State FE cannot be combined with region interactions
# because states are nested within regions, producing perfect
# multicollinearity. Region FE used as geographic control here.

model2 <- lm_robust(
  rent_growth ~ imm_flow_rate * factor(census_region) +
    domestic_migration_rate + rental_vacancy_rate +
    pop_growth + median_gross_rent_real +
    median_hh_income_real + unemp_rate + unemp_rate_change,
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 2b: REGION INTERACTION REGRESSION (main) ===\n")
summary(model2)

cat("\n--- Implied total immigration slope by region ---\n")
coefs2 <- coef(model2)
cat("Midwest (baseline): ",
    round(coefs2["imm_flow_rate"], 3), "\n")
cat("Northeast:          ",
    round(coefs2["imm_flow_rate"] +
            coefs2["imm_flow_rate:factor(census_region)Northeast"], 3), "\n")
cat("South:              ",
    round(coefs2["imm_flow_rate"] +
            coefs2["imm_flow_rate:factor(census_region)South"], 3), "\n")
cat("West:               ",
    round(coefs2["imm_flow_rate"] +
            coefs2["imm_flow_rate:factor(census_region)West"], 3), "\n")

# STEP 12: Stage 2c — Division interaction regression (robustness)
#
# Replaces Census region interactions with Census division
# interactions (9 divisions, 8 interaction terms).
# East North Central is the reference category.
#
# Purpose: deconstruct the significant South and West region
# effects from Stage 2b into constituent divisions. Identifies
# whether the South effect is driven by South Atlantic
# (FL, GA, NC, VA) vs West South Central (TX, LA, OK, AR)
# vs East South Central (AL, KY, MS, TN).
#
# IMPORTANT: Check division cell counts from Step 7 before
# interpreting. Divisions with fewer than 20 MSAs will have
# wide confidence intervals. Treat those results with caution.

model3 <- lm_robust(
  rent_growth ~ imm_flow_rate * factor(census_division) +
    domestic_migration_rate + rental_vacancy_rate +
    pop_growth + median_gross_rent_real +
    median_hh_income_real + unemp_rate + unemp_rate_change,
  data    = merged,
  se_type = "HC1"
)

cat("\n=== STAGE 2c: DIVISION INTERACTION REGRESSION (robustness) ===\n")
summary(model3)

cat("\n--- Implied total immigration slope by division ---\n")
coefs3     <- coef(model3)
base_slope <- coefs3["imm_flow_rate"]
divisions  <- c(
  "East North Central",
  "East South Central",
  "Middle Atlantic",
  "Mountain",
  "New England",
  "Pacific",
  "South Atlantic",
  "West North Central",
  "West South Central"
)

for (div in divisions) {
  int_name <- paste0("imm_flow_rate:factor(census_division)", div)
  if (int_name %in% names(coefs3)) {
    total <- base_slope + coefs3[int_name]
  } else {
    total <- base_slope   # reference category — no interaction term
  }
  cat(sprintf("%-30s %.3f\n", div, total))
}

# STEP 13: Division cell count check
#
# Flags any divisions with fewer than 20 MSAs to know
# which division-level interaction estimates to treat with
# caution when writing up Stage 2c results.

cat("\n=== DIVISION CELL COUNT CHECK ===\n")
merged %>%
  count(census_division) %>%
  arrange(n) %>%
  mutate(flag = ifelse(n < 20,
                       "** THIN — interpret with caution **",
                       "OK")) %>%
  print()


# Immigration flow rate and real rent growth across US metro areas

# Step 1: Residualize both variables on controls + region FE
resid_y <- residuals(lm(rent_growth ~ domestic_migration_rate +
                          rental_vacancy_rate + pop_growth +
                          median_gross_rent_real + median_hh_income_real +
                          unemp_rate + unemp_rate_change + factor(census_region),
                        data = merged))

resid_x <- residuals(lm(imm_flow_rate ~ domestic_migration_rate +
                          rental_vacancy_rate + pop_growth +
                          median_gross_rent_real + median_hh_income_real +
                          unemp_rate + unemp_rate_change + factor(census_region),
                        data = merged))

# Step 2: Add residualized variables to merged
merged <- merged %>%
  mutate(resid_y = resid_y,
         resid_x = resid_x)

# Step 3: Plot (Figure 1 in the paper)
scatter_plot <- ggplot(merged, aes(x = imm_flow_rate * 100,
                                   y = rent_growth * 100)) +
  geom_point(aes(color = census_region), alpha = 0.5, size = 1.8) +
  # Unconditional line
  geom_smooth(method = "lm", se = FALSE,
              color = "black", linewidth = 0.8,
              linetype = "dashed") +
  # Conditional line — shift residualized slope to pass through sample means
  geom_abline(intercept = mean(merged$rent_growth * 100) -
                coef(lm(resid_y ~ resid_x))[2] *
                mean(merged$imm_flow_rate * 100),
              slope     = coef(lm(resid_y ~ resid_x))[2],
              color     = "darkred", linewidth = 0.8) +
  scale_color_manual(values = c("Midwest"   = "#F8766D",
                                "Northeast" = "#7CAE00",
                                "South"     = "#00BFC4",
                                "West"      = "#C77CFF")) +
  annotate("text", x = 1.55, y = 16.5,
           label = "Unconditional",
           color = "black", hjust = 0, size = 3.2, fontface = "italic") +
  annotate("text", x = 1.55, y = 7,
           label = "Conditional (region FE\n+ controls)",
           color = "darkred", hjust = 0, size = 3.2, fontface = "italic") +
  labs(title = "Immigration flow rate and real rent growth across U.S. metro areas",
       x     = "Immigration flow rate (% of MSA population, 2010-2014)",
       y     = "Real rent growth (%, 2014-2019)",
       color = "Census region") +
  theme_minimal()

scatter_plot

ggsave(here("output", "scatter_immigration_rent.png"),
       plot   = scatter_plot,
       width  = 10,
       height = 7,
       dpi    = 300,
       bg     = "white")

# Overachievers and Underachievers Residuals Bar Chart

notes_wrapped_bar_plot <- str_wrap(
  "NOTE: Figure above displays the top 15 over-performing and bottom 15 
  under-performing metropolitan statistical areas (MSAs) ranked by their 
  regression residual from the state fixed effects model. Each bar represents 
  one MSA. Blue bars extending to the right indicate MSAs whose actual real
  rent growth exceeded the model's predicted value. Red bars extending
  to the left indicate MSAs whose actual real rent growth fell short of 
  the model's predicted value. Residuals are expressed in percentage points. 
  Data sourced from IPUMS NHGIS ACS 5-year estimates.",
  width = 120
)

top_bottom <- merged %>%
  arrange(desc(residual)) %>%
  slice(c(1:15, (n()-14):n())) %>%
  mutate(msa_short = str_extract(msa_name, "^[^,]+"),
         direction = ifelse(residual > 0,
                            "Over-performer", "Under-performer"))

residual_plot <- ggplot(top_bottom, aes(x = residual * 100,
                                        y = reorder(msa_short, residual),
                                        fill = direction)) +
  geom_col() +
  geom_vline(xintercept = 0, color = "black", linewidth = 0.5) +
  scale_fill_manual(values = c("Over-performer"  = "steelblue",
                               "Under-performer" = "firebrick")) +
  labs(title = "Top and bottom 15 MSAs by regression residual",
       x     = "Residual (percentage points)",
       y     = NULL, fill  = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")

residual_plot_with_notes <- residual_plot +
  plot_annotation(
    caption = notes_wrapped_bar_plot,
    theme = theme(
      plot.caption = element_text(
        size   = 12,
        hjust  = 0,
        face   = "plain",
        color  = "black",
        margin = margin(t = 10)
      )
    )
  )

ggsave(here("output", "bar_plot_with_notes.png"),
       plot   = residual_plot_with_notes,
       width  = 10,
       height = 7,
       dpi    = 300,
       bg     = "white")

# Immigration flow rate vs Real Rent Growth by proportion of MSA

plot1 <- ggplot(merged, aes(x = rent_growth * 100)) +
  geom_histogram(aes(y = after_stat(count / sum(count))),
                 bins = 30, fill = "steelblue", color = "white") +
  geom_vline(aes(xintercept = mean(rent_growth * 100)),
             linetype = "dashed", color = "black", linewidth = 0.8) +
  annotate("text",
           x = mean(merged$rent_growth * 100) + 1.5,
           y = 0.19,
           label = paste0("Mean = ",
                          round(mean(merged$rent_growth * 100), 1), "%"),
           hjust = 0, size = 3.5) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 0.21)) +
  labs(title = "Real rent growth (2014-2019)",
       x = "Real rent growth (%)",
       y = "Proportion of MSAs") +
  theme_minimal()

plot2 <- ggplot(merged, aes(x = imm_flow_rate * 100)) +
  geom_histogram(aes(y = after_stat(count / sum(count))),
                 bins = 30, fill = "darkorange", color = "white") +
  geom_vline(aes(xintercept = mean(imm_flow_rate * 100)),
             linetype = "dashed", color = "black", linewidth = 0.8) +
  annotate("text",
           x = mean(merged$imm_flow_rate * 100) + 0.05,
           y = 0.19,
           label = paste0("Mean = ",
                          round(mean(merged$imm_flow_rate * 100), 2), "%"),
           hjust = 0, size = 3.5) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 0.21)) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 0.1,
                                                     scale = 1)) +
  labs(title = "Immigration flow rate (2010-2014)",
       x = "Immigration flow rate (% of MSA population from abroad)",
       y = "Proportion of MSAs") +
  theme_minimal()

plot2 + plot1

# Notes text
notes_wrapped <- str_wrap(
  paste(
    "NOTE: Figure above uses American Community Survey (ACS) 5-year estimates",
    "from IPUMS NHGIS to display the distribution of two key variables across",
    "332 U.S. metropolitan statistical areas. The left panel shows the immigration",
    "flow rate — the average annual share of each MSA's population that arrived",
    "from abroad — measured during the 2010-2014 baseline period. The right panel",
    "shows real rent growth — the inflation-adjusted percentage change in median",
    "gross rent between the 2010-2014 and 2015-2019 ACS 5-year estimates, where",
    "the 2010-2014 baseline rent is converted to 2019 dollars using the BLS CPI-U",
    "adjustment factor prior to calculating the percentage change. Dashed vertical",
    "lines indicate the sample mean for each variable."
  ),
  width = 180
)

combined <- (plot2 + plot1) +
  plot_annotation(
    caption = notes_wrapped,
    theme = theme(
      plot.caption = element_text(
        size   = 8,
        hjust  = 0,
        face   = "plain",
        color  = "black",
        margin = margin(t = 10)
      )
    )
  )

ggsave(here("output", "histograms_with_notes.png"),
       plot   = combined,
       width  = 10,
       height = 7,
       dpi    = 300,
       bg     = "white")

# Summary Statistics Table

merged %>%
  select(
    "Real rent growth"              = rent_growth,
    "Immigration flow rate"         = imm_flow_rate,
    "Domestic migration rate"       = domestic_migration_rate,
    "Rental vacancy rate"           = rental_vacancy_rate,
    "Population growth"             = pop_growth,
    "Baseline median rent ($000s)"  = median_gross_rent_real,
    "Median HH income ($000s)"      = median_hh_income_real,
    "Unemployment rate"             = unemp_rate,
    "Unemployment rate change"      = unemp_rate_change
  ) %>%
  summarise(across(everything(), list(
    Mean   = ~mean(., na.rm = TRUE),
    SD     = ~sd(., na.rm = TRUE),
    Min    = ~min(., na.rm = TRUE),
    Max    = ~max(., na.rm = TRUE),
    N      = ~sum(!is.na(.))
  ))) %>%
  pivot_longer(everything(),
               names_to  = c("Variable", ".value"),
               names_sep = "_") %>%
  mutate(across(where(is.numeric), ~round(., 4))) %>%
  print(n = Inf)

# Check: MSAs with the highest rental vacancy rates (outlier review)

summary(merged$rental_vacancy_rate)

merged %>%
  arrange(desc(rental_vacancy_rate)) %>%
  select(msa_name, rental_vacancy_rate) %>%
  head(10) %>%
  print()