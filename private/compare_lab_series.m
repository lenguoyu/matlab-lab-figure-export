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
    [baseline, baselineKeys, baselineStarts] = read_lab_line_data(baselineCSV, mfilename);
    [candidate, candidateKeys, candidateStarts] = read_lab_line_data(candidateCSV, mfilename);
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
