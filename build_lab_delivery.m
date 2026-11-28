function [archive, summary] = build_lab_delivery(source, outputZip, widthMm, targetDPI, varargin)
%BUILD_LAB_DELIVERY Export, check, and package a MATLAB project handoff.
%   [ARCHIVE, SUMMARY] = BUILD_LAB_DELIVERY(SOURCE, OUTPUTZIP, WIDTHMM,
%   TARGETDPI) creates a new ZIP with a figure gallery, PNG and PDF exports,
%   available XY data, a PNG artwork check, and a delivery index. SOURCE
%   can be a folder of FIG files or a vector of open figures. For a folder,
%   'FigureFiles' can select relative FIG paths in the supplied order.
%   Load only trusted FIG files. Review reports for figure-level failures.
%
%   'Files' lists the relative paths of files to include as attachments.
%   They are copied as-is, with their directory structure, from the
%   'AttachmentRoot' directory (default current MATLAB folder).
%   'PlotlyJS' and 'PlotlyLicense' add an offline interactive gallery when
%   supplied together. 'DPI' and 'CombinePDF' are passed to EXPORT_LAB_BATCH
%   and default to 450 and true. 'ArtworkOverrides' passes a per-figure
%   width and DPI table to CHECK_LAB_ARTWORK. Open index.html after
%   extracting the ZIP.
%
%   SUMMARY contains Figures, Artwork, Plotly, Attachments, and Inventory.
%   Figure and Plotly output paths are relative to their respective
%   figures/ and interactive/ folders. The inventory uses ZIP-root paths.

    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'FigureFiles', strings(0, 1));
    addParameter(options, 'ArtworkOverrides', table());
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
    exportOptions = {'DPI', settings.DPI, 'CombinePDF', settings.CombinePDF};
    if ~any(strcmp('FigureFiles', options.UsingDefaults))
        exportOptions = [exportOptions, {'FigureFiles', settings.FigureFiles}];
    end
    summary.Figures = export_lab_batch(source, figures, exportOptions{:});
    summary.Artwork = check_lab_artwork(figures, widthMm, targetDPI, ...
        'ArtworkOverrides', settings.ArtworkOverrides);
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
    write_lab_delivery_index(contents, summary);
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
    relative = lab_file_selection(value, 'Files', 'build_lab_delivery');
    lab_validate_portable_paths(relative, 'build_lab_delivery:UnsafeAttachment', ...
        'build_lab_delivery:DuplicateAttachment');
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
    lab_validate_portable_paths(relative, 'build_lab_delivery:UnsafeArchivePath', ...
        'build_lab_delivery:DuplicateArchivePath');
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
