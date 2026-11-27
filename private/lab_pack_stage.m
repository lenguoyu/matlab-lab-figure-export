function [folder, cleanup] = lab_pack_stage(parent, caller)
%LAB_PACK_STAGE Reserve a temporary sibling for a new pack or report.
    folder = string(tempname(parent));
    [created, message, messageId] = mkdir(folder);
    if ~created || ~isempty(messageId)
        error([caller ':StageCreate'], 'Cannot create a staging folder: %s', message);
    end
    cleanup = onCleanup(@() removeStage(folder));
end

function removeStage(folder)
    if isfolder(folder)
        rmdir(folder, 's');
    end
end
