function makeEdaFigures(data, cfg)
%MAKEEDAFIGURES Exploratory figures that motivate the cleaning/validation choices.

arguments
    data table
    cfg (1,1) struct
end

isTrain = ~isnan(data.site_eui);
tr = data(isTrain, :);

% 1) Target distribution: right-skewed -> motivates a log-target model
f = figure('Visible', 'off', 'Position', [100 100 1000 380]);
tiledlayout(f, 1, 2);
nexttile; histogram(tr.site_eui, 120, 'FaceColor', [0.2 0.45 0.7], 'EdgeColor', 'none');
xlabel('site EUI (kBtu/ft^2/yr)'); ylabel('buildings'); title('Target is right-skewed'); xlim([0 400]);
nexttile; histogram(log1p(tr.site_eui), 120, 'FaceColor', [0.85 0.4 0.2], 'EdgeColor', 'none');
xlabel('log(1 + site EUI)'); ylabel('buildings'); title('Log scale is near-symmetric');
saveFig(f, cfg, '01_target_distribution');

% 2) Train vs test state mix: State_6 is absent from test
f = figure('Visible', 'off', 'Position', [100 100 800 380]);
states = categories(data.State_Factor);
pctTr = 100*countcats(data.State_Factor(isTrain))  / nnz(isTrain);
pctTe = 100*countcats(data.State_Factor(~isTrain)) / nnz(~isTrain);
bar(categorical(states), [pctTr pctTe]);
legend({'train (years 1-6)', 'test (year 7)'}, 'Location', 'northwest');
ylabel('% of rows');
s6 = strcmp(states, 'State_6');
title(sprintf('State mix shifts: State\\_6 is %.0f%% of train, %.0f%% of test', pctTr(s6), pctTe(s6)));
saveFig(f, cfg, '02_state_shift');

% 3) Missingness train vs test
vars = {'energy_star_rating', 'year_built'};
missTr = 100*mean(isnan(data{isTrain, vars}), 1);
missTe = 100*mean(isnan(data{~isTrain, vars}), 1);
f = figure('Visible', 'off', 'Position', [100 100 700 380]);
bar(categorical(strrep(vars, '_', ' ')), [missTr' missTe']);
legend({'train', 'test'}); ylabel('% missing'); title('Missing values (after cleaning)');
saveFig(f, cfg, '03_missingness');

% 4) EUI by facility type (12 most common)
counts = countcats(tr.facility_type);
names  = categories(tr.facility_type);
[~, idx] = sort(counts, 'descend');
top = names(idx(1:min(12, numel(names))));
keep = ismember(tr.facility_type, top);
ft = removecats(tr.facility_type(keep));
f = figure('Visible', 'off', 'Position', [100 100 1100 450]);
boxchart(ft, tr.site_eui(keep), 'MarkerStyle', 'none');
ylim([0 300]); ylabel('site EUI (kBtu/ft^2/yr)'); title('Energy use depends strongly on what the building is used for');
set(gca, 'TickLabelInterpreter', 'none');
saveFig(f, cfg, '04_eui_by_facility');

% 5) Physics check: EUI vs heating degree days
f = figure('Visible', 'off', 'Position', [100 100 700 450]);
edges = prctile(tr.heating_degree_days, 0:5:100);
bin = discretize(tr.heating_degree_days, unique(edges));
ok = ~isnan(bin);
medEui = accumarray(bin(ok), tr.site_eui(ok), [], @median);
medHdd = accumarray(bin(ok), tr.heating_degree_days(ok), [], @median);
plot(medHdd, medEui, 'o-', 'LineWidth', 1.5);
xlabel('heating degree days (annual)'); ylabel('median site EUI (kBtu/ft^2/yr)');
title('Colder climate -> more heating energy (Q \propto UA\cdotHDD)'); grid on;
saveFig(f, cfg, '05_eui_vs_hdd');
end
