load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "tool",
    "tool_path",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("//cpp/private:utils.bzl", "is_clang", "is_libcpp", "is_lld", "is_llvm")

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

def _get_tool_path(target, path):
    return path
    # TODO: figure out how to use this
    # return target.label.workspace_root + "/" + path

def _get_compiler(target, tool):
    if is_clang(target):
        if tool == "cpp":
            return _get_tool_path(target, "bin/clang-cpp")
        elif tool == "c++":
            return _get_tool_path(target, "bin/clang++")
        elif tool == "gcc":
            return _get_tool_path(target, "bin/clang")
    return _get_tool_path(target, "bin/" + tool)

def _get_linker(target):
    if is_lld(target):
        return _get_tool_path(target, "bin/ld.lld")
    return _get_tool_path(target, "bin/ld")

def _get_tool(target, tool):
    if tool == "ld":
        return _get_linker(target)

    if tool == "cpp" or tool == "c++" or tool == "gcc":
        return _get_compiler(target, tool)

    if tool == "gcov":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-cov")
        return _get_tool_path(target, "bin/gcov")

    if tool == "nm":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-nm")
        return _get_tool_path(target, "bin/nm")

    if tool == "objcopy":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-objcopy")
        return _get_tool_path(target, "bin/objcopy")

    if tool == "objdump":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-objdump")
        return _get_tool_path(target, "bin/objdump")

    if tool == "strip":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-strip")
        return _get_tool_path(target, "bin/strip")

    if tool == "ar":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-ar")
        return _get_tool_path(target, "bin/ar")

    if tool == "dwp":
        if is_llvm(target):
            return _get_tool_path(target, "bin/llvm-dwp")
        return _get_tool_path(target, "bin/dwp")

    return "unkown_tool_" + tool

def _get_include_paths(stdlib, compiler):
    include_dirs = []
    stdlib_base = stdlib.label.workspace_root + "/"
    compiler_base = compiler.label.workspace_root + "/"
    if is_libcpp(stdlib):
        include_dirs += [
            stdlib_base + "include/c++/v1",
            stdlib_base + "include/x86_64-unknown-linux-gnu",
            stdlib_base + "include/x86_64-unknown-linux-gnu/c++/v1",
        ]

    if is_clang(compiler):
        include_dirs += [
            compiler_base + "lib/clang/17/include",
        ]

    return include_dirs

def _get_linker_flag(linker):
    if is_lld(linker):
        return ["-fuse-ld=lld"]
    return []

def _get_link_paths(stdlib, compiler):
    stdlib_base = stdlib.label.workspace_root + "/"
    compiler_base = compiler.label.workspace_root + "/"

    link_dirs = [stdlib_base + "lib"]

    if link_dirs[0] != compiler_base + "lib":
        link_dirs.append(compiler_base + "lib")

    return link_dirs

def _get_exec_rpath_prefix(ctx):
    if ctx.attr.target_cpu in ["aarch64", "k8"]:
        return "$EXECROOT/"
    elif ctx.attr.target_cpu in ["darwin", "darwin_arm64"]:
        return "@loader_path/../../../"
    return None

def _get_rpath_prefix(ctx):
    if ctx.attr.target_cpu in ["aarch64", "k8"]:
        return "$ORIGIN/"
    elif ctx.attr.target_cpu in ["darwin", "darwin_arm64"]:
        return "@loader_path/"
    return None

def _get_target_triple(target_cpu):
    if target_cpu == "k8":
        return "x86_64-linux-gnu"
    elif target_cpu == "darwin":
        return "x86_64-apple-darwin"
    elif target_cpu == "aarch64":
        return "aarch64-linux-gnu"
    elif target_cpu == "darwin_arm64":
        return "aarch64-apple-darwin"

    return "unknown-unknown-unknown"

