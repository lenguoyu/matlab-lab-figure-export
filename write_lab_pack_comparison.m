function write_lab_pack_comparison(destination, figures, series, absTol, relTol)
%WRITE_LAB_PACK_COMPARISON Write an offline review of two figure packs.

    [file, openMessage] = fopen(destination, 'w', 'n', 'UTF-8');
    if file < 0
        error('write_lab_pack_comparison:OpenFailed', ...
            'Could not open comparison report: %s', openMessage);
    end
    fileGuard = onCleanup(@() fclose(file));

    writeHeader(file);
    fprintf(file, '<header class="intro"><h1>Figure pack comparison</h1>\n');
    fprintf(file, ['<p class="summary">%d figures &middot; %d series compared ' ...
        '&middot; %d series outside tolerance</p>\n'], ...
        height(figures), nnz(series.ComparedSamples > 0), nnz(series.OutsideSamples > 0));
    fprintf(file, ['<dl class="tolerances"><div><dt>Absolute tolerance</dt><dd>%s</dd></div>' ...
        '<div><dt>Relative tolerance</dt><dd>%s</dd></div></dl>\n'], ...
        formatNumber(absTol), formatNumber(relTol));
    fprintf(file, ['<p class="method">Each sample uses the limit <code>max(absTol, relTol &times; |baseline|)</code>. ' ...
        'Deltas are candidate minus baseline. Metrics use finite pairs on an identical ordered X grid. ' ...
        'Grid changes, unmatched series, and changed gaps require review.</p>\n']);
    fprintf(file, ['<nav class="downloads" aria-label="Comparison downloads">' ...
        '<a href="./comparison.csv">Figure results CSV</a>' ...
        '<a href="./series.csv">Series results CSV</a></nav></header>\n']);

    if isempty(figures)
        fprintf(file, '<p class="empty">Both packs contain zero figure entries.</p>\n');
    else
        writeFilter(file, figures);
        fprintf(file, '<section class="results" aria-label="Figure results">\n');
        for row = 1:height(figures)
            writeFigure(file, figures(row, :), series(series.Source == figures.Source(row), :));
        end
        fprintf(file, '</section>\n');
        writeFilterScript(file);
    end

    fprintf(file, '</main></body></html>\n');
    [writeMessage, writeStatus] = ferror(file);
    if writeStatus ~= 0
        error('write_lab_pack_comparison:WriteFailed', ...
            'Could not write the comparison report: %s', writeMessage);
    end
end

