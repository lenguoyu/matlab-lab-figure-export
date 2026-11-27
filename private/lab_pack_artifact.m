function [path, issue] = lab_pack_artifact(pack, relative, extension)
%LAB_PACK_ARTIFACT Resolve an existing manifest or contained plot artifact.
    if extension == "" && relative == "manifest.csv"
        [path, issue] = lab_pack_contained_file(pack.Folder, pack.Root, relative);
        return;
    end
    path = "";
    if relative == ""
        issue = "No path was recorded in the manifest.";
    elseif ~lab_pack_relative_path(relative) || ~startsWith(relative, "plots/") || ...
            ~endsWith(relative, extension, 'IgnoreCase', true)
        issue = "The manifest path must be a relative " + extension + " file under plots/.";
    else
        [path, issue] = lab_pack_contained_file(pack.Folder, pack.Root, relative, 'plots');
    end
end
