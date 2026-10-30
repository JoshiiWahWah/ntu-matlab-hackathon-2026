function [Xtrain, Xother] = imputeMedian(Xtrain, Xother)
%IMPUTEMEDIAN Fill numeric NaNs with medians learned on the TRAINING rows only
%   (used for linear and neural-net models, which cannot take NaN inputs).

arguments
    Xtrain table
    Xother table
end

names = Xtrain.Properties.VariableNames;
for k = 1:numel(names)
    v = names{k};
    if isnumeric(Xtrain.(v))
        med = median(Xtrain.(v), 'omitnan');
        if isnan(med)
            med = 0;
        end
        Xtrain.(v)(isnan(Xtrain.(v))) = med;
        Xother.(v)(isnan(Xother.(v))) = med;
    end
end
end
