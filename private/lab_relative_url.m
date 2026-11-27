function url = lab_relative_url(path)
%LAB_RELATIVE_URL Encode a relative UTF-8 path for an HTML attribute.
    bytes = char(unicode2native(char(path), 'UTF-8'));
    encoded = cell(size(bytes));
    unreserved = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/';
    for index = 1:numel(bytes)
        if any(bytes(index) == unreserved)
            encoded{index} = bytes(index);
        else
            encoded{index} = sprintf('%%%02X', uint8(bytes(index)));
        end
    end
    url = lab_html_escape(['./', encoded{:}]);
end
