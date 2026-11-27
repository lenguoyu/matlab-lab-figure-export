function tests = test_compare_lab_packs
%TEST_COMPARE_LAB_PACKS Check numerical rules and portable comparison reports.
    tests = functiontests(localfunctions);
end

function testAbsoluteAndRelativeLimitsAndSharedGap(testCase)
    root = newFolder(testCase);
    [baseline, candidate] = csvPair(root, ...
        samples(1, "001", [0, 1, 2, 3], [0, 2, -4, NaN]), ...
        samples(1, "001", [0, 1, 2, 3], [0.125, 2.25, -3.25, NaN]));

    result = compare_lab_series("run.fig", baseline, candidate, 0.125, 0.125);

    verifyEqual(testCase, result.Label, "001");
    verifyEqual(testCase, result.Status, "Outside tolerance");
    verifyEqual(testCase, result.ComparedSamples, 3);
    verifyEqual(testCase, result.SkippedSamples, 1);
    verifyEqual(testCase, result.OutsideSamples, 1);
    verifyEqual(testCase, result.MaxAbsDelta, 0.75);
    verifyEqual(testCase, result.XAtMax, 2);
end

function testIncompatibleSeriesAreVisible(testCase)
    root = newFolder(testCase);
    baselineData = [samples(1, "01", [0, 1], [1, 2]); ...
        samples(2, "Grid", [0, 1, 2], [1, 2, 3]); ...
        samples(3, "Gap", [0, 1], [1, NaN]); ...
        samples(4, "Removed", 0, 1); ...
        samples(6, "Empty", [0, 1], [NaN, NaN])];
    candidateData = [samples(1, "1", [0, 1], [1, 2]); ...
        samples(2, "Grid", [0, 2, 1], [1, 3, 2]); ...
        samples(3, "Gap", [0, 1], [1, 2]); ...
        samples(5, "New", 0, 1); ...
        samples(6, "Empty", [0, 1], [NaN, NaN])];
    [baseline, candidate] = csvPair(root, baselineData, candidateData);

    result = compare_lab_series("run.fig", baseline, candidate, 0, 0);

    verifyEqual(testCase, result.Series, (1:6).');
    verifyEqual(testCase, result.Status, ["Metadata changed"; "Grid changed"; ...
        "Gap changed"; "Missing series"; "Added series"; "No finite samples"]);
end

function testComparisonOfTwoPacksCreatesPortableArtifacts(testCase)
    root = newFolder(testCase);
    baseline = fullfile(root, 'baseline');
    candidate = fullfile(root, 'candidate');
    destination = fullfile(root, 'comparison');
    sources = ["nested/01 & #设备.fig"; "02-removed.fig"; ...
        "03-visual.fig"; "04-unsafe.fig"; "05-added.fig"];
    writePack(baseline, sources([1, 2, 3, 4]), [0; 0; NaN; 0]);
    baselineManifest = readUtf8(fullfile(baseline, 'manifest.csv'));
    right = writePack(candidate, sources([1, 3, 4, 5]), [0.5; NaN; 0; 0]);
    right.DataCSV(3) = "../outside.csv";
    writeTable(right, fullfile(candidate, 'manifest.csv'));
    writeTable(samples(1, "Outside", 0, 99), fullfile(root, 'outside.csv'));

    [figures, series] = compare_lab_packs(baseline, candidate, destination, 'AbsTol', 0.1);

    verifyEqual(testCase, statusFor(figures, sources(1)), "Outside tolerance");
    verifyEqual(testCase, statusFor(figures, sources(2)), "Removed");
    verifyEqual(testCase, statusFor(figures, sources(3)), "Visual only");
    verifyEqual(testCase, statusFor(figures, sources(4)), "Needs review");
    verifyEqual(testCase, statusFor(figures, sources(5)), "Added");
    verifyFalse(testCase, any(series.Label == "Outside"));
    peak = series(series.Source == sources(1), :);
    verifyEqual(testCase, peak.MaxAbsDelta, 0.5);
    verifyEqual(testCase, peak.XAtMax, 1);
    verifyTrue(testCase, isfile(fullfile(destination, 'comparison.csv')));
    verifyTrue(testCase, isfile(fullfile(destination, 'series.csv')));
    previews = [figures.BaselinePreview; figures.CandidatePreview];
    previews = previews(previews ~= "");
    verifyTrue(testCase, all(isfile(fullfile(destination, previews))));
    verifyEqual(testCase, readUtf8(fullfile(baseline, 'manifest.csv')), baselineManifest);
    html = readUtf8(fullfile(destination, 'index.html'));
    verifySubstring(testCase, html, '01 &amp; #设备.fig');
    verifySubstring(testCase, html, 'series.csv');
    verifyError(testCase, @() compare_lab_packs(baseline, candidate, destination), ...
        'compare_lab_packs:OutputExists');
end

function root = newFolder(testCase)
    root = tempname;
    mkdir(root);
    addTeardown(testCase, @rmdir, root, 's');
end

function [baseline, candidate] = csvPair(root, baselineData, candidateData)
    baseline = fullfile(root, 'baseline.csv');
    candidate = fullfile(root, 'candidate.csv');
    writeTable(baselineData, baseline);
    writeTable(candidateData, candidate);
end

function data = samples(series, label, x, y)
    n = numel(x);
    data = table(ones(n, 1), repmat("Waveform", n, 1), repmat("Time (s)", n, 1), ...
        repmat("Output", n, 1), repmat(series, n, 1), repmat(label, n, 1), ...
        (1:n).', x(:), y(:), 'VariableNames', {'Axes', 'AxesTitle', ...
        'XLabel', 'YLabel', 'Series', 'Label', 'Sample', 'X', 'Y'});
end

function manifest = writePack(pack, sources, deltas)
    count = numel(sources);
    status = repmat("Exported", count, 1);
    png = "plots/" + replace(sources, '.fig', '.png');
    data = strings(count, 1);
    counts = zeros(count, 1);

    for row = 1:count
        path = fullfile(pack, png(row));
        [created, message] = mkdir(fileparts(path));
        assert(created, '%s', message);
        imwrite(uint8(120*ones(12, 16)), path, 'png');
        if isfinite(deltas(row))
            data(row) = "plots/" + replace(sources(row), '.fig', '.csv');
            writeTable(samples(1, "Signal", [0, 1], [0, 1+deltas(row)]), ...
                fullfile(pack, data(row)));
            counts(row) = 1;
        end
    end

    manifest = table(sources, status, png, strings(count, 1), data, counts, ...
        zeros(count, 1), strings(count, 1), 'VariableNames', {'Source', ...
        'Status', 'PNG', 'PDF', 'DataCSV', 'SeriesCount', 'BookPage', 'Message'});
    writeTable(manifest, fullfile(pack, 'manifest.csv'));
end

function status = statusFor(figures, source)
    status = figures.Status(figures.Source == source);
end

function writeTable(data, path)
    writetable(data, path, 'Encoding', 'UTF-8');
end

function text = readUtf8(path)
    file = fopen(path, 'r', 'n', 'UTF-8');
    closeFile = onCleanup(@() fclose(file));
    text = fscanf(file, '%c');
end
