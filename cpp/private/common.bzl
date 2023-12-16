load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def get_compile_command_args(infile, outfile, toolchain, features):
    action = ACTION_NAMES.c_compile
    if infile.basename.endswith(".cpp") or infile.basename.endswith(".hpp"):
        action = ACTION_NAMES.cpp_compile

    variables = cc_common.create_compile_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        source_file = infile.path,
        output_file = outfile.path,
    ) 

    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = action,
        variables = variables
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
                if not item.resolved_symlink_dynamic_library == None and (not prefer_static or item.pic_static_library == None):
                    libs.append(item.resolved_symlink_dynamic_library)
                else:
                    if item.alwayslink:
                        always_link_libs.append(item.pic_static_library)
                    else:
                        libs.append(item.pic_static_library)

    return depset(libs), depset(always_link_libs)

def resolve_linker_arguments(ctx, toolchain, features, output_file, is_linking_dynamic_library):
    libs, _always_link_libs = resolve_dependency_libraries(ctx, True)

    # FIXME(alexbatashev): resolve always link libs
    # FIXME(alexbatashev): correctly set arguments

    link_dirs = []
    link_flags = []
    for lib in libs.to_list():
        link_dirs.append(lib.dirname)
        link_flags.append("-l:" + lib.basename)

    link_variables = cc_common.create_link_variables(
        cc_toolchain = toolchain,
        feature_configuration = features,
        output_file = output_file,
        is_linking_dynamic_library = is_linking_dynamic_library,
        library_search_directories = depset(link_dirs)
    ) 

    link_flags_frozen = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_link_dynamic_library,
        variables = link_variables
    )

    link_flags.extend(link_flags_frozen)

    return link_flags, libs
