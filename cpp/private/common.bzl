load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("//cpp:providers.bzl", "CppModuleInfo")

def collect_external_headers(deps):
    headers = []

    for dep in deps:
        if CcInfo in dep:
            headers.extend(dep[CcInfo].compilation_context.headers)

    return headers

def collect_external_includes(deps):
    includes = []
    for dep in deps:
        if CcInfo in dep:
            includes.extend(dep[CcInfo].compilation_context.includes.to_list())
            includes.extend(dep[CcInfo].compilation_context.external_includes.to_list())
            includes.extend(dep[CcInfo].compilation_context.system_includes.to_list())
            includes.extend(dep[CcInfo].compilation_context.quote_includes.to_list())
    return depset(includes)

def collect_modules(deps):
    modules = []

    for dep in deps:
        if CppModuleInfo in dep:
            modules.append({
                "name": dep[CppModuleInfo].module_name,
                "file": dep[CppModuleInfo].pcm,
            })
            for part in dep[CppModuleInfo].partitions.to_list():
                modules.append({
                    "name": part[CppModuleInfo].module_name,
                    "file": part[CppModuleInfo].pcm,
                })

    return modules

def collect_module_objects(deps):
    obj_files = []

    for dep in deps:
        if CppModuleInfo in dep:
            obj_files.extend(dep[CppModuleInfo].objs)

    return obj_files

def create_compilation_context(ctx, headers = [], is_aspect = False):
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

    srcs = []

    if hasattr(ctx.files, "srcs"):
        srcs = ctx.files.srcs
    elif is_aspect and hasattr(ctx.rule.files, "srcs"):
        srcs = ctx.rule.files.srcs

    for src in srcs:
        if src.basename.endswith(".h") or src.basename.endswith(".hpp") or src.basename.endswith(".inc") or src.basename.endswith(".def"):
            all_headers.append(src.path)

    if hasattr(ctx.files, "textual_hdrs"):
        for src in ctx.files.textual_hdrs:
            all_headers.append(src.path)
    elif is_aspect and hasattr(ctx.rule.files, "textual_hdrs"):
        for src in ctx.rule.files.textual_hdrs:
            all_headers.append(src.path)

    includes = None
    dependency_headers = depset([])

    return struct(
        headers = all_headers,
        dependency_headers = dependency_headers,
        sources = srcs,
        includes = includes,
    )

def get_compile_command_args(toolchain, source = None, output = None, features = None, include_directories = None, pic = True, action_name = "", extra_vars = None):
    action = action_name
    if action == "":
        action = ACTION_NAMES.c_compile
        if source.endswith(".cpp") or source.endswith(".hpp"):
            action = ACTION_NAMES.cpp_compile

    if extra_vars == None:
        extra_vars = {
            "cpp_precompiled_modules": [],
        }

    variables = cc_common.create_compile_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        source_file = source,
        output_file = output,
        include_directories = include_directories,
        use_pic = pic,
        variables_extension = extra_vars,
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
        if CcInfo in dep:
            dep_libs = dep[CcInfo].linking_context.linker_inputs.to_list()
            for input in dep_libs:
                for item in input.libraries:
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
        link_dirs.append(lib.dirname)
        lib_name = lib.basename
        if lib_name.startswith("lib"):
            lib_name = lib_name[3:]
        if lib_name.endswith(".a"):
            lib_name = lib_name[:-2]
        if lib_name.endswith(".so"):
            lib_name = lib_name[:-3]
        if lib_name.endswith(".dylib"):
            lib_name = lib_name[:-6]
        link_flags.append("-l" + lib_name)

    link_variables = cc_common.create_link_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        output_file = output_file,
        is_linking_dynamic_library = is_linking_dynamic_library,
        library_search_directories = depset(link_dirs),
    )

    action_name = ACTION_NAMES.cpp_link_executable

    if is_linking_dynamic_library:
        action_name = ACTION_NAMES.cpp_link_dynamic_library

    link_flags_frozen = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = action_name,
        variables = link_variables,
    )

    link_flags.extend(link_flags_frozen)

    return link_flags, libs

def resolve_includes(ctx, external_includes):
    includes = [ctx.bin_dir.path + "/_virtual_includes/" + ctx.attr.name]

    includes.extend(ctx.attr.includes)
    includes.extend(external_includes.to_list())

    return depset(includes)

def generate_header_names(name, actions, bin_dir, hdrs, strip_include_prefix, include_prefix):
    headers = []
    for hdr in hdrs:
        for file in hdr.files.to_list():
            if not file.path.startswith(strip_include_prefix):
                fail("Path " + file.path + " does not start with prefix " + strip_include_prefix)
            target_path = "_virtual_includes/" + name + "/" + file.path.replace(strip_include_prefix, include_prefix)
            headers.append(target_path)
    return headers
