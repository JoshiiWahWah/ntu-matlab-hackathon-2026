# Demo script (under 5 minutes)

Show the README and the `figures/` images while speaking. The timings are targets.

**0:00–0:30 — Hook (the problem)**
"Buildings are among the largest contributors to energy use and carbon emissions. To fix
them we first need to know which buildings are wasting energy. Not which use the most,
but which use more than they should, given what they are and where they are. That's what
we built in MATLAB."

**0:30–1:10 — Physics framing** (fig. 05 EUI vs HDD)
"A building's heating energy follows an energy balance: Q ≈ UA·ΔT summed over the year.
So we engineered degree-day and seasonal temperature features. In the raw data, median
energy use is roughly 36–53 in milder climates and 68–82 in colder ones."

**1:10–2:10 — Data mastery** (fig. 02 state shift, results/decisions.csv)
"Before modelling we looked hard at the data. Three findings drove our design:
1. State_6 is 67% of the training data and *0%* of the test data. So besides the normal
   score we report a 'test-like' score on non-State_6 buildings.
2. The wind and fog columns are 56% missing in train but 90% in test. That's a
   missingness shift a model would wrongly learn from, so we dropped them.
3. The same buildings appear in several years without an id. We reconstructed one
   (63,907 buildings), so a building's *past* energy use becomes a feature. It is
   computed only from earlier years, and a unit test proves it."

**2:10–3:20 — Model ladder** (fig. 06, fig. 09)
"We validate the way the task works: train on years 1–5, predict year 6, never seen.
Same model, a random split would have told us RMSE 37.9; the honest temporal split
says 42.5. Then we climbed a ladder of 10 models, each answering one question:
- linear regression 46.2, a single tree 40.9: interactions matter;
- adding building history brought buildings with a track record down to RMSE 20;
- blending raw- and log-scale boosted trees gave our best model: **RMSE 37.6, 34%
  better than the naive baseline, R² 0.57**.
One MATLAB-specific lesson: MATLAB trees without surrogate splits stop rows that are
missing a split variable. Our first run barely learned from buildings without a rating.
Encoding missing values explicitly took us from 46.8 to 37.6."

**3:20–4:20 — Impact: retrofit shortlist** (fig. 11, fig. 12)
"Partial dependence shows clean responses: a higher ENERGY STAR score means lower
energy use, and past use predicts future use. Honest caveat: once the model knows the
state, the degree-day features add little, because weather is recorded per state and
year. Then we turn predictions into action. A cold-start model predicts what a typical building of the
same type, size, age and climate *should* use. Buildings far above that are retrofit
candidates: **1,123 buildings, 5% of the stock, wasting 1.55×10¹⁰ kBtu a year, 5.3%
of all energy used**. Ranked by absolute excess energy, so an organisation knows where a
retrofit pays off most."

**4:20–4:50 — Engineering quality**
"Everything runs with one command, `main`, from raw CSV to submission, figures and
report. The code is modular functions with argument validation, unit tests in
`matlab.unittest`, a validated submission file, and every number in our README is printed
by MATLAB."

**4:50–5:00 — Close**
"Next steps: monthly meter data, occupancy, and optimising which retrofits to fund
first. Thank you."
