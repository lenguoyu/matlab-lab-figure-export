function [folder, parent] = lab_pack_destination(folder, caller)
%LAB_PACK_DESTINATION Resolve a fresh output location with an existing parent.
    folder = pathText(folder, caller);
    assertFresh(folder, caller);
    if ispc
        folder = replace(folder, "\", "/");
    end
    folder = regexprep(folder, '/+$', '');
    [parent, name, extension] = fileparts(folder);
    if parent == ""
        parent = string(pwd);
    end
    parent = lab_pack_folder(parent, "Output parent", caller);
    folder = fullfile(parent, name + extension);
    assertFresh(folder, caller);
end

function assertFresh(folder, caller)
    if isfolder(folder) || isfile(folder)
        error([caller ':OutputExists'], 'Choose a new destination: %s', folder);
    end
end

function value = pathText(value, caller)
    if ischar(value) && isrow(value)
        value = string(value);
    end
    if ~isstring(value) || ~isscalar(value) || ismissing(value) || strlength(value) == 0
        error([caller ':InvalidPath'], 'Output folder must be a nonempty path.');
    end
end