function writeHeader(file)
    fprintf(file, '%s\n', strjoin({
        '<!doctype html>'
        '<html lang="en">'
        '<head>'
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Figure pack comparison</title>'
        '<style>'
        ':root { color-scheme: light; --ink: #192a32; --muted: #485c65; --accent: #0b6057; --rule: #d1dedd; --wash: #edf4f3; }'
        '* { box-sizing: border-box; }'
        '[hidden] { display: none !important; }'
        'body { margin: 0; background: #f3f7f6; color: var(--ink); font: 1rem/1.55 system-ui, sans-serif; }'
        'main { max-width: 88rem; margin: auto; padding: clamp(1rem, 4vw, 3.5rem); }'
        '.intro { border-bottom: 1px solid var(--rule); padding-bottom: 1.5rem; }'
        'h1 { margin: 0; font-size: clamp(2.25rem, 6vw, 4.2rem); line-height: 1.05; letter-spacing: -.045em; }'
        'h2 { font-size: clamp(1.05rem, 2vw, 1.35rem); margin: 0; overflow-wrap: anywhere; }'
        'p { margin: .5rem 0; }'
        '.summary, .method, .message, #visible-count, .empty { color: var(--muted); }'
        '.summary { font-size: 1.1rem; }'
        '.method { max-width: 67ch; }'
        'code { color: var(--ink); }'
        'nav { display: flex; gap: .25rem 1.25rem; flex-wrap: wrap; margin-top: .8rem; }'
        'a { color: var(--accent); font-weight: 650; text-underline-offset: .18em; }'
        'button:focus-visible, a:focus-visible, summary:focus-visible, .table-scroll:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }'
        'dl { display: flex; flex-wrap: wrap; gap: .5rem 1.35rem; margin: .7rem 0; }'
        'dt { font-size: .8rem; color: var(--muted); }'
        'dd { margin: 0; font-weight: 650; font-variant-numeric: tabular-nums; }'
        '#status-filter { border: 0; margin: 1.4rem 0 0; padding: 0; min-width: 0; }'
        'legend { font-weight: 650; padding: 0; }'
        '.filter-controls { display: flex; flex-wrap: wrap; gap: .45rem; margin-top: .4rem; }'
        'button { border: 1px solid var(--rule); border-radius: .35rem; padding: .45rem .65rem; background: #fff; color: var(--ink); font: inherit; cursor: pointer; }'
        'button[aria-pressed="true"] { border-color: var(--accent); color: #fff; background: var(--accent); }'
        '.results { display: grid; gap: 1rem; margin-top: 1.2rem; }'
        '.case { min-width: 0; border: 1px solid var(--rule); border-radius: .65rem; background: #fff; padding: clamp(.9rem, 2vw, 1.4rem); }'
        '.case-header { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: .35rem 1rem; }'
        '.status { display: inline-block; padding: .14rem .48rem; border-radius: .3rem; font-size: .8rem; font-weight: 700; color: #304b54; background: #e9eff0; }'
        '.status[data-status="within-tolerance"] { color: #155440; background: #dff0e6; }'
        '.status[data-status="outside-tolerance"] { color: #983121; background: #fae6e2; }'
        '.status[data-status="needs-review"] { color: #72500c; background: #faefcd; }'
        '.status[data-status="added"] { color: #184f74; background: #e4f0f9; }'
        '.status[data-status="removed"] { color: #67365e; background: #f2e8f0; }'
        '.message { overflow-wrap: anywhere; white-space: pre-wrap; }'
        '.previews { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .8rem; margin: 1rem 0; }'
        '.previews figure { margin: 0; min-width: 0; }'
        'figcaption { margin-bottom: .2rem; font-size: .9rem; font-weight: 650; }'
        '.preview { display: grid; place-items: center; aspect-ratio: 16 / 9; overflow: hidden; background: var(--wash); border: 1px solid var(--rule); border-radius: .35rem; }'
        '.preview img { width: 100%; height: 100%; min-height: 0; object-fit: contain; }'
        '.preview span { color: var(--muted); padding: .8rem; }'
        'details { border-top: 1px solid var(--rule); padding-top: .65rem; margin-top: .8rem; }'
        'summary { font-weight: 650; cursor: pointer; }'
        '.table-scroll { max-width: 100%; overflow: auto; margin-top: .5rem; }'
        'table { width: 100%; border-collapse: collapse; font-size: .9rem; }'
        'th, td { padding: .55rem .65rem; border-bottom: 1px solid var(--rule); vertical-align: top; text-align: left; }'
        'thead th { background: var(--wash); white-space: nowrap; }'
        'tbody th { min-width: 10rem; overflow-wrap: anywhere; }'
        'tbody td:nth-child(2) { min-width: 8rem; overflow-wrap: anywhere; }'
        'td.number { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }'
        'small { display: block; font-weight: 400; color: var(--muted); white-space: pre-wrap; }'
        '@media (max-width: 40rem) { .previews { grid-template-columns: minmax(0, 1fr); } }'
        '</style>'
        '</head>'
        '<body><main>'
        }, newline));
end

function writeFilter(file, figures)
    fprintf(file, ['<fieldset id="status-filter" hidden><legend>Filter by result</legend>' ...
        '<div class="filter-controls">\n']);
    fprintf(file, '<button type="button" data-filter="all" aria-pressed="true">All (%d)</button>\n', ...
        height(figures));
    statuses = ["Outside tolerance", "Needs review", "Added", "Removed", ...
        "Visual only", "Within tolerance"];
    for status = statuses
        count = nnz(figures.Status == status);
        if count > 0
            fprintf(file, ['<button type="button" data-filter="%s" aria-pressed="false">' ...
                '%s (%d)</button>\n'], statusSlug(status), lab_html_escape(status), count);
        end
    end
    fprintf(file, '</div></fieldset>\n');
    fprintf(file, '<p id="visible-count" role="status" hidden></p>\n');
end

function writeFigure(file, entry, series)
    source = lab_html_escape(entry.Source);
    status = entry.Status;
    fprintf(file, '<article class="case" data-figure-status="%s">\n', statusSlug(status));
    fprintf(file, '<header class="case-header"><h2>%s</h2>%s</header>\n', source, statusMarkup(status));
    if strlength(entry.Message) > 0
        fprintf(file, '<p class="message">%s</p>\n', lab_html_escape(entry.Message));
    end
    fprintf(file, ['<dl><div><dt>Compared series</dt><dd>%d</dd></div>' ...
        '<div><dt>Outside tolerance</dt><dd>%d</dd></div>' ...
        '<div><dt>Review series</dt><dd>%d</dd></div>' ...
        '<div><dt>Max |&Delta;|</dt><dd>%s</dd></div></dl>\n'], ...
        entry.ComparedSeries, entry.OutsideSeries, entry.ReviewSeries, formatNumber(entry.MaxAbsDelta));

    fprintf(file, '<div class="previews">\n');
    baselineEmpty = 'Preview unavailable';
    candidateEmpty = 'Preview unavailable';
    if status == "Added"
        baselineEmpty = 'No baseline figure';
    elseif status == "Removed"
        candidateEmpty = 'No candidate figure';
    end
    writePreview(file, entry.BaselinePreview, "Baseline", entry.Source, baselineEmpty);
    writePreview(file, entry.CandidatePreview, "Candidate", entry.Source, candidateEmpty);
    fprintf(file, '</div>\n');

    if ~isempty(series)
        writeSeries(file, series, status, source);
    end
    fprintf(file, '</article>\n');
