function escaped = lab_html_escape(value)
%LAB_HTML_ESCAPE Escape text for the figure pack's offline HTML reports.
    escaped = char(value);
    escaped = strrep(escaped, '&', '&amp;');
    escaped = strrep(escaped, '<', '&lt;');
    escaped = strrep(escaped, '>', '&gt;');
    escaped = strrep(escaped, '"', '&quot;');
    escaped = strrep(escaped, '''', '&#39;');
end
