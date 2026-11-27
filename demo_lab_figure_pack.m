function [report, packFolder] = demo_lab_figure_pack(demoFolder)
%DEMO_LAB_FIGURE_PACK Generate two synthetic FIG files and a sample pack.
%   [REPORT, PACKFOLDER] = DEMO_LAB_FIGURE_PACK creates a temporary demo.
%   To keep the sample in your current folder, supply a new directory name,
%   for example DEMO_LAB_FIGURE_PACK('figure-pack-demo').

    narginchk(0, 1);
    if nargin == 0
        demoFolder = tempname;
    end
    if isfolder(demoFolder) || isfile(demoFolder)
        error('demo_lab_figure_pack:OutputExists', ...
            'Choose a new folder for the demo: %s', demoFolder);
    end

    inputFolder = fullfile(demoFolder, 'fig-input');
    signalFolder = fullfile(inputFolder, '01-signals');
    responseFolder = fullfile(inputFolder, '02-response');
    mkdir(signalFolder);
    mkdir(responseFolder);

    saveSignalFigure(fullfile(signalFolder, 'sine-traces.fig'));
    saveFilterFigure(fullfile(responseFolder, 'rc-low-pass.fig'));

    packFolder = fullfile(demoFolder, 'figure-pack');
    report = export_lab_batch(inputFolder, packFolder);
    fprintf('Figure gallery: %s\n', fullfile(packFolder, 'index.html'));
end

function saveSignalFigure(path)
    fig = figure('Visible', 'off', 'Color', 'white', ...
        'Position', [100, 100, 760, 410]);
    cleanup = onCleanup(@() delete(fig));
    ax = axes('Parent', fig);
    referenceTime = 0:0.2:80;
    sampledTime = 0:1.25:80;
    tone = @(time) sin(2*pi*50*time/1000);

    plot(ax, referenceTime, tone(referenceTime), 'Color', [0.08, 0.36, 0.55], ...
        'LineWidth', 2, 'DisplayName', '5 kHz reference');
    hold(ax, 'on');
    plot(ax, sampledTime, 0.85*tone(sampledTime - 2), '-o', ...
        'Color', [0.75, 0.31, 0.12], 'LineWidth', 1.3, ...
        'MarkerIndices', 1:3:numel(sampledTime), 'MarkerSize', 4, ...
        'DisplayName', '800 Hz sampled trace');
    xlabel(ax, 'Time (ms)');
    ylabel(ax, 'Amplitude (p.u.)');
    title(ax, '50 Hz signal on two sampling grids');
    legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
    xlim(ax, [0, 80]);
    ylim(ax, [-1.15, 1.15]);
    grid(ax, 'on');
    box(ax, 'on');
    savefig(fig, path);
end

function saveFilterFigure(path)
    fig = figure('Visible', 'off', 'Color', 'white', ...
        'Position', [100, 100, 760, 480]);
    cleanup = onCleanup(@() delete(fig));
    layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    frequency = logspace(1, 5, 241);
    response = 1./(1 + 1i*frequency/1000);
    magnitude = 20*log10(abs(response));
    phase = rad2deg(angle(response));

    magnitudeAxes = nexttile(layout);
    semilogx(magnitudeAxes, frequency, magnitude, 'Color', [0.08, 0.36, 0.55], ...
        'LineWidth', 2, 'DisplayName', 'Magnitude');
    title(magnitudeAxes, 'Magnitude');
    ylabel(magnitudeAxes, 'Gain (dB)');
    grid(magnitudeAxes, 'on');

    phaseAxes = nexttile(layout);
    semilogx(phaseAxes, frequency, phase, 'Color', [0.75, 0.31, 0.12], ...
        'LineWidth', 2, 'DisplayName', 'Phase');
    title(phaseAxes, 'Phase');
    xlabel(phaseAxes, 'Frequency (Hz)');
    ylabel(phaseAxes, 'Phase (deg)');
    grid(phaseAxes, 'on');
    title(layout, 'RC low-pass filter, 1 kHz cutoff');
    savefig(fig, path);
end
