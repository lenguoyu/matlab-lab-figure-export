function tests = test_build_lab_delivery
%TEST_BUILD_LAB_DELIVERY Exercise ZIP contents through the public entry point.
    tests = functiontests(localfunctions);
end

function testCompleteDeliveryPreservesFilesAndLocalLinks(testCase)
    [root, source, output] = newDelivery(testCase);
    relativeFigure = "01 signals/波形.fig";
    mkdir(fullfile(source, '01 signals'));
    figurePath = fullfile(source, relativeFigure);
    saveTrace(figurePath);
    originalFigure = readBytes(figurePath);

    project = fullfile(root, 'project');
    mkdir(fullfile(project, '实验'));
    scriptFile = "实验/复现 #脚本.m";
    documentFile = "实验/说明.pdf";
    writeText(fullfile(project, scriptFile), '% Recreate the synthetic trace.');
    writeText(fullfile(project, documentFile), '%PDF-1.4 attachment fixture');
    writeText(fullfile(project, 'unselected.m'), '% Private notes fixture.');
    bundle = fullfile(root, 'stub.js');
    license = fullfile(root, 'stub-license.txt');
    writeText(bundle, 'window.Plotly = {newPlot: function () {}};');
    writeText(license, 'Renderer license fixture.');

    [archive, summary] = build_lab_delivery(source, output, 180, 2400, ...
        'AttachmentRoot', project, 'Files', {char(scriptFile), char(documentFile)}, ...
        'PlotlyJS', bundle, 'PlotlyLicense', license, 'DPI', 100, 'CombinePDF', true);

    verifyEqual(testCase, string(archive), output);
    verifyTrue(testCase, isfile(output));
    verifyEqual(testCase, summary.Figures.Source, relativeFigure);
    verifyEqual(testCase, summary.Figures.Status, "Exported");
    verifyEqual(testCase, summary.Figures.BookPage, 1);
    verifyEqual(testCase, summary.Artwork.Status, "Below target");
    verifyEqual(testCase, summary.Plotly.Status, "Interactive");
    attachmentPaths = "attachments/" + [scriptFile; documentFile];
    verifyEqual(testCase, sort(string(summary.Attachments(:))), sort(attachmentPaths));

    unpacked = fullfile(root, 'unpacked');
    members = extractMembers(archive, unpacked);
    expected = ["index.html"; "artwork-check.csv"; "delivery-manifest.csv"; ...
        "figures/index.html"; "figures/manifest.csv"; "figures/figures.pdf"; ...
        "figures/plots/01 signals/波形.png"; "figures/plots/01 signals/波形.pdf"; ...
        "figures/plots/01 signals/波形.csv"; "interactive/index.html"; ...
        "interactive/plotly.min.js"; "interactive/plotly.LICENSE.txt"; ...
        "interactive/plotly-manifest.csv"; attachmentPaths];
    verifyEqual(testCase, sort(members), sort(expected));
    verifyInventory(testCase, unpacked, summary.Inventory, expected);

    rootHtml = readUtf8(fullfile(unpacked, 'index.html'));
    verifyLocalLink(testCase, rootHtml, 'figures/index.html');
    verifyLocalLink(testCase, rootHtml, 'figures/figures.pdf');
    verifyLocalLink(testCase, rootHtml, 'interactive/index.html');
    verifyLocalLink(testCase, rootHtml, 'artwork-check.csv');
    verifyLocalLink(testCase, rootHtml, 'delivery-manifest.csv');
    verifySubstring(testCase, rootHtml, 'Below target 1.');
    verifySubstring(testCase, rootHtml, 'Interactive plots 1.');
    verifyLocalLink(testCase, rootHtml, ...
        'attachments/%E5%AE%9E%E9%AA%8C/%E5%A4%8D%E7%8E%B0%20%23%E8%84%9A%E6%9C%AC.m');
    figureHtml = readUtf8(fullfile(unpacked, 'figures', 'index.html'));
    verifyLocalLink(testCase, figureHtml, 'plots/01%20signals/%E6%B3%A2%E5%BD%A2.png');
    interactiveHtml = readUtf8(fullfile(unpacked, 'interactive', 'index.html'));
    verifyLocalLink(testCase, interactiveHtml, 'plotly.min.js');
    verifySubstring(testCase, interactiveHtml, 'Plotly.newPlot');
    verifyFalse(testCase, contains(interactiveHtml, 'https://cdn.plot.ly'));
    verifyFalse(testCase, contains(rootHtml, 'unselected.m'));

    png = imfinfo(fullfile(unpacked, 'figures', summary.Figures.PNG));
    verifyEqual(testCase, round(png.XResolution * 0.0254), 100);
    artwork = readtable(fullfile(unpacked, 'artwork-check.csv'), ...
        'TextType', 'string', 'Encoding', 'UTF-8');
    verifyEqual(testCase, artwork.Source, relativeFigure);
    verifyEqual(testCase, artwork.Status, "Below target");
    verifyEqual(testCase, artwork.PixelWidth, png.Width);
    verifyEqual(testCase, readBytes(fullfile(unpacked, 'interactive', 'plotly.min.js')), readBytes(bundle));
    verifyEqual(testCase, readBytes(fullfile(unpacked, 'interactive', 'plotly.LICENSE.txt')), readBytes(license));
    for i = 1:numel(attachmentPaths)
        original = extractAfter(attachmentPaths(i), "attachments/");
        verifyEqual(testCase, readBytes(fullfile(unpacked, attachmentPaths(i))), ...
            readBytes(fullfile(project, original)));
    end
    verifyEqual(testCase, readBytes(figurePath), originalFigure);
    verifyFalse(testCase, isfile(fullfile(source, '01 signals', '波形.png')));
