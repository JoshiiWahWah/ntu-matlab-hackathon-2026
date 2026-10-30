function mdl = fitBoost(X, y, cfg)
%FITBOOST Least-squares gradient-boosted regression trees (LSBoost).
%   Trees handle NaN predictors and categorical variables natively, so no
%   imputation is needed for this model family.

arguments
    X table
    y (:,1) double
    cfg (1,1) struct
end

tree = templateTree('MaxNumSplits', cfg.boost.maxSplits, 'MinLeafSize', cfg.boost.minLeaf);
mdl  = fitrensemble(X, y, 'Method', 'LSBoost', 'Learners', tree, ...
    'NumLearningCycles', cfg.boost.cycles, 'LearnRate', cfg.boost.learnRate);
end
