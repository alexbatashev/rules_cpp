"""Rules for declaring C++ toolchain files"""

load("//cpp:providers.bzl", "BinutilsInfo", "CompilerInfo", "LinkerInfo", "StdlibInfo")

_compiler_attrs = {
    "kind": attr.string(doc = "one of ['gcc', 'clang']", mandatory = True),
    "binary": attr.label(doc = "compiler executable", mandatory = True, allow_single_file = True),
    "deps": attr.label_list(doc = "compiler dependency files", allow_files = True),
}

_stdlib_attrs = {
    "kind": attr.string(doc = "one of ['libstdc++', 'libc++']", mandatory = True),
    "headers": attr.label_list(doc = "header files", mandatory = True, allow_files = True),
    "shared_libraries": attr.label_list(doc = "shared libraries", mandatory = True, allow_files = True),
    "static_libraries": attr.label_list(doc = "static libraries", mandatory = True, allow_files = True),
    "includes": attr.string_list(doc = "standard headers include paths", mandatory = True),
}

_binutils_attrs = {
    "ar": attr.label(doc = "archiver", mandatory = True, allow_single_file = True),
    "assembler": attr.label(doc = "assembler", mandatory = True, allow_single_file = True),
    "objcopy": attr.label(doc = "objcopy tool", mandatory = True, allow_single_file = True),
    "strip": attr.label(doc = "strip tool", mandatory = True, allow_single_file = True),
    "dwp": attr.label(doc = "debug info fission tool", mandatory = True, allow_single_file = True),
    "deps": attr.label_list(doc = "tools dependency files", allow_files = True),
}

_linker_attrs = {
    "kind": attr.string(doc = "one of ['lld', 'ld', 'gold', 'mold']", mandatory = True),
    "binary": attr.label(doc = "compiler executable", mandatory = True, allow_single_file = True),
    "deps": attr.label_list(doc = "compiler dependency files", allow_files = True),
}

def _compiler_impl(ctx):
    """Implementation for compiler rule

    Args:
        ctx: rule context
    """

    comp_info = CompilerInfo(
        binary = ctx.files.binary[0],
        kind = ctx.attr.kind,
    )

    default = DefaultInfo(
        files = depset(ctx.files.binary + ctx.files.deps),
    )

    return comp_info, default

compiler = rule(
    implementation = _compiler_impl,
    attrs = _compiler_attrs,
    provides = [CompilerInfo, DefaultInfo],
)

def _stdlib_impl(ctx):
    """Implementation for standard_library rule

    Args:
        ctx: rule context
    """

    stdlib_info = StdlibInfo(
        headers = ctx.files.headers,
        shared_libraries = ctx.files.shared_libraries,
        static_libraries = ctx.files.static_libraries,
        kind = ctx.attr.kind,
        includes = ctx.attr.includes,
    )

    default_info = DefaultInfo(
        files = depset(ctx.files.headers + ctx.files.shared_libraries + ctx.files.static_libraries),
    )

    return stdlib_info, default_info

standard_library = rule(
    implementation = _stdlib_impl,
    attrs = _stdlib_attrs,
    provides = [StdlibInfo, DefaultInfo],
)

def _binutils_impl(ctx):
    """Implementation for binutils rule

    Args:
        ctx: rule context
    """

    binutils_info = BinutilsInfo(
        ar = ctx.files.ar[0],
        assembler = ctx.files.assembler[0],
        objcopy = ctx.files.objcopy[0],
        strip = ctx.files.strip[0],
        dwp = ctx.files.dwp[0],
    )

    default_info = DefaultInfo(
        files = depset(ctx.files.ar + ctx.files.assembler + ctx.files.objcopy + ctx.files.strip + ctx.files.dwp),
    )

    return binutils_info, default_info

binutils = rule(
    implementation = _binutils_impl,
    attrs = _binutils_attrs,
    provides = [BinutilsInfo, DefaultInfo],
)

def _linker_impl(ctx):
    """Implementation for linker rule

    Args:
        ctx: rule context
    """
    linker_info = LinkerInfo(
        binary = ctx.files.binary[0],
        kind = ctx.attr.kind,
    )

    default = DefaultInfo(
        files = depset(ctx.files.binary + ctx.files.deps),
    )

    return linker_info, default

linker = rule(
    implementation = _linker_impl,
    attrs = _linker_attrs,
    provides = [LinkerInfo, DefaultInfo],
)
