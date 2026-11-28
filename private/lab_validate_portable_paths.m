function lab_validate_portable_paths(paths, unsafeId, duplicateId)
%LAB_VALIDATE_PORTABLE_PATHS Check relative paths and case-insensitive aliases.
    unsafeCharacters = '[<>"|?*]|[ .](?:/|$)';
    reservedName = '(?:^|/)(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|/|$)';
    folders = strings(0, 1);
    for path = paths(:).'
        if ~lab_pack_relative_path(path) || ...
                ~isempty(regexp(path, [unsafeCharacters '|' reservedName], 'once'))
            error(unsafeId, 'The path is not portable: %s', path);
        end
        for position = find(char(path) == '/')
            folders(end + 1, 1) = extractBefore(path, position); %#ok<AGROW>
        end
    end
    % Include parent spellings so case-insensitive extraction preserves the layout.
    entries = [paths(:); unique(folders)];
    if numel(unique(lower(entries))) ~= numel(entries)
        error(duplicateId, 'Paths must be unique on case-insensitive systems.');
    end
end
