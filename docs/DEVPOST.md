# Devpost write-up (copy into the Devpost form)

**Project name:** Which buildings waste energy? Predicting building energy use with MATLAB

**Tagline:** Leak-free, physics-informed prediction of building energy use, turned into a retrofit shortlist.

## Inspiration
Buildings are major contributors to global energy use and carbon emissions. Retrofitting
works best when it targets buildings that use far more energy than they should, not just
the biggest users. We wanted a model honest enough to trust for that decision.

## What it does
It predicts a building's annual site Energy Use Intensity (kBtu/ft²/yr) from building
characteristics and local weather (WiDS Datathon 2022, 75,757 building-years). On a
held-out future year it reaches **RMSE 37.6 vs 57.1 for a naive baseline (−34%),
R² 0.57**. A cold-start model then estimates what each building *should* use and flags
**1,123 buildings (about 5%) that waste 1.55×10¹⁰ kBtu/yr, 5.3% of all energy used**.

## How we built it
All in MATLAB with the Statistics and Machine Learning Toolbox. `main.m` runs the
whole modular pipeline:
- **Data mastery.** We found that State_6 (67% of train) is absent from test, so we report
  a test-like score as well. Wind/fog columns were dropped because of a missingness shift
  (56% → 90%). We added missingness indicators, pooled rare facility types, and logged
  every decision with its evidence in `results/decisions.csv`.
- **Physics features.** Degree days, seasonal temperatures, annual temperature range,
  log floor area and building age, all motivated by the energy balance Q ≈ UA·ΔT.
- **Building history.** We reconstructed building identity from static attributes and
  used causal lag features from earlier years only (unit-tested).
- **Temporal validation.** Train on years 1–5, validate on year 6. A random split would
  have reported 37.9 instead of the honest 42.5.
- **A 10-rung model ladder:** `fitlm`, `fitrtree`, `fitrensemble` (Bag, LSBoost), `fitrnet`,
  and a raw/log blend.
- Partial dependence and predictor importance, then a retrofit shortlist ranked by excess
  energy (excess EUI × floor area).

## Challenges we ran into
Our first full run was disappointing: adding the strongest features made the model
*worse*. The cause was MATLAB's missing-value handling in trees. Without surrogate splits,
a row missing the split variable stops at that node. Encoding missing values as an
out-of-range sentinel fixed it, and RMSE fell from 46.8 to 37.6. The neural network
underperformed tree ensembles on this tabular data, and we report that honestly.

## Accomplishments that we're proud of
- A validation design that mirrors the real task and refuses to fool itself.
- A one-command, tested, reproducible pipeline.
- A result that turns into an action: the retrofit shortlist.

## What we learned
- Look for distribution shift before modelling.
- Random splits flatter models when entities repeat over time.
- Small library details, like how trees treat NaN, can matter more than the choice of algorithm.

## What's next
Monthly meter data and occupancy; an optimisation layer that picks which retrofits to
fund under a budget; uncertainty estimates for each building.

## Built with
MATLAB, Statistics and Machine Learning Toolbox, matlab.unittest, GitHub

## Links
- Code: https://github.com/JoshiiWahWah/ntu-matlab-hackathon-2026
- Demo: see `docs/DEMO_SCRIPT.md` and the figures in the repo README
