function [data, decisions] = cleanData(train, test, cfg)
%CLEANDATA Combine train+test and apply evidence-based cleaning steps.
%   Every decision is logged (with the number that justifies it) to the
%   DECISIONS table, which main.m writes to results/decisions.csv.
%   No target value is altered and no test row is ever dropped.

arguments
    train table
    test table
    cfg (1,1) struct
end

data = [train; test];
isTrain = ~isnan(data.site_eui);
decisions = table('Size', [0 3], 'VariableTypes', ["string", "string", "string"], ...
    'VariableNames', ["decision", "evidence", "rubric"]);

% 1) year_built = 0 is not a real construction year -> missing.
bad = data.year_built <= 0;
data.year_built(bad) = NaN;
decisions = logDecision(decisions, "year_built <= 0 set to missing", ...
    sprintf("%d rows had year_built <= 0", nnz(bad)), "Data Mastery: cleaning");

% 2) Missingness indicators BEFORE any imputation: whether a building has an
%    ENERGY STAR rating is itself informative (it must have been benchmarked).
data.esr_missing        = double(isnan(data.energy_star_rating));
data.year_built_missing = double(isnan(data.year_built));
decisions = logDecision(decisions, "Added missingness indicators (energy_star_rating, year_built)", ...
    sprintf("energy_star_rating missing: %.1f%% train / %.1f%% test", ...
    100*mean(data.esr_missing(isTrain)), 100*mean(data.esr_missing(~isTrain))), ...
    "Data Mastery: processing");

% 3) Wind/fog columns: heavily missing AND the missingness pattern shifts
%    between train and test, so a model would learn a spurious signal.
windVars = ["direction_max_wind_speed", "direction_peak_wind_speed", ...
    "max_wind_speed", "days_with_fog"];
windVars = intersect(windVars, string(data.Properties.VariableNames), "stable");
missTr = 100*mean(isnan(data{isTrain, cellstr(windVars)}), "all");
missTe = 100*mean(isnan(data{~isTrain, cellstr(windVars)}), "all");
data = removevars(data,cellstr(windVars));
decisions = logDecision(decisions, "Dropped wind/fog columns", ...
    sprintf("missing %.1f%% in train vs %.1f%% in test (distribution shift)", missTr, missTe), ...
    "Data Mastery: cleaning");

% 4) Pool rare facility types (counts from training rows only).
counts = countcats(data.facility_type(isTrain));
names  = categories(data.facility_type);
rare   = names(counts < cfg.minFacilityCount);
if ~isempty(rare)
    data.facility_type = mergecats(data.facility_type, rare, 'Other_rare');
end
decisions = logDecision(decisions, ...
    sprintf("Pooled facility types with < %d training rows into Other_rare", cfg.minFacilityCount), ...
    sprintf("%d of %d types pooled (%d rows)", numel(rare), numel(names), ...
    sum(counts(counts < cfg.minFacilityCount))), "Data Mastery: processing");

% 5) Keep extreme EUI values: they are plausible (labs, data centres, food
%    service) and the metric (RMSE) is computed on them too.
decisions = logDecision(decisions, "Kept extreme site_eui values (no clipping of the target)", ...
    sprintf("max %.1f, 99.9th pct %.1f kBtu/ft2/yr", max(data.site_eui(isTrain)), ...
    prctile(data.site_eui(isTrain), 99.9)), "Data Mastery: cleaning");

% 6) State mix: State_6 dominates training but is absent from the test set.
s6Train = 100*mean(data.State_Factor(isTrain) == 'State_6');
s6Test  = 100*mean(data.State_Factor(~isTrain) == 'State_6');
decisions = logDecision(decisions, ...
    "Report a 'test-like' validation score on non-State_6 buildings", ...
    sprintf("State_6 is %.1f%% of train but %.1f%% of test", s6Train, s6Test), ...
    "Data Mastery: separating");
end

function d = logDecision(d, decision, evidence, rubric)
d = [d; {string(decision), string(evidence), string(rubric)}];
fprintf("  [decision] %s -- %s\n", decision, evidence);
end
