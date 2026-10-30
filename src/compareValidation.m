function cmp = compareValidation(full, temporalRmse, featureSets, cfg)
%COMPAREVALIDATION Show why a random split would fool us.
%   A random 80/20 split puts other years of the SAME building in training,
%   so the model partly memorises buildings. The temporal split (train on
%   past years, test on the next) is the honest estimate for forecasting
%   year 7. Same model and features in both cases (boosted, withESR).

arguments
    full table
    temporalRmse (1,1) double
    featureSets (1,1) struct
    cfg (1,1) struct
end

part = cvpartition(height(full), 'HoldOut', 0.2);
Xtr  = treeInputs(full(training(part), :), featureSets.withESR);
Xte  = treeInputs(full(test(part), :), featureSets.withESR);
mdl  = fitBoost(Xtr, full.site_eui(training(part)), cfg);
m    = regMetrics(full.site_eui(test(part)), predict(mdl, Xte));

cmp = table(["Random 80/20 split (all years)"; sprintf("Temporal: train years < %d, test year %d", ...
    cfg.valYear, cfg.valYear)], [m.rmse; temporalRmse], 'VariableNames', {'scheme', 'rmse'});
fprintf("\nValidation scheme comparison (boosted trees, withESR features):\n");
disp(cmp);
end
