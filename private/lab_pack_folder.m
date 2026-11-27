function folder = lab_pack_folder(folder, label, caller)
%LAB_PACK_FOLDER Validate and resolve an existing input directory.
    if ischar(folder) && isrow(folder)
        folder = string(folder);
    end
    if ~isstring(folder) || ~isscalar(folder) || ismissing(folder) || strlength(folder) == 0
        error([caller ':InvalidPath'], '%s must be a nonempty path.', label);
    end
    if ~isfolder(folder)
        error([caller ':MissingFolder'], '%s does not exist: %s', label, folder);
    end
    [found, attributes] = fileattrib(folder);
    if ~found || ~isscalar(attributes)
        error([caller ':FolderPath'], 'Cannot resolve %s: %s', label, folder);
    end
    folder = string(attributes.Name);
end
