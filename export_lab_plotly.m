function report = export_lab_plotly(packFolder, outputFolder, varargin)
%EXPORT_LAB_PLOTLY Export a Figure Pack's XY lines to Plotly.
%   REPORT = EXPORT_LAB_PLOTLY(PACKFOLDER, OUTPUTFOLDER) writes one Plotly
%   figure JSON per supported figure and a plotly-manifest.csv index.
%
%   Supply 'PlotlyJS' and 'PlotlyLicense' with paths to a local official
%   browser bundle and its matching license to build an offline HTML
%   workbook instead. The page can download individual figure JSON files.
%   A figure without usable line data can show its original PNG preview.
%
%   'XScale' and 'YScale' each default to 'linear'. Set either to 'log'
%   when all finite paired coordinates on that dimension are positive.
%   The output directory must be new and its parent must exist.

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'PlotlyJS', "");
    addParameter(options, 'PlotlyLicense', "");
    addParameter(options, 'XScale', "linear");
    addParameter(options, 'YScale', "linear");
    parse(options, varargin{:});

    [bundle, license] = lab_plotly_assets(options.Results.PlotlyJS, options.Results.PlotlyLicense, mfilename);
    xScale = axisScale(options.Results.XScale, 'XScale');
    yScale = axisScale(options.Results.YScale, 'YScale');
    hasViewer = bundle ~= "";

    [outputFolder, parent] = lab_pack_destination(outputFolder, mfilename);
    pack = read_lab_pack(packFolder, "Input", mfilename);
    [stage, stageCleanup] = lab_pack_stage(parent, mfilename);
    count = height(pack.Manifest);
    report = table(pack.Manifest.Source, strings(count, 1), zeros(count, 1), ...
        strings(count, 1), strings(count, 1), ...
        'VariableNames', {'Source', 'Status', 'SeriesCount', 'Artifact', 'Message'});
    entries = repmat(struct('source', "", 'status', "", 'message', "", ...
        'preview', "", 'spec', []), count, 1);

    for index = 1:count
        row = pack.Manifest(index, :);
        [spec, numberOfSeries, state, detail] = figureSpec(pack, row, xScale, yScale);
        artifact = "";
        preview = "";
        if hasViewer
            if isempty(spec)
                [preview, state, detail] = addPreview(pack, row, stage, index, state, detail);
                if preview ~= ""
                    artifact = "index.html";
                end
            else
                state = "Interactive";
                artifact = "index.html";
            end
            entries(index) = struct('source', row.Source, 'status', state, ...
                'message', detail, 'preview', preview, 'spec', spec);
        elseif ~isempty(spec)
            folder = fullfile(stage, 'figures');
            makeFolder(folder);
            artifact = string(sprintf('figures/%04d.json', index));
            writeSpec(fullfile(stage, artifact), spec);
        end
        report.Status(index) = state;
        report.SeriesCount(index) = numberOfSeries;
        report.Artifact(index) = artifact;
        report.Message(index) = detail;
    end

    if hasViewer
        copyInput(bundle, fullfile(stage, 'plotly.min.js'));
        copyInput(license, fullfile(stage, 'plotly.LICENSE.txt'));
        write_lab_plotly_viewer(fullfile(stage, 'index.html'), entries);
    end
    writetable(report, fullfile(stage, 'plotly-manifest.csv'), ...
        'Encoding', 'UTF-8', 'QuoteStrings', true);
    publish_lab_pack(stage, outputFolder, mfilename);
end

function [spec, numberOfSeries, state, detail] = figureSpec(pack, row, xScale, yScale)
    spec = [];
    numberOfSeries = 0;
    state = "Needs review";
    detail = "";
    if row.Status ~= "Exported"
        detail = "See the input pack's manifest for the original export error.";
        return;
    end
    if row.DataCSV == "" && ~(row.SeriesCount > 0)
        state = "Static only";
        detail = "Open the original preview for this figure.";
        return;
    end
    [csv, issue] = lab_pack_artifact(pack, row.DataCSV, ".csv");
    if issue ~= ""
        detail = "XY CSV: " + issue;
        return;
    end
    try
        [data, keys, starts] = read_lab_line_data(csv, 'export_lab_plotly');
        if isempty(keys)
            detail = "The recorded XY CSV contains no line samples.";
            return;
        end
        spec = build_lab_plotly_spec(data, keys, starts, row.Source, xScale, yScale);
    catch problem
        switch problem.identifier
            case 'export_lab_plotly:InvalidCSV'
                detail = "The XY CSV could not be read with consistent Figure Pack metadata.";
            case 'export_lab_plotly:InvalidLogCoordinates'
                detail = string(problem.message);
            otherwise
                rethrow(problem);
        end
        return;
    end
    numberOfSeries = size(keys, 1);
    state = "Exported";
end

function [preview, state, detail] = addPreview(pack, row, stage, index, state, detail)
    preview = "";
    if row.Status ~= "Exported"
        return;
    end
    [png, issue] = lab_pack_artifact(pack, row.PNG, ".png");
    if issue == ""
        makeFolder(fullfile(stage, 'previews'));
        path = string(sprintf('previews/%04d.png', index));
        issue = copy_lab_preview(png, fullfile(stage, path), 'export_lab_plotly');
        if issue == ""
            preview = path;
        end
    end
    if issue ~= ""
        state = "Needs review";
        detail = strip(detail + " PNG preview: " + issue);
    end
end

function value = textOption(value, name)
    if ischar(value) && (isrow(value) || isempty(value))
        value = string(value);
    end
    if ~isstring(value) || ~isscalar(value) || ismissing(value)
        error('export_lab_plotly:InvalidOption', '%s must be a text scalar.', name);
    end
end

function value = axisScale(value, name)
    value = lower(textOption(value, name));
    if ~ismember(value, ["linear", "log"])
        error('export_lab_plotly:InvalidScale', '%s must be linear or log.', name);
    end
end

function makeFolder(folder)
    if ~isfolder(folder)
        [created, message] = mkdir(folder);
        if ~created
            error('export_lab_plotly:OutputFolder', 'Cannot create an output directory: %s', message);
        end
    end
end

function copyInput(input, output)
    [copied, message] = copyfile(input, output);
    if ~copied
        error('export_lab_plotly:CopyBundle', 'Cannot copy the local renderer files: %s', message);
    end
end

function writeSpec(destination, spec)
    [file, openMessage] = fopen(destination, 'w', 'n', 'UTF-8');
    if file < 0
        error('export_lab_plotly:JSONWrite', 'Cannot open the JSON output: %s', openMessage);
    end
    fileGuard = onCleanup(@() fclose(file));
    fprintf(file, '%s\n', jsonencode(spec));
    [writeMessage, status] = ferror(file);
    if status ~= 0
        error('export_lab_plotly:JSONWrite', 'Cannot write the JSON output: %s', writeMessage);
    end
end
