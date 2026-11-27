function tests = test_replot_lab_figure
%TEST_REPLOT_LAB_FIGURE Check editable line data, layout, and validation.
    tests = functiontests(localfunctions);
end

function testLiteralLabelsAndSampleOrder(testCase)
    first = samples(2, 1, "001", [2, 1, 1, 3], [1, NaN, 4, 5]);
    second = samples(2, 5, "实测 \tau, A", [3, 1], [10, 11]);
    third = samples(9, 1, "001", [3, 4], [1, 2]);
    third.AxesTitle(:) = "第二幅";
    data = [third; second; first];
    path = writeSamples(testCase, data(end:-1:1, :));

    [fig, ax, lines] = replot_lab_figure(path, 'Visible', 'off', 'Columns', 2);
    addTeardown(testCase, @delete, fig);

    verifySize(testCase, ax, [2, 1]);
    verifySize(testCase, lines, [3, 1]);
    verifyEqual(testCase, ax(1).Parent.GridSize, [1, 2]);
    verifyEqual(testCase, string(ax(1).Title.String), "Lab \theta");
    verifyEqual(testCase, string(ax(2).Title.String), "第二幅");
    verifyEqual(testCase, string(ax(1).XLabel.String), "001 ms");
    verifyEqual(testCase, string(ax(1).YLabel.String), "电压 (V)");
    verifyEqual(testCase, ax(1).Title.Interpreter, 'none');
    verifyEqual(testCase, string(lines(1).DisplayName), "001");
    verifyEqual(testCase, string(lines(2).DisplayName), "实测 \tau, A");
    verifyEqual(testCase, lines(1).Parent, ax(1));
    verifyEqual(testCase, lines(3).Parent, ax(2));
    verifyEqual(testCase, lines(1).XData(:), first.X);
    verifyTrue(testCase, isequaln(lines(1).YData(:), first.Y));
    verifyEqual(testCase, lines(2).XData(:), second.X);
    verifyEqual(testCase, lines(2).YData(:), second.Y);
    verifyEqual(testCase, char(fig.Visible), 'off');

    legends = findall(fig, 'Type', 'legend');
    verifyNumElements(testCase, legends, 1);
    verifyEqual(testCase, legends.Interpreter, 'none');
    roundTrip = extract_lab_figure_data(ax(1));
    verifyEqual(testCase, roundTrip.X, [first.X; second.X]);
    verifyTrue(testCase, isequaln(roundTrip.Y, [first.Y; second.Y]));
end

function testLogOptionsApplyToAxesInIDOrder(testCase)
    path = writeSamples(testCase, [samples(9, 1, "A", [1, 2], [3, 4]); ...
        samples(3, 1, "B", [1, 2], [3, 4])]);
    [fig, ax] = replot_lab_figure(path, 'Visible', "off", ...
        'XScale', ["log", "linear"], 'YScale', "log");
    addTeardown(testCase, @delete, fig);

    verifyEqual(testCase, ax(1).Parent.GridSize, [2, 1]);
    verifyEqual(testCase, {ax.XScale}, {'log', 'linear'});
    verifyEqual(testCase, {ax.YScale}, {'log', 'log'});
end

function testBadDataAndOptionsDoNotCreateFigures(testCase)
    valid = samples(1, 1, "A", [0, 1], [2, 3]);
    invalid = valid;
    invalid.Sample(:) = 1;
    validPath = writeSamples(testCase, valid);
    invalidPath = writeSamples(testCase, invalid);
    existing = figure('Visible', 'off');
    addTeardown(testCase, @delete, existing);
    before = findall(groot, 'Type', 'figure');

    verifyError(testCase, @() replot_lab_figure(invalidPath), 'replot_lab_figure:InvalidCSV');
    verifyError(testCase, @() replot_lab_figure(validPath, 'Columns', 0), ...
        'replot_lab_figure:InvalidOption');
    verifyError(testCase, @() replot_lab_figure(validPath, 'YScale', ["linear", "log"]), ...
        'replot_lab_figure:InvalidOption');
    verifyError(testCase, @() replot_lab_figure(validPath, 'XScale', 'log'), ...
        'replot_lab_figure:NonpositiveLogData');
    verifyEqual(testCase, findall(groot, 'Type', 'figure'), before);
end

function testHeaderOnlyReturnsNoFigure(testCase)
    data = samples(1, 1, "A", 1, 2);
    path = writeSamples(testCase, data([], :));
    before = findall(groot, 'Type', 'figure');
    [fig, ax, lines] = replot_lab_figure(path);
    verifyEmpty(testCase, fig);
    verifyEmpty(testCase, ax);
    verifyEmpty(testCase, lines);
    verifyEqual(testCase, findall(groot, 'Type', 'figure'), before);
end

function path = writeSamples(testCase, data)
    path = [tempname, '.csv'];
    writetable(data, path, 'Encoding', 'UTF-8');
    addTeardown(testCase, @delete, path);
end

function data = samples(axesID, seriesID, label, x, y)
    count = numel(x);
    data = table(repmat(axesID, count, 1), repmat("Lab \theta", count, 1), ...
        repmat("001 ms", count, 1), repmat("电压 (V)", count, 1), ...
        repmat(seriesID, count, 1), repmat(label, count, 1), ...
        (1:count).', x(:), y(:), 'VariableNames', {'Axes', 'AxesTitle', ...
        'XLabel', 'YLabel', 'Series', 'Label', 'Sample', 'X', 'Y'});
end
