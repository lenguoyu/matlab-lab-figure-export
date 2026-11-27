function [file, issue] = lab_pack_contained_file(folder, root, relative, subfolder)
%LAB_PACK_CONTAINED_FILE Resolve a validated relative path within a directory.
    file = "";
    issue = "";
    proposed = fullfile(folder, replace(relative, "/", filesep));
    if ~isempty(root)
        try
            resolved = lab_pack_real_path(proposed);
            if nargin == 4
                root = root.resolve(subfolder);
            end
            if ~resolved.startsWith(root)
                issue = "The file resolves outside the permitted directory.";
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
        issue = verifyNoSymbolicLinks(folder, relative);
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
