function [path, issue] = lab_pack_artifact(pack, relative, extension)
%LAB_PACK_ARTIFACT Resolve an existing manifest or contained plot artifact.
    if extension == "" && relative == "manifest.csv"
        [path, issue] = containedFile(pack, relative, false);
        return;
    end
    path = "";
    if relative == ""
        issue = "No path was recorded in the manifest.";
    elseif ~lab_pack_relative_path(relative) || ~startsWith(relative, "plots/") || ...
            ~endsWith(relative, extension, 'IgnoreCase', true)
        issue = "The manifest path must be a relative " + extension + " file under plots/.";
    else
        [path, issue] = containedFile(pack, relative, true);
    end
end

function [file, issue] = containedFile(pack, relative, withinPlots)
    file = "";
    issue = "";
    proposed = fullfile(pack.Folder, replace(relative, "/", filesep));
    if ~isempty(pack.Root)
        try
            resolved = lab_pack_real_path(proposed);
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