end

function writePreview(file, path, side, source, emptyMessage)
    fprintf(file, '<figure><figcaption>%s</figcaption>\n', lab_html_escape(side));
    path = char(path);
    if isempty(regexp(path, '^previews/[0-9]{4,}-(baseline|candidate)\.png$', 'once'))
        fprintf(file, '<div class="preview"><span>%s</span></div>\n', lab_html_escape(emptyMessage));
    else
        url = lab_html_escape(['./', path]);
        description = lab_html_escape("Open full-size " + lower(side) + " preview of " + source);
        fprintf(file, ['<a class="preview" href="%s"><img src="%s" alt="%s" ' ...
            'loading="lazy" decoding="async"></a>\n'], url, url, description);
    end
    fprintf(file, '</figure>\n');
end

function writeSeries(file, series, figureStatus, escapedSource)
    openAttribute = '';
    if figureStatus == "Outside tolerance" || figureStatus == "Needs review"
        openAttribute = ' open';
    end
    fprintf(file, '<details%s><summary>Series results (%d)</summary>\n', ...
        openAttribute, height(series));
    fprintf(file, ['<div class="table-scroll" tabindex="0" role="region" ' ...
        'aria-label="Series results for %s"><table>\n'], escapedSource);
    fprintf(file, ['<thead><tr><th scope="col">Series</th><th scope="col">Result</th>' ...
        '<th scope="col">Compared</th><th scope="col">Skipped</th><th scope="col">Outside</th>' ...
        '<th scope="col">Max |&Delta;|</th><th scope="col">X at max</th></tr></thead><tbody>\n']);
    for row = 1:height(series)
        fprintf(file, ['<tr><th scope="row">%s<small>Axes %s &middot; series %s</small></th>' ...
            '<td>%s'], lab_html_escape(series.Label(row)), formatNumber(series.Axes(row)), ...
            formatNumber(series.Series(row)), statusMarkup(series.Status(row)));
        if strlength(series.Message(row)) > 0
            fprintf(file, '<small>%s</small>', lab_html_escape(series.Message(row)));
        end
        fprintf(file, ['</td><td class="number">%s</td><td class="number">%s</td>' ...
            '<td class="number">%s</td><td class="number">%s</td><td class="number">%s</td></tr>\n'], ...
            formatNumber(series.ComparedSamples(row)), formatNumber(series.SkippedSamples(row)), ...
            formatNumber(series.OutsideSamples(row)), formatNumber(series.MaxAbsDelta(row)), ...
            formatNumber(series.XAtMax(row)));
    end
    fprintf(file, '</tbody></table></div></details>\n');
end

function markup = statusMarkup(status)
    markup = sprintf('<span class="status" data-status="%s">%s</span>', ...
        statusSlug(status), lab_html_escape(status));
end

function slug = statusSlug(status)
    slug = regexprep(lower(char(status)), '[^a-z]+', '-');
end

function formatted = formatNumber(number)
    if isnan(number)
        formatted = '&mdash;';
    else
        formatted = sprintf('%.12g', number);
    end
end

function writeFilterScript(file)
    fprintf(file, '%s\n', strjoin({
        '<script>'
        'const controls = document.getElementById("status-filter");'
        'const countLabel = document.getElementById("visible-count");'
        'const buttons = [...controls.querySelectorAll("button[data-filter]")];'
        'const figures = [...document.querySelectorAll("[data-figure-status]")];'
        'for (const button of buttons) {'
        '  button.addEventListener("click", () => {'
        '    const result = button.dataset.filter;'
        '    let visible = 0;'
        '    for (const figure of figures) {'
        '      figure.hidden = result !== "all" && figure.dataset.figureStatus !== result;'
        '      if (!figure.hidden) visible++;'
        '    }'
        '    for (const option of buttons) option.setAttribute("aria-pressed", String(option === button));'
        '    countLabel.textContent = `Showing ${visible} of ${figures.length} figures`;'
        '  });'
        '}'
        'countLabel.textContent = `Showing all ${figures.length} figures`;'
        'countLabel.hidden = false;'
        'controls.hidden = false;'
        '</script>'
        }, newline));
end
