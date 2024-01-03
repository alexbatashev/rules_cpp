load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "variable_with_value",
    "with_feature_set",
)
load(
    "//cpp/private:extra_actions.bzl",
    "EXTRA_ACTIONS",
    "all_c_compile_actions",
    "all_compile_actions",
    "all_cpp_compile_actions",
    "all_link_actions",
    "codegen_compile_actions",
    "preprocessor_compile_actions",
)

def get_default_flags(include_dirs, link_dirs, exec_rpath_prefix, rpath_prefix):
    return feature(
        name = "default_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_cpp_compile_actions + all_link_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = ([
                    flag_group(
                        flags = ["-std=c++17"],
                    ),
                ]),
            ),
            flag_set(
                actions = all_c_compile_actions + [
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ] + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(
                        flags = ["-isystem" + x for x in include_dirs] + [
                            "--system-header-prefix=external/",
                            "-no-canonical-prefixes",
                            # TODO enable this option for GCC
                            # "-fno-canonical-system-headers",
                            "-isystem",
                            "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk/usr/include",
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = ([
                    flag_group(
                        # Compile actions shouldn't link anything.
                        flags = ["-c"],
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
                actions = preprocessor_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=\"redacted\"",
                            "-D__TIMESTAMP__=\"redacted\"",
                            "-D__TIME__=\"redacted\"",
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
                        flags = ["-nodefaultlibs"],
                    ),
                    flag_group(
                        flags = ["-Wl,-L" + d for d in link_dirs],
                    ),
                    flag_group(
                        flags = ["-Wl,-rpath," + exec_rpath_prefix + d for d in link_dirs],
                    ),
                    flag_group(
                        flags = ["-Wl,--gdb-index"],
                        expand_if_available = "is_using_fission",
                    ),
                    flag_group(
                        flags = ["-Wl,-S"],
                        expand_if_available = "strip_debug_symbols",
                    ),
                    flag_group(
                        flags = ["-Wl,-L%{library_search_directories}"],
                        iterate_over = "library_search_directories",
                        expand_if_available = "library_search_directories",
                    ),
                    flag_group(
                        iterate_over = "runtime_library_search_directories",
                        flags = [
                            "-Wl,-rpath," + rpath_prefix + "%{runtime_library_search_directories}",
                        ],
                        expand_if_available =
                            "runtime_library_search_directories",
                    ),
                ],
            ),
        ],
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

darwin_default_feature = feature(
    name = "darwin_default_libraries",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = all_compile_actions,
            flag_groups = (
                [
                    flag_group(
                        flags = [
                            "-isystem",
                            "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk/usr/include",
                        ],
                    ),
                ]
            ),
        ),
        flag_set(
            actions = all_link_actions,
            flag_groups = [
                flag_group(
                    flags = [
                        "-L",
                        "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk/usr/lib",
                    ],
                ),
            ],
        ),
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_executable,
            ],
            flag_groups = [
                flag_group(
                    flags = ["-fpie"],
                    expand_if_available = "force_pic",
                ),
            ],
        ),
    ],
)

minimal_optimization_flags = feature(
    name = "minimal_optimization_flags",
    flag_sets = [
        flag_set(
            actions = codegen_compile_actions,
            flag_groups = [flag_group(flags = [
                "-O1",
            ])],
        ),
    ],
)

default_optimization_flags = feature(
    name = "default_optimization_flags",
    enabled = True,
    requires = [feature_set(["opt"])],
    flag_sets = [
        flag_set(
            actions = all_compile_actions,
            flag_groups = [flag_group(flags = [
                "-DNDEBUG",
            ])],
        ),
        flag_set(
            actions = codegen_compile_actions,
            flag_groups = [flag_group(flags = [
                "-O2",
            ])],
        ),
    ],
)

pic_feature = feature(
    name = "pic",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [
                ACTION_NAMES.assemble,
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
                ACTION_NAMES.c_compile,
                ACTION_NAMES.cpp_compile,
                ACTION_NAMES.cpp_module_codegen,
                ACTION_NAMES.cpp_module_compile,
            ],
            flag_groups = [
                flag_group(flags = ["-fPIC"], expand_if_available = "pic"),
            ],
        ),
    ],
)

extra_warnings_flags = feature(
    name = "extra_warnings",
    flag_sets = [flag_set(
        actions = all_compile_actions,
        # Do not forget to update docs!
        flag_groups = [flag_group(flags = [
            "-Wall",
            "-Wextra",
            "-Wshadow",
            "-Wnon-virtual-dtor",
            "-Wold-style-cast",
            "-Wcast-align",
            "-Wunused",
            "-Woverloaded-virtual",
            "-Wpedantic",
            "-Wconversion",
            "-Wsign-conversion",
            "-Wmisleading-indentation",
            "-Wdouble-promotion",
            "-Wformat=2",
        ])],
    )],
)

werror_flags = feature(
    name = "werror",
    flag_sets = [
        flag_set(
            actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [flag_group(flags = [
                "-Werror",
            ])],
        ),
    ],
)

minimal_debug_info_flags = feature(
    name = "minimal_debug_info_flags",
    flag_sets = [
        flag_set(
            actions = codegen_compile_actions,
            flag_groups = [
                flag_group(
                    flags = ["-gmlt"],
                ),
            ],
        ),
    ],
)

default_debug_info_flags = feature(
    name = "default_debug_info_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = codegen_compile_actions,
            flag_groups = ([
                flag_group(
                    flags = ["-g"],
                ),
            ]),
            with_features = [with_feature_set(features = ["dbg"])],
        ),
        flag_set(
            actions = codegen_compile_actions,
            flag_groups = [
                flag_group(
                    flags = ["-gsplit-dwarf", "-g"],
                    expand_if_available = "per_object_debug_info_file",
                ),
            ],
        ),
    ],
)

preserve_call_stacks = feature(
    name = "preserve_call_stacks",
    flag_sets = [flag_set(
        actions = codegen_compile_actions,
        flag_groups = [flag_group(flags = [
            "-fno-omit-frame-pointer",
            "-mno-omit-leaf-frame-pointer",
            "-fno-optimize-sibling-calls",
        ])],
    )],
)

cpp20_feature = feature(
    name = "c++20",
    implies = ["c++20_modules"],
    flag_sets = [
        flag_set(
            actions = all_cpp_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [
                flag_group(
                    flags = ["-std=c++20"],
                ),
            ],
        ),
    ],
)

openmp_feature = feature(
    name = "openmp",
    flag_sets = [
        flag_set(
            actions = all_compile_actions + all_link_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [
                flag_group(flags = ["-fopenmp"]),
            ],
        ),
    ],
)

def get_cpu_flags(target_cpu):
    mavx_flag = feature(
        name = "avx",
        enabled = target_cpu in ["k8", "darwin"],
        flag_sets = [flag_set(
            actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [flag_group(flags = ["-mavx"])],
        )],
    )

    mavx2_flag = feature(
        name = "avx2",
        enabled = target_cpu in ["k8", "darwin"],
        flag_sets = [flag_set(
            actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [flag_group(flags = ["-mavx2"])],
        )],
    )

    return [mavx_flag, mavx2_flag]

sysroot_feature = feature(
    name = "sysroot",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = all_compile_actions + all_link_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
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
            actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
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
