# Demo script: one paragraph per slide (12 slides, under 5 minutes)

Open `docs/demo_slides.pptx` in Presenter View (Alt+F5): each slide's speaker notes hold exactly the paragraph below. Advance one slide per paragraph.

**Slide 1: The problem**
"Buildings are among the largest contributors to energy use and carbon emissions. To fix them we first need to know which buildings are wasting energy. Not which use the most, but which use more than they should, given what they are and where they are. That's what we built in MATLAB."

**Slide 2: Physics framing**
"A building's heating energy follows an energy balance: Q ≈ UA·ΔT summed over the year. So we engineered degree-day and seasonal temperature features. In the raw data, median energy use is roughly 36 to 53 in milder climates and 68 to 82 in colder ones."

**Slide 3: Data finding 1: state shift**
"Before modelling we looked hard at the data. Three findings drove our design. One: State_6 is 67% of the training data and 0% of the test data. So besides the normal score, we report a 'test-like' score on non-State_6 buildings."

**Slide 4: Data finding 2: missingness shift**
"Two: the wind and fog columns are 56% missing in train but 90% in test. A model would wrongly learn from that missingness shift, so we dropped them."

**Slide 5: Data finding 3: building history**
"Three: the same buildings appear in several years without an id. We reconstructed one, giving 63,907 buildings, so a building's past energy use becomes a feature. It is computed only from earlier years, and a unit test proves it."

**Slide 6: Honest validation**
"We validate the way the task works: train on years 1 to 5, predict year 6, which the model has never seen. With the same model, a random split would have reported an RMSE of 37.9. The honest temporal split says 42.5."

**Slide 7: Model ladder**
"Then we climbed a ladder of 10 models, each answering one question. Linear regression gets 46.2 and a single tree 40.9, so interactions matter. Adding building history brought buildings with a track record down to an RMSE of 20. Blending raw- and log-scale boosted trees gave our best model: RMSE 37.6, 34% better than the naive baseline, with an R² of 0.57."

**Slide 8: A MATLAB-specific lesson**
"One MATLAB-specific lesson: MATLAB trees without surrogate splits stop rows that are missing the split variable. Our first run barely learned from buildings without a rating. Encoding missing values explicitly took us from 46.8 to 37.6."

**Slide 9: What the model learned**
"Partial dependence shows clean responses: a higher ENERGY STAR score means lower energy use, and past use predicts future use. An honest caveat: once the model knows the state, the degree-day features add little, because weather is recorded per state and year."

**Slide 10: Retrofit shortlist**
"Then we turn predictions into action. A cold-start model predicts what a typical building of the same type, size, age and climate should use. Buildings far above that are retrofit candidates: 1,123 buildings, 5% of the stock, using 1.55 × 10¹⁰ kBtu a year more than expected. That's 5.3% of all energy used. They are ranked by absolute excess energy, so an organisation knows where a retrofit pays off most."

**Slide 11: Engineering quality**
"Everything runs with one command, main, from raw CSV to submission and figures. The code is modular functions with argument validation, unit tests in matlab.unittest, and a validated submission file. Every number in our README was printed by MATLAB."

**Slide 12: Next steps and close**
"Next steps: monthly meter data, occupancy, and optimising which retrofits to fund first. Thank you."
