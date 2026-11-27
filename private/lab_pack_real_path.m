function path = lab_pack_real_path(file)
%LAB_PACK_REAL_PATH Resolve a filesystem path with the MATLAB JVM.
    handle = java.io.File(char(file));
    nioPath = handle.toPath();
    path = nioPath.toRealPath(javaArray('java.nio.file.LinkOption', 0));
end
