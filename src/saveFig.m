function saveFig(f, cfg, name)
%SAVEFIG Export a figure as PNG into figures/ and close it.

arguments
    f (1,1) matlab.ui.Figure
    cfg (1,1) struct
    name (1,1) string
end

file = fullfile(cfg.figDir, name + ".png");
exportgraphics(f, file, 'Resolution', 150);
close(f);
end
