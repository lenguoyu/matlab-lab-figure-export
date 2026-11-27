function samples = extract_lab_figure_data(target)
%EXTRACT_LAB_FIGURE_DATA Read XY samples from MATLAB line plots.
%   SAMPLES = EXTRACT_LAB_FIGURE_DATA(TARGET) reads a Cartesian axes or a
%   figure, including Cartesian axes inside a tiled layout. Each row holds
%   one sample. Axes indices follow the reversed graphics search order and
%   series indices restart per axes in ordinary plot creation order.
%
%   Only visible, direct child Line objects with real numeric XData and
%   YData and empty ZData are included. Therefore, scatter, images, grouped
%   charts and 3-D lines are outside this data export. Sample indices start
%   at 1 and retain each line's original order and NaN breaks. Line names
%   come from DisplayName, with "Series N" used for unnamed lines.
%   YLabel is empty for dual-y axes because either active label could
%   incorrectly describe the lines on the other side.

    narginchk(1, 1);
    if isscalar(target) && isa(target, 'matlab.graphics.axis.Axes') && isvalid(target)
        axesHandles = target;
    elseif isscalar(target) && isa(target, 'matlab.ui.Figure') && isvalid(target)
        foundAxes = findall(target, 'Type', 'axes');
        cartesian = arrayfun(@(ax) isa(ax, 'matlab.graphics.axis.Axes'), foundAxes);
        axesHandles = foundAxes(cartesian);
        axesHandles = flipud(axesHandles(:));
    else
        error('extract_lab_figure_data:InvalidTarget', ...
            'Target must be a scalar Cartesian axes or figure handle.');
    end

    emptySamples = table('Size', [0, 9], ...
        'VariableTypes', {'double', 'string', 'string', 'string', ...
        'double', 'string', 'double', 'double', 'double'}, ...
        'VariableNames', {'Axes', 'AxesTitle', 'XLabel', 'YLabel', ...
        'Series', 'Label', 'Sample', 'X', 'Y'});
    axesTables = cell(numel(axesHandles) + 1, 1);
    axesTables{1} = emptySamples;
    for axesIndex = 1:numel(axesHandles)
        axesTables{axesIndex + 1} = collectAxes(axesHandles(axesIndex), axesIndex, emptySamples);
    end
    samples = vertcat(axesTables{:});
end

function samples = collectAxes(ax, axesIndex, emptySamples)
    children = allchild(ax);
    children = flipud(children(:));
    lineTables = cell(numel(children) + 1, 1);
    lineTables{1} = emptySamples;
    axesTitle = readText(ax.Title.String);
    xLabel = readText(ax.XLabel.String);
    yLabel = "";
    if isscalar(ax.YAxis)
        yLabel = readText(ax.YLabel.String);
    end
    seriesIndex = 0;

    for childIndex = 1:numel(children)
        line = children(childIndex);
        if ~isa(line, 'matlab.graphics.chart.primitive.Line') || ...
                ~strcmp(line.Visible, 'on') || ~isempty(line.ZData)
            continue;
        end

        x = line.XData;
        y = line.YData;
        if ~isnumeric(x) || ~isnumeric(y) || ~isreal(x) || ~isreal(y) || ...
                isempty(x) || ~isvector(x) || ~isvector(y) || numel(x) ~= numel(y)
            continue;
        end

        seriesIndex = seriesIndex + 1;
        label = readText(line.DisplayName);
        if ismissing(label) || strlength(strip(label)) == 0
            label = "Series " + string(seriesIndex);
        end

        count = numel(x);
        lineTables{seriesIndex + 1} = table( ...
            repmat(axesIndex, count, 1), repmat(axesTitle, count, 1), ...
            repmat(xLabel, count, 1), repmat(yLabel, count, 1), ...
            repmat(seriesIndex, count, 1), repmat(label, count, 1), ...
            (1:count).', full(double(x(:))), full(double(y(:))), ...
            'VariableNames', emptySamples.Properties.VariableNames);
    end

    samples = vertcat(lineTables{1:seriesIndex + 1});
end

function label = readText(value)
    parts = string(value);
    if isempty(parts)
        label = "";
    else
        label = join(parts(:), newline);
    end
end
