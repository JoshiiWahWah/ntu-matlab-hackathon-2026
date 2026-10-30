function [train, test, sampleIds] = loadData(cfg)
%LOADDATA Read train/test CSVs with explicit types and verify the schema.
%   Categorical columns are read as categorical; everything else numeric.
%   Errors early (with a clear message) if the files are not the expected
%   WiDS Datathon 2022 data.

arguments
    cfg (1,1) struct
end

mustExist(cfg.trainFile);
mustExist(cfg.testFile);

catVars = ["State_Factor", "building_class", "facility_type"];

train = readTyped(cfg.trainFile, catVars);
test  = readTyped(cfg.testFile,  catVars);

required = ["id", "Year_Factor", catVars, "floor_area", "year_built", ...
    "energy_star_rating", "ELEVATION", "heating_degree_days", ...
    "cooling_degree_days", "january_avg_temp", "december_max_temp"];
missingTrain = setdiff([required "site_eui"], string(train.Properties.VariableNames));
missingTest  = setdiff(required, string(test.Properties.VariableNames));
if ~isempty(missingTrain) || ~isempty(missingTest)
    error("loadData:schema", "Missing columns. train: [%s] test: [%s]", ...
        strjoin(missingTrain, ", "), strjoin(missingTest, ", "));
end

% The test set has no target; add it as NaN so train/test share one schema.
test.site_eui = NaN(height(test), 1);
test = test(:, train.Properties.VariableNames);

% Submission ids: from sample_solution.csv if present, else the test ids.
if isfile(cfg.sampleFile)
    sample = readtable(cfg.sampleFile);
    sampleIds = sample.id;
    if ~isequal(sampleIds, test.id)
        error("loadData:ids", "test.csv ids do not match sample_solution.csv ids (order matters).");
    end
else
    sampleIds = test.id;
end

fprintf("Loaded train %d x %d, test %d x %d\n", height(train), width(train), ...
    height(test), width(test) - 1);
fprintf("  train ids %d-%d, years %s | test ids %d-%d, years %s\n", ...
    min(train.id), max(train.id), mat2str(unique(train.Year_Factor)'), ...
    min(test.id), max(test.id), mat2str(unique(test.Year_Factor)'));
end

function T = readTyped(file, catVars)
opts = detectImportOptions(file);
present = intersect(catVars, string(opts.VariableNames));
opts = setvartype(opts, cellstr(present), "categorical");
numericVars = setdiff(string(opts.VariableNames), catVars);
opts = setvartype(opts, cellstr(numericVars), "double");
try
    T = readtable(file, opts);
catch err
    error("loadData:read", "Could not read %s: %s", file, err.message);
end
end

function mustExist(file)
if ~isfile(file)
    error("loadData:missingFile", ...
        "%s not found. Put the WiDS 2022 train.csv and test.csv in the data/ folder (see data/README.md).", file);
end
end
