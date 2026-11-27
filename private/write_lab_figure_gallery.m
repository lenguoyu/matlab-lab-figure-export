function write_lab_figure_gallery(destination, report, bookFilename)
%WRITE_LAB_FIGURE_GALLERY Write the offline HTML index for a figure batch.

    [file, openMessage] = fopen(destination, 'w', 'n', 'UTF-8');
    if file < 0
        error('write_lab_figure_gallery:OpenFailed', ...
            'Could not open gallery file: %s', openMessage);
    end
    fileGuard = onCleanup(@() fclose(file));

    exported = report.Status == "Exported";
    failed = ~exported;
    writeHeader(file);
    fprintf(file, '<header class="intro"><h1>Figure gallery</h1>\n');
    fprintf(file, '<p class="summary">%d exported &middot; %d failed</p>\n', ...
        nnz(exported), nnz(failed));
    fprintf(file, '<nav aria-label="Batch downloads">%s%s</nav></header>\n', ...
        artifactLink('manifest.csv', 'Export manifest', 'Download the export manifest as CSV'), ...
        artifactLink(bookFilename, 'PDF figure book', 'Open the PDF figure book'));

    if any(exported)
        fprintf(file, '<section aria-labelledby="figures"><h2 id="figures">Figures</h2>\n');
        fprintf(file, '<div class="grid">\n');
        for row = find(exported).'
            writeFigure(file, report, row);
        end
        fprintf(file, '</div></section>\n');
    end

    if any(failed)
        fprintf(file, '<section aria-labelledby="failures"><h2 id="failures">Failed exports</h2>\n');
        fprintf(file, '<ul class="failures">\n');
        for row = find(failed).'
            fprintf(file, '<li><strong>%s</strong><p>%s</p></li>\n', ...
                lab_html_escape(report.Source(row)), lab_html_escape(report.Message(row)));
        end
        fprintf(file, '</ul></section>\n');
    end

    fprintf(file, '</main></body></html>\n');
    [writeMessage, writeStatus] = ferror(file);
    if writeStatus ~= 0
        error('write_lab_figure_gallery:WriteFailed', ...
            'Could not write the figure gallery: %s', writeMessage);
    end
end

function writeHeader(file)
    fprintf(file, '%s\n', strjoin({
        '<!doctype html>'
        '<html lang="en">'
        '<head>'
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Figure gallery</title>'
        '<style>'
        ':root { color-scheme: light; --ink: #182832; --muted: #455962; --accent: #0a5f56; --rule: #d5e0df; }'
        '* { box-sizing: border-box; }'
        'body { margin: 0; background: #f3f7f6; color: var(--ink); font: 1rem/1.5 system-ui, sans-serif; }'
        'main { max-width: 80rem; margin: auto; padding: clamp(1rem, 4vw, 3.5rem); }'
        '.intro { border-bottom: 1px solid var(--rule); padding-bottom: 1.5rem; }'
        'h1 { margin: 0; font-size: clamp(2.4rem, 6vw, 4.6rem); line-height: 1.05; letter-spacing: -.045em; }'
        'h2 { margin: 1.75rem 0 .8rem; font-size: 1.25rem; }'
        'h3 { font-size: 1.08rem; margin: 0; overflow-wrap: anywhere; }'
        '.summary, .metadata { color: var(--muted); margin: .5rem 0 .8rem; }'
        '.metadata { margin: .3rem 0; font-size: .9rem; }'
        'nav, .downloads { display: flex; gap: .25rem 1rem; flex-wrap: wrap; }'
        'a { color: var(--accent); font-weight: 650; text-underline-offset: .18em; }'
        'a:focus-visible { outline: 2px solid var(--accent); outline-offset: 4px; }'
        '.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 22rem), 1fr)); gap: 1rem; }'
        '.card { min-width: 0; background: white; border: 1px solid var(--rule); border-radius: .65rem; overflow: hidden; }'
        '.preview { display: grid; place-items: center; aspect-ratio: 16 / 9; background: #e7efee; border-bottom: 1px solid var(--rule); }'
        '.preview img { width: 100%; height: 100%; min-height: 0; object-fit: contain; }'
        '.card-content { padding: 1rem 1.15rem; }'
        '.downloads { margin-top: .75rem; }'
        '.failures { margin: 0; padding: 0; list-style: none; }'
        '.failures li { padding: .8rem 1rem; border: 1px solid var(--rule); border-radius: .45rem; background: white; margin-bottom: .6rem; overflow-wrap: anywhere; }'
        '.failures p { margin: .25rem 0 0; color: var(--muted); white-space: pre-wrap; }'
        '</style>'
        '</head>'
        '<body><main>'
        }, newline));
end

function writeFigure(file, report, row)
    source = report.Source(row);
    fprintf(file, '<article class="card">\n');
    if strlength(report.PNG(row)) > 0
        fprintf(file, ['<div class="preview"><img src="%s" alt="%s" ' ...
            'loading="lazy" decoding="async"></div>\n'], ...
            lab_relative_url(report.PNG(row)), lab_html_escape("Preview of " + source));
    end
    fprintf(file, '<div class="card-content"><h3>%s</h3>\n', lab_html_escape(source));
    fprintf(file, '<p class="metadata">%d series', report.SeriesCount(row));
    if report.BookPage(row) > 0
        fprintf(file, ' &middot; book page %d', report.BookPage(row));
    end
    fprintf(file, '</p>\n');
    fprintf(file, '<div class="downloads">%s%s%s</div>\n', ...
        artifactLink(report.PNG(row), 'PNG', "Open the PNG for " + source), ...
        artifactLink(report.PDF(row), 'PDF', "Open the PDF for " + source), ...
        artifactLink(report.DataCSV(row), 'Data CSV', "Download the data CSV for " + source));
    fprintf(file, '</div></article>\n');
end

function link = artifactLink(path, label, context)
    link = '';
    if strlength(string(path)) > 0
        link = sprintf('<a href="%s" aria-label="%s">%s</a>', ...
            lab_relative_url(path), lab_html_escape(context), lab_html_escape(label));
    end
end
