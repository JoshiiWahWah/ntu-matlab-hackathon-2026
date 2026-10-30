function [candidates, summary] = retrofitAnalysis(val, coldPred, cfg)
%RETROFITANALYSIS Flag buildings that use far more energy than expected.
%   Expected EUI comes from the COLD-START model (no ENERGY STAR rating, no
%   energy history), trained on earlier years and applied out-of-sample to
%   the validation year: "what a typical building of this type, size, age
%   and climate uses". Excess = actual - expected. The top 5% within each
%   facility type are retrofit candidates; ranking is by total excess energy
%   (excess EUI x floor area), i.e. where a retrofit saves the most kBtu.

arguments
    val table
    coldPred (:,1) double
    cfg (1,1) struct
end

T = val(:, {'id', 'State_Factor', 'building_class', 'facility_type', 'floor_area', ...
    'year_built', 'energy_star_rating', 'site_eui'});
T.expected_eui = coldPred;
T.excess_eui   = T.site_eui - T.expected_eui;
T.excess_kbtu  = T.excess_eui .* T.floor_area;

% Top 5% excess EUI within each facility type
[g, ~] = findgroups(T.facility_type);
thresh = splitapply(@(x) prctile(x, 95), T.excess_eui, g);
T.is_candidate = T.excess_eui >= thresh(g) & T.excess_eui > 0;

candidates = sortrows(T(T.is_candidate, :), 'excess_kbtu', 'descend');
summary.nCandidates     = height(candidates);
summary.totalExcessKbtu = sum(candidates.excess_kbtu);
summary.shareOfAllEnergy = summary.totalExcessKbtu / sum(T.site_eui .* T.floor_area);
fprintf("\nRetrofit shortlist: %d candidate buildings, %.3g kBtu/yr excess (%.1f%% of all energy in year %d)\n", ...
    summary.nCandidates, summary.totalExcessKbtu, 100*summary.shareOfAllEnergy, cfg.valYear);
end
