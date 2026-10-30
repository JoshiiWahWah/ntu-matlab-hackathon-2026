function makeResultFigures(ladder, cmp, val, preds, importance, pd, candidates, cfg)
%MAKERESULTFIGURES Figures for the model ladder, accuracy, explanations and retrofit.

arguments
    ladder table
    cmp table
    val table
    preds (1,1) struct
    importance table
    pd struct
    candidates table
    cfg (1,1) struct
end

% 6) Model ladder
f = figure('Visible', 'off', 'Position', [100 100 1100 480]);
names = categorical(ladder.model);
names = reordercats(names, cellstr(ladder.model));
b = bar(names, [ladder.rmse ladder.rmse_testlike]);
b(1).FaceColor = [0.2 0.45 0.7]; b(2).FaceColor = [0.85 0.4 0.2];
legend({'all validation buildings', 'test-like (non-State\_6)'}, 'Location', 'northeast');
ylabel(sprintf('RMSE on year %d (kBtu/ft^2/yr)', cfg.valYear));
title('Model ladder: every step is validated on an unseen year'); grid on;
set(gca, 'TickLabelInterpreter', 'none');
saveFig(f, cfg, '06_model_ladder');

% 7) Predicted vs actual for the final (blend) model
f = figure('Visible', 'off', 'Position', [100 100 600 560]);
scatter(val.site_eui, preds.blend, 6, [0.2 0.45 0.7], 'filled', 'MarkerFaceAlpha', 0.3);
hold on; plot([0 400], [0 400], 'k--'); hold off;
xlim([0 400]); ylim([0 400]); axis square; grid on;
xlabel('actual site EUI'); ylabel('predicted site EUI');
m = regMetrics(val.site_eui, preds.blend);
title(sprintf('Year %d holdout: RMSE %.1f, R^2 %.2f', cfg.valYear, m.rmse, m.r2));
saveFig(f, cfg, '07_pred_vs_actual');

% 8) History vs cold start
f = figure('Visible', 'off', 'Position', [100 100 700 420]);
rows = ladder.features == "coldStart" | ladder.features == "withESR" | startsWith(ladder.model, "9");
sub = ladder(rows, :);
groups = ["new building (no rating, no history)", "+ ENERGY STAR rating", "+ rating + past energy use"];
bar(categorical(groups, groups), [sub.rmse_coldstart sub.rmse_history]);
legend({'buildings without history', 'buildings with history'}, 'Location', 'northeast');
ylabel('RMSE (kBtu/ft^2/yr)'); title('Knowing a building''s past is the strongest signal'); grid on;
saveFig(f, cfg, '08_history_vs_coldstart');

% 9) Random vs temporal validation
f = figure('Visible', 'off', 'Position', [100 100 650 400]);
bar(categorical(cmp.scheme), cmp.rmse, 'FaceColor', [0.5 0.5 0.5]);
ylabel('RMSE (kBtu/ft^2/yr)'); title('Random split vs temporal split (same model)');
set(gca, 'TickLabelInterpreter', 'none'); grid on;
saveFig(f, cfg, '09_validation_schemes');

% 10) Predictor importance
top = importance(1:min(15, height(importance)), :);
f = figure('Visible', 'off', 'Position', [100 100 750 520]);
barh(categorical(top.predictor, flipud(top.predictor)), top.importance);
xlabel('importance (reduction in MSE)'); title('What drives energy use (boosted trees)');
set(gca, 'TickLabelInterpreter', 'none');
saveFig(f, cfg, '10_importance');

% 11) Partial dependence
f = figure('Visible', 'off', 'Position', [100 100 1200 360]);
tiledlayout(f, 1, numel(pd));
for k = 1:numel(pd)
    nexttile; plot(pd(k).grid, pd(k).response, 'LineWidth', 2); grid on;
    xlabel(strrep(pd(k).var, '_', ' ')); ylabel('predicted EUI');
end
sgtitle('Partial dependence: the model learned physically sensible responses');
saveFig(f, cfg, '11_partial_dependence');

% 12) Retrofit shortlist
top = candidates(1:min(15, height(candidates)), :);
labels = "id " + string(top.id) + " (" + string(top.facility_type) + ")";
f = figure('Visible', 'off', 'Position', [100 100 900 520]);
barh(categorical(labels, flipud(labels)), top.excess_kbtu / 1e6, 'FaceColor', [0.85 0.4 0.2]);
xlabel('excess energy vs expected (million kBtu/yr)');
title('Retrofit shortlist: biggest absolute energy savings opportunities');
set(gca, 'TickLabelInterpreter', 'none');
saveFig(f, cfg, '12_retrofit_shortlist');
end
