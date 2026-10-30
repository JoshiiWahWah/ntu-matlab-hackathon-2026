function [ladder, preds, best] = runModelLadder(trn, val, featureSets, cfg)
%RUNMODELLADDER Train increasingly capable models on years < valYear and
%   score each on the held-out year. Every rung is one row of LADDER.
%
%   Each rung answers one question:
%     0 naive median        -> what is "no skill"?
%     1 linear (log target) -> how far do linear physics terms get us?
%     2 single tree         -> do non-linear interactions matter?
%     3 bagged trees        -> does variance reduction help?
%     4 boosted, cold start -> best model for a NEW building (no rating, no history)
%     5 boosted + ESR       -> value of the ENERGY STAR rating
%     6 boosted + history   -> value of the building's own past energy use
%     7 boosted + history, log target -> handles the right-skewed target
%     8 neural net          -> a different model family for comparison
%     9 blend of 6 and 7    -> combine raw- and log-scale strengths

arguments
    trn table
    val table
    featureSets (1,1) struct
    cfg (1,1) struct
end

y      = trn.site_eui;
yVal   = val.site_eui;
masks.testLike = val.State_Factor ~= 'State_6';
masks.history  = val.has_history == 1;

ladder = table();
preds  = struct();

% 0) Naive baseline
t = tic;
preds.naive = repmat(median(y), height(val), 1);
ladder = addRow(ladder, "0 Naive median", "-", "raw", yVal, preds.naive, masks, toc(t));

% 1) Linear regression on log1p(EUI) with median-imputed predictors.
%    A compact, non-collinear physics set keeps coefficients interpretable
%    (e.g. building_age = const - year_built would make the fit rank-deficient).
t = tic;
linVars = {'State_Factor', 'building_class', 'facility_type', 'log_floor_area', ...
    'year_built', 'ELEVATION', 'energy_star_rating', 'esr_missing', ...
    'heating_degree_days', 'cooling_degree_days', 'winter_avg_temp', ...
    'summer_avg_temp', 'annual_temp_range', 'precipitation_inches', 'snowfall_inches'};
[Xl, Xlv] = imputeMedian(trn(:, linVars), val(:, linVars));
Xl.logEUI = log1p(y);
lin = fitlm(Xl, 'linear', 'ResponseVar', 'logEUI');
preds.linear = capLog(predict(lin, Xlv), y, cfg);
ladder = addRow(ladder, "1 Linear regression (fitlm)", "physics-linear", "log", yVal, preds.linear, masks, toc(t));

% 2) Single regression tree
t = tic;
tree = fitrtree(treeInputs(trn, featureSets.full), y, 'MinLeafSize', cfg.tree.minLeaf);
preds.tree = predict(tree, treeInputs(val, featureSets.full));
ladder = addRow(ladder, "2 Regression tree (fitrtree)", "full", "raw", yVal, preds.tree, masks, toc(t));

% 3) Bagged trees (random-forest style)
t = tic;
bag = fitrensemble(treeInputs(trn, featureSets.full), y, 'Method', 'Bag', ...
    'NumLearningCycles', cfg.bag.cycles, 'Learners', templateTree('MinLeafSize', cfg.bag.minLeaf));
preds.bag = predict(bag, treeInputs(val, featureSets.full));
ladder = addRow(ladder, "3 Bagged trees (fitrensemble Bag)", "full", "raw", yVal, preds.bag, masks, toc(t));

% 4) Boosted trees, cold-start features
t = tic;
best.coldStart = fitBoost(treeInputs(trn, featureSets.coldStart), y, cfg);
preds.coldStart = predict(best.coldStart, treeInputs(val, featureSets.coldStart));
ladder = addRow(ladder, "4 Boosted trees (LSBoost)", "coldStart", "raw", yVal, preds.coldStart, masks, toc(t));

% 5) Boosted trees + ENERGY STAR rating
t = tic;
mdl = fitBoost(treeInputs(trn, featureSets.withESR), y, cfg);
preds.withESR = predict(mdl, treeInputs(val, featureSets.withESR));
ladder = addRow(ladder, "5 Boosted trees (LSBoost)", "withESR", "raw", yVal, preds.withESR, masks, toc(t));

% 6) Boosted trees + building history
t = tic;
best.fullRaw = fitBoost(treeInputs(trn, featureSets.full), y, cfg);
preds.fullRaw = predict(best.fullRaw, treeInputs(val, featureSets.full));
ladder = addRow(ladder, "6 Boosted trees (LSBoost)", "full", "raw", yVal, preds.fullRaw, masks, toc(t));

% 7) Boosted trees + history, log target
t = tic;
mdl = fitBoost(treeInputs(trn, featureSets.full), log1p(y), cfg);
preds.fullLog = capLog(predict(mdl, treeInputs(val, featureSets.full)), y, cfg);
ladder = addRow(ladder, "7 Boosted trees (LSBoost)", "full", "log", yVal, preds.fullLog, masks, toc(t));

% 8) Neural network (standardised, median-imputed inputs, log target)
t = tic;
[Xn, Xnv] = imputeMedian(trn(:, featureSets.full), val(:, featureSets.full));
net = fitrnet(Xn, log1p(y), 'Standardize', true, 'LayerSizes', cfg.nnet.layers, ...
    'Lambda', cfg.nnet.lambda, 'IterationLimit', cfg.nnet.iterations);
preds.nnet = capLog(predict(net, Xnv), y, cfg);
ladder = addRow(ladder, "8 Neural network (fitrnet)", "full", "log", yVal, preds.nnet, masks, toc(t));

% 9) Blend raw- and log-target boosted models; weight chosen on validation
weights = 0:0.1:1;
blendRmse = arrayfun(@(w) regMetrics(yVal, w*preds.fullRaw + (1-w)*preds.fullLog).rmse, weights);
[~, k] = min(blendRmse);
best.blendWeight = weights(k);
preds.blend = best.blendWeight*preds.fullRaw + (1-best.blendWeight)*preds.fullLog;
ladder = addRow(ladder, sprintf("9 Blend %.1f*raw + %.1f*log (6+7)", best.blendWeight, 1-best.blendWeight), ...
    "full", "blend", yVal, preds.blend, masks, 0);

fprintf("\nModel ladder (validation = Year_Factor %d):\n", cfg.valYear);
disp(ladder(:, {'model', 'features', 'target', 'rmse', 'rmse_testlike', 'rmse_history', 'rmse_coldstart'}));
end

function p = capLog(logPred, yTrain, cfg)
% Back-transform a log1p prediction, clamped to the observed EUI range: a
% small extrapolation error on the log scale becomes a huge one after expm1.
p = min(max(expm1(logPred), cfg.predFloor), max(yTrain));
end

function ladder = addRow(ladder, name, features, target, y, p, masks, seconds)
all_ = regMetrics(y, p);
tl   = regMetrics(y(masks.testLike), p(masks.testLike));
hi   = regMetrics(y(masks.history),  p(masks.history));
co   = regMetrics(y(~masks.history), p(~masks.history));
row = table(string(name), string(features), string(target), all_.rmse, all_.mae, all_.r2, ...
    tl.rmse, hi.rmse, co.rmse, seconds, 'VariableNames', {'model', 'features', 'target', ...
    'rmse', 'mae', 'r2', 'rmse_testlike', 'rmse_history', 'rmse_coldstart', 'train_seconds'});
ladder = [ladder; row];
fprintf("  %-40s RMSE %6.2f | test-like %6.2f | %5.1fs\n", name, all_.rmse, tl.rmse, seconds);
end
