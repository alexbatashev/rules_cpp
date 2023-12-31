def is_clang(target):
    if "clang" in target.path:
        return True

    return False

def is_lld(target):
    if "lld" in target.path:
        return True

    return False

def is_llvm(target):
    for file in target.files.to_list():
        if "llvm" in file.path:
            return True

    return False

def is_libcpp(_stdlib):
    return True
