function issue = copy_lab_preview(source, destination, caller)
%COPY_LAB_PREVIEW Copy a bounded PNG for inclusion in a portable report.
    issue = "Could not read a bounded PNG preview.";
    [input, ~] = fopen(source, 'rb', 'ieee-be');
    if input < 0
        return
    end
    inputGuard = onCleanup(@() fclose(input));
    if fseek(input, 0, 'eof') ~= 0
        return
    end
    byteCount = ftell(input);
    if byteCount < 45 || byteCount > 32 * 1024^2
        issue = "PNG size is invalid or exceeds 32 MiB.";
        return
    end
    frewind(input);
    header = fread(input, 16, '*uint8').';
    pngHeader = uint8([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, double('IHDR')]);
    if ~isequal(header, pngHeader)
        issue = "The file does not have a valid PNG header.";
        return
    end
    dimensions = fread(input, 2, 'uint32=>double');
    if numel(dimensions) ~= 2 || any(dimensions == 0 | dimensions > 10000) || prod(dimensions) > 40e6
        issue = "PNG dimensions are invalid or exceed the preview limit.";
        return
    end
    frewind(input);
    bytes = fread(input, byteCount, '*uint8');
    if numel(bytes) ~= byteCount
        return
    end
    [output, message] = fopen(destination, 'wb');
    if output < 0
        error([caller ':PreviewWrite'], 'Cannot write a preview: %s', message);
    end
    outputGuard = onCleanup(@() fclose(output));
    if fwrite(output, bytes, 'uint8') ~= byteCount
        error([caller ':PreviewWrite'], 'Could not write the complete PNG preview.');
    end
    issue = "";
end
