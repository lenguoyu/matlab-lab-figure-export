function report = check_lab_artwork(packFolder, widthMm, targetDPI, varargin)
%CHECK_LAB_ARTWORK Check PNG resolution at a planned manuscript width.
%   REPORT = CHECK_LAB_ARTWORK(PACKFOLDER, WIDTHMM, TARGETDPI) reads an
%   existing Figure Pack. It compares the PNG pixel widths to the target
%   at the planned placement width for each figure. It does not write files.
%
%   'ArtworkOverrides' accepts a table with Source, PlacedWidthMm, and
%   TargetDPI columns. Each Source identifies one manifest row. Rows
%   without an override use the supplied widthMm and targetDPI.
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
    options = inputParser;
    options.FunctionName = mfilename;
    options.PartialMatching = false;
    addParameter(options, 'ArtworkOverrides', table());
    parse(options, varargin{:});
    overrides = artworkOverrides(options.Results.ArtworkOverrides);
    widths = [double(widthMm); overrides.PlacedWidthMm];
    targets = [double(targetDPI); overrides.TargetDPI];
    requiredWidths = requiredPixelWidths(widths, targets);

    pack = read_lab_pack(packFolder, "Figure Pack", mfilename);
    manifest = pack.Manifest;
    count = height(manifest);
    [found, rows] = ismember(overrides.Source, manifest.Source);
    if any(~found)
        error('check_lab_artwork:UnknownArtworkSource', ...
            'No figure has the Source %s.', overrides.Source(find(~found, 1)));
    end
    settings = ones(count, 1);
    settings(rows) = (2:(height(overrides) + 1)).';
    report = table(manifest.Source, widths(settings), targets(settings), ...
        nan(count, 1), nan(count, 1), nan(count, 1), requiredWidths(settings), ...
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
                report.EffectiveDPI(index) = pixelWidth * 25.4 / report.PlacedWidthMm(index);
                if pixelWidth >= report.RequiredPixelWidth(index)
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

function overrides = artworkOverrides(value)
    required = {'Source', 'PlacedWidthMm', 'TargetDPI'};
    if istable(value) && isequal(size(value), [0, 0])
        value = table(strings(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', required);
    end
    if ~istable(value) || ~all(ismember(required, value.Properties.VariableNames))
        error('check_lab_artwork:InvalidArtworkOverrides', ...
            'ArtworkOverrides must be a table with Source, PlacedWidthMm, and TargetDPI columns.');
    end
    overrides = value(:, required);
    keys = lab_file_selection(overrides.Source, 'ArtworkOverrides', 'check_lab_artwork');
    if numel(keys) ~= height(overrides)
        error('check_lab_artwork:InvalidArtworkOverrides', 'Provide one Source per override row.');
    end
    for source = keys.'
        if ~lab_pack_relative_path(source)
            error('check_lab_artwork:InvalidArtworkOverrides', 'Invalid relative Source: %s', source);
        end
    end
    if numel(unique(keys)) ~= height(overrides)
        error('check_lab_artwork:DuplicateArtworkSource', 'Each Source may have one override.');
    end
    overrides.Source = keys;
    for name = required(2:3)
        column = overrides.(name{1});
        if ~isnumeric(column) || ~isreal(column) || ~isequal(size(column), [height(overrides), 1]) || ...
                any(~isfinite(column) | column <= 0)
            error('check_lab_artwork:InvalidArtworkOverrides', ...
                '%s must have one finite positive number per row.', name{1});
        end
        overrides.(name{1}) = double(column);
    end
end

function pixels = requiredPixelWidths(widths, targets)
    exactWidth = widths .* targets / 25.4;
    if any(exactWidth > flintmax | ~isfinite(double(intmax('uint32')) * 25.4 ./ widths))
        error('check_lab_artwork:InvalidPlacement', ...
            'The placement width and target DPI exceed the numeric range for this check.');
    end
    % Remove floating-point roundoff immediately above a whole-pixel boundary.
    nearest = round(exactWidth);
    nearInteger = abs(exactWidth - nearest) <= 4 * eps(exactWidth);
    exactWidth(nearInteger) = nearest(nearInteger);
    pixels = max(1, ceil(exactWidth));
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
