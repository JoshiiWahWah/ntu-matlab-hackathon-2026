classdef PipelineTest < matlab.unittest.TestCase
    %PIPELINETEST Unit tests for the building-energy pipeline.
    %   Run from the repo root with:  results = runtests('tests')

    properties
        cfg
    end

    methods (TestClassSetup)
        function addPaths(tc)
            root = fileparts(fileparts(mfilename("fullpath")));
            addpath(root, fullfile(root, "src"));
            tc.cfg = config(true);
        end
    end

    methods (Test)
        function metricsAreCorrect(tc)
            m = regMetrics([1; 2; 3], [1; 2; 5]);
            tc.verifyEqual(m.rmse, sqrt(4/3), 'AbsTol', 1e-12);
            tc.verifyEqual(m.mae, 2/3, 'AbsTol', 1e-12);
        end

        function historyIsCausal(tc)
            % Building 1 seen in years 1, 2, 2 (duplicate), 3; test row in year 4.
            T = table([1; 2; 2; 3; 4], [10; 20; 30; 40; NaN], 'VariableNames', {'Year_Factor', 'site_eui'});
            T.State_Factor   = categorical(repmat("S", 5, 1));
            T.building_class = categorical(repmat("C", 5, 1));
            T.facility_type  = categorical(repmat("F", 5, 1));
            T.floor_area = repmat(1000, 5, 1); T.year_built = repmat(1990, 5, 1); T.ELEVATION = zeros(5, 1);
            months = ["january", "february", "march", "april", "may", "june", "july", ...
                "august", "september", "october", "november", "december"];
            for v = [months + "_min_temp", months + "_avg_temp", months + "_max_temp"]
                T.(v) = zeros(5, 1);
            end
            T.heating_degree_days = ones(5, 1); T.cooling_degree_days = ones(5, 1);
            T = makeFeatures(T);
            tc.verifyTrue(isnan(T.prev_eui(1)));          % no history in first year
            tc.verifyEqual(T.prev_eui(2:3), [10; 10]);    % same-year duplicates never see each other
            tc.verifyEqual(T.prev_eui(4), 25);            % mean of the two year-2 rows
            tc.verifyEqual(T.prev_mean_eui(5), 25);       % (10+20+30+40)/4
            tc.verifyEqual(T.n_prev_years(5), 4);
        end

        function validatorRejectsBadFile(tc)
            f = [tempname '.csv'];
            writetable(table([1; 2], [5; NaN], 'VariableNames', {'id', 'site_eui'}), f);
            threw = false;
            try
                validateSubmission(f, [1; 2]);
            catch
                threw = true;
            end
            tc.verifyTrue(threw, "NaN prediction must be rejected");
            writetable(table([1; 2], [5; 6], 'VariableNames', {'id', 'site_eui'}), f);
            validateSubmission(f, [1; 2]);   % must not error
            delete(f);
        end

        function dataLoadsIfPresent(tc)
            tc.assumeTrue(isfile(tc.cfg.trainFile) && isfile(tc.cfg.testFile), ...
                "data/train.csv and data/test.csv not present");
            [train, test] = loadData(tc.cfg);
            tc.verifyTrue(ismember('site_eui', train.Properties.VariableNames));
            tc.verifyTrue(all(isnan(test.site_eui)));
            tc.verifyClass(train.facility_type, 'categorical');
        end

        function submissionValidIfPresent(tc)
            sub = fullfile(tc.cfg.resultsDir, "submission.csv");
            tc.assumeTrue(isfile(sub) && isfile(tc.cfg.sampleFile), "no submission yet");
            sample = readtable(tc.cfg.sampleFile);
            ids = sample.id;
            validateSubmission(sub, ids);
        end
    end
end
