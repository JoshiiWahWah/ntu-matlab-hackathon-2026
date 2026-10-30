function cfg = config(quick)
%CONFIG Central settings for the building-energy pipeline.
%   cfg = config()       full run (used for the reported results)
%   cfg = config(true)   QUICK smoke run: subsampled rows, few trees (~1-2 min)

arguments
    quick (1,1) logical = false
end

root = fileparts(mfilename("fullpath"));

cfg.quick       = quick;
cfg.seed        = 42;
cfg.root        = root;
cfg.dataDir     = fullfile(root, "data");
cfg.figDir      = fullfile(root, "figures");
cfg.resultsDir  = fullfile(root, "results");
cfg.trainFile   = fullfile(cfg.dataDir, "train.csv");
cfg.testFile    = fullfile(cfg.dataDir, "test.csv");
cfg.sampleFile  = fullfile(cfg.dataDir, "sample_solution.csv");

% Validation design: train on Year_Factor <= 5, validate on Year_Factor 6
% (mirrors the real task of forecasting the unseen Year_Factor 7).
cfg.valYear     = 6;

% Facility types with fewer training rows than this are pooled into "Other".
cfg.minFacilityCount = 50;

% Gradient-boosted trees (LSBoost). Moderate depth + shrinkage; kept fixed so
% every rung of the ladder is compared on equal terms.
cfg.boost.cycles      = 300;
cfg.boost.learnRate   = 0.08;
cfg.boost.maxSplits   = 63;
cfg.boost.minLeaf     = 20;

cfg.bag.cycles        = 60;
cfg.bag.minLeaf       = 10;

cfg.tree.minLeaf      = 20;

cfg.nnet.layers       = [64 32];
cfg.nnet.lambda       = 1e-4;
cfg.nnet.iterations   = 300;

% Physical floor for predictions (EUI cannot be negative; min observed ~1).
cfg.predFloor = 1;

if quick
    cfg.subsampleFrac     = 0.25;
    cfg.boost.cycles      = 60;
    cfg.boost.learnRate   = 0.2;
    cfg.bag.cycles        = 10;
    cfg.nnet.iterations   = 30;
else
    cfg.subsampleFrac     = 1;
end
end
