function [data, keys, starts] = read_lab_line_data(path, caller)
%READ_LAB_LINE_DATA Validate and group the saved Figure Pack XY samples.
    metadata = {'AxesTitle', 'XLabel', 'YLabel', 'Label'};
    names = {'Axes', 'AxesTitle', 'XLabel', 'YLabel', 'Series', 'Label', 'Sample', 'X', 'Y'};
    checkHeader(path, names, caller);

    % Read every value as text so numeric-looking titles and labels stay exact.
    options = delimitedTextImportOptions('NumVariables', numel(names));
    options.Delimiter = ',';
    options.Encoding = 'UTF-8';
    options.DataLines = [2, Inf];
    options.VariableNames = names;
    options.TrailingDelimitersRule = 'keep';
    options.ExtraColumnsRule = 'error';
    options.EmptyLineRule = 'error';
    options.MissingRule = 'error';
    options.ImportErrorRule = 'error';
    options = setvartype(options, names, 'string');
    options = setvaropts(options, names, 'WhitespaceRule', 'preserve', ...
        'EmptyFieldRule', 'auto');
    try
        data = readtable(path, options);
    catch importError
        invalidCSV(caller, path, importError.message);
    end

    for name = metadata
        column = name{1};
        data.(column)(ismissing(data.(column))) = "";
    end
    for name = {'Axes', 'Series', 'Sample', 'X', 'Y'}
        column = name{1};
        tokens = strip(data.(column));
        values = str2double(tokens);
        allowedNaN = ismissing(tokens) | tokens == "" | strcmpi(tokens, 'NaN');
        if ~isreal(values) || any(isnan(values) & ~allowedNaN)
            invalidCSV(caller, path, sprintf('Column %s contains a nonnumeric sample.', column));
        end
        data.(column) = values;
    end

    idColumns = {'Axes', 'Series', 'Sample'};
    ids = data{:, idColumns};
    if any(~isfinite(ids) | ids < 1 | ids > flintmax | ids ~= fix(ids), 'all')
        invalidCSV(caller, path, 'Axes, Series and Sample must contain positive integer IDs.');
    end

    data = sortrows(data, idColumns);
    if isempty(data)
        keys = zeros(0, 2);
        starts = 1;
        return;
    end

    starts = find([true; diff(data.Axes) ~= 0 | diff(data.Series) ~= 0]);
    keys = data{starts, {'Axes', 'Series'}};
    starts(end + 1) = height(data) + 1;
    for group = 1:size(keys, 1)
        rows = starts(group):starts(group + 1) - 1;
        if ~isequal(data.Sample(rows), (1:numel(rows)).')
            invalidCSV(caller, path, 'Each series must contain Sample indices 1 through N exactly once.');
        end
        values = data{rows, metadata};
        if any(values ~= values(1, :), 'all')
            invalidCSV(caller, path, 'Plot metadata must remain constant within each series.');
        end
    end
end

function checkHeader(path, names, caller)
    [file, message] = fopen(path, 'rt', 'n', 'UTF-8');
    if file == -1
        invalidCSV(caller, path, message);
    end
    cleanup = onCleanup(@() fclose(file));
    line = fgetl(file);
    if ~ischar(line)
        invalidCSV(caller, path, 'The line-data header is missing.');
    end
    if ~isempty(line) && line(1) == char(65279)
        line(1) = [];
    end
    header = split(string(line), ',').';
    header = regexprep(header, '^"([^"]*)"$', '$1');
    if ~isequal(header, string(names))
        invalidCSV(caller, path, 'The header does not match the Figure Pack line-data schema.');
    end
end

function invalidCSV(caller, path, detail)
    error([caller ':InvalidCSV'], 'Invalid line-data CSV "%s". %s', path, detail);
end
