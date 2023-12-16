load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

HeadersInfo = provider(
    fields = {
        "headers": "a depset of all header files",
        "includes": "a depset of all include paths",
    },
)

def create_compilation_context(ctx, headers = []):
    """
    Creates a compiler context structure to be used with C++ rules.

    Args:
        ctx: rule context
        headers: optional list of Files with target headers

    Returns:
        A structure containing compilation context
    """

    srcs = []
    all_headers = []
    all_headers.extend(headers)

    if hasattr(ctx.files, "srcs"):
        srcs = ctx.files.srcs

        for src in ctx.files.srcs:
            if src.basename.endswith(".h") or src.basename.endswith(".hpp") or src.basename.endswith(".inc") or src.basename.endswith(".def"):
                all_headers.append(src.path)

    if hasattr(ctx.files, "textual_hdrs"):
        for src in ctx.files.textual_hdrs:
            all_headers.append(src.path)

    includes = []
    dependency_headers = []

    if hasattr(ctx.attr, "header_map"):
        dep_includes = ctx.attr.header_map[HeadersInfo].includes
        dep_headers = ctx.attr.header_map[HeadersInfo].headers

        includes = resolve_includes(ctx, dep_includes)
        dependency_headers = dep_headers

    return struct(
        headers = all_headers,
        dependency_headers = dependency_headers,
        sources = srcs,
        includes = includes,
    )


def get_compile_command_args(toolchain, source = None, output = None, features = None, include_directories = None, pic = True):
    action = ACTION_NAMES.c_compile
    if source.endswith(".cpp") or source.endswith(".hpp"):
        action = ACTION_NAMES.cpp_compile

    variables = cc_common.create_compile_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        source_file = source,
        output_file = output,
        include_directories = include_directories,
        use_pic = pic,
    )

    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = action,
        variables = variables,
    )

    return flags

def resolve_dependency_libraries(ctx, prefer_static):
    """
        Resolves dependencies to C++ libraries

        Args:
            ctx: rule context
            prefer_static: True or False; prefer static library over shared with cc_library
    """

    libs = []
    always_link_libs = []

    for dep in ctx.attr.deps:
        dep_libs = dep[CcInfo].linking_context.linker_inputs.to_list()
        for input in dep_libs:
            for item in input.libraries:
                print(item)
                if not item.resolved_symlink_dynamic_library == None and (not prefer_static or item.pic_static_library == None):
                    libs.append(item.resolved_symlink_dynamic_library)
                elif not item.pic_static_library == None:
                    libs.append(item.pic_static_library)
                else:
                    libs.append(item.static_library)

    return depset(libs), depset(always_link_libs)

def resolve_linker_arguments(ctx, toolchain, features, output_file, is_linking_dynamic_library):
    libs, _always_link_libs = resolve_dependency_libraries(ctx, True)

    # FIXME(alexbatashev): resolve always link libs
    # FIXME(alexbatashev): correctly set arguments

    link_dirs = []
    link_flags = []
    for lib in libs.to_list():
        print(lib)
        link_dirs.append(lib.dirname)
        link_flags.append("-l:" + lib.basename)

    link_variables = cc_common.create_link_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        output_file = output_file,
        is_linking_dynamic_library = is_linking_dynamic_library,
        library_search_directories = depset(link_dirs),
    )

    link_flags_frozen = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_link_dynamic_library,
        variables = link_variables,
    )

    link_flags.extend(link_flags_frozen)

    return link_flags, libs

def resolve_includes(ctx, external_includes):
    includes = [ctx.bin_dir.path + "/_virtual_includes/" + ctx.attr.name]

    includes.extend(ctx.attr.includes)
    includes.extend(external_includes.to_list())

    return depset(includes)
