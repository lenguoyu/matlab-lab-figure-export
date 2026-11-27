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

    [outputFolder, outputParent] = freshDestination(outputFolder);
    baseline = readPack(baselineFolder, "Baseline");
    candidate = readPack(candidateFolder, "Candidate");
    source = union(baseline.Manifest.Source, candidate.Manifest.Source);
    [~, baselineRows] = ismember(source, baseline.Manifest.Source);
    [~, candidateRows] = ismember(source, candidate.Manifest.Source);
    count = numel(source);

    stage = string(tempname(outputParent));
    [created, message, messageId] = mkdir(stage);
    if ~created || ~isempty(messageId)
        error('compare_lab_packs:StageCreate', 'Cannot create a staging folder: %s', message);
    end
    stageCleanup = onCleanup(@() removeStage(stage));
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

    writetable(figures, fullfile(stage, 'comparison.csv'), 'Encoding', 'UTF-8');
    writetable(series, fullfile(stage, 'series.csv'), 'Encoding', 'UTF-8');
    write_lab_pack_comparison(fullfile(stage, 'index.html'), figures, series, absTol, relTol);
    publish_lab_pack(stage, outputFolder, mfilename);
end

function result = tolerance(value, name)
    validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, ...
        'compare_lab_packs', name);
    result = double(value);
end

function [folder, parent] = freshDestination(folder)
    folder = pathText(folder, "Output folder");
    assertFresh(folder);
    if ispc
        folder = replace(folder, "\", "/");
    end
    folder = regexprep(folder, '/+$', '');
    [parent, name, extension] = fileparts(folder);
    if parent == ""
        parent = string(pwd);
    end
    parent = existingFolder(parent, "Output parent");
    folder = fullfile(parent, name + extension);
    assertFresh(folder);
end

function assertFresh(folder)
    if isfolder(folder) || isfile(folder)
        error('compare_lab_packs:OutputExists', 'Choose a new destination: %s', folder);
    end
end

function value = pathText(value, label)
    if ischar(value) && isrow(value)
        value = string(value);
    end
    if ~isstring(value) || ~isscalar(value) || ismissing(value) || strlength(value) == 0
        error('compare_lab_packs:InvalidPath', '%s must be a nonempty path.', label);
    end
end

function folder = existingFolder(folder, label)
    if ~isfolder(folder)
        error('compare_lab_packs:MissingFolder', '%s does not exist: %s', label, folder);
    end
    [found, attributes] = fileattrib(folder);
    if ~found || ~isscalar(attributes)
        error('compare_lab_packs:FolderPath', 'Cannot resolve %s: %s', label, folder);
    end
    folder = string(attributes.Name);
end

function pack = readPack(folder, label)
    pack.Folder = existingFolder(pathText(folder, label), label);
    pack.Label = label;
    pack.Root = [];
    if usejava('jvm')
        pack.Root = realPath(pack.Folder);
    end
    [file, issue] = containedFile(pack, "manifest.csv", false);
    if issue ~= ""
        error('compare_lab_packs:InvalidManifest', '%s manifest.csv: %s', label, issue);
    end

    required = {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'SeriesCount', 'BookPage', 'Message'};
    textVars = {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'Message'};
    try
        opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ',', ...
            'Encoding', 'UTF-8', 'VariableNamingRule', 'preserve');
        if ~all(ismember(required, opts.VariableNames))
            error('compare_lab_packs:ManifestColumns', 'Expected the Figure Pack manifest columns.');
        end
        opts = setvartype(opts, textVars, 'string');
        opts = setvartype(opts, {'SeriesCount', 'BookPage'}, 'double');
        opts = setvaropts(opts, textVars, 'WhitespaceRule', 'preserve');
        opts.ImportErrorRule = 'error';
        opts.ExtraColumnsRule = 'error';
        manifest = readtable(file, opts);
    catch problem
        error('compare_lab_packs:InvalidManifest', ...
            '%s manifest.csv could not be read: %s', label, problem.message);
    end
    for name = string(textVars)
        value = manifest.(name);
        value(ismissing(value)) = "";
        manifest.(name) = value;
    end
    for index = 1:height(manifest)
        if ~safeRelativePath(manifest.Source(index))
            error('compare_lab_packs:InvalidSource', ...
                '%s manifest.csv has an invalid relative Source at row %d.', label, index);
        end
    end
    if numel(unique(manifest.Source)) ~= height(manifest)
        error('compare_lab_packs:DuplicateSource', '%s manifest.csv repeats a Source path.', label);
    end
    pack.Manifest = manifest;
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

    [pngPath, issue] = artifactFile(pack, row.PNG, ".png");
    if issue == ""
        previewName = string(sprintf('previews/%04d-%s.png', fileIndex, lower(pack.Label)));
        issue = copyPreview(pngPath, fullfile(stage, previewName));
        if issue == ""
            preview = previewName;
        end
    end
    if issue ~= ""
        notes(end + 1) = pack.Label + " PNG: " + issue;
    end

    if row.DataCSV ~= "" || row.SeriesCount > 0
        [csvPath, issue] = artifactFile(pack, row.DataCSV, ".csv");
        if issue ~= ""
            notes(end + 1) = pack.Label + " data CSV: " + issue;
        end
    end
