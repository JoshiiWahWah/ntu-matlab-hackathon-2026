function X = treeInputs(T, vars)
%TREEINPUTS Predictor table for tree models with missing values encoded.
%   Without surrogate splits, a MATLAB tree stops an observation at the
%   first node that splits on a predictor it is missing, and predicts that
%   node's mean. With energy_star_rating (35% missing) and the history
%   features (~60% missing) among the strongest predictors, those buildings
%   would barely be learned. Encoding NaN as an out-of-range sentinel lets
%   each split decide which side missing values belong on (the *_missing and
%   has_history flags are kept as explicit predictors too).

arguments
    T table
    vars cell
end

X = T(:, vars);
for k = 1:numel(vars)
    v = vars{k};
    if isnumeric(X.(v))
        x = X.(v);
        x(isnan(x)) = missingSentinel();
        X.(v) = x;
    end
end
end
