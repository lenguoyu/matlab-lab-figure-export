function valid = lab_pack_relative_path(path)
%LAB_PACK_RELATIVE_PATH Check the portable manifest path syntax.
    components = split(path, "/");
    code = double(char(path));
    valid = ~contains(path, ["\", ":"]) && ~any(components == "" | ...
        components == "." | components == "..") && ~any(code < 32 | code == 127);
end
