function tests = test_export_lab_batch
%TEST_EXPORT_LAB_BATCH Exercise the figure-pack workflow with real FIG files.
    tests = functiontests(localfunctions);
end

function testDryRunDoesNotOpenFiguresOrCreateOutputs(testCase)
    [root, inputFolder, outputFolder] = folders(testCase);
    writeBrokenFigure(fullfile(inputFolder, 'unreadable.FIG'));

    plan = export_lab_batch(inputFolder, outputFolder, 'DryRun', true);

    verifyEqual(testCase, plan.Source, "unreadable.FIG");
    verifyEqual(testCase, plan.Status, "Planned");
    verifyEqual(testCase, plan.PNG, "plots/unreadable.png");
    verifyFalse(testCase, isfolder(outputFolder));
    contents = dir(root);
    names = string({contents.name});
    verifyEqual(testCase, names(~ismember(names, [".", ".."])), "source");
end

function testNestedExportsAndCorruptInput(testCase)
    [~, inputFolder, outputFolder] = folders(testCase);
    mkdir(fullfile(inputFolder, '01 signals'));
    mkdir(fullfile(inputFolder, '02 response'));
    lineName = 'a & #波形';
    saveTraces(fullfile(inputFolder, '01 signals', [lineName '.fig']));
    saveScatter(fullfile(inputFolder, '02 response', 'b.fig'));
    writeBrokenFigure(fullfile(inputFolder, '03-corrupt.fig'));

    existing = figure('Visible', 'off');
    addTeardown(testCase, @delete, existing);
    openBefore = findall(groot, 'Type', 'figure');
    report = export_lab_batch(inputFolder, outputFolder, 'DPI', 300);

    verifyEqual(testCase, report.Source, ["01 signals/" + string(lineName) + ".fig"; ...
        "02 response/b.fig"; "03-corrupt.fig"]);
    verifyEqual(testCase, report.Status, ["Exported"; "Exported"; "Failed"]);
    verifyEqual(testCase, report.SeriesCount, [2; 0; 0]);
    verifyEqual(testCase, report.BookPage, [1; 2; 0]);
    verifyEqual(testCase, report.DataCSV(2:3), [""; ""]);
    verifyEqual(testCase, report.PNG(3), "");
    verifyNotEmpty(testCase, char(report.Message(3)));
    verifyFalse(testCase, contains(report.Message(3), string(inputFolder)));
    verifyTrue(testCase, isgraphics(existing, 'figure'));
    verifyEqual(testCase, numel(findall(groot, 'Type', 'figure')), numel(openBefore));
    verifyTrue(testCase, all(isgraphics(openBefore, 'figure')));

    png = imfinfo(fullfile(outputFolder, report.PNG(1)));
    verifyEqual(testCase, round(png.XResolution * 0.0254), 300);
    verifyTrue(testCase, isfile(fullfile(outputFolder, report.PDF(1))));
    verifyTrue(testCase, isfile(fullfile(outputFolder, 'figures.pdf')));
    verifyTrue(testCase, isfile(fullfile(outputFolder, 'manifest.csv')));
    data = readtable(fullfile(outputFolder, report.DataCSV(1)), ...
        'TextType', 'string', 'Encoding', 'UTF-8');
    verifyEqual(testCase, data.Series, [1; 1; 1; 2; 2]);
    verifyEqual(testCase, data.Sample, [1; 2; 3; 1; 2]);
    verifyEqual(testCase, data.X, [0; 1; 2; 0; 2]);
    verifyTrue(testCase, isnan(data.Y(3)));
    verifyEqual(testCase, data.Label(1), "A & B, ""trace""");

    html = readUtf8(fullfile(outputFolder, 'index.html'));
    verifySubstring(testCase, html, 'a &amp; #波形.fig');
    verifySubstring(testCase, html, 'a%20%26%20%23%E6%B3%A2%E5%BD%A2.png');
    verifySubstring(testCase, html, '03-corrupt.fig');
    verifyError(testCase, @() export_lab_batch(inputFolder, outputFolder), ...
        'export_lab_batch:OutputExists');
    verifyTrue(testCase, isfile(fullfile(outputFolder, report.PNG(1))));
end

