function report = export_lab_batch(source, outputFolder, varargin)
%EXPORT_LAB_BATCH Export saved or currently open MATLAB figures for review.
%   REPORT = EXPORT_LAB_BATCH(SOURCE, OUTPUTFOLDER) accepts a folder of .fig
%   files or a vector of open figure handles. Open figures stay open and
%   receive source IDs such as figure-0001 in the supplied order. Only
%   load trusted FIG files. MATLAB can execute code when opening a FIG.
%
%   The destination parent must exist. Each successful figure gets a PNG
%   and a vector PDF under plots/, preserving relative paths for saved figures.
%   Supported line samples are written to a companion CSV. The batch also
%   writes manifest.csv and index.html. A broken figure is recorded in the
%   report and does not stop other figures.
%
%   Name-value options:
%     'DPI'        Resolution of PNG exports (default 450).
%     'DryRun'     Plan output paths without opening figures or writing
%                  anything (default false).
%     'CombinePDF' Include successful figures in figures.pdf (default true).
%     'FigureFiles' Export a nonempty list of relative .fig paths under a
%                  source folder. Omit this option to scan the folder.
%
%   The report contains Source, Status, PNG, PDF, DataCSV, SeriesCount,
%   BookPage, and Message. Paths are relative to their source or output
%   root. A BookPage of zero means there is no page in the combined PDF.
%
%   Example:
%     plan = export_lab_batch('saved_figures', 'figure_pack', 'DryRun', true);
%     report = export_lab_batch('saved_figures', 'figure_pack', 'DPI', 300);
%     report = export_lab_batch([figA, figB], 'live_figures');
%
%   The combined PDF uses the Append option introduced in MATLAB R2021b.

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'DPI', 450);
    addParameter(options, 'DryRun', false, @(value) islogical(value) && isscalar(value));
    addParameter(options, 'CombinePDF', true, @(value) islogical(value) && isscalar(value));
    addParameter(options, 'FigureFiles', strings(0, 1));
    parse(options, varargin{:});
    dpi = options.Results.DPI;
    validateattributes(dpi, {'numeric'}, {'scalar', 'real', 'finite', ...
        'integer', 'positive'}, mfilename, 'DPI');

    selection = lab_file_selection(options.Results.FigureFiles, 'FigureFiles', mfilename);
    if isempty(selection) && ~any(strcmp('FigureFiles', options.UsingDefaults))
        error('export_lab_batch:EmptyFigureFiles', ...
            'Supply at least one .fig path or omit FigureFiles to scan the source folder.');
    end
    sourceFolder = "";
    handles = [];
    if ischar(source) || isstring(source)
        sourceFolder = lab_pack_folder(source, "sourceFolder", mfilename);
    else
        handles = validateFigures(source, selection);
    end
    [outputFolder, outputParent] = lab_pack_destination(outputFolder, mfilename);

    [sources, inputFiles] = figureSources(sourceFolder, selection, handles);
    [report, stems] = figurePlan(sources);
    if options.Results.DryRun
        return
    end

    [stageFolder, stageCleanup] = lab_pack_stage(outputParent, mfilename);
    originalFigure = get(groot, 'CurrentFigure');
    figureState = onCleanup(@() restoreCurrentFigure(originalFigure));

    bookName = "figures.pdf";
    bookPath = "";
    if options.Results.CombinePDF
        bookPath = fullfile(stageFolder, bookName);
    end
    nextBookPage = 1;
    for rowIndex = find(report.Status == "Planned").'
        figureHandle = [];
        if ~isempty(handles)
            figureHandle = handles(rowIndex);
        end
        [report(rowIndex, :), nextBookPage] = exportOne(report(rowIndex, :), ...
            stems(rowIndex), inputFiles(rowIndex), figureHandle, stageFolder, dpi, bookPath, nextBookPage);
    end
    if nextBookPage == 1
        bookName = "";
    end

    writetable(report, fullfile(stageFolder, 'manifest.csv'), ...
        'Encoding', 'UTF-8', 'QuoteStrings', true);
    write_lab_figure_gallery(fullfile(stageFolder, 'index.html'), report, bookName);
    publish_lab_pack(stageFolder, outputFolder, mfilename);
end

function figures = validateFigures(source, selection)
    if ~isobject(source) || isempty(source) || ~isvector(source) || ~all(isgraphics(source(:), 'figure'))
        error('export_lab_batch:InvalidFigures', 'Source must be a folder or a nonempty vector of open figure handles.');
    end
    if ~isempty(selection)
        error('export_lab_batch:FigureFilesWithHandles', 'FigureFiles requires a source folder.');
    end
    figures = source(:);
    for index = 2:numel(figures)
        if any(figures(1:index-1) == figures(index))
            error('export_lab_batch:DuplicateFigures', 'Supply each figure handle once.');
        end
    end
end

function [sources, files] = figureSources(folder, selection, handles)
    if ~isempty(handles)
        sources = compose("figure-%04d", (1:numel(handles)).');
        files = strings(size(sources));
        return;
    end
    if isempty(selection)
        sources = scanFigures(folder);
        files = pathWithin(folder, sources);
        return;
    end

    lab_validate_portable_paths(selection, 'export_lab_batch:UnsafeFigureFile', ...
        'export_lab_batch:DuplicateFigureFile');
    if ~all(endsWith(selection, ".fig", 'IgnoreCase', true))
        error('export_lab_batch:InvalidFigureFiles', 'FigureFiles must contain .fig paths.');
    end
    sources = selection;
    files = strings(size(sources));
    root = [];
    if usejava('jvm')
        root = lab_pack_real_path(folder);
    end
    for index = 1:numel(sources)
        [files(index), issue] = lab_pack_contained_file(folder, root, sources(index));
        if issue ~= ""
            error('export_lab_batch:FigureFile', 'Cannot select %s. %s', sources(index), issue);
        end
    end
end

function sources = scanFigures(sourceFolder)
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
end

function [report, stems] = figurePlan(sources)
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

function [row, nextBookPage] = exportOne(row, stem, sourcePath, figureHandle, stageFolder, dpi, bookPath, nextBookPage)
    outputBase = pathWithin(stageFolder, stem);
    pngPath = outputBase + ".png";
    pdfPath = outputBase + ".pdf";
    csvPath = outputBase + ".csv";
    ownPaths = false;
    try
        if sourcePath ~= ""
            figureHandle = openfig(sourcePath, 'new', 'invisible');
            closeFigure = onCleanup(@() deleteFigures(figureHandle));
            if ~isscalar(figureHandle) || ~isgraphics(figureHandle, 'figure')
                error('export_lab_batch:FigureCount', 'Each FIG file must contain one figure.');
            end
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
    for index = find(absolutePaths ~= "")
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
