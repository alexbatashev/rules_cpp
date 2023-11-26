load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "action_config", "tool_path", "flag_group", "flag_set", "feature", "tool",
"variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

all_c_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
]

all_cpp_compile_actions = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

all_compile_actions = all_c_compile_actions + all_cpp_compile_actions

preprocessor_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
]

codegen_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_module_codegen,
]

all_link_actions = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

def get_tool_path(ctx, target, path):
    return target.label.workspace_root + "/" + path

def toolchain_impl(ctx):
    compiler = ctx.attr.compiler
    tool_paths = [
        tool_path(name = "ar", path = get_tool_path(ctx, compiler, "bin/llvm-ar")),
        # TODO: use linker if available
        tool_path(name = "ld", path = get_tool_path(ctx, compiler, "bin/ld.lld")),
        tool_path(name = "cpp", path = get_tool_path(ctx, compiler, "bin/clang-cpp")),
        tool_path(name = "gcc", path = get_tool_path(ctx, compiler, "bin/clang")),
        tool_path(name = "dwp", path = get_tool_path(ctx, compiler, "bin/llvm-dwp")),
        tool_path(name = "gcov", path = get_tool_path(ctx, compiler, "bin/llvm-cov")),
        tool_path(name = "nm", path = get_tool_path(ctx, compiler, "bin/llvm-nm")),
        tool_path(name = "objcopy", path = get_tool_path(ctx, compiler, "bin/llvm-objcopy")),
        tool_path(name = "objdump", path = get_tool_path(ctx, compiler, "bin/llvm-objdump")),
        tool_path(name = "strip", path = get_tool_path(ctx, compiler, "bin/llvm-strip")),
    ]

    action_configs = [
        action_config(action_name = name, enabled = True, tools = [tool(path = get_tool_path(ctx, compiler, "bin/clang"))])
        for name in all_c_compile_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = get_tool_path(ctx, compiler, "bin/clang++"))])
        for name in all_cpp_compile_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = get_tool_path(ctx, compiler, "bin/clang++"))])
        for name in all_link_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = get_tool_path(ctx, compiler, "bin/llvm-ar"))])
        for name in [ACTION_NAMES.cpp_link_static_library]
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = get_tool_path(ctx, compiler, "bin/llvm-strip"))])
        for name in [ACTION_NAMES.strip]
    ]

    std_compile_flags = ["-std=c++17", "-stdlib=libc++"]

    default_flags_feature = feature(
        name = "default_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_cpp_compile_actions + all_link_actions,
                flag_groups = ([
                    flag_group(
                        flags = std_compile_flags,
                    ),
                ]),
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            #"-Werror",
                            #"-Wall",
                            #"-Wextra",
                            #"-Wthread-safety",
                            #"-Wself-assign",
                            #"-Wimplicit-fallthrough",
                            #"-Wctad-maybe-unsupported",
                            #"-Wdelete-non-virtual-dtor",
                            # Don't warn on external code as we can't
                            # necessarily patch it easily.
                            "--system-header-prefix=external/",
                            # Compile actions shouldn't link anything.
                            "-c",
                        ],
                    ),
                    flag_group(
                        expand_if_available = "output_assembly_file",
                        flags = ["-S"],
                    ),
                    flag_group(
                        expand_if_available = "output_preprocess_file",
                        flags = ["-E"],
                    ),
                    flag_group(
                        flags = ["-MD", "-MF", "%{dependency_file}"],
                        expand_if_available = "dependency_file",
                    ),
                    flag_group(
                        flags = ["-frandom-seed=%{output_file}"],
                        expand_if_available = "output_file",
                    ),
                ]),
            ),
            flag_set(
                actions = preprocessor_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            # Disable a warning and override builtin macros to
                            # ensure a hermetic build.
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=\"redacted\"",
                            "-D__TIMESTAMP__=\"redacted\"",
                            "-D__TIME__=\"redacted\"",
                            # Pass the clang version as a define so that bazel
                            # caching is more likely to notice version changes.
                            # "-DCLANG_VERSION_FOR_CACHE=\"%s\"" % clang_version_for_cache,
                        ],
                    ),
                    flag_group(
                        flags = ["-D%{preprocessor_defines}"],
                        iterate_over = "preprocessor_defines",
                    ),
                    flag_group(
                        flags = ["-include", "%{includes}"],
                        iterate_over = "includes",
                        expand_if_available = "includes",
                    ),
                    flag_group(
                        flags = ["-iquote", "%{quote_include_paths}"],
                        iterate_over = "quote_include_paths",
                    ),
                    flag_group(
                        flags = ["-I%{include_paths}"],
                        iterate_over = "include_paths",
                    ),
                    flag_group(
                        flags = ["-isystem", "%{system_include_paths}"],
                        iterate_over = "system_include_paths",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [flag_group(flags = ["-shared"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-Wl,--gdb-index"],
                        expand_if_available = "is_using_fission",
                    ),
                    flag_group(
                        flags = ["-Wl,-S"],
                        expand_if_available = "strip_debug_symbols",
                    ),
                    flag_group(
                        flags = ["-L%{library_search_directories}"],
                        iterate_over = "library_search_directories",
                        expand_if_available = "library_search_directories",
                    ),
                    flag_group(
                        iterate_over = "runtime_library_search_directories",
                        flags = [
                            "-Wl,-rpath,$ORIGIN/%{runtime_library_search_directories}",
                        ],
                        expand_if_available =
                            "runtime_library_search_directories",
                    ),
                ],
            ),
        ]
    )

    default_link_libraries_feature = feature(
        name = "default_link_libraries",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{linkstamp_paths}"],
                        iterate_over = "linkstamp_paths",
                        expand_if_available = "linkstamp_paths",
                    ),
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                flags = ["-Wl,--start-lib"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                            flag_group(
                                flags = ["-Wl,-whole-archive"],
                                expand_if_true =
                                    "libraries_to_link.is_whole_archive",
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.object_files}"],
                                iterate_over = "libraries_to_link.object_files",
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "interface_library",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-l%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "dynamic_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-l:%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "versioned_dynamic_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-Wl,-no-whole-archive"],
                                expand_if_true = "libraries_to_link.is_whole_archive",
                            ),
                            flag_group(
                                flags = ["-Wl,--end-lib"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                        ],
                        expand_if_available = "libraries_to_link",
                    ),
                    # Note that the params file comes at the end, after the
                    # libraries to link above.
                    flag_group(
                        expand_if_available = "linker_param_file",
                        flags = ["@%{linker_param_file}"],
                    ),
                ],
            ),
        ],
    )

    sysroot_feature = feature(
        name = "sysroot",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["--sysroot=%{sysroot}"],
                        expand_if_available = "sysroot",
                    ),
                ],
            ),
        ],
    )

    final_flags_feature = feature(
        name = "final_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{user_compile_flags}"],
                        iterate_over = "user_compile_flags",
                        expand_if_available = "user_compile_flags",
                    ),
                    flag_group(
                        flags = ["%{source_file}"],
                        expand_if_available = "source_file",
                    ),
                    flag_group(
                        expand_if_available = "output_file",
                        flags = ["-o", "%{output_file}"],
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{user_link_flags}"],
                        iterate_over = "user_link_flags",
                        expand_if_available = "user_link_flags",
                    ),
                    flag_group(
                        flags = ["-o", "%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                ],
            ),
        ],
    )

    default_archiver_flags_feature = feature(
        name = "default_archiver_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(flags = ["rcsD"]),
                    flag_group(
                        flags = ["%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.object_files}"],
                                iterate_over = "libraries_to_link.object_files",
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                        ],
                        expand_if_available = "libraries_to_link",
                    ),
                    flag_group(
                        expand_if_available = "linker_param_file",
                        flags = ["@%{linker_param_file}"],
                    ),
                ],
            ),
        ],
    )

    features = [
        feature(name = "dbg"),
        feature(name = "fastbuild"),
        feature(name = "host"),
        feature(name = "no_legacy_features"),
        feature(name = "nonhost"),
        feature(name = "opt"),
        feature(name = "supports_dynamic_linker", enabled = ctx.attr.target_cpu == "k8"),
        feature(name = "supports_pic", enabled = True),
        feature(name = "supports_start_end_lib", enabled = ctx.attr.target_cpu == "k8"),
    ]

    features += [
        default_flags_feature,
        #minimal_optimization_flags,
        #default_optimization_flags,
        #minimal_debug_info_flags,
        #default_debug_info_flags,
        #preserve_call_stacks,
        sysroot_feature,
        #sanitizer_common_flags,
        #asan,
        #enable_asan_in_fastbuild,
        #fuzzer,
        #layering_check,
        #module_maps,
        #use_module_maps,
        default_archiver_flags_feature,
    ]

    features += [
        default_link_libraries_feature,
        final_flags_feature,
    ]

    sysroot = None

    include_dirs = []
    include_dirs.append(get_tool_path(ctx, compiler, "include/c++/v1"))
    include_dirs.append(get_tool_path(ctx, compiler, "lib/clang/17/include"))
    include_dirs.append(get_tool_path(ctx, compiler, "include/x86_64-unknown-linux-gnu"))
    # FIXME: completely seal the toolchain
    include_dirs.append("/usr/include")

    print(include_dirs)

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        action_configs = action_configs,
        cxx_builtin_include_directories = include_dirs,
        builtin_sysroot = sysroot,

        # This configuration only supports local non-cross builds so derive
        # everything from the target CPU selected.
        toolchain_identifier = "local-" + ctx.attr.target_cpu,
        host_system_name = "local-" + ctx.attr.target_cpu,
        target_system_name = "local-" + ctx.attr.target_cpu,
        target_cpu = ctx.attr.target_cpu,

        # These attributes aren't meaningful at all so just use placeholder
        # values.
        target_libc = "local",
        compiler = "local",
        abi_version = "local",
        abi_libc_version = "local",

        # We do have to pass in our tool paths.
        tool_paths = tool_paths,
    )

