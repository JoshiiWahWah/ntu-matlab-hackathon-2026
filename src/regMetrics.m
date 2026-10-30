function m = regMetrics(y, p)
%REGMETRICS RMSE (official WiDS metric), MAE and R^2 on the original scale.

arguments
    y (:,1) double
    p (:,1) double
end

err    = y - p;
m.rmse = sqrt(mean(err.^2));
m.mae  = mean(abs(err));
m.r2   = 1 - sum(err.^2) / sum((y - mean(y)).^2);
end
