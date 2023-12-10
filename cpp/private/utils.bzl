def is_clang(target):
    for file in target.files.to_list():
        if "clang" in file.path:
            return True

    return False

def is_lld(target):
    for file in target.files.to_list():
        if "lld" in file.path:
            return True

    return False

def is_llvm(target):
    for file in target.files.to_list():
        if "llvm" in file.path:
            return True

    return False

def is_libcpp(_stdlib):
    return True
