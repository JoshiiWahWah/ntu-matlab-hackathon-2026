function validateSubmission(file, expectedIds)
%VALIDATESUBMISSION Assert the submission file is exactly what is expected.

arguments
    file (1,1) string
    expectedIds (:,1) double
end

if ~isfile(file)
    error("validateSubmission:missing", "%s does not exist.", file);
end
sub = readtable(file);
assert(isequal(sub.Properties.VariableNames, {'id', 'site_eui'}), ...
    "Header must be exactly id,site_eui");
assert(height(sub) == numel(expectedIds), ...
    "Expected %d rows, found %d", numel(expectedIds), height(sub));
assert(isequal(sub.id, expectedIds), "ids differ from sample_solution (values or order)");
assert(isnumeric(sub.site_eui) && all(isfinite(sub.site_eui)), "site_eui has NaN/Inf");
assert(all(sub.site_eui > 0), "site_eui has non-positive values");
fprintf("validateSubmission: PASS (%d rows, site_eui range %.1f-%.1f)\n", ...
    height(sub), min(sub.site_eui), max(sub.site_eui));
end