end

function testDeliveryWithoutOptionalContents(testCase)
    [root, source, output] = newDelivery(testCase);
    saveTrace(fullfile(source, 'plot.fig'));

    [archive, summary] = build_lab_delivery(source, output, 25.4, 1, ...
        'DPI', 100, 'CombinePDF', false);

    unpacked = fullfile(root, 'unpacked');
    members = extractMembers(archive, unpacked);
    expected = ["index.html"; "artwork-check.csv"; "delivery-manifest.csv"; ...
        "figures/index.html"; "figures/manifest.csv"; "figures/plots/plot.png"; ...
        "figures/plots/plot.pdf"; "figures/plots/plot.csv"];
    verifyEqual(testCase, sort(members), sort(expected));
    verifyEqual(testCase, summary.Figures.BookPage, 0);
    verifyEqual(testCase, summary.Artwork.Status, "Meets target");
    verifyTrue(testCase, istable(summary.Plotly));
    verifyEmpty(testCase, summary.Plotly);
    verifyEmpty(testCase, summary.Attachments);
    verifyInventory(testCase, unpacked, summary.Inventory, expected);
end

function testDeliveryInsideFigureFolderDoesNotReexportAnAttachment(testCase)
    [root, source] = newDelivery(testCase);
    figurePath = fullfile(source, 'plot.fig');
    output = fullfile(source, 'delivery.zip');
    saveTrace(figurePath);
    originalFigure = readBytes(figurePath);

    [archive, summary] = build_lab_delivery(source, output, 90, 300, ...
        'AttachmentRoot', source, 'Files', 'plot.fig', 'CombinePDF', false);

    verifyEqual(testCase, summary.Figures.Source, "plot.fig");
    verifyEqual(testCase, summary.Figures.Status, "Exported");
    verifyEqual(testCase, summary.Attachments, "attachments/plot.fig");
    unpacked = fullfile(root, 'unpacked');
    members = extractMembers(archive, unpacked);
    verifyEqual(testCase, members(endsWith(members, '.fig')), "attachments/plot.fig");
    verifyEqual(testCase, members(endsWith(members, '.png')), "figures/plots/plot.png");
    verifyEqual(testCase, readBytes(fullfile(unpacked, 'attachments', 'plot.fig')), originalFigure);
    verifyEqual(testCase, readBytes(figurePath), originalFigure);
end

