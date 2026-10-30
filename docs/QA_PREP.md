# Judges' Q&A prep

Every number here was printed by the full MATLAB run (`results/*.csv`) or set in `config.m`.

## Ten numbers to memorise
| | |
|---|---|
| Final RMSE (year-6 holdout) | **37.56** kBtu/ft²/yr (naive median 57.07) |
| Improvement / R² / MAE | **34.2%** / **0.566** / **17.32** |
| Random vs temporal split (same model) | **37.9 vs 42.5** |
| Buildings with history vs without | RMSE **20.3 vs 44.9** |
| Missing-value fix | **46.8 → 37.6** |
| Data split | train 53,308 rows (years 1–5) · validate 22,449 (year 6) · test 9,705 (year 7) |
| State_6 | **67.1%** of train, **0%** of test |
| Wind/fog missing | **56.0%** train vs **89.8%** test |
| Reconstructed buildings | **63,907**; **22.1%** of test rows have history |
| Retrofit list | **1,123** buildings, **1.55×10¹⁰ kBtu/yr** excess, **5.3%** of year-6 energy |

---

## A. Data mastery

**Q1. Why not a random train/test split?**
"The test set is a future year, Year_Factor 7. So we trained on years 1–5 and validated on year 6, which mirrors the real task. The same buildings appear in several years, so a random split puts a building's other years into training. On the same model, a random split reported 37.9 RMSE; the honest temporal split gave 42.5. We report the temporal number."

**Q2. What is the 'test-like' score?**
"State_6 is 67% of training rows but doesn't appear in the test set at all. So besides the overall score, we score only non-State_6 validation buildings, because they resemble the test set most. Our final blend scores 38.06 there."

**Q3. Why drop the wind and fog columns instead of imputing them?**
"They're 56% missing in train but 90% in test. That isn't just missing data; the missingness pattern itself changes between train and test. A model would learn a pattern that doesn't exist at prediction time. Imputing doesn't fix a shift like that, so we removed them."

**Q4. How did you handle missing values in general?**
"It depends on the model. We first add explicit flags such as `esr_missing`. Trees get missing values encoded as an out-of-range sentinel, -999. Linear regression and the neural net get median imputation, with medians computed on training rows only, so there's no leakage from validation or test."

**Q5. How do you identify buildings when there's no building id?**
"We build a key from static attributes: state, building class, facility type, floor area, year built and elevation. That gives 63,907 buildings, 22% of them seen in more than one year. It isn't perfect: two different buildings with identical attributes would merge. We found 884 same-year duplicates, and the code handles them so a row never sees its own year's energy."

**Q6. Isn't using past energy use leakage?**
"No. It's computed strictly from earlier years, which is information you genuinely have when forecasting next year. A unit test in `tests/PipelineTest.m` checks this, including same-year duplicates. It's also why we report buildings with and without history separately: 20.3 vs 44.9 RMSE."

**Q7. Did you remove outliers?**
"No. Extreme EUIs up to 997.9 are plausible for labs, data centres or food service, and the metric includes them. We only treated `year_built = 0` as missing (7 rows) and pooled 14 rare facility types, 330 rows, into one group."

**Q8. Isn't ENERGY STAR rating basically the answer?**
"Partly, yes. It's derived from measured energy use, which is why we report models with and without it. The cold-start model uses neither the rating nor history, and that's the model we use for the retrofit list. Adding the rating cut RMSE from 48.7 to 42.5."

## B. Machine learning

**Q9. Why boosted trees?**
"Energy use depends on interactions, such as facility type times climate times size. A single tree already beat linear regression, 40.9 against 46.2. Ensembles reduce variance further, and boosted trees handle categorical predictors like facility type natively. The ladder justifies each step with a number."

**Q10. Why blend a raw-target and a log-target model?**
"EUI is right-skewed. The log model was better overall (38.2), the raw model was better on test-like buildings (37.0), and the blend got the best overall score, 37.6."

**Q11. You chose the blend weight on the validation set. Isn't that optimistic?**
"Slightly, yes. We searched 11 weights on year 6 and picked 0.3 raw / 0.7 log. Each component's honest score is reported separately: 40.8 and 38.2. The proper fix is nested or rolling-origin validation, which is a next step."

**Q12. Did you tune hyperparameters?**
"Not with a search. We held settings fixed so every rung of the ladder is compared fairly: 300 trees, learning rate 0.08, at most 63 splits per tree, minimum leaf size 20. Bayesian tuning with `OptimizeHyperparameters` is the obvious next step, but we prioritised validation design given four hours."

**Q13. Why did the neural network do so badly (59.5)?**
"Tabular data with heavy missingness and many categorical levels favours trees. We standardised inputs, imputed medians and used L2 regularisation, but it still underperformed, so we report it rather than drop it. It's evidence for our model choice."

**Q14. What happened with MATLAB's missing values?**
"Without surrogate splits, a MATLAB tree stops a row that's missing the split variable at that node and predicts the node mean. Two of our strongest features are often missing: ENERGY STAR for 35% of rows, and history for about three-quarters. So those buildings were barely learned, and adding history even made the model worse. Encoding missing values as a sentinel fixed it: 46.8 to 37.6."

**Q15. Why not turn on surrogate splits?**
"That's a valid alternative. Surrogates are much slower to train on 53,000 rows with 300 trees. The sentinel combined with explicit missing flags lets each split learn where missing rows belong, which suited our time budget."

