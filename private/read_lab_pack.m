function pack = read_lab_pack(folder, label, caller)
%READ_LAB_PACK Read a Figure Pack manifest, preserving names and metadata.
    pack.Folder = lab_pack_folder(folder, label, caller);
    pack.Label = label;
    pack.Root = [];
    if usejava('jvm')
        pack.Root = lab_pack_real_path(pack.Folder);
    end
    [file, issue] = lab_pack_artifact(pack, "manifest.csv", "");
    if issue ~= ""
        error([caller ':InvalidManifest'], '%s manifest.csv: %s', label, issue);
    end

    required = {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'SeriesCount', 'BookPage', 'Message'};
    textVars = {'Source', 'Status', 'PNG', 'PDF', 'DataCSV', 'Message'};
    try
        opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ',', ...
            'Encoding', 'UTF-8', 'VariableNamingRule', 'preserve');
        if ~all(ismember(required, opts.VariableNames))
            error([caller ':ManifestColumns'], 'Expected the Figure Pack manifest columns.');
        end
        opts = setvartype(opts, textVars, 'string');
        opts = setvartype(opts, {'SeriesCount', 'BookPage'}, 'double');
        opts = setvaropts(opts, textVars, 'WhitespaceRule', 'preserve');
        opts.ImportErrorRule = 'error';
        opts.ExtraColumnsRule = 'error';
        manifest = readtable(file, opts);
    catch problem
        error([caller ':InvalidManifest'], ...
            '%s manifest.csv could not be read: %s', label, problem.message);
    end
    for name = string(textVars)
        value = manifest.(name);
        value(ismissing(value)) = "";
        manifest.(name) = value;
    end
    for index = 1:height(manifest)
        if ~lab_pack_relative_path(manifest.Source(index))
            error([caller ':InvalidSource'], ...
                '%s manifest.csv has an invalid relative Source at row %d.', label, index);
        end
    end
    if numel(unique(manifest.Source)) ~= height(manifest)
        error([caller ':DuplicateSource'], '%s manifest.csv repeats a Source path.', label);
    end
    pack.Manifest = manifest;
end