end

function [path, issue] = artifactFile(pack, relative, extension)
    path = "";
    if relative == ""
        issue = "No path was recorded in the manifest.";
    elseif ~safeRelativePath(relative) || ~startsWith(relative, "plots/") || ...
            ~endsWith(relative, extension, 'IgnoreCase', true)
        issue = "The manifest path must be a relative " + extension + " file under plots/.";
    else
        [path, issue] = containedFile(pack, relative, true);
    end
end

function valid = safeRelativePath(path)
    components = split(path, "/");
    code = double(char(path));
    valid = ~contains(path, ["\", ":"]) && ~any(components == "" | ...
        components == "." | components == "..") && ~any(code < 32 | code == 127);
end

function [file, issue] = containedFile(pack, relative, withinPlots)
    file = "";
    issue = "";
    proposed = fullfile(pack.Folder, replace(relative, "/", filesep));
    if ~isempty(pack.Root)
        try
            resolved = realPath(proposed);
            boundary = pack.Root;
            if withinPlots
                boundary = boundary.resolve('plots');
            end
            if ~resolved.startsWith(boundary)
                issue = "The file resolves outside the permitted pack directory.";
                return
            end
            if ~javaMethod('isRegularFile', 'java.nio.file.Files', resolved, ...
                    javaArray('java.nio.file.LinkOption', 0))
                issue = "The path is not a regular file.";
                return
            end
            proposed = string(resolved.toString());
        catch
            issue = "The file is missing or cannot be resolved.";
            return
        end
    else
        issue = verifyNoSymbolicLinks(pack.Folder, relative);
        if issue ~= ""
            return
        end
    end
    if ~isfile(proposed)
        issue = "The file does not exist.";
        return
    end
    file = proposed;
end

function path = realPath(file)
    handle = java.io.File(char(file));
    nioPath = handle.toPath();
    path = nioPath.toRealPath(javaArray('java.nio.file.LinkOption', 0));
end

function issue = verifyNoSymbolicLinks(root, relative)
    issue = "";
    if ispc || isempty(which('isSymbolicLink'))
        issue = "MATLAB could not verify the path without its JVM.";
        return
    end
    for part = split(relative, "/").'
        root = fullfile(root, part);
        try
            if isSymbolicLink(root)
                issue = "Symbolic links require MATLAB's JVM for containment verification.";
                return
            end
        catch
            issue = "Cannot verify the file path.";
            return
        end
    end
end

function issue = copyPreview(source, destination)
    issue = "Could not read a bounded PNG preview.";
    [input, ~] = fopen(source, 'rb', 'ieee-be');
    if input < 0
        return
    end
    inputGuard = onCleanup(@() fclose(input));
    if fseek(input, 0, 'eof') ~= 0
        return
    end
    byteCount = ftell(input);
    if byteCount < 45 || byteCount > 32 * 1024^2
        issue = "PNG size is invalid or exceeds 32 MiB.";
        return
    end
    frewind(input);
    header = fread(input, 16, '*uint8').';
    pngHeader = uint8([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, double('IHDR')]);
    if ~isequal(header, pngHeader)
        issue = "The file does not have a valid PNG header.";
        return
    end
    dimensions = fread(input, 2, 'uint32=>double');
    if numel(dimensions) ~= 2 || any(dimensions == 0 | dimensions > 10000) || prod(dimensions) > 40e6
        issue = "PNG dimensions are invalid or exceed the preview limit.";
        return
    end
    frewind(input);
    bytes = fread(input, byteCount, '*uint8');
    if numel(bytes) ~= byteCount
        return
    end
    [output, message] = fopen(destination, 'wb');
    if output < 0
        error('compare_lab_packs:PreviewWrite', 'Cannot write a preview: %s', message);
    end
    outputGuard = onCleanup(@() fclose(output));
    if fwrite(output, bytes, 'uint8') ~= byteCount
        error('compare_lab_packs:PreviewWrite', 'Could not write the complete PNG preview.');
    end
    issue = "";
end

function rows = emptySeries()
    rows = table('Size', [0, 11], ...
        'VariableNames', {'Source', 'Axes', 'Series', 'Label', 'Status', 'ComparedSamples', ...
        'SkippedSamples', 'OutsideSamples', 'MaxAbsDelta', 'XAtMax', 'Message'}, ...
        'VariableTypes', {'string', 'double', 'double', 'string', 'string', 'double', ...
        'double', 'double', 'double', 'double', 'string'});
end

function removeStage(folder)
    if isfolder(folder)
        rmdir(folder, 's');
    end
end
