function publish_lab_pack(stageFolder, outputFolder, caller)
%PUBLISH_LAB_PACK Publish a staged directory to a fresh destination.
    assertFresh(outputFolder, caller);
    if usejava('jvm')
        stageFile = java.io.File(char(stageFolder));
        outputFile = java.io.File(char(outputFolder));
        try
            javaMethod('move', 'java.nio.file.Files', stageFile.toPath(), ...
                outputFile.toPath(), javaArray('java.nio.file.CopyOption', 0));
        catch issue
            assertFresh(outputFolder, caller);
            rethrow(issue);
        end
    else
        lockFolder = outputFolder + ".export_lab_batch.lock";
        [created, message, messageId] = mkdir(lockFolder);
        if ~created || ~isempty(messageId)
            error([caller ':OutputExists'], 'Cannot reserve destination %s: %s', ...
                outputFolder, message);
        end
        lockCleanup = onCleanup(@() rmdir(lockFolder));
        assertFresh(outputFolder, caller);
        [moved, message] = movefile(stageFolder, outputFolder);
        if ~moved
            error([caller ':Publish'], 'Cannot publish the output folder: %s', message);
        end
    end
end

function assertFresh(outputFolder, caller)
    if isfile(outputFolder) || isfolder(outputFolder)
        error([caller ':OutputExists'], 'Choose a new destination: %s', outputFolder);
    end
end
