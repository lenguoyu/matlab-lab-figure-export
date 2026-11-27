function [figures, series] = compare_lab_packs(baselineFolder, candidateFolder, outputFolder, varargin)
%COMPARE_LAB_PACKS Compare plotted XY data in two exported Figure Packs.
%   [FIGURES, SERIES] = COMPARE_LAB_PACKS(BASELINE, CANDIDATE, OUTPUT)
%   pairs entries by their exact Source paths in manifest.csv. It writes
%   comparison.csv, series.csv, and an offline index.html in a fresh
%   output directory. The parent directory must already exist.
%
%   'AbsTol' and 'RelTol' are nonnegative tolerances, both defaulting to
%   zero. Only compatible plotted samples are compared. PNG previews are
%   for visual inspection. This function does not open FIG files.
%
%   Example:
%     [figures, series] = compare_lab_packs('first-pack', 'new-pack', ...
%         'comparison', 'AbsTol', 1e-6, 'RelTol', 1e-3);

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'AbsTol', 0);
    addParameter(options, 'RelTol', 0);
    parse(options, varargin{:});
    absTol = tolerance(options.Results.AbsTol, 'AbsTol');
    relTol = tolerance(options.Results.RelTol, 'RelTol');

    [outputFolder, outputParent] = lab_pack_destination(outputFolder, mfilename);
    baseline = read_lab_pack(baselineFolder, "Baseline", mfilename);
    candidate = read_lab_pack(candidateFolder, "Candidate", mfilename);
    source = union(baseline.Manifest.Source, candidate.Manifest.Source);
    [~, baselineRows] = ismember(source, baseline.Manifest.Source);
    [~, candidateRows] = ismember(source, candidate.Manifest.Source);
    count = numel(source);

    [stage, stageCleanup] = lab_pack_stage(outputParent, mfilename);
    [created, message] = mkdir(fullfile(stage, 'previews'));
    if ~created
        error('compare_lab_packs:PreviewFolder', 'Cannot create the preview folder: %s', message);
    end

    figures = table(source, strings(count, 1), strings(count, 1), strings(count, 1), ...
        zeros(count, 1), zeros(count, 1), zeros(count, 1), nan(count, 1), strings(count, 1), ...
        'VariableNames', {'Source', 'Status', 'BaselinePreview', 'CandidatePreview', ...
        'ComparedSeries', 'OutsideSeries', 'ReviewSeries', 'MaxAbsDelta', 'Message'});
    details = cell(count + 1, 1);
    details{1} = emptySeries();
    for index = 1:count
        [figures(index, :), details{index + 1}] = compareFigure(figures(index, :), ...
            baseline, baselineRows(index), candidate, candidateRows(index), ...
            stage, index, absTol, relTol);
    end
    series = vertcat(details{:});

    writetable(figures, fullfile(stage, 'comparison.csv'), 'Encoding', 'UTF-8', 'QuoteStrings', true);
    writetable(series, fullfile(stage, 'series.csv'), 'Encoding', 'UTF-8', 'QuoteStrings', true);
    write_lab_pack_comparison(fullfile(stage, 'index.html'), figures, series, absTol, relTol);
    publish_lab_pack(stage, outputFolder, mfilename);
end

function result = tolerance(value, name)
    validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, ...
        'compare_lab_packs', name);
    result = double(value);
end

function [figure, rows] = compareFigure(figure, baseline, baseRow, candidate, candRow, ...
        stage, index, absTol, relTol)
    [figure.BaselinePreview, baseCSV, baseNotes] = inspectRow(baseline, baseRow, stage, index);
    [figure.CandidatePreview, candCSV, candNotes] = inspectRow(candidate, candRow, stage, index);
    notes = [baseNotes, candNotes];
    rows = emptySeries();
    if baseRow == 0 || candRow == 0
        figure.Status = "Added";
        presence = "Source exists only in the candidate pack.";
        if candRow == 0
            figure.Status = "Removed";
            presence = "Source exists only in the baseline pack.";
        end
        if ~isempty(notes)
            figure.Status = "Needs review";
        end
        figure.Message = strjoin([presence, notes], " ");
        return
    end

    if baseCSV ~= "" && candCSV ~= ""
        try
            rows = compare_lab_series(figure.Source, baseCSV, candCSV, absTol, relTol);
        catch
            notes(end + 1) = "XY data could not be read in the expected Figure Pack CSV format.";
        end
    elseif xor(baseCSV ~= "", candCSV ~= "")
        notes(end + 1) = "Compatible XY data files are required on both sides.";
    end

    numeric = rows.ComparedSamples > 0;
    outside = rows.Status == "Outside tolerance" | rows.OutsideSamples > 0;
    review = rows.Status ~= "Within tolerance" & rows.Status ~= "Outside tolerance";
    figure.ComparedSeries = nnz(numeric);
    figure.OutsideSeries = nnz(outside);
    figure.ReviewSeries = nnz(review);
    deltas = rows.MaxAbsDelta(numeric & ~isnan(rows.MaxAbsDelta));
    if ~isempty(deltas)
        figure.MaxAbsDelta = max(deltas);
    end
    if any(review)
        notes(end + 1) = sprintf('%d series need review. See series.csv for details.', nnz(review));
    end

    if any(outside)
        figure.Status = "Outside tolerance";
    elseif ~isempty(notes)
        figure.Status = "Needs review";
    elseif any(numeric)
        figure.Status = "Within tolerance";
    else
        figure.Status = "Visual only";
        notes = "Neither pack contains supported XY samples for this figure.";
    end
    if ~isempty(notes)
        figure.Message = strjoin(notes, " ");
    end
end

function [preview, csvPath, notes] = inspectRow(pack, index, stage, fileIndex)
    preview = "";
    csvPath = "";
    notes = strings(1, 0);
    if index == 0
        return
    end
    row = pack.Manifest(index, :);
    if row.Status ~= "Exported"
        notes = pack.Label + " export requires review. See its manifest for details.";
        return
    end

    [pngPath, issue] = lab_pack_artifact(pack, row.PNG, ".png");
    if issue == ""
        previewName = string(sprintf('previews/%04d-%s.png', fileIndex, lower(pack.Label)));
        issue = copy_lab_preview(pngPath, fullfile(stage, previewName), 'compare_lab_packs');
        if issue == ""
            preview = previewName;
        end
    end
    if issue ~= ""
        notes(end + 1) = pack.Label + " PNG: " + issue;
    end

    if row.DataCSV ~= "" || row.SeriesCount > 0
        [csvPath, issue] = lab_pack_artifact(pack, row.DataCSV, ".csv");
        if issue ~= ""
            notes(end + 1) = pack.Label + " data CSV: " + issue;
        end
    end
end

function rows = emptySeries()
    rows = table('Size', [0, 11], ...
        'VariableNames', {'Source', 'Axes', 'Series', 'Label', 'Status', 'ComparedSamples', ...
        'SkippedSamples', 'OutsideSamples', 'MaxAbsDelta', 'XAtMax', 'Message'}, ...
        'VariableTypes', {'string', 'double', 'double', 'string', 'string', 'double', ...
        'double', 'double', 'double', 'double', 'string'});
end
