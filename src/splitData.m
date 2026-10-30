function [trn, val, full, tst] = splitData(data, cfg)
%SPLITDATA Temporal split that mirrors the real forecasting task.
%   trn  : Year_Factor <  valYear   (model development)
%   val  : Year_Factor == valYear   (holdout "next year")
%   full : all labelled years       (final model)
%   tst  : unlabelled test rows     (Year_Factor 7, never dropped/subsampled)

arguments
    data table
    cfg (1,1) struct
end

labelled = ~isnan(data.site_eui);
trn  = data(labelled & data.Year_Factor <  cfg.valYear, :);
val  = data(labelled & data.Year_Factor == cfg.valYear, :);
full = data(labelled, :);
tst  = data(~labelled, :);

if cfg.subsampleFrac < 1
    % QUICK mode only: subsample the training sets for a fast smoke test.
    trn  = trn(randperm(height(trn),  round(cfg.subsampleFrac*height(trn))), :);
    full = full(randperm(height(full), round(cfg.subsampleFrac*height(full))), :);
end

fprintf("Split: train (years < %d) %d rows | validation (year %d) %d rows | test %d rows\n", ...
    cfg.valYear, height(trn), cfg.valYear, height(val), height(tst));
end
