function [fig, ax, lines] = replot_lab_figure(csvPath, varargin)
%REPLOT_LAB_FIGURE Create an editable figure from Figure Pack line data.
%   [FIG, AX, LINES] = REPLOT_LAB_FIGURE(CSVPATH) creates a Cartesian tile
%   for each represented axes ID. AX is ordered by ascending axes ID and
%   LINES by ascending axes and series IDs. Sample order within each line
%   is preserved, including repeated X coordinates and NaN gaps.
%
%   'Visible' defaults to 'on'. 'Columns' sets the maximum number of tiles
%   across and defaults to 1. 'XScale' and 'YScale' default to 'linear'.
%   Pass 'linear' or 'log' for all axes, or one value per AX element.
%   Logarithmic scales require all finite values on that coordinate to be
%   positive. Each scale can be a character vector, string vector, or cell
%   vector of character vectors.
%
%   The CSV supplies the plotted values and literal text. Original tile
%   positions, formatting, annotations, and dual-Y sides are unavailable.
%   A legend is added for named lines when a tile has multiple series.
%   An empty line-data CSV returns empty handles without opening a figure.

    parser = inputParser;
    parser.FunctionName = mfilename;
    parser.PartialMatching = false;
    addParameter(parser, 'Visible', 'on');
    addParameter(parser, 'Columns', 1);
    addParameter(parser, 'XScale', 'linear');
    addParameter(parser, 'YScale', 'linear');
    parse(parser, varargin{:});
    options = parser.Results;

    visible = readChoices(options.Visible, ["on", "off"], 'Visible');
    if ~isscalar(visible)
        error('replot_lab_figure:InvalidOption', 'Visible requires one value.');
    end
    columns = options.Columns;
    if ~isnumeric(columns) || ~isscalar(columns) || ~isreal(columns) || ...
            ~isfinite(columns) || columns < 1 || columns ~= fix(columns)
        error('replot_lab_figure:InvalidOption', 'Columns must be a positive integer.');
    end

    [data, keys, starts] = read_lab_line_data(csvPath, mfilename);
    [axesIDs, firstSeries] = unique(keys(:, 1), 'first');
    axesCount = numel(axesIDs);
    firstSeries(end + 1) = size(keys, 1) + 1;
    xScales = readScales(options.XScale, 'XScale', axesCount);
    yScales = readScales(options.YScale, 'YScale', axesCount);
    validateAxesData(data, axesIDs, firstSeries, starts, xScales, yScales);

    if axesCount == 0
        fig = gobjects(0, 1);
        ax = gobjects(0, 1);
        lines = gobjects(0, 1);
        return;
    end

    columns = min(double(columns), axesCount);
    rows = ceil(axesCount / columns);
    ax = gobjects(axesCount, 1);
    lines = gobjects(size(keys, 1), 1);
    fig = figure('Visible', 'off');
    try
        layout = tiledlayout(fig, rows, columns, 'TileSpacing', 'compact', 'Padding', 'compact');
        for axesIndex = 1:axesCount
            currentAxes = nexttile(layout, axesIndex);
            ax(axesIndex) = currentAxes;
            series = firstSeries(axesIndex):firstSeries(axesIndex + 1) - 1;
            hold(currentAxes, 'on');
            for seriesIndex = series
                sampleRows = starts(seriesIndex):starts(seriesIndex + 1) - 1;
                label = data.Label(starts(seriesIndex));
                lines(seriesIndex) = plot(currentAxes, data.X(sampleRows), ...
                    data.Y(sampleRows), 'DisplayName', char(label));
            end
            hold(currentAxes, 'off');

            firstRow = starts(series(1));
            title(currentAxes, char(data.AxesTitle(firstRow)), 'Interpreter', 'none');
            xlabel(currentAxes, char(data.XLabel(firstRow)), 'Interpreter', 'none');
            ylabel(currentAxes, char(data.YLabel(firstRow)), 'Interpreter', 'none');
            set(currentAxes, 'XScale', char(xScales(axesIndex)), 'YScale', char(yScales(axesIndex)));

            labels = data.Label(starts(series));
            named = strlength(strip(labels)) > 0;
            if numel(series) > 1 && any(named)
                legend(currentAxes, lines(series(named)), cellstr(labels(named)), ...
                    'Interpreter', 'none', 'Location', 'best');
            end
        end
        fig.Visible = char(visible);
    catch issue
        if isgraphics(fig, 'figure')
            delete(fig);
        end
        rethrow(issue);
    end
end

function choices = readChoices(value, allowed, name)
    if ~(ischar(value) && isrow(value)) && ~(isstring(value) && isvector(value)) && ...
            ~(iscellstr(value) && isvector(value))
        error('replot_lab_figure:InvalidOption', '%s must contain text values.', name);
    end
    choices = lower(string(value));
    choices = choices(:);
    if any(ismissing(choices)) || any(~ismember(choices, allowed))
        error('replot_lab_figure:InvalidOption', 'Allowed values for %s are %s.', ...
            name, char(strjoin(allowed, ', ')));
    end
end

function scales = readScales(value, name, axesCount)
    scales = readChoices(value, ["linear", "log"], name);
    if isscalar(scales)
        scales = repmat(scales, axesCount, 1);
    elseif numel(scales) ~= axesCount
        error('replot_lab_figure:InvalidOption', '%s requires one value or one per recovered axes.', name);
    end
end

function validateAxesData(data, axesIDs, firstSeries, starts, xScales, yScales)
    metadataFields = {'AxesTitle', 'XLabel', 'YLabel'};
    for axesIndex = 1:numel(axesIDs)
        first = firstSeries(axesIndex);
        after = firstSeries(axesIndex + 1);
        metadata = data{starts(first:after - 1), metadataFields};
        if any(metadata ~= metadata(1, :), 'all')
            error('replot_lab_figure:InvalidCSV', ...
                'Axes %g has inconsistent title or axis labels.', axesIDs(axesIndex));
        end
        if xScales(axesIndex) == "log"
            requirePositive(data.X(starts(first):starts(after) - 1), axesIDs(axesIndex), 'X');
        end
        if yScales(axesIndex) == "log"
            requirePositive(data.Y(starts(first):starts(after) - 1), axesIDs(axesIndex), 'Y');
        end
    end
end

function requirePositive(values, axesID, coordinate)
    if any(isfinite(values) & values <= 0)
        error('replot_lab_figure:NonpositiveLogData', ...
            'Axes %g contains nonpositive %s values on a requested logarithmic scale.', ...
            axesID, coordinate);
    end
end
