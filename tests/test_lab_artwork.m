function tests = test_lab_artwork
    tests = functiontests(localfunctions);
end

function testPlacementAtAndBelowTarget(testCase)
    pack = newPack(testCase);
    imwrite(zeros(20, 2100, 'uint8'), fullfile(pack, 'plots', 'exact.png'));
    imwrite(zeros(25, 2099, 'uint8'), fullfile(pack, 'plots', 'short.png'));
    writeManifest(pack, ["exact.fig"; "short.fig"], repmat("Exported", 2, 1), ...
        ["plots/exact.png"; "plots/short.png"], strings(2, 1));

    report = check_lab_artwork(pack, 88.9, 600);
    verifyEqual(testCase, report.Properties.VariableNames, ...
        {'Source', 'PlacedWidthMm', 'TargetDPI', 'PixelWidth', 'PixelHeight', ...
        'EffectiveDPI', 'RequiredPixelWidth', 'Status', 'PDF', 'Message'});
    verifyEqual(testCase, report.Source, ["exact.fig"; "short.fig"]);
    verifyEqual(testCase, report.PlacedWidthMm, [88.9; 88.9]);
    verifyEqual(testCase, report.TargetDPI, [600; 600]);
    verifyEqual(testCase, report.PixelWidth, [2100; 2099]);
    verifyEqual(testCase, report.PixelHeight, [20; 25]);
    verifyEqual(testCase, report.RequiredPixelWidth, [2100; 2100]);
    verifyEqual(testCase, report.EffectiveDPI, [600; 2099 * 25.4 / 88.9], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.Status, ["Meets target"; "Below target"]);

    narrower = check_lab_artwork(pack, 75, 600);
    verifyEqual(testCase, narrower.RequiredPixelWidth, [1772; 1772]);
    verifyEqual(testCase, narrower.Status, repmat("Meets target", 2, 1));
end

function testDecimalWidthRoundoff(testCase)
    pack = newPack(testCase);
    imwrite(zeros(12, 780, 'uint8'), fullfile(pack, 'plots', 'exact.png'));
    writeManifest(pack, "exact.fig", "Exported", "plots/exact.png", "");

    report = check_lab_artwork(pack, 33.02, 600);
    verifyEqual(testCase, report.RequiredPixelWidth, 780);
    verifyEqual(testCase, report.Status, "Meets target");
end

function testUnusablePNGAndFailedExport(testCase)
    pack = newPack(testCase);
    imwrite(zeros(10, 10, 'uint8'), fullfile(pack, 'outside.png'));
    imwrite(zeros(10, 10, 'uint8'), fullfile(pack, 'plots', 'wrong-format.png'), 'jpg');
    writeText(fullfile(pack, 'plots', 'broken.png'), 'not an image');
    source = ["missing.fig"; "broken.fig"; "wrong-format.fig"; "unsafe.fig"; "failed.fig"];
    status = [repmat("Exported", 4, 1); "Failed"];
    paths = ["plots/no.png"; "plots/broken.png"; "plots/wrong-format.png"; "plots/../outside.png"; ""];
    writeManifest(pack, source, status, paths, strings(5, 1));

    result = check_lab_artwork(pack, 88.9, 300);
    verifyEqual(testCase, result.Source, source);
    verifyEqual(testCase, result.Status, repmat("Needs review", 5, 1));
    verifyTrue(testCase, all(isnan(result.PixelWidth)));
    verifyTrue(testCase, all(isnan(result.EffectiveDPI)));
    verifyTrue(testCase, all(contains(result.Message(1:4), "PNG:")));
    verifyTrue(testCase, contains(result.Message(5), "Failed"));
end

function testOptionalPDFPaths(testCase)
    pack = newPack(testCase);
    imwrite(zeros(10, 1200, 'uint8'), fullfile(pack, 'plots', 'plot.png'));
    writeText(fullfile(pack, 'plots', 'plot.pdf'), '%PDF-1.4');
    writeText(fullfile(pack, 'outside.pdf'), '%PDF-1.4');
    source = ["valid.fig"; "missing.fig"; "unsafe.fig"; "omitted.fig"];
    paths = ["plots/plot.pdf"; "plots/missing.pdf"; "plots/../outside.pdf"; ""];
    writeManifest(pack, source, repmat("Exported", 4, 1), repmat("plots/plot.png", 4, 1), paths);

    report = check_lab_artwork(pack, 88.9, 300);
    verifyEqual(testCase, report.Status, repmat("Meets target", 4, 1));
    verifyEqual(testCase, report.PDF, ["plots/plot.pdf"; ""; ""; ""]);
    verifyEqual(testCase, report.Message([1, 4]), [""; ""]);
    verifyTrue(testCase, all(contains(report.Message(2:3), "PDF:")));
end

function pack = newPack(testCase)
    pack = string(tempname);
    mkdir(fullfile(pack, 'plots'));
    addTeardown(testCase, @() rmdir(pack, 's'));
end

function writeManifest(pack, source, status, png, pdf)
    count = numel(source);
    manifest = table(source, status, png, pdf, strings(count, 1), zeros(count, 1), ...
        zeros(count, 1), strings(count, 1), 'VariableNames', ...
        {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'SeriesCount', 'BookPage', 'Message'});
    writetable(manifest, fullfile(pack, 'manifest.csv'), 'Encoding', 'UTF-8');
end

function writeText(path, text)
    file = fopen(path, 'w');
    cleanup = onCleanup(@() fclose(file));
    fprintf(file, '%s', text);
end
