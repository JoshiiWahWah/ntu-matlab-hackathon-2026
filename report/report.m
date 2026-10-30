%% Predicting Building Energy Consumption -- Results Report
% NTU "Learn to Hack: MATLAB Edition 2026". Run |main| first, then publish:
%
%   publish('report/report.m', 'outputDir', 'report', 'format', 'html')
%
% Every number below is read from the files written by |main.m|.

root = fileparts(fileparts(mfilename("fullpath")));
res  = fullfile(root, "results");
figs = fullfile(root, "figures");
showFig = @(name) imshow(imread(fullfile(figs, name + ".png")));

%% 1. The problem
% Buildings are major contributors to energy use and carbon emissions. We
% predict a building's annual site Energy Use Intensity (EUI, kBtu/ft^2/yr)
% from its characteristics and local weather (WiDS Datathon 2022), and use
% the model to find buildings that use far more energy than they should.

%% 2. Data: what we found and how we cleaned it
decisions = readtable(fullfile(res, "decisions.csv"), "TextType", "string");
disp(decisions)
figure; showFig("01_target_distribution");
figure; showFig("02_state_shift");
figure; showFig("05_eui_vs_hdd");

%% 3. Validation design
% We train on Year_Factor 1-5 and validate on Year_Factor 6, which mirrors
% the real task (forecasting the unseen Year_Factor 7). Because State_6 is
% absent from the test set, we also report a "test-like" score without it.
schemes = readtable(fullfile(res, "validation_schemes.csv"), "TextType", "string");
disp(schemes)

%% 4. Model ladder
ladder = readtable(fullfile(res, "results.csv"), "TextType", "string");
disp(ladder(:, ["model", "features", "target", "rmse", "mae", "r2", "rmse_testlike"]))
figure; showFig("06_model_ladder");
figure; showFig("08_history_vs_coldstart");
figure; showFig("07_pred_vs_actual");

%% 5. What drives energy use
figure; showFig("10_importance");
figure; showFig("11_partial_dependence");

%% 6. Retrofit shortlist
retrofit = readtable(fullfile(res, "retrofit_top20.csv"), "TextType", "string");
disp(retrofit(:, ["id", "facility_type", "floor_area", "site_eui", "expected_eui", "excess_kbtu"]))
figure; showFig("12_retrofit_shortlist");