function testLiveFigureBatchPreservesCallerOrderAndState(testCase)
    [root, ~, outputFolder] = folders(testCase);
    original = get(groot, 'CurrentFigure');
    addTeardown(testCase, @() set(groot, 'CurrentFigure', original));

    first = figure('Visible', 'off');
    addTeardown(testCase, @delete, first);
    plot(axes(first), [0, 1], [1, 2]);
    second = figure('Visible', 'off');
    addTeardown(testCase, @delete, second);
    plot(axes(second), [0, 1], [3, 4]);
    current = figure('Visible', 'off');
    addTeardown(testCase, @delete, current);
    openBefore = findall(groot, 'Type', 'figure');
    sources = [second; first];

    plan = export_lab_batch(sources, outputFolder, 'DryRun', true);
    verifyEqual(testCase, plan.Source, ["figure-0001"; "figure-0002"]);
    verifyEqual(testCase, plan.Status, ["Planned"; "Planned"]);
    verifyFalse(testCase, isfolder(outputFolder));
    verifyEqual(testCase, get(groot, 'CurrentFigure'), current);

    report = export_lab_batch(sources, outputFolder, 'DPI', 100);

    verifyEqual(testCase, report.Source, plan.Source);
    assertEqual(testCase, report.Status, ["Exported"; "Exported"]);
    verifyEqual(testCase, report.BookPage, [1; 2]);
    verifyTrue(testCase, isfile(fullfile(outputFolder, 'figures.pdf')));
    firstData = readtable(fullfile(outputFolder, report.DataCSV(1)));
    secondData = readtable(fullfile(outputFolder, report.DataCSV(2)));
    verifyEqual(testCase, firstData.Y, [3; 4]);
    verifyEqual(testCase, secondData.Y, [1; 2]);
    verifyTrue(testCase, all(isgraphics(openBefore, 'figure')));
    verifyEqual(testCase, numel(findall(groot, 'Type', 'figure')), numel(openBefore));
    verifyEqual(testCase, get(groot, 'CurrentFigure'), current);
    verifyEqual(testCase, [string(first.Visible), string(second.Visible)], ["off", "off"]);
    verifyEmpty(testCase, dir(fullfile(root, '**', '*.fig')));
end

function testSelectedFilesExportInCallerOrder(testCase)
    [root, inputFolder, outputFolder] = folders(testCase);
    mkdir(fullfile(inputFolder, 'nested'));
    saveTraces(fullfile(inputFolder, 'nested', 'a.fig'));
    saveScatter(fullfile(root, 'scatter.fig'));
    [copied, message] = copyfile(fullfile(root, 'scatter.fig'), fullfile(inputFolder, 'z.FIG'));
    assertTrue(testCase, logical(copied), message);
    decoy = fullfile(inputFolder, 'broken.fig');
    writeBrokenFigure(decoy);
    originalDecoy = fileread(decoy);

    selection = {'z.FIG', 'nested/a.fig'};
    report = export_lab_batch(inputFolder, outputFolder, 'FigureFiles', selection, 'DPI', 100);

    verifyEqual(testCase, report.Source, ["z.FIG"; "nested/a.fig"]);
    verifyEqual(testCase, report.Status, ["Exported"; "Exported"]);
    verifyEqual(testCase, report.BookPage, [1; 2]);
    verifyEqual(testCase, report.PNG, ["plots/z.png"; "plots/nested/a.png"]);
    verifyEqual(testCase, report.SeriesCount, [0; 2]);
    verifyEqual(testCase, fileread(decoy), originalDecoy);
end

function testInvalidFigureInputsDoNotCreateOutputs(testCase)
    [root, inputFolder, outputFolder] = folders(testCase);
    original = get(groot, 'CurrentFigure');
    addTeardown(testCase, @() set(groot, 'CurrentFigure', original));
    fig = figure('Visible', 'off');
    addTeardown(testCase, @delete, fig);
    ax = axes(fig);
    deleted = figure('Visible', 'off');
    delete(deleted);
    mkdir(fullfile(inputFolder, 'directory.fig'));

    exportInput = @(input) export_lab_batch(input, outputFolder);
    verifyError(testCase, @() exportInput(deleted), 'export_lab_batch:InvalidFigures');
    verifyError(testCase, @() exportInput(gobjects(0, 1)), 'export_lab_batch:InvalidFigures');
    verifyError(testCase, @() exportInput(ax), 'export_lab_batch:InvalidFigures');
    verifyError(testCase, @() exportInput([fig, fig; fig, fig]), 'export_lab_batch:InvalidFigures');
    verifyError(testCase, @() exportInput([fig, fig]), 'export_lab_batch:DuplicateFigures');
    verifyError(testCase, @() export_lab_batch(fig, outputFolder, 'FigureFiles', 'picked.fig'), ...
        'export_lab_batch:FigureFilesWithHandles');

    exportFiles = @(files) export_lab_batch(inputFolder, outputFolder, 'FigureFiles', files);
    verifyError(testCase, @() exportFiles(5), 'export_lab_batch:InvalidFigureFiles');
    verifyError(testCase, @() exportFiles(strings(0, 1)), 'export_lab_batch:EmptyFigureFiles');
    verifyError(testCase, @() exportFiles('notes.txt'), 'export_lab_batch:InvalidFigureFiles');
    verifyError(testCase, @() exportFiles('../outside.fig'), 'export_lab_batch:UnsafeFigureFile');
    verifyError(testCase, @() exportFiles(fullfile(inputFolder, 'absolute.fig')), ...
        'export_lab_batch:UnsafeFigureFile');
    verifyError(testCase, @() exportFiles(["same.fig", "SAME.FIG"]), ...
        'export_lab_batch:DuplicateFigureFile');
    verifyError(testCase, @() exportFiles('missing.fig'), 'export_lab_batch:FigureFile');
    verifyError(testCase, @() exportFiles('directory.fig'), 'export_lab_batch:FigureFile');
    contents = dir(root);
    names = string({contents.name});
    verifyEqual(testCase, names(~ismember(names, [".", ".."])), "source");
