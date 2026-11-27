function report = export_lab_batch(sourceFolder, outputFolder, varargin)
%EXPORT_LAB_BATCH Export a tree of saved MATLAB figures for review.
%   REPORT = EXPORT_LAB_BATCH(SOURCEFOLDER, OUTPUTFOLDER) exports the .fig
%   files under SOURCEFOLDER to a new OUTPUTFOLDER. Only open FIG files
%   from sources you trust. MATLAB can execute code when opening a FIG.
%
%   The destination parent must exist. Each successful figure gets a PNG
%   and a vector PDF under plots/, preserving its relative source path.
%   Supported line samples are written to a companion CSV. The batch also
%   writes manifest.csv and index.html. A broken figure is recorded in the
%   report and does not stop other figures.
%
%   Name-value options:
%     'DPI'        Resolution of PNG exports (default 450).
%     'DryRun'     Plan output paths without opening figures or writing
%                  anything (default false).
%     'CombinePDF' Include successful figures in figures.pdf (default true).
%
%   The report contains Source, Status, PNG, PDF, DataCSV, SeriesCount,
%   BookPage, and Message. Paths are relative to their source or output
%   root. A BookPage of zero means there is no page in the combined PDF.
%
%   Example:
%     plan = export_lab_batch('saved_figures', 'figure_pack', 'DryRun', true);
%     report = export_lab_batch('saved_figures', 'figure_pack', 'DPI', 300);
%
%   The combined PDF uses the Append option introduced in MATLAB R2021b.

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'DPI', 450);
    addParameter(options, 'DryRun', false, @(value) islogical(value) && isscalar(value));
    addParameter(options, 'CombinePDF', true, @(value) islogical(value) && isscalar(value));
    parse(options, varargin{:});
    dpi = options.Results.DPI;
    validateattributes(dpi, {'numeric'}, {'scalar', 'real', 'finite', ...
        'integer', 'positive'}, mfilename, 'DPI');

    sourceFolder = lab_pack_folder(sourceFolder, "sourceFolder", mfilename);
    outputFolder = pathText(outputFolder, 'outputFolder');
    assertFreshOutput(outputFolder);
    if ispc
        outputFolder = replace(outputFolder, "\", "/");
    end
    outputFolder = regexprep(outputFolder, '/+$', '');
    assertFreshOutput(outputFolder);
    [outputParent, outputName, outputExtension] = fileparts(outputFolder);
    if strlength(outputParent) == 0
        outputParent = string(pwd);
    end
    outputParent = lab_pack_folder(outputParent, "outputFolder parent", mfilename);
    outputFolder = fullfile(outputParent, outputName + outputExtension);
    assertFreshOutput(outputFolder);

    [report, stems] = figurePlan(sourceFolder);
    if options.Results.DryRun
        return
    end

    stageFolder = string(tempname(outputParent));
    [created, message, messageId] = mkdir(stageFolder);
    if ~created || ~isempty(messageId)
        error('export_lab_batch:StageCreate', 'Cannot create a staging folder: %s', message);
    end
    stageCleanup = onCleanup(@() removeStage(stageFolder));
    originalFigure = get(groot, 'CurrentFigure');
    figureState = onCleanup(@() restoreCurrentFigure(originalFigure));

    bookName = "figures.pdf";
    bookPath = "";
    if options.Results.CombinePDF
        bookPath = fullfile(stageFolder, bookName);
    end
    nextBookPage = 1;
    for rowIndex = find(report.Status == "Planned").'
        [report(rowIndex, :), nextBookPage] = exportOne(report(rowIndex, :), ...
            stems(rowIndex), sourceFolder, stageFolder, dpi, bookPath, nextBookPage);
    end
    if nextBookPage == 1
        bookName = "";
    end

    writetable(report, fullfile(stageFolder, 'manifest.csv'), ...
        'Encoding', 'UTF-8', 'QuoteStrings', true);
    write_lab_figure_gallery(fullfile(stageFolder, 'index.html'), report, bookName);
    publish_lab_pack(stageFolder, outputFolder, mfilename);
end

function value = pathText(value, argumentName)
    if ischar(value) && isrow(value)
        value = string(value);
    end
    if ~isstring(value) || ~isscalar(value) || ismissing(value) || strlength(value) == 0
        error('export_lab_batch:InvalidPath', '%s must be a nonempty path.', argumentName);
    end
end

function [report, stems] = figurePlan(sourceFolder)
    listing = dir(fullfile(sourceFolder, '**', '*'));
    listing = listing(~[listing.isdir] & endsWith({listing.name}, '.fig', 'IgnoreCase', true));
    sources = strings(0, 1);
    if ~isempty(listing)
        prefix = sourceFolder;
        if ~endsWith(prefix, filesep)
            prefix = prefix + filesep;
        end
        absolute = string(fullfile({listing.folder}, {listing.name})).';
        sources = sort(replace(extractAfter(absolute, strlength(prefix)), filesep, '/'));
    end
    sourceStems = regexprep(sources, '\.fig$', '', 'ignorecase');
    % Preserve a usable filename for an input whose entire basename is ".fig".
    extensionOnly = sourceStems == "" | endsWith(sourceStems, '/');
    sourceStems(extensionOnly) = sources(extensionOnly);
    stems = "plots/" + sourceStems;

    count = numel(sources);
    report = table(sources, repmat("Planned", count, 1), stems + ".png", stems + ".pdf", ...
        strings(count, 1), zeros(count, 1), zeros(count, 1), strings(count, 1), ...
        'VariableNames', {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', ...
        'SeriesCount', 'BookPage', 'Message'});

    if count > 1
        % Case-folding prevents output collisions across case-insensitive filesystems.
        [~, ~, groups] = unique(lower(stems));
        occurrences = accumarray(groups, 1);
        conflict = occurrences(groups) > 1;
        report.Status(conflict) = "Failed";
        report.PNG(conflict) = "";
        report.PDF(conflict) = "";
        report.Message(conflict) = "Multiple inputs map to the same output path.";
    end
end

function [row, nextBookPage] = exportOne(row, stem, sourceFolder, stageFolder, dpi, bookPath, nextBookPage)
    outputBase = pathWithin(stageFolder, stem);
    pngPath = outputBase + ".png";
    pdfPath = outputBase + ".pdf";
    csvPath = outputBase + ".csv";
    sourcePath = pathWithin(sourceFolder, row.Source);
    ownPaths = false;
    try
        figureHandle = openfig(sourcePath, 'new', 'invisible');
        closeFigure = onCleanup(@() deleteFigures(figureHandle));
        if ~isscalar(figureHandle) || ~isgraphics(figureHandle, 'figure')
            error('export_lab_batch:FigureCount', 'Each FIG file must contain one figure.');
        end

        [created, message] = mkdir(fileparts(outputBase));
        if ~created
            error('export_lab_batch:PlotFolder', 'Cannot create the figure output folder: %s', message);
        end
        if any(isfile([pngPath, pdfPath, csvPath]) | isfolder([pngPath, pdfPath, csvPath]))
            error('export_lab_batch:PlotExists', 'An output file or folder conflicts with this figure.');
        end
        ownPaths = true;
        export_lab_figure(figureHandle, outputBase, dpi);
        samples = extract_lab_figure_data(figureHandle);
        if ~isempty(samples)
            writeSamples(samples, csvPath);
            row.DataCSV = stem + ".csv";
            row.SeriesCount = height(unique(samples(:, {'Axes', 'Series'})));
        end
    catch issue
        if ownPaths
            deleteFiles([pngPath, pdfPath, csvPath]);
        end
        row.Status = "Failed";
        row.PNG = "";
        row.PDF = "";
        row.DataCSV = "";
        row.SeriesCount = 0;
        row.Message = relativeError(issue.message, sourcePath, row.Source, stageFolder);
        return
    end

    % A failed append aborts the staging directory instead of losing page alignment.
    if strlength(bookPath) > 0
        exportgraphics(figureHandle, bookPath, 'ContentType', 'vector', ...
            'Append', nextBookPage > 1);
        row.BookPage = nextBookPage;
        nextBookPage = nextBookPage + 1;
    end
    row.Status = "Exported";
end

function writeSamples(samples, path)
    % Keep enough decimal digits to round-trip a MATLAB double.
    samples.X = compose('%.17g', samples.X);
    samples.Y = compose('%.17g', samples.Y);
    writetable(samples, path, 'Encoding', 'UTF-8', 'QuoteStrings', true);
end

function message = relativeError(detail, sourcePath, relativeSource, stageFolder)
    message = string(detail);
    absolutePaths = [sourcePath, stageFolder];
    descriptions = [relativeSource, "the output staging folder"];
    for index = 1:numel(absolutePaths)
        path = absolutePaths(index);
        message = replace(message, path, descriptions(index));
        if ispc
            message = replace(message, replace(path, "\", "/"), descriptions(index));
        end
    end
end

function path = pathWithin(rootFolder, relativePath)
    path = fullfile(rootFolder, replace(relativePath, '/', filesep));
end

function assertFreshOutput(outputFolder)
    if isfile(outputFolder) || isfolder(outputFolder)
        error('export_lab_batch:OutputExists', 'Choose a new destination: %s', outputFolder);
    end
end

function deleteFigures(figures)
    delete(figures(isgraphics(figures, 'figure')));
end

function restoreCurrentFigure(originalFigure)
    if isempty(originalFigure) || isgraphics(originalFigure, 'figure')
        set(groot, 'CurrentFigure', originalFigure);
    end
end

function deleteFiles(paths)
    for path = paths(isfile(paths))
        delete(path);
    end
end

function removeStage(folder)
    if isfolder(folder)
        rmdir(folder, 's');
    end
end
