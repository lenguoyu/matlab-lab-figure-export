function publish_lab_pack(staged, destination, caller)
%PUBLISH_LAB_PACK Move a staged directory or file to a fresh destination.
    assertFresh(destination, caller);
    lockFolder = destination + ".export_lab_batch.lock";
    if usejava('jvm')
        lock = java.io.File(char(lockFolder));
        created = lock.mkdir();
        message = 'The destination could not be reserved.';
    else
        [created, message, messageId] = mkdir(lockFolder);
        created = created && isempty(messageId);
    end
    if ~created
        error([caller ':OutputExists'], 'Cannot reserve destination %s. %s', destination, message);
    end
    lockCleanup = onCleanup(@() rmdir(lockFolder));
    assertFresh(destination, caller);

    if usejava('jvm')
        stageFile = java.io.File(char(staged));
        outputFile = java.io.File(char(destination));
        try
            javaMethod('move', 'java.nio.file.Files', stageFile.toPath(), ...
                outputFile.toPath(), javaArray('java.nio.file.CopyOption', 0));
        catch issue
            assertFresh(destination, caller);
            rethrow(issue);
        end
    else
        [moved, message] = movefile(staged, destination);
        if ~moved
            error([caller ':Publish'], 'Cannot publish the output: %s', message);
        end
    end
end

function assertFresh(outputFolder, caller)
    if isfile(outputFolder) || isfolder(outputFolder)
        error([caller ':OutputExists'], 'Choose a new destination: %s', outputFolder);
    end
end
