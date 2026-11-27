function spec = build_lab_plotly_spec(data, keys, starts, source, xScale, yScale)
%BUILD_LAB_PLOTLY_SPEC Adapt validated lab line data to a Plotly figure.
%   Axes IDs are mapped to consecutive Plotly subplot IDs in ascending
%   order. Each trace retains its stored sample order and gaps.

    [axesIDs, firstSeries] = unique(keys(:, 1), 'first');
    axesCount = numel(axesIDs);
    firstSeries(end + 1) = size(keys, 1) + 1;
    traces = cell(size(keys, 1), 1);
    annotations = cell(axesCount, 1);
    layout = struct('autosize', true, 'height', max(420, 265 * axesCount + 140), ...
        'title', struct('text', plotlyText(source)), 'hovermode', 'closest', ...
        'margin', struct('l', 72, 'r', 36, 't', 92, 'b', 64));
    if axesCount > 0
        layout.grid = struct('rows', axesCount, 'columns', 1, ...
            'pattern', 'independent', 'roworder', 'top to bottom', 'ygap', 0.28);
    end

    for axesIndex = 1:axesCount
        series = firstSeries(axesIndex):firstSeries(axesIndex + 1) - 1;
        metadata = data{starts(series), {'AxesTitle', 'XLabel', 'YLabel'}};
        if any(metadata ~= metadata(1, :), 'all')
            error('export_lab_plotly:InvalidCSV', ...
                'Axes %d has inconsistent title or axis labels.', axesIDs(axesIndex));
        end

        suffix = '';
        if axesIndex > 1
            suffix = sprintf('%d', axesIndex);
        end
        xRef = ['x', suffix];
        yRef = ['y', suffix];
        layout.(['xaxis', suffix]) = plotlyAxis(xScale, metadata(1, 2), yRef);
        layout.(['yaxis', suffix]) = plotlyAxis(yScale, metadata(1, 3), xRef);

        axesTitle = metadata(1, 1);
        if axesCount > 1 && strlength(strip(axesTitle)) == 0
            axesTitle = "Axes " + string(axesIDs(axesIndex));
        end
        if strlength(strip(axesTitle)) > 0
            annotations{axesIndex} = struct('text', plotlyText(axesTitle), ...
                'x', 0.5, 'y', 1, 'xref', [xRef, ' domain'], 'yref', [yRef, ' domain'], ...
                'xanchor', 'center', 'yanchor', 'bottom', 'yshift', 6, 'showarrow', false);
        end

        for seriesIndex = series
            rows = starts(seriesIndex):starts(seriesIndex + 1) - 1;
            x = data.X(rows);
            y = data.Y(rows);
            paired = isfinite(x) & isfinite(y);
            if (strcmp(xScale, 'log') && any(x(paired) <= 0)) || ...
                    (strcmp(yScale, 'log') && any(y(paired) <= 0))
                error('export_lab_plotly:InvalidLogCoordinates', ...
                    'Axes %d contains nonpositive paired values on a requested log scale.', axesIDs(axesIndex));
            end

            label = data.Label(rows(1));
            if strlength(strip(label)) == 0
                label = "Series " + string(keys(seriesIndex, 2));
            end
            legendKey = sprintf('axes-%d-series-%d', keys(seriesIndex, :));
            mode = 'lines';
            adjacent = [false; paired(1:end-1)] | [paired(2:end); false];
            if any(paired & ~adjacent)
                mode = 'lines+markers';
            end
            traces{seriesIndex} = struct('type', 'scatter', 'mode', mode, ...
                'name', plotlyText(label), 'uid', legendKey, 'legendgroup', legendKey, ...
                'xaxis', xRef, 'yaxis', yRef, 'connectgaps', false, ...
                'x', {num2cell(x)}, 'y', {num2cell(y)}, ...
                'customdata', {num2cell(data.Sample(rows))}, ...
                'hovertemplate', 'Sample %{customdata}<br>X %{x}<br>Y %{y}<extra>%{fullData.name}</extra>');
        end
    end

    layout.annotations = annotations(~cellfun('isempty', annotations));
    spec = struct('data', {traces}, 'layout', layout);
end

function axisSpec = plotlyAxis(scale, label, anchor)
    axisSpec = struct('type', char(scale), 'title', struct('text', plotlyText(label)), ...
        'anchor', anchor, 'automargin', true);
end

function escaped = plotlyText(value)
    escaped = lab_html_escape(value);
    escaped = strrep(escaped, sprintf('\r\n'), newline);
    escaped = strrep(escaped, sprintf('\r'), newline);
    escaped = strrep(escaped, newline, '<br>');
end
