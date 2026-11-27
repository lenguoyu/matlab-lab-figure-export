function tests = test_export_lab_plotly
%TEST_EXPORT_LAB_PLOTLY Exercise the optional bridge through its public API.
    tests = functiontests(localfunctions);
end

function testJSONPreservesOrderPrecisionAndSubplotIdentity(testCase)
    [root, pack] = fixture(testCase);
    target = fullfile(root, 'json');
    manifestBefore = readUtf8(fullfile(pack, 'manifest.csv'));

    report = export_lab_plotly(pack, target, 'XScale', 'log');

    verifyEqual(testCase, report.Status, ["Exported"; "Static only"; "Needs review"]);
    verifyEqual(testCase, report.SeriesCount, [2; 0; 0]);
    verifyEqual(testCase, report.Artifact(1), "figures/0001.json");
    spec = jsondecode(readUtf8(fullfile(target, report.Artifact(1))));
    verifyEqual(testCase, spec.layout.xaxis.type, 'log');
    verifyEqual(testCase, spec.layout.xaxis2.type, 'log');
    verifyEqual(testCase, spec.layout.grid.rows, 2);
    verifyEqual(testCase, spec.data(1).x(:), [2; 1; 1]);
    verifyEqual(testCase, spec.data(1).y(1), 1 + eps);
    verifyTrue(testCase, isnan(spec.data(1).y(2)));
    verifyFalse(testCase, spec.data(1).connectgaps);
    verifyEqual(testCase, spec.data(1).mode, 'lines+markers');
    verifySubstring(testCase, spec.data(1).name, '趋势 &lt;/script&gt;');
    verifyEqual(testCase, spec.data(2).xaxis, 'x2');
    verifySubstring(testCase, readUtf8(fullfile(target, report.Artifact(1))), '"x":[4]');
    verifyEqual(testCase, readUtf8(fullfile(pack, 'manifest.csv')), manifestBefore);
    verifyError(testCase, @() export_lab_plotly(pack, target), 'export_lab_plotly:OutputExists');
end

function testViewerCopiesExplicitAssetsAndKeepsStaticPreviews(testCase)
    [root, pack] = fixture(testCase);
    bundle = fullfile(root, 'stub.js');
    license = fullfile(root, 'LICENSE');
    writeText(bundle, '/* Test fixture, never executed */');
    writeText(license, 'License test fixture');
    target = fullfile(root, 'viewer');

    report = export_lab_plotly(pack, target, 'PlotlyJS', bundle, 'PlotlyLicense', license);

    verifyEqual(testCase, report.Status, ["Interactive"; "Static only"; "Needs review"]);
    verifyTrue(testCase, isfile(fullfile(target, 'previews', '0002.png')));
    verifyTrue(testCase, isfile(fullfile(target, 'previews', '0003.png')));
    verifyFalse(testCase, isfolder(fullfile(target, 'figures')));
    verifyEqual(testCase, readUtf8(fullfile(target, 'plotly.min.js')), readUtf8(bundle));
    verifyEqual(testCase, readUtf8(fullfile(target, 'plotly.LICENSE.txt')), readUtf8(license));
    html = readUtf8(fullfile(target, 'index.html'));
    verifySubstring(testCase, html, './plotly.min.js');
    verifySubstring(testCase, html, '\u003Ccase>');
    verifyFalse(testCase, contains(html, '<case>'));
    verifyFalse(testCase, contains(html, 'https://cdn.plot.ly'));
    verifyFalse(testCase, contains(html, 'outside-value'));
end

function testInvalidLogCoordinatesRequireReviewAndOptionsAreValidated(testCase)
    [root, pack] = fixture(testCase);
    target = fullfile(root, 'log');

    verifyError(testCase, @() export_lab_plotly(pack, target, 'PlotlyJS', 'missing.js'), ...
        'export_lab_plotly:BundlePair');
    verifyError(testCase, @() export_lab_plotly(pack, target, 'XScale', 'invalid'), ...
        'export_lab_plotly:InvalidScale');
    verifyFalse(testCase, isfolder(target));
    report = export_lab_plotly(pack, target, 'YScale', 'log');
    verifyEqual(testCase, report.Status(1), "Needs review");
    verifySubstring(testCase, char(report.Message(1)), 'nonpositive');
    verifyFalse(testCase, isfolder(fullfile(target, 'figures')));
end

function [root, pack] = fixture(testCase)
    root = tempname;
    pack = fullfile(root, 'pack');
    mkdir(fullfile(pack, 'plots'));
    addTeardown(testCase, @rmdir, root, 's');
    sources = ["01-<case>.fig"; "02-scatter.fig"; "03-unsafe.fig"];
    pngs = ["plots/first.png"; "plots/static.png"; "plots/unsafe.png"];
    dataFiles = ["plots/line.csv"; ""; "../outside.csv"];
    for row = 1:numel(pngs)
        imwrite(uint8(120*ones(10, 15)), fullfile(pack, pngs(row)), 'png');
    end
    written = table(sources, repmat("Exported", 3, 1), pngs, strings(3, 1), ...
        dataFiles, [2; 0; 1], zeros(3, 1), strings(3, 1), 'VariableNames', ...
        {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'SeriesCount', 'BookPage', 'Message'});
    writetable(written, fullfile(pack, 'manifest.csv'), 'Encoding', 'UTF-8', 'QuoteStrings', true);
    titles = [repmat("Axes title" + newline + "Second line", 3, 1); "Singleton"];
    samples = table([1; 1; 1; 9], titles, repmat("Time (s)", 4, 1), repmat("Value", 4, 1), ...
        [3; 3; 3; 4], [repmat("趋势 </script>", 3, 1); "004"], [1; 2; 3; 1], ...
        [2; 1; 1; 4], compose('%.17g', [1 + eps; NaN; -2; 7]), 'VariableNames', ...
        {'Axes', 'AxesTitle', 'XLabel', 'YLabel', 'Series', 'Label', 'Sample', 'X', 'Y'});
    writetable(samples, fullfile(pack, 'plots', 'line.csv'), 'Encoding', 'UTF-8', 'QuoteStrings', true);
    writeText(fullfile(root, 'outside.csv'), 'outside-value');
end

function writeText(path, value)
    file = fopen(path, 'w', 'n', 'UTF-8');
    closeFile = onCleanup(@() fclose(file));
    fprintf(file, '%s', value);
end

function value = readUtf8(path)
    file = fopen(path, 'r', 'n', 'UTF-8');
    closeFile = onCleanup(@() fclose(file));
    value = fscanf(file, '%c');
end