end

function testCombinedPdfCanBeDisabled(testCase)
    [~, inputFolder, outputFolder] = folders(testCase);
    saveScatter(fullfile(inputFolder, 'scatter.fig'));
    report = export_lab_batch(inputFolder, outputFolder, 'CombinePDF', false);

    verifyEqual(testCase, report.Status, "Exported");
    verifyEqual(testCase, report.BookPage, 0);
    verifyTrue(testCase, isfile(fullfile(outputFolder, report.PDF)));
    verifyFalse(testCase, isfile(fullfile(outputFolder, 'figures.pdf')));
    html = readUtf8(fullfile(outputFolder, 'index.html'));
    verifyFalse(testCase, contains(html, 'PDF figure book'));
end

function testEmptyInputProducesAnEmptyManifest(testCase)
    [~, inputFolder, outputFolder] = folders(testCase);

    report = export_lab_batch(inputFolder, outputFolder);

    verifySize(testCase, report, [0, 8]);
    verifyTrue(testCase, isfile(fullfile(outputFolder, 'manifest.csv')));
    verifyTrue(testCase, isfile(fullfile(outputFolder, 'index.html')));
    verifyFalse(testCase, isfile(fullfile(outputFolder, 'figures.pdf')));
end

function testQuotedMetadataAndExactDoubleRoundTrip(testCase)
    [root, baseline, baselinePack] = folders(testCase);
    candidate = fullfile(root, 'candidate');
    candidatePack = fullfile(root, 'candidate-pack');
    mkdir(candidate);
    savePrecisionPlot(fullfile(baseline, 'precision.fig'), 1);
    savePrecisionPlot(fullfile(candidate, 'precision.fig'), 1 + eps);
    export_lab_batch(baseline, baselinePack, 'DPI', 100, 'CombinePDF', false);
    exported = export_lab_batch(candidate, candidatePack, 'DPI', 100, 'CombinePDF', false);

    [figures, series] = compare_lab_packs(baselinePack, candidatePack, fullfile(root, 'comparison'));
    verifyEqual(testCase, figures.Status, "Outside tolerance");
    verifyEqual(testCase, series.MaxAbsDelta, eps);
    verifyEqual(testCase, series.OutsideSamples, 1);

    [fig, ax, lines] = replot_lab_figure(fullfile(candidatePack, exported.DataCSV), 'Visible', 'off');
    addTeardown(testCase, @delete, fig);
    verifyEqual(testCase, lines.YData, [1 + eps, 2]);
    titleLines = string(ax.Title.String);
    verifyEqual(testCase, titleLines(:), ["First line"; "Second line"]);
end

function testSingleFigureHonorsAnExistingWriteReservation(testCase)
    [root, ~, ~] = folders(testCase);
    target = fullfile(root, 'reserved');
    mkdir([target, '.figure-pack-lock']);
    fig = figure('Visible', 'off');
    addTeardown(testCase, @delete, fig);
    plot(axes(fig), [0, 1], [0, 1]);

    verifyError(testCase, @() export_lab_figure(fig, target), 'export_lab_figure:OutputBusy');
    verifyFalse(testCase, isfile([target, '.png']));
    verifyFalse(testCase, isfile([target, '.pdf']));
end

function [root, inputFolder, outputFolder] = folders(testCase)
    root = tempname;
    mkdir(root);
    addTeardown(testCase, @rmdir, root, 's');
    inputFolder = fullfile(root, 'source');
    outputFolder = fullfile(root, 'pack');
    mkdir(inputFolder);
end

function savePrecisionPlot(path, firstValue)
    fig = figure('Visible', 'off');
    guard = onCleanup(@() delete(fig));
    ax = axes(fig);
    plot(ax, [1, 2], [firstValue, 2], 'DisplayName', 'Precision trace');
    title(ax, {'First line', 'Second line'});
    savefig(fig, path);
end

function saveTraces(path)
    fig = figure('Visible', 'off');
    guard = onCleanup(@() delete(fig));
    ax = axes(fig);
    plot(ax, [0, 1, 2], [3, 4, NaN], 'DisplayName', 'A & B, "trace"');
    hold(ax, 'on');
    plot(ax, [0, 2], [5, 6], 'DisplayName', 'Slow grid');
    plot(ax, [0, 1], [6, 7], 'Visible', 'off');
    savefig(fig, path);
end

function saveScatter(path)
    fig = figure('Visible', 'off');
    guard = onCleanup(@() delete(fig));
    scatter(axes(fig), [1, 2, 3], [2, 3, 5]);
    savefig(fig, path);
end

function writeBrokenFigure(path)
    file = fopen(path, 'w');
    guard = onCleanup(@() fclose(file));
    fprintf(file, 'This file intentionally contains no MATLAB figure.');
end

function text = readUtf8(path)
    file = fopen(path, 'r', 'n', 'UTF-8');
    guard = onCleanup(@() fclose(file));
    text = fscanf(file, '%c');
end
