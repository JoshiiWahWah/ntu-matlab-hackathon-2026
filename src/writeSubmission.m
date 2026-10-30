function writeSubmission(ids, pred, file)
%WRITESUBMISSION Write a Kaggle-format submission: header "id,site_eui".

arguments
    ids (:,1) double
    pred (:,1) double
    file (1,1) string
end

sub = table(ids, pred, 'VariableNames', {'id', 'site_eui'});
writetable(sub, file);
fprintf("Wrote %s (%d rows)\n", file, height(sub));
end
