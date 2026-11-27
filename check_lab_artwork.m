function report = check_lab_artwork(packFolder, widthMm, targetDPI)
%CHECK_LAB_ARTWORK Check PNG resolution at a planned manuscript width.
%   REPORT = CHECK_LAB_ARTWORK(PACKFOLDER, WIDTHMM, TARGETDPI) reads an
%   existing Figure Pack. It compares the PNG pixel widths to the target
%   at the same placement width for each figure. It does not write files.
%
%   EffectiveDPI is the actual width in pixels divided by the planned
%   width in inches. RequiredPixelWidth rounds up to a whole pixel.
%   PDF lists available companion paths without assessing their content.
%
%   Example:
%     report = check_lab_artwork('figure-pack', 88.9, 600);

    validateattributes(widthMm, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'widthMm', 2);
    validateattributes(targetDPI, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'targetDPI', 3);
    widthMm = double(widthMm);
    targetDPI = double(targetDPI);
    exactWidth = widthMm * targetDPI / 25.4;
    if exactWidth > flintmax || ~isfinite(double(intmax('uint32')) * 25.4 / widthMm)
        error('check_lab_artwork:InvalidPlacement', ...
            'The placement width and target DPI exceed the numeric range for this check.');
    end
    % Remove floating-point roundoff immediately above a whole-pixel boundary.
    nearestPixel = round(exactWidth);
    if abs(exactWidth - nearestPixel) <= 4 * eps(exactWidth)
        exactWidth = nearestPixel;
    end
    requiredWidth = max(1, ceil(exactWidth));

    pack = read_lab_pack(packFolder, "Figure Pack", mfilename);
    manifest = pack.Manifest;
    count = height(manifest);
    report = table(manifest.Source, repmat(widthMm, count, 1), repmat(targetDPI, count, 1), ...
        nan(count, 1), nan(count, 1), nan(count, 1), repmat(requiredWidth, count, 1), ...
        repmat("Needs review", count, 1), strings(count, 1), strings(count, 1), ...
        'VariableNames', {'Source', 'PlacedWidthMm', 'TargetDPI', 'PixelWidth', ...
        'PixelHeight', 'EffectiveDPI', 'RequiredPixelWidth', 'Status', 'PDF', 'Message'});

    for index = 1:count
        if manifest.Status(index) ~= "Exported"
            status = manifest.Status(index);
            if status == ""
                status = "(missing)";
            end
            report.Message(index) = "Figure Pack export status: " + status + ".";
            continue
        end

        [pngPath, pngIssue] = lab_pack_artifact(pack, manifest.PNG(index), ".png");
        if pngIssue == ""
            [pixelWidth, pixelHeight, pngIssue] = pngDimensions(pngPath);
            if pngIssue == ""
                report.PixelWidth(index) = pixelWidth;
                report.PixelHeight(index) = pixelHeight;
                report.EffectiveDPI(index) = pixelWidth * 25.4 / widthMm;
                if pixelWidth >= requiredWidth
                    report.Status(index) = "Meets target";
                else
                    report.Status(index) = "Below target";
                end
            end
        end
        if pngIssue ~= ""
            report.Message(index) = "PNG: " + pngIssue;
        end

        if manifest.PDF(index) ~= ""
            [~, pdfIssue] = lab_pack_artifact(pack, manifest.PDF(index), ".pdf");
            if pdfIssue == ""
                report.PDF(index) = manifest.PDF(index);
            else
                report.Message(index) = strip(report.Message(index) + " PDF: " + pdfIssue);
            end
        end
    end
end

function [pixelWidth, pixelHeight, issue] = pngDimensions(path)
    pixelWidth = NaN;
    pixelHeight = NaN;
    issue = "Could not read PNG metadata.";
    try
        info = imfinfo(path);
    catch
        return
    end
    if ~isscalar(info) || ~strcmpi(info.Format, 'png')
        issue = "The file is not a single PNG image.";
        return
    end
    pixelWidth = double(info.Width);
    pixelHeight = double(info.Height);
    if any(~isfinite([pixelWidth, pixelHeight]) | [pixelWidth, pixelHeight] <= 0)
        pixelWidth = NaN;
        pixelHeight = NaN;
        issue = "The PNG dimensions are invalid.";
        return
    end
    issue = "";
end
