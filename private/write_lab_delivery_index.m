function write_lab_delivery_index(rootFolder, summary, widthMm, targetDPI)
%WRITE_LAB_DELIVERY_INDEX Write the delivery archive's offline start page.

    [file, message] = fopen(fullfile(rootFolder, 'index.html'), 'w', 'n', 'UTF-8');
    if file < 0
        error('write_lab_delivery_index:OpenFailed', 'Could not open the delivery index. %s', message);
    end
    closeFile = onCleanup(@() fclose(file));

    writeHeader(file);
    fprintf(file, '<header><h1>Figure Pack delivery</h1></header>\n');
    fprintf(file, '<nav aria-label="Delivery files"><ul>\n');
    writeLink(file, "figures/index.html", "Figure gallery");
    if isfile(fullfile(rootFolder, 'figures', 'figures.pdf'))
        writeLink(file, "figures/figures.pdf", "PDF figure book");
    end
    if isfile(fullfile(rootFolder, 'interactive', 'index.html'))
        writeLink(file, "interactive/index.html", "Interactive figure gallery");
    end
    writeLink(file, "artwork-check.csv", "Artwork check CSV");
    writeLink(file, "delivery-manifest.csv", "Delivery inventory CSV");
    fprintf(file, '</ul></nav>\n');

    writeSummary(file, summary, widthMm, targetDPI);
    if ~isempty(summary.Attachments)
        fprintf(file, '<section aria-labelledby="attachments"><h2 id="attachments">Attachments</h2><ul>\n');
        for index = 1:numel(summary.Attachments)
            path = summary.Attachments(index);
            writeLink(file, path, extractAfter(path, "attachments/"));
        end
        fprintf(file, '</ul></section>\n');
    end

    fprintf(file, '</main></body></html>\n');
    [message, status] = ferror(file);
    if status ~= 0
        error('write_lab_delivery_index:WriteFailed', 'Could not write the delivery index. %s', message);
    end
end

function writeHeader(file)
    fprintf(file, '%s\n', strjoin({
        '<!doctype html>'
        '<html lang="en">'
        '<head>'
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Figure Pack delivery</title>'
        '<style>'
        ':root { color-scheme: light; }'
        'body { margin: 0; color: #182832; background: #f3f7f6; font: 1rem/1.55 system-ui, sans-serif; }'
        'main { max-width: 62rem; margin: auto; padding: clamp(1rem, 4vw, 3rem); }'
        'h1 { font-size: clamp(2rem, 5vw, 3.6rem); line-height: 1.05; margin: 0 0 1rem; }'
        'h2 { font-size: 1.25rem; margin: 0 0 .55rem; }'
        'nav ul { display: flex; flex-wrap: wrap; gap: .4rem 1.1rem; margin: 0; padding: 0; list-style: none; }'
        'section { margin-top: 1.8rem; }'
        'p { margin: .35rem 0 .7rem; }'
        'a { color: #0a5f56; font-weight: 650; text-underline-offset: .18em; overflow-wrap: anywhere; }'
        ':focus-visible { outline: 2px solid #0a5f56; outline-offset: 4px; }'
        '.table-scroll { overflow-x: auto; margin-top: .85rem; }'
        'table { width: 100%; border-collapse: collapse; background: #fff; }'
        'th, td { padding: .55rem .7rem; border-bottom: 1px solid #d5e0df; text-align: left; }'
        'th { overflow-wrap: anywhere; }'
        'thead th { background: #e7efee; }'
        '</style>'
        '</head>'
        '<body><main>'
        }, newline));
end

function writeLink(file, path, label)
    fprintf(file, '<li><a href="%s">%s</a></li>\n', ...
        lab_relative_url(path), lab_html_escape(label));
end

function writeSummary(file, summary, widthMm, targetDPI)
    figures = summary.Figures;
    artwork = summary.Artwork;
    exported = nnz(figures.Status == "Exported");
    fprintf(file, '<section aria-labelledby="figure-results"><h2 id="figure-results">Figure results</h2>\n');
    fprintf(file, '<p>Exported %d of %d figures. See the figure gallery for individual downloads and export messages.</p>\n', ...
        exported, height(figures));
    fprintf(file, ['<p>PNG checks use a %g mm placement width and a %g DPI target. Meets target %d. ' ...
        'Below target %d. Needs review %d.</p>\n'], widthMm, targetDPI, ...
        nnz(artwork.Status == "Meets target"), nnz(artwork.Status == "Below target"), ...
        nnz(artwork.Status == "Needs review"));
    if ~isempty(summary.Plotly)
        fprintf(file, '<p>Interactive plots %d. Static previews %d. Needs review %d.</p>\n', ...
            nnz(summary.Plotly.Status == "Interactive"), nnz(summary.Plotly.Status == "Static only"), ...
            nnz(summary.Plotly.Status == "Needs review"));
    end
    if ~isempty(figures)
        writeFigureResults(file, figures, artwork);
    end
    fprintf(file, '</section>\n');
end

function writeFigureResults(file, figures, artwork)
    fprintf(file, ['<div class="table-scroll" tabindex="0" role="region" aria-labelledby="figure-results">' ...
        '<table><thead><tr><th scope="col">Figure</th><th scope="col">Export</th>' ...
        '<th scope="col">PNG resolution</th><th scope="col">Effective DPI</th></tr></thead><tbody>\n']);
    [present, location] = ismember(figures.Source, artwork.Source);
    for index = 1:height(figures)
        status = "Needs review";
        dpi = "Unavailable";
        if present(index)
            row = location(index);
            status = artwork.Status(row);
            if isfinite(artwork.EffectiveDPI(row))
                dpi = string(sprintf('%.2f', artwork.EffectiveDPI(row)));
            end
        end
        fprintf(file, '<tr><th scope="row">%s</th><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
            lab_html_escape(figures.Source(index)), lab_html_escape(figures.Status(index)), ...
            lab_html_escape(status), lab_html_escape(dpi));
    end
    fprintf(file, '</tbody></table></div>\n');
end
