function [archive, summary] = build_lab_delivery(figFolder, outputZip, widthMm, targetDPI, varargin)
%BUILD_LAB_DELIVERY Export, check, and package a MATLAB project handoff.
%   [ARCHIVE, SUMMARY] = BUILD_LAB_DELIVERY(FIGFOLDER, OUTPUTZIP, WIDTHMM,
%   TARGETDPI) creates a new ZIP with a figure gallery, PNG and PDF exports,
%   available XY data, a PNG artwork check, and a delivery index. Load
%   only trusted FIG files. Review the reports for figure-level failures.
%
%   'Files' lists the relative paths of files to include as attachments.
%   They are copied as-is, with their directory structure, from the
%   'AttachmentRoot' directory (default current MATLAB folder).
%   'PlotlyJS' and 'PlotlyLicense' add an offline interactive gallery when
%   supplied together. 'DPI' and 'CombinePDF' are passed to EXPORT_LAB_BATCH
%   and default to 450 and true. Open index.html after extracting the ZIP.
%
%   SUMMARY contains Figures, Artwork, Plotly, Attachments, and Inventory.
%   Figure and Plotly output paths are relative to their respective
%   figures/ and interactive/ folders. The inventory uses ZIP-root paths.

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'AttachmentRoot', pwd);
    addParameter(options, 'Files', strings(0, 1));
    addParameter(options, 'PlotlyJS', "");
    addParameter(options, 'PlotlyLicense', "");
    addParameter(options, 'DPI', 450);
    addParameter(options, 'CombinePDF', true);
    parse(options, varargin{:});
    settings = options.Results;

    validateattributes(widthMm, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'widthMm', 3);
    validateattributes(targetDPI, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'targetDPI', 4);
    [archive, parent] = lab_pack_destination(outputZip, mfilename);
    [~, name, extension] = fileparts(archive);
    if name == "" || ~strcmpi(extension, '.zip')
        error('build_lab_delivery:OutputFormat', 'Choose a destination with a .zip extension.');
    end
    [bundle, license] = lab_plotly_assets(settings.PlotlyJS, settings.PlotlyLicense, mfilename);
    [sources, attachments] = selectedFiles(settings.Files, settings.AttachmentRoot);

    [stage, stageCleanup] = lab_pack_stage(parent, mfilename);
    contents = fullfile(stage, 'contents');
    makeFolder(contents);

    figures = fullfile(contents, 'figures');
    summary.Figures = export_lab_batch(figFolder, figures, ...
        'DPI', settings.DPI, 'CombinePDF', settings.CombinePDF);
    summary.Artwork = check_lab_artwork(figures, widthMm, targetDPI);
    writetable(summary.Artwork, fullfile(contents, 'artwork-check.csv'), ...
        'Encoding', 'UTF-8', 'QuoteStrings', true);
    summary.Plotly = table();
    if bundle ~= ""
        summary.Plotly = export_lab_plotly(figures, fullfile(contents, 'interactive'), ...
            'PlotlyJS', bundle, 'PlotlyLicense', license);
    end
    % An attachment can itself be a FIG. Copy it after the source scan.
    copyAttachments(sources, attachments, contents);
    summary.Attachments = attachments;
    write_lab_delivery_index(contents, summary, widthMm, targetDPI);
    summary.Inventory = makeInventory(contents);
    manifest = "delivery-manifest.csv";
    writetable(summary.Inventory, fullfile(contents, manifest), ...
        'Encoding', 'UTF-8', 'QuoteStrings', true);

    stagedZip = fullfile(stage, 'delivery.zip');
    expected = sort([summary.Inventory.File; manifest]);
    members = string(zip(stagedZip, cellstr(expected), contents));
    if ~isequal(sort(replace(members(:), "\", "/")), expected)
        error('build_lab_delivery:ArchiveMembers', 'ZIP members differ from the delivery inventory.');
    end
    publish_lab_pack(stagedZip, archive, mfilename);
end

function [sources, destinations] = selectedFiles(value, attachmentRoot)
    if (ischar(value) && isrow(value)) || iscellstr(value)
        value = string(value);
    end
    if ~isstring(value) || (~isempty(value) && ~isvector(value)) || any(ismissing(value(:)))
        error('build_lab_delivery:InvalidFiles', 'Files must be a list of relative paths.');
    end
    relative = value(:);
    if ispc
        relative = replace(relative, "\", "/");
    end
    validatePaths(relative, 'UnsafeAttachment', 'DuplicateAttachment');
    sources = strings(size(relative));
    destinations = repmat("attachments/", size(relative)) + relative;
    if isempty(relative)
        return
    end
    folder = lab_pack_folder(attachmentRoot, "AttachmentRoot", 'build_lab_delivery');
    root = [];
    if usejava('jvm')
        root = lab_pack_real_path(folder);
    end
    for index = 1:numel(relative)
        [sources(index), issue] = lab_pack_contained_file(folder, root, relative(index));
        if issue ~= ""
            error('build_lab_delivery:AttachmentFile', 'Cannot attach %s. %s', relative(index), issue);
        end
    end
end

function validatePaths(paths, unsafeId, duplicateId)
    unsafeCharacters = '[<>"|?*]|[ .](?:/|$)';
    reservedName = '(?:^|/)(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|/|$)';
    folders = strings(0, 1);
    for index = 1:numel(paths)
        path = paths(index);
        if ~lab_pack_relative_path(path) || ...
                ~isempty(regexp(path, [unsafeCharacters '|' reservedName], 'once'))
            error(['build_lab_delivery:' unsafeId], 'The archive path is not portable: %s', path);
        end
        for position = find(char(path) == '/')
            folders(end + 1, 1) = extractBefore(path, position); %#ok<AGROW>
        end
    end
    % Include parent spellings so case-insensitive extraction preserves the layout.
    entries = [paths; unique(folders)];
    if numel(unique(lower(entries))) ~= numel(entries)
        error(['build_lab_delivery:' duplicateId], ...
            'Archive paths must be unique on case-insensitive systems.');
    end
end

function copyAttachments(sources, destinations, root)
    for index = 1:numel(destinations)
        destination = fullfile(root, replace(destinations(index), "/", filesep));
        makeFolder(fileparts(destination));
        [copied, message] = copyfile(sources(index), destination);
        if ~copied
            error('build_lab_delivery:CopyAttachment', 'Cannot copy %s. %s', destinations(index), message);
        end
    end
end

function inventory = makeInventory(root)
    files = dir(fullfile(root, '**', '*'));
    files = files(~[files.isdir]);
    absolute = string(fullfile({files.folder}, {files.name})).';
    relative = replace(extractAfter(absolute, strlength(root) + 1), filesep, "/");
    validatePaths(relative, 'UnsafeArchivePath', 'DuplicateArchivePath');
    role = repmat("Delivery index", size(relative));
    role(relative == "artwork-check.csv") = "Artwork check";
    role(startsWith(relative, "figures/")) = "Figure Pack";
    role(startsWith(relative, "interactive/")) = "Interactive gallery";
    role(startsWith(relative, "attachments/")) = "Attachment";
    inventory = sortrows(table(relative, role, [files.bytes].', ...
        'VariableNames', {'File', 'Role', 'Bytes'}), 'File');
end

function makeFolder(folder)
    if ~isfolder(folder)
        [created, message] = mkdir(folder);
        if ~created
            error('build_lab_delivery:OutputFolder', 'Cannot create a staging directory: %s', message);
        end
    end
end
