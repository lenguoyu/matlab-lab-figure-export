function paths = lab_file_selection(value, option, caller)
%LAB_FILE_SELECTION Normalize a name-value list of relative file paths.
    if (ischar(value) && isrow(value)) || iscellstr(value)
        value = string(value);
    end
    if ~isstring(value) || (~isempty(value) && ~isvector(value)) || any(ismissing(value(:)))
        error([caller ':Invalid' option], '%s must be a list of relative paths.', option);
    end
    paths = value(:);
    if ispc
        paths = replace(paths, "\", "/");
    end
end