def toolchain_impl(ctx):
    compiler = ctx.attr.compiler
    binutils = ctx.attr.binutils
    linker = ctx.attr.linker
    stdlib = ctx.attr.stdlib

    include_dirs = _get_include_paths(stdlib, compiler)
    link_dirs = _get_link_paths(stdlib, compiler)

    tool_paths = [
        tool_path(name = "ar", path = _get_tool(binutils, "ar")),
        tool_path(name = "ld", path = _get_tool(linker, "ld")),
        tool_path(name = "cpp", path = _get_tool(compiler, "cpp")),
        tool_path(name = "gcc", path = _get_tool(compiler, "gcc")),
        tool_path(name = "dwp", path = _get_tool(binutils, "dwp")),
        tool_path(name = "gcov", path = _get_tool(binutils, "gcov")),
        tool_path(name = "nm", path = _get_tool(binutils, "nm")),
        tool_path(name = "objcopy", path = _get_tool(binutils, "objcopy")),
        tool_path(name = "objdump", path = _get_tool(binutils, "objdump")),
        tool_path(name = "strip", path = _get_tool(binutils, "strip")),
    ]

    action_configs = [
        action_config(action_name = name, enabled = True, tools = [tool(path = _get_tool(compiler, "gcc"))])
        for name in all_c_compile_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = _get_tool(compiler, "c++"))])
        for name in all_cpp_compile_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = _get_tool(compiler, "c++"))])
        for name in all_link_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = _get_tool(binutils, "ar"))])
        for name in [ACTION_NAMES.cpp_link_static_library]
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = _get_tool(binutils, "strip"))])
        for name in [ACTION_NAMES.strip]
    ]

    std_compile_flags = ["-std=c++17"]

    if is_libcpp(stdlib):
        std_compile_flags.append("-stdlib=libc++")
    else:
        std_compile_flags.append("-stdlib=libstdc++")

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
                        flags = ["-isystem" + x for x in include_dirs] + [
                            "--system-header-prefix=external/",
                            "-no-canonical-prefixes",
                            # TODO enable this option for GCC
                            # "-fno-canonical-system-headers",
                            "-isystem",
                            "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk/usr/include",
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
                        flags = _get_linker_flag(linker),
                    ),
                    flag_group(
                        flags = ["-Wl,-nostdlib"],
                    ),
                    flag_group(
                        flags = ["-L" + d for d in link_dirs],
                    ),
                    flag_group(
                        flags = ["-Wl,-rpath," + _get_exec_rpath_prefix(ctx) + d for d in link_dirs],
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
                        flags = ["-L%{library_search_directories}"],
                        iterate_over = "library_search_directories",
                        expand_if_available = "library_search_directories",
                    ),
                    flag_group(
                        iterate_over = "runtime_library_search_directories",
                        flags = [
                            "-Wl,-rpath," + _get_rpath_prefix(ctx) + "%{runtime_library_search_directories}",
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

    module_maps_flags = []

    if is_clang(compiler):
        module_maps_flags = ["-fmodules"]

    module_maps = feature(
        name = "module_maps",
        implies = [],
        requires = [feature_set(features = ["clang"])],
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(flags = module_maps_flags),
                ],
            ),
        ],
    )

    layering_check = feature(
        name = "layering_check",
        implies = ["use_module_maps"],
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(flags = [
                        "-fmodules-strict-decluse",
                        "-Wprivate-header",
                    ] if is_clang(compiler) else []),
                    flag_group(
                        iterate_over = "dependent_module_map_files",
                        flags = [
                            "-fmodule-map-file=%{dependent_module_map_files}",
                        ] if is_clang(compiler) else [],
                    ),
                ],
            ),
        ],
    )

    triple_feature = feature(
        name = "default_triple",
        enabled = is_clang(compiler),
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions,
                flag_groups = [flag_group(flags = [
                    "--target=" + _get_target_triple(ctx.attr.target_cpu),
                ])],
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

    weverything_flags = feature(
        name = "weverything",
        provides = ["extra_warnings"],
        requires = [feature_set(features = ["clang"])],
        flag_sets = [flag_set(
            actions = all_compile_actions,
            flag_groups = [flag_group(flags = ["-Weverything"])],
        )],
    )

    werror_flags = feature(
        name = "werror",
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
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

    use_module_maps = feature(
        name = "use_module_maps",
        requires = [feature_set(features = ["module_maps"])],
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(flags = ["-fmodule-name=%{module_name}"]),
                    flag_group(
                        flags = ["-fmodule-map-file=%{module_map_file}"],
                    ),
                ],
            ),
        ],
    )

    static_stdlib_flags = []
    if is_clang(compiler):
        static_stdlib_flags = [
            "-lc",
            "-Wno-unused-command-line-argument",
            "-static-libstdc++",
            "-l:libc++abi.a",
            "-l:libc++.a",
            "-l:libunwind.a",
            "-static-libgcc",
        ]

    static_stdlib_feature = feature(
        name = "static_stdlib",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = static_stdlib_flags)],
            ),
        ],
    )

    # FIXME(alexbatashev): figure out how to use the default feature so that we don't need a custom one
    static_link_cpp_runtimes_feature = feature(
        name = "static_link_cpp_runtimes",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = static_stdlib_flags)],
            ),
        ],
    )

    cpp20_feature = feature(
        name = "c++20",
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
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
                actions = all_compile_actions + all_link_actions,
                flag_groups = [
                    flag_group(flags = ["-fopenmp"]),
                ],
            ),
        ],
    )

    mavx_flag = feature(
        name = "avx",
        enabled = ctx.attr.target_cpu == "k8" or ctx.attr.target_cpu == "darwin",
        flag_sets = [flag_set(
            actions = all_compile_actions,
            flag_groups = [flag_group(flags = ["-mavx"])],
        )],
    )

    mavx2_flag = feature(
        name = "avx2",
        enabled = ctx.attr.target_cpu == "k8" or ctx.attr.target_cpu == "darwin",
        flag_sets = [flag_set(
            actions = all_compile_actions,
            flag_groups = [flag_group(flags = ["-mavx2"])],
        )],
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
        feature(name = "clang", enabled = is_clang(compiler)),
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
        minimal_optimization_flags,
        default_optimization_flags,
        minimal_debug_info_flags,
        default_debug_info_flags,
        triple_feature,
        preserve_call_stacks,
        sysroot_feature,
        extra_warnings_flags,
        werror_flags,
        static_stdlib_feature,
        static_link_cpp_runtimes_feature,
        cpp20_feature,
        openmp_feature,
        mavx_flag,
        mavx2_flag,
        layering_check,
        module_maps,
        use_module_maps,
        default_archiver_flags_feature,
    ]

    if ctx.attr.target_cpu in ["darwin", "darwin_arm64"]:
        features.append(darwin_default_feature)

    features += [
        default_link_libraries_feature,
        final_flags_feature,
    ]

    sysroot = None

    # FIXME: completely seal the toolchain?
    include_dirs.append("/usr/include")
    include_dirs.append("/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk/usr/include")

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        action_configs = action_configs,
        cxx_builtin_include_directories = include_dirs,
        builtin_sysroot = sysroot,
        toolchain_identifier = ctx.attr.toolchain_prefix + "-" + ctx.attr.target_cpu,
        host_system_name = ctx.attr.toolchain_prefix + "-" + ctx.attr.host_cpu,
        target_system_name = ctx.attr.toolchain_prefix + "-" + ctx.attr.target_cpu,
        target_cpu = ctx.attr.target_cpu,

        # These attributes aren't meaningful at all so just use placeholder
        # values.
        target_libc = "local",
        compiler = "local",
        abi_version = "local",
        abi_libc_version = "local",
        tool_paths = tool_paths,
    )
