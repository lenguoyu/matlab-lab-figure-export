function report = compare_lab_series(source, baselineCSV, candidateCSV, absTol, relTol)
%COMPARE_LAB_SERIES Compare line-data CSVs made by MATLAB Figure Pack.
%   Series are matched by Axes and Series, with exact plot metadata and X
%   samples required. Samples are read in Sample order. Shared nonfinite
%   gaps do not enter numeric metrics. A gap change can still have metrics
%   for the remaining finite pairs. This comparison does no interpolation.
%   MaxAbsDelta is Inf when the largest difference exceeds double range.

    validateattributes(absTol, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(relTol, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    absTol = double(absTol);
    relTol = double(relTol);

    metadata = {'AxesTitle', 'XLabel', 'YLabel', 'Label'};
    [baseline, baselineKeys, baselineStarts] = readSeries(baselineCSV, metadata);
    [candidate, candidateKeys, candidateStarts] = readSeries(candidateCSV, metadata);
    keys = unique([baselineKeys; candidateKeys], 'rows');
    [~, baselineGroups] = ismember(keys, baselineKeys, 'rows');
    [~, candidateGroups] = ismember(keys, candidateKeys, 'rows');
    report = initializeReport(source, keys);

    for index = 1:height(report)
        baselineGroup = baselineGroups(index);
        candidateGroup = candidateGroups(index);
        if baselineGroup == 0
            report.Label(index) = candidate.Label(candidateStarts(candidateGroup));
            report.Status(index) = "Added series";
            report.Message(index) = "The candidate has no matching baseline series.";
            continue;
        end

        baselineStart = baselineStarts(baselineGroup);
        report.Label(index) = baseline.Label(baselineStart);
        if candidateGroup == 0
            report.Status(index) = "Missing series";
            report.Message(index) = "The baseline series is absent from the candidate.";
            continue;
        end

        candidateStart = candidateStarts(candidateGroup);
        changedMetadata = baseline{baselineStart, metadata} ~= candidate{candidateStart, metadata};
        if any(changedMetadata)
            report.Status(index) = "Metadata changed";
            report.Message(index) = "Changed metadata fields are " + ...
                strjoin(string(metadata(changedMetadata)), ', ') + ".";
            continue;
        end

        baselineRows = baselineStart:baselineStarts(baselineGroup + 1) - 1;
        candidateRows = candidateStart:candidateStarts(candidateGroup + 1) - 1;
        x = baseline.X(baselineRows);
        if ~isequaln(x, candidate.X(candidateRows))
            report.Status(index) = "Grid changed";
            report.Message(index) = "The runs differ in their ordered X samples or sample counts.";
            continue;
        end

        reference = baseline.Y(baselineRows);
        test = candidate.Y(candidateRows);
        finiteX = isfinite(x);
        referenceFinite = isfinite(reference);
        testFinite = isfinite(test);
        compared = finiteX & referenceFinite & testFinite;
        bothGaps = finiteX & ~referenceFinite & ~testFinite;
        gapChanged = any(finiteX & (referenceFinite ~= testFinite)) || ...
            ~isequaln(reference(bothGaps), test(bothGaps));
        report.ComparedSamples(index) = nnz(compared);
        report.SkippedSamples(index) = nnz(~compared);

        if any(compared)
            [outsideCount, maxDelta, peakX] = compareFinite( ...
                x(compared), reference(compared), test(compared), absTol, relTol);
            report.OutsideSamples(index) = outsideCount;
            report.MaxAbsDelta(index) = maxDelta;
            report.XAtMax(index) = peakX;
        end

        if gapChanged
            report.Status(index) = "Gap changed";
            report.Message(index) = "The nonfinite Y values differ at one or more finite X samples.";
        elseif ~any(compared)
            report.Status(index) = "No finite samples";
            report.Message(index) = "The series has no common finite XY samples.";
        elseif report.OutsideSamples(index) > 0
            report.Status(index) = "Outside tolerance";
        else
            report.Status(index) = "Within tolerance";
        end
    end
end

function report = initializeReport(source, keys)
    count = size(keys, 1);
    report = table(repmat(string(source), count, 1), keys(:, 1), keys(:, 2), ...
        strings(count, 1), strings(count, 1), zeros(count, 1), zeros(count, 1), ...
        zeros(count, 1), nan(count, 1), nan(count, 1), strings(count, 1), ...
        'VariableNames', {'Source', 'Axes', 'Series', 'Label', 'Status', ...
        'ComparedSamples', 'SkippedSamples', 'OutsideSamples', ...
        'MaxAbsDelta', 'XAtMax', 'Message'});
end

function [data, keys, starts] = readSeries(path, metadata)
    names = {'Axes', 'AxesTitle', 'XLabel', 'YLabel', 'Series', 'Label', 'Sample', 'X', 'Y'};
    checkHeader(path, names);

    % Read every value as text so numeric-looking titles and labels stay exact.
    options = delimitedTextImportOptions('NumVariables', numel(names));
    options.Delimiter = ',';
    options.Encoding = 'UTF-8';
    options.DataLines = [2, Inf];
    options.VariableNames = names;
    options.TrailingDelimitersRule = 'keep';
    options.ExtraColumnsRule = 'error';
    options.EmptyLineRule = 'error';
    options.MissingRule = 'error';
    options.ImportErrorRule = 'error';
    options = setvartype(options, names, 'string');
    options = setvaropts(options, names, 'WhitespaceRule', 'preserve', ...
        'EmptyFieldRule', 'auto');
    try
        data = readtable(path, options);
    catch importError
        invalidCSV(path, importError.message);
    end

    for name = metadata
        column = name{1};
        data.(column)(ismissing(data.(column))) = "";
    end
    for name = {'Axes', 'Series', 'Sample', 'X', 'Y'}
        column = name{1};
        tokens = strip(data.(column));
        values = str2double(tokens);
        allowedNaN = ismissing(tokens) | tokens == "" | strcmpi(tokens, 'NaN');
        if ~isreal(values) || any(isnan(values) & ~allowedNaN)
            invalidCSV(path, sprintf('Column %s contains a nonnumeric sample.', column));
        end
        data.(column) = values;
    end

    idColumns = {'Axes', 'Series', 'Sample'};
    ids = data{:, idColumns};
    if any(~isfinite(ids) | ids < 1 | ids > flintmax | ids ~= fix(ids), 'all')
        invalidCSV(path, 'Axes, Series and Sample must contain positive integer IDs.');
    end

    data = sortrows(data, idColumns);
    if isempty(data)
        keys = zeros(0, 2);
        starts = 1;
        return;
    end

    starts = find([true; diff(data.Axes) ~= 0 | diff(data.Series) ~= 0]);
    keys = data{starts, {'Axes', 'Series'}};
    starts(end + 1) = height(data) + 1;
    for group = 1:size(keys, 1)
        rows = starts(group):starts(group + 1) - 1;
        if ~isequal(data.Sample(rows), (1:numel(rows)).')
            invalidCSV(path, 'Each series must contain Sample indices 1 through N exactly once.');
        end
        values = data{rows, metadata};
        if any(values ~= values(1, :), 'all')
            invalidCSV(path, 'Plot metadata must remain constant within each series.');
        end
    end
end

function checkHeader(path, names)
    [file, message] = fopen(path, 'rt', 'n', 'UTF-8');
    if file == -1
        invalidCSV(path, message);
    end
    cleanup = onCleanup(@() fclose(file));
    line = fgetl(file);
    if ~ischar(line)
        invalidCSV(path, 'The line-data header is missing.');
    end
    if ~isempty(line) && line(1) == char(65279)
        line(1) = [];
    end
    header = split(string(line), ',').';
    header = regexprep(header, '^"([^"]*)"$', '$1');
    if ~isequal(header, string(names))
        invalidCSV(path, 'The header does not match the Figure Pack line-data schema.');
    end
end

function invalidCSV(path, detail)
    error('compare_lab_series:InvalidCSV', 'Invalid line-data CSV "%s". %s', path, detail);
end

function [outsideCount, maxDelta, peakX] = compareFinite(x, reference, test, absTol, relTol)
    delta = abs(test - reference);
    allowed = max(absTol, relTol .* abs(reference));
    outside = delta > allowed;

    % Reevaluate Inf > Inf on a scaled grid when both expressions overflow.
    overflow = isinf(delta) & isinf(allowed);
    if any(overflow)
        scale = max(abs(reference(overflow)), abs(test(overflow)));
        scaledReference = reference(overflow) ./ scale;
        scaledTest = test(overflow) ./ scale;
        outside(overflow) = abs(scaledTest - scaledReference) > ...
            max(absTol ./ scale, relTol .* abs(scaledReference));
    end
    outsideCount = nnz(outside);
    [maxDelta, peakIndex] = max(delta);
    if isinf(maxDelta)
        % Halving first preserves the peak's order when several deltas overflow.
        [~, peakIndex] = max(abs(test / 2 - reference / 2));
    end
    peakX = x(peakIndex);
end
