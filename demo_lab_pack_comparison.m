function [figures, series, comparisonFolder] = demo_lab_pack_comparison(demoFolder)
%DEMO_LAB_PACK_COMPARISON Compare two synthetic runs end to end.
%   DEMO_LAB_PACK_COMPARISON creates and compares two saved FIG trees in a
%   temporary folder. Pass a new folder name to keep the inputs and results.

    narginchk(0, 1);
    if nargin == 0
        demoFolder = tempname;
    end
    if isfolder(demoFolder) || isfile(demoFolder)
        error('demo_lab_pack_comparison:OutputExists', ...
            'Choose a new folder for the demo: %s', demoFolder);
    end

    baseline = fullfile(demoFolder, 'baseline-figs');
    candidate = fullfile(demoFolder, 'candidate-figs');
    mkdir(baseline);
    mkdir(candidate);
    createExampleRun(baseline, false);
    createExampleRun(candidate, true);

    baselinePack = fullfile(demoFolder, 'baseline-pack');
    candidatePack = fullfile(demoFolder, 'candidate-pack');
    export_lab_batch(baseline, baselinePack, 'DPI', 180, 'CombinePDF', false);
    export_lab_batch(candidate, candidatePack, 'DPI', 180, 'CombinePDF', false);

    comparisonFolder = fullfile(demoFolder, 'comparison');
    [figures, series] = compare_lab_packs(baselinePack, candidatePack, ...
        comparisonFolder, 'AbsTol', 0.015, 'RelTol', 0.02);
    fprintf('Comparison report: %s\n', fullfile(comparisonFolder, 'index.html'));
end

function createExampleRun(folder, isCandidate)
    time = 0:0.005:0.4;
    response = @(t) 1 - exp(-14*t).*cos(2*pi*8*t);
    writeFigure(folder, '01-reference.fig', 'Reference step response', time, response(time));

    overshoot = double(isCandidate)*0.09*exp(-((time - 0.09)/0.024).^2);
    writeFigure(folder, '02-controller-step.fig', 'Controller step response', ...
        time, response(time) + overshoot);

    if isCandidate
        time = 0:0.0125:0.4;
        writeFigure(folder, '05-new-probe.fig', 'New probe', time, response(time));
    else
        time = 0:0.01:0.4;
        writeFigure(folder, '04-legacy-probe.fig', 'Legacy probe', time, response(time));
    end
    writeFigure(folder, '03-sampling-grid.fig', 'Sampling grid example', time, response(time));
end

function writeFigure(folder, name, heading, t, values)
    fig = figure('Visible', 'off', 'Color', 'white', 'Position', [100, 100, 700, 390]);
    cleanup = onCleanup(@() delete(fig));
    ax = axes(fig);
    plot(ax, t, values, 'Color', [0.10, 0.35, 0.57], 'LineWidth', 2, ...
        'DisplayName', 'Output signal');
    title(ax, heading);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Output (p.u.)');
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [0, 0.4]);
    ylim(ax, [0, 1.65]);
    savefig(fig, fullfile(folder, name));
end