**Q16. How does 37.6 compare to the Kaggle leaderboard?**
"Not directly comparable. Kaggle scored year 7 on their hidden test labels, and we can't score year 7 because the labels aren't public. Our 37.6 is an honest holdout on year 6, which includes the State_6 shift."

**Q17. How do you know you're not overfitting?**
"Every score is on a year the model never saw. Boosting uses shrinkage and a minimum leaf size, and the same settings work across all rungs. The final model is then retrained on all six labelled years before predicting year 7."

**Q18. How confident are individual predictions?**
"We don't produce prediction intervals yet. MAE is 17.3, and errors are much larger for buildings without history. Quantile regression or ensemble spread would add uncertainty bands; that's on our next-steps list."

## C. Physics and engineering

**Q19. Where does the physics come in?**
"Through the energy balance: annual heating energy ≈ UA × ΔT summed over time, which is heating degree days. So we engineered degree-day totals, cooling share, seasonal temperatures and the annual temperature range. EUI is per square foot, so floor area enters as a log feature."

**Q20. Your partial-dependence plot for degree days is almost flat. Doesn't that contradict the physics?**
"Good catch, and it's honest. Weather is recorded per state and year, so once the model knows the state, degree days add little new information; the climate signal is absorbed by State_Factor. In the raw data, median EUI is about 36–53 in milder climates against 68–82 in colder ones. The physics is in the data; the model just gets it through the state variable."

**Q21. What's a degree day?**
"For each day, how far the mean temperature falls below a base temperature, conventionally 65 °F in US data, summed over the year. It's proportional to heating demand. Cooling degree days are the mirror image above the base."

**Q22. How much CO₂ does the retrofit list represent?**
"We deliberately didn't state a CO₂ number. Site energy mixes electricity and fuels, and the emissions factor depends on the fuel mix and grid, which the dataset doesn't give. We report energy: 1.55×10¹⁰ kBtu a year above expected, 5.3% of year-6 energy. With a verified grid factor it's a single multiplication."

**Q23. How would this become an optimisation problem?**
"Each candidate has an estimated excess energy. Add a retrofit cost and an expected saving fraction per building, and choosing which to fund under a budget becomes a knapsack-style integer programme that maximises energy saved. That's our next step, and MATLAB's `intlinprog` would solve it."

**Q24. Does high excess EUI mean a building is wasteful?**
"Not by itself. It means the building uses much more than similar buildings of the same type, size, age and climate. The cause could be inefficiency, or something we can't see, like 24/7 operation or a data room. It's a screening tool that tells an auditor where to look first."

**Q25. Why rank by excess energy rather than excess EUI?**
"A big building slightly over budget can waste more total energy than a small building far over. Excess EUI × floor area gives total excess kBtu, which is what a retrofit actually saves."

**Q26. kBtu/ft² is unfamiliar here. In SI units?**
"1 kBtu/ft² ≈ 3.15 kWh/m², so our RMSE of 37.6 is about 119 kWh/m² per year."

## D. Impact and practicality

**Q27. Who would use this?**
"Building owners, city energy offices and facility managers with portfolios of buildings. They can benchmark every building against what it should use and prioritise audits and retrofit budgets."

**Q28. Would it work in Singapore?**
"Not as-is. It's trained on US buildings, and Singapore is cooling-dominated with almost no heating degree days. The pipeline transfers: retrain on local benchmarking data, and cooling degree days and humidity would matter most."

**Q29. What would you do with more time?**
"Rolling-origin validation and hyperparameter tuning, prediction intervals, monthly meter and occupancy data, and the budget-constrained retrofit optimiser."

## E. MATLAB proficiency and code

**Q30. Why scripts and functions rather than the Regression Learner app?**
"Reproducibility. One command, `main`, reruns everything from raw CSV to submission and figures with a fixed seed (42). The functions use `arguments` validation, and the tests use `matlab.unittest`. The app is great for exploring, but a script is reviewable and repeatable."

**Q31. Which MATLAB features did you use?**
"Tables with categorical variables; `detectImportOptions`/`readtable` with explicit types; `findgroups` and `splitapply`; `fitlm`, `fitrtree`, `fitrensemble` (Bag and LSBoost), `fitrnet`, `predictorImportance` and `cvpartition`; `tiledlayout`, `boxchart` and `exportgraphics`; `matlab.unittest`."

**Q32. How long does it take to run?**
"About 11 minutes for the full pipeline on a laptop (650.7 s). `main(true)` is a 1–2 minute smoke test on a 25% subsample."

**Q33. How do you know the submission file is valid?**
"`validateSubmission.m` asserts the exact header `id,site_eui`, 9,705 rows, ids identical to the sample solution in the same order, and no NaN, Inf or non-positive values. It passed, with predictions ranging from 1.0 to 665.1."

**Q34. Did you use AI tools?** (Answer honestly; the README already discloses it.)
"Yes, and it's disclosed in our README. We used Claude Code to help draft code. We ran everything in MATLAB ourselves, every reported number comes from our MATLAB output, and we made and checked the design decisions. Debugging the missing-value problem from our own run results was a good example."

---

## Tips for the panel
- **Lead with the number, then the reason.** For example: "37.6, 34% better than naive, because…"
- **Admit limits confidently:** the blend weight was picked on the validation set, there's no tuning, the HDD curve is flat, and the building key is imperfect. Judges reward honesty about validation.
- **If you don't know:** "We didn't test that, but here's how we would…" Never guess a number.
