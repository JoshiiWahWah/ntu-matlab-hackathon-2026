# Which buildings waste energy? Predicting building energy use with MATLAB

**NTU "Learn to Hack: MATLAB Edition 2026" — Predicting Building Energy Consumption**

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=JoshiiWahWah/ntu-matlab-hackathon-2026)

We predict a building's annual **site Energy Use Intensity** (EUI, kBtu/ft²/yr) from its
characteristics and local weather (WiDS Datathon 2022, ~76k building-years). The
pipeline is validated on a future year the model has never seen, and then used to
produce a **retrofit shortlist**: buildings using far more energy than physics and
peers say they should.

One command runs everything: `main` (or `main(true)` for a 1–2 minute smoke test).

---

## Why this is more than the starter code

| Starter script | Our pipeline | Why it matters |
|---|---|---|
| Drops all text columns | Keeps `facility_type`, `building_class`, `State_Factor` as **categorical** predictors | Building use is the #1 driver of EUI (fig. 4) |
| Drops every column with a missing value | Missingness **indicators** + model-appropriate handling (trees use NaN natively, linear/NN get train-only medians) | Whether a building has an ENERGY STAR rating is itself informative |
| Random 80/20 split | **Temporal split**: train on years 1–5, validate on year 6 (the test set is year 7) | Mirrors the real forecasting task; random splits let the same building leak across years |
| One model from the app | A **10-rung model ladder**, each rung answering one question | Justifies every algorithm choice with numbers |
| — | **Reconstructed building identity** + causal history features | Past energy use is the strongest predictor — computed only from earlier years |
| — | **Retrofit shortlist** from an out-of-sample cold-start model | Turns predictions into an action |

## What we found in the data (Data Mastery)

All decisions and their evidence are written by `cleanData.m` to
[`results/decisions.csv`](results/decisions.csv).

1. **Distribution shift between train and test.** State_6 makes up about 67% of training
   rows but **none of the test rows**. So we report a second, **test-like** validation score
   on non-State_6 buildings (fig. 2).
2. **Wind and fog columns are unreliable.** They are about 54% missing in train and about
   88% missing in test. A model would learn a missingness pattern that doesn't exist at
   test time, so we drop them.
3. **`year_built = 0`** is not a real year. We set it to missing.
4. **ENERGY STAR rating is ~35% missing.** We add an `esr_missing` flag before any imputation.
   The rating is itself derived from measured energy use, so we report models with and without it.
5. **Rare facility types** (fewer than 50 training rows) are pooled into `Other_rare`.
6. **The target is right-skewed** (fig. 1), so we train both raw-scale and log-scale models
   and blend them. Extreme EUIs (labs, data centres) are kept because the metric includes them.
7. **The same buildings recur across years**, but no building id is given. We reconstruct
   one from static attributes (state, class, type, floor area, year built, elevation).
   The building's **previous-year EUI** is then a feature. It is computed strictly from
   earlier years, and a unit test (`tests/PipelineTest.m`) proves that.

## Physics-informed features

A building's heating energy follows an energy balance, *Q ≈ UA · ΔT* summed over
the year, so heating demand scales with **heating degree days** and cooling demand
with **cooling degree days**. We add:

- winter and summer mean temperatures
- annual temperature range
- total degree days and the cooling share
- log floor area
- relative building age

Partial-dependence plots (fig. 11) confirm the model learned physically sensible responses.

## Model ladder (Use of ML)

Validation = Year_Factor 6, trained on years 1–5. RMSE in kBtu/ft²/yr (official WiDS metric).

<!-- RESULTS_TABLE: filled from results/results.csv after the MATLAB run -->
_Table generated from `results/results.csv` after running `main`._

## Retrofit shortlist (the "so what")

The **cold-start** model (no rating, no history) is trained on earlier years and estimates
what a typical building of the same type, size, age and climate uses. A building's excess
EUI is its actual EUI minus that prediction. Candidates are the top 5% by excess within
each facility type, ranked by **excess energy = excess EUI × floor area**. That ranking puts
the biggest absolute savings first. See [`results/retrofit_top20.csv`](results/retrofit_top20.csv) and fig. 12.

## How to run

1. Put `train.csv` and `test.csv` in `data/` (see [`data/README.md`](data/README.md)).
2. In MATLAB (R2022a or newer, Statistics and Machine Learning Toolbox), from the repo root:
   ```matlab
   main(true)                 % quick smoke test (~1-2 min)
   main                       % full run: results/, figures/, results/submission.csv
   results = runtests('tests')
   publish('report/report.m', 'outputDir', 'report', 'format', 'html')
   ```

## Repository layout

```
main.m              end-to-end pipeline (one command)
config.m            all settings in one place (seed 42, model hyperparameters, QUICK mode)
src/                loadData, cleanData, makeFeatures, splitData, runModelLadder,
                    fitBoost, compareValidation, explainModel, retrofitAnalysis,
                    makeEdaFigures, makeResultFigures, validateSubmission, ...
tests/              matlab.unittest tests (metrics, causal history, submission validator)
report/report.m     publishable results report
results/            model ladder, decisions log, retrofit list, submission.csv
figures/            all figures (PNG)
docs/               demo script and Devpost write-up
```

## AI-assistance disclosure

Code was drafted with Claude Code (Anthropic). All results come from running the MATLAB
code, and the team reviewed the design decisions. Python was used only for an early
offline sanity check of data facts; it is not part of the submission.
