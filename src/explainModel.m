function [importance, pd] = explainModel(mdl, X, cfg)
%EXPLAINMODEL Predictor importance + partial dependence for a tree ensemble.
%   Partial dependence is computed directly: set one variable to a grid value
%   for every building, predict, average. This shows the model's learned
%   physical response (e.g. EUI vs heating degree days).

arguments
    mdl
    X table
    cfg (1,1) struct
end

imp = predictorImportance(mdl);
importance = table(string(mdl.PredictorNames(:)), imp(:), 'VariableNames', {'predictor', 'importance'});
importance = sortrows(importance, 'importance', 'descend');

nSample = min(1000, height(X));
Xs = X(randperm(height(X), nSample), :);
pdVars = {'heating_degree_days', 'cooling_degree_days', 'energy_star_rating', 'building_age', 'prev_eui'};
pdVars = pdVars(ismember(pdVars, X.Properties.VariableNames));
pd = struct('var', {}, 'grid', {}, 'response', {});
for k = 1:numel(pdVars)
    v = pdVars{k};
    x = X.(v);
    x = x(x ~= missingSentinel());     % grid over real values only
    gridVals = linspace(prctile(x, 2), prctile(x, 98), 25)';
    resp = zeros(size(gridVals));
    Xg = Xs;
    for g = 1:numel(gridVals)
        Xg.(v)(:) = gridVals(g);
        resp(g) = mean(predict(mdl, Xg));
    end
    pd(end+1) = struct('var', v, 'grid', gridVals, 'response', resp); %#ok<AGROW>
end
fprintf("\nTop 10 predictors (boosted trees, full features):\n");
disp(importance(1:min(10, height(importance)), :));
end
