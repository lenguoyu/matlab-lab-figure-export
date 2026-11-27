function [pngFile, pdfFile] = export_lab_figure(target, outputBase, dpi)
%EXPORT_LAB_FIGURE Save an axes, tiled layout, or figure as PNG and PDF.
%   EXPORT_LAB_FIGURE(GCA, 'response') saves response.png at 450 DPI and
%   response.pdf using vector rendering. The third input changes PNG DPI.
%   The output folder must already exist. Existing files are preserved.

    narginchk(2, 3);
    if nargin < 3
        dpi = 450;
    end
    validateattributes(dpi, {'numeric'}, {'scalar', 'real', 'finite', ...
        'integer', 'positive'}, mfilename, 'dpi', 3);

    if isstring(outputBase) && isscalar(outputBase) && ~ismissing(outputBase)
        outputBase = char(outputBase);
    end
    validateattributes(outputBase, {'char'}, {'row', 'nonempty'}, ...
        mfilename, 'outputBase', 2);
    [outputDir, stem, extension] = fileparts(outputBase);
    if isempty(strtrim([stem, extension]))
        error('export_lab_figure:MissingFilename', 'Provide an output filename stem.');
    end
    if isempty(outputDir)
        outputDir = pwd;
    end
    if ~isfolder(outputDir)
        error('export_lab_figure:MissingFolder', 'Output folder does not exist: %s', outputDir);
    end

    pngFile = [outputBase, '.png'];
    pdfFile = [outputBase, '.pdf'];
    checkAvailable(pngFile, pdfFile);

    temporaryBase = tempname(outputDir);
    stagedPng = [temporaryBase, '.png'];
    stagedPdf = [temporaryBase, '.pdf'];
    cleanup = onCleanup(@() removeStagedFiles(stagedPng, stagedPdf)); %#ok<NASGU>

    exportgraphics(target, stagedPng, 'Resolution', double(dpi));
    exportgraphics(target, stagedPdf, 'ContentType', 'vector');

    checkAvailable(pngFile, pdfFile);
    movefile(stagedPng, pngFile);
    try
        movefile(stagedPdf, pdfFile);
    catch exportError
        delete(pngFile);
        rethrow(exportError);
    end
end

function checkAvailable(pngFile, pdfFile)
    if isfile(pngFile) || isfolder(pngFile) || isfile(pdfFile) || isfolder(pdfFile)
        error('export_lab_figure:OutputExists', ...
            'An output path already exists. Choose a new filename stem: %s, %s', ...
            pngFile, pdfFile);
    end
end

function removeStagedFiles(stagedPng, stagedPdf)
    if isfile(stagedPng)
        delete(stagedPng);
    end
    if isfile(stagedPdf)
        delete(stagedPdf);
    end
end
