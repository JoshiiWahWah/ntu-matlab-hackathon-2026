function [data, featureSets, keyStats] = makeFeatures(data)
%MAKEFEATURES Physics-informed features + causal building-history features.
%
%   Energy balance: annual heating/cooling energy ~ UA * (degree-days), so
%   per-area energy (EUI) depends on climate severity (HDD/CDD, seasonal
%   temperatures) and on building type/age (envelope quality, internal gains).
%
%   Building history: the same building re-appears in several years, but no
%   building id is given. We reconstruct one from static attributes and add
%   its PAST energy use. Lags only ever use strictly earlier Year_Factors, so
%   they are known at prediction time (legitimate forecasting, not leakage).

arguments
    data table
end

months = ["january", "february", "march", "april", "may", "june", "july", ...
    "august", "september", "october", "november", "december"];
avgT = data{:, cellstr(months + "_avg_temp")};
minT = data{:, cellstr(months + "_min_temp")};
maxT = data{:, cellstr(months + "_max_temp")};

% --- Climate features --------------------------------------------------
data.winter_avg_temp   = mean(avgT(:, [12 1 2]), 2);
data.summer_avg_temp   = mean(avgT(:, 6:8), 2);
data.annual_temp_range = max(maxT, [], 2) - min(minT, [], 2);
data.total_degree_days = data.heating_degree_days + data.cooling_degree_days;
data.cooling_share     = data.cooling_degree_days ./ max(data.total_degree_days, 1);

% --- Building features -------------------------------------------------
data.log_floor_area = log(data.floor_area);
% Year_Factor is anonymised, so age is relative to the newest building.
data.building_age   = max(data.year_built) - data.year_built;

% --- Reconstructed building id + causal lag features --------------------
key = string(data.State_Factor) + "|" + string(data.building_class) + "|" + ...
      string(data.facility_type) + "|" + compose("%.4f", data.floor_area) + "|" + ...
      compose("%.1f", data.year_built) + "|" + compose("%.4f", data.ELEVATION);
data.building_id = findgroups(key);
[data.prev_eui, data.prev_mean_eui, data.n_prev_years, data.years_since_prev] = ...
    historyFeatures(data.building_id, data.Year_Factor, data.site_eui);
data.has_history = double(data.n_prev_years > 0);

nYears = splitapply(@(y) numel(unique(y)), data.Year_Factor, data.building_id);
[~, ~, dupWithinYear] = unique([data.building_id data.Year_Factor], "rows");
keyStats.nBuildings      = max(data.building_id);
keyStats.multiYearShare  = mean(nYears > 1);
keyStats.dupWithinYear   = height(data) - max(dupWithinYear);
keyStats.testWithHistory = mean(data.has_history(isnan(data.site_eui)));
fprintf("  building key: %d buildings, %.1f%% seen in >1 year, %d same-year duplicates\n", ...
    keyStats.nBuildings, 100*keyStats.multiYearShare, keyStats.dupWithinYear);
fprintf("  test rows with past energy history: %.1f%%\n", 100*keyStats.testWithHistory);

% --- Feature sets ------------------------------------------------------
weather = [cellstr(months + "_min_temp"), cellstr(months + "_avg_temp"), ...
    cellstr(months + "_max_temp"), {'cooling_degree_days', 'heating_degree_days', ...
    'precipitation_inches', 'snowfall_inches', 'snowdepth_inches', 'avg_temp', ...
    'days_below_30F', 'days_below_20F', 'days_below_10F', 'days_below_0F', ...
    'days_above_80F', 'days_above_90F', 'days_above_100F', 'days_above_110F'}];
static  = {'State_Factor', 'building_class', 'facility_type', 'floor_area', ...
    'year_built', 'ELEVATION', 'year_built_missing'};
physics = {'winter_avg_temp', 'summer_avg_temp', 'annual_temp_range', ...
    'total_degree_days', 'cooling_share', 'log_floor_area', 'building_age'};
esr     = {'energy_star_rating', 'esr_missing'};
history = {'prev_eui', 'prev_mean_eui', 'n_prev_years', 'years_since_prev', 'has_history'};

% "coldStart": what we know about a NEW, never-benchmarked building.
featureSets.coldStart = [static, weather, physics];
featureSets.withESR   = [static, weather, physics, esr];
featureSets.full      = [static, weather, physics, esr, history];
end

function [prevE, prevMean, nPrev, gap] = historyFeatures(bid, year, eui)
% One pass over rows sorted by (building, year). Rows of the same year are
% buffered and only committed to the history once the year changes, so a
% row never sees its own year's energy use.
n = numel(bid);
prevE = NaN(n, 1); prevMean = NaN(n, 1); nPrev = zeros(n, 1); gap = NaN(n, 1);
[~, order] = sortrows([bid year]);

curB = -1;
for j = 1:n
    i = order(j);
    if bid(i) ~= curB
        curB = bid(i); curY = year(i);
        histSum = 0; histCnt = 0; lastE = NaN; lastY = NaN;
        yearSum = 0; yearCnt = 0;
    elseif year(i) ~= curY
        if yearCnt > 0
            lastE = yearSum / yearCnt; lastY = curY;
            histSum = histSum + yearSum; histCnt = histCnt + yearCnt;
        end
        curY = year(i); yearSum = 0; yearCnt = 0;
    end
    prevE(i) = lastE;
    if histCnt > 0
        prevMean(i) = histSum / histCnt;
    end
    nPrev(i) = histCnt;
    gap(i)   = year(i) - lastY;
    if ~isnan(eui(i))
        yearSum = yearSum + eui(i); yearCnt = yearCnt + 1;
    end
end
end
