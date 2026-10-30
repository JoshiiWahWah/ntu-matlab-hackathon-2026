function main(quick)
%MAIN Predicting building energy consumption (WiDS 2022) -- end-to-end.
%
%   main          full run: EDA -> cleaning -> features -> model ladder ->
%                 final model -> submission -> explanations -> retrofit list
%   main(true)    QUICK smoke run on a subsample (~1-2 minutes)
%
%   Outputs: results/*.csv, results/submission.csv, figures/*.png
%   Requires: Statistics and Machine Learning Toolbox (R2022a or newer).

arguments
    quick (1,1) logical = false
end

root = fileparts(mfilename("fullpath"));
addpath(fullfile(root, "src"));
cfg = config(quick);
rng(cfg.seed);
if ~isfolder(cfg.figDir),     mkdir(cfg.figDir);     end
if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
runTimer = tic;
fprintf("=== Building energy pipeline (%s mode, seed %d) ===\n", ...
    string(ternary(quick, "QUICK", "FULL")), cfg.seed);

%% 1. Load and verify
[train, test, sampleIds] = loadData(cfg);

%% 2. Clean (each decision logged with evidence)
fprintf("\nCleaning:\n");
[data, decisions] = cleanData(train, test, cfg);

%% 3. Features: physics + reconstructed building history
fprintf("\nFeatures:\n");
[data, featureSets, keyStats] = makeFeatures(data);
decisions = [decisions; {"Reconstructed building id from static attributes; added causal lag features", ...
    sprintf("%d buildings, %.1f%% seen in >1 year; %.1f%% of test rows have past energy data", ...
    keyStats.nBuildings, 100*keyStats.multiYearShare, 100*keyStats.testWithHistory), ...
    "Use of ML: features"}];
makeEdaFigures(data, cfg);

%% 4. Temporal split
fprintf("\n");
[trn, val, full, tst] = splitData(data, cfg);

%% 5. Model ladder on the held-out year
[ladder, valPreds, best] = runModelLadder(trn, val, featureSets, cfg);
cmp = compareValidation(full, ladder.rmse(ladder.features == "withESR"), featureSets, cfg);

%% 6. Final model: retrain the best pipeline on ALL labelled years, predict test
fprintf("\nFinal model: retraining on all labelled years (blend weight %.1f raw / %.1f log)\n", ...
    best.blendWeight, 1 - best.blendWeight);
Xfull = full(:, featureSets.full);
Xtest = tst(:, featureSets.full);
finalRaw = fitBoost(Xfull, full.site_eui, cfg);
finalLog = fitBoost(Xfull, log1p(full.site_eui), cfg);
testPred = best.blendWeight * predict(finalRaw, Xtest) + ...
    (1 - best.blendWeight) * expm1(predict(finalLog, Xtest));
nFloored = nnz(testPred < cfg.predFloor);
testPred = max(testPred, cfg.predFloor);
fprintf("  %d test predictions raised to the physical floor of %g\n", nFloored, cfg.predFloor);

if ~isequal(tst.id, sampleIds)
    error("main:order", "Test row order changed during processing.");
end
subFile = fullfile(cfg.resultsDir, "submission.csv");
writeSubmission(tst.id, testPred, subFile);
validateSubmission(subFile, sampleIds);
copyfile(subFile, fullfile(cfg.resultsDir, "submission_lkg.csv"));

%% 7. Explain the model and find retrofit candidates
[importance, pd] = explainModel(finalRaw, Xfull, cfg);
[candidates, retro] = retrofitAnalysis(val, valPreds.coldStart, cfg);
makeResultFigures(ladder, cmp, val, valPreds, importance, pd, candidates, cfg);

%% 8. Save results
writetable(ladder,     fullfile(cfg.resultsDir, "results.csv"));
writetable(decisions,  fullfile(cfg.resultsDir, "decisions.csv"));
writetable(cmp,        fullfile(cfg.resultsDir, "validation_schemes.csv"));
writetable(importance, fullfile(cfg.resultsDir, "importance.csv"));
writetable(candidates(1:min(20, height(candidates)), :), fullfile(cfg.resultsDir, "retrofit_top20.csv"));
save(fullfile(cfg.resultsDir, "models.mat"), "finalRaw", "finalLog", "best", "featureSets", "cfg");

bestRow = ladder(end, :);
fprintf("\n=== SUMMARY ===\n");
fprintf("Naive median RMSE (year %d):  %.2f\n", cfg.valYear, ladder.rmse(1));
fprintf("Final blend RMSE  (year %d):  %.2f  (MAE %.2f, R^2 %.3f, test-like %.2f)\n", ...
    cfg.valYear, bestRow.rmse, bestRow.mae, bestRow.r2, bestRow.rmse_testlike);
fprintf("Improvement over naive:       %.1f%%\n", 100*(1 - bestRow.rmse/ladder.rmse(1)));
fprintf("Retrofit candidates:          %d buildings, %.3g kBtu/yr excess\n", ...
    retro.nCandidates, retro.totalExcessKbtu);
fprintf("Submission:                   %s\n", subFile);
fprintf("Total runtime:                %.1f s\n", toc(runTimer));
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