function testInvalidOptionsAndAttachmentsLeaveNoArchive(testCase)
    [root, source, output] = newDelivery(testCase);
    project = fullfile(root, 'project');
    mkdir(project);
    mkdir(fullfile(project, 'subfolder'));
    writeText(fullfile(project, 'Script.m'), '% Selected attachment fixture.');
    writeText(fullfile(root, 'outside.m'), '% Outside attachment root.');
    buildWithFiles = @(files) build_lab_delivery(source, output, 90, 300, ...
        'AttachmentRoot', project, 'Files', files);

    verifyError(testCase, @() build_lab_delivery(source, fullfile(root, 'output.pdf'), 90, 300), ...
        'build_lab_delivery:OutputFormat');
    verifyError(testCase, @() buildWithFiles('../outside.m'), 'build_lab_delivery:UnsafeAttachment');
    verifyError(testCase, @() buildWithFiles('CON.txt'), 'build_lab_delivery:UnsafeAttachment');
    verifyError(testCase, @() buildWithFiles(["Script.m", "Script.m"]), ...
        'build_lab_delivery:DuplicateAttachment');
    verifyError(testCase, @() buildWithFiles(["Script.m", "script.m"]), ...
        'build_lab_delivery:DuplicateAttachment');
    verifyError(testCase, @() buildWithFiles('missing.m'), 'build_lab_delivery:AttachmentFile');
    verifyError(testCase, @() buildWithFiles('subfolder'), 'build_lab_delivery:AttachmentFile');
    verifyError(testCase, @() build_lab_delivery(source, output, 90, 300, 'PlotlyJS', 'stub.js'), ...
        'build_lab_delivery:BundlePair');
    verifyFalse(testCase, isfile(output));
    verifyFalse(testCase, isfile(fullfile(root, 'output.pdf')));
    entries = dir(root);
    names = string({entries.name});
    verifyEqual(testCase, sort(names(~ismember(names, [".", ".."]))).', ...
        ["outside.m"; "project"; "source"]);
end

function testExistingDeliveryIsPreserved(testCase)
    [root, source, output] = newDelivery(testCase);
    writeText(fullfile(root, 'keep.txt'), 'A previously delivered file.');
    zip(output, 'keep.txt', root);
    original = readBytes(output);

    verifyError(testCase, @() build_lab_delivery(source, output, 90, 300), ...
        'build_lab_delivery:OutputExists');
    verifyEqual(testCase, readBytes(output), original);
end

function [root, source, output] = newDelivery(testCase)
    root = string(tempname);
    source = fullfile(root, 'source');
    output = fullfile(root, 'delivery.zip');
    mkdir(source);
    addTeardown(testCase, @() rmdir(root, 's'));
end

function saveTrace(path)
    fig = figure('Visible', 'off', 'Position', [100, 100, 480, 320]);
    cleanup = onCleanup(@() delete(fig));
    ax = axes(fig);
    plot(ax, [0, 1, 2], [1, 3, 2], 'DisplayName', 'Synthetic trace');
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Response');
    savefig(fig, path);
end

function members = extractMembers(archive, unpacked)
    entries = string(unzip(archive, unpacked));
    entries = replace(entries(:), '\', '/');
    prefix = replace(unpacked, '\', '/') + "/";
    members = erase(entries, prefix);
end

function verifyInventory(testCase, unpacked, inventory, expectedMembers)
    saved = readtable(fullfile(unpacked, 'delivery-manifest.csv'), ...
        'TextType', 'string', 'Encoding', 'UTF-8');
    verifyEqual(testCase, saved.Properties.VariableNames, {'File', 'Role', 'Bytes'});
    verifyEqual(testCase, sortrows(inventory, 'File'), sortrows(saved, 'File'));
    verifyEqual(testCase, sort(saved.File), sort(expectedMembers(expectedMembers ~= "delivery-manifest.csv")));
    verifyTrue(testCase, all(strlength(saved.Role) > 0));
    for i = 1:height(saved)
        info = dir(fullfile(unpacked, saved.File(i)));
        assertEqual(testCase, numel(info), 1);
        verifyEqual(testCase, saved.Bytes(i), info.bytes);
    end
end

function verifyLocalLink(testCase, html, relative)
    url = regexptranslate('escape', relative);
    pattern = ['(?:href|src)="(?:\./)?', url, '"'];
    verifyNotEmpty(testCase, regexp(html, pattern, 'once'));
end

function writeText(path, value)
    file = fopen(path, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(file));
    fprintf(file, '%s', value);
end

function value = readUtf8(path)
    file = fopen(path, 'r', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(file));
    value = fscanf(file, '%c');
end

function value = readBytes(path)
    file = fopen(path, 'rb');
    cleanup = onCleanup(@() fclose(file));
    value = fread(file, Inf, '*uint8');
end
