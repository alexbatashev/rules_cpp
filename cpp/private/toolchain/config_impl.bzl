"""
Implementation of C++ toolchain
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "with_feature_set",
)
load("//cpp:providers.bzl", "BinutilsInfo", "CompilerInfo", "LinkerInfo", "StdlibInfo")
load(
    "//cpp/private:extra_actions.bzl",
    "EXTRA_ACTIONS",
    "all_c_compile_actions",
    "all_compile_actions",
    "all_cpp_compile_actions",
    "all_link_actions",
)
load(
    "//cpp/private/toolchain:unix_toolchain_features.bzl",
    "cpp20_feature",
    "darwin_default_feature",
    "default_archiver_flags_feature",
    "default_debug_info_flags",
    "default_link_libraries_feature",
    "default_optimization_flags",
    "extra_warnings_flags",
    "final_flags_feature",
    "get_cpu_flags",
    "get_default_flags",
    "minimal_debug_info_flags",
    "minimal_optimization_flags",
    "openmp_feature",
    "pic_feature",
    "preserve_call_stacks",
    "sysroot_feature",
    "werror_flags",
)

def _get_include_paths(stdlib, compiler):
    include_dirs = []
    stdlib_base = stdlib.headers[0].owner.workspace_root + "/"
    compiler_base = compiler.binary.dirname + "/../"
    for inc in stdlib.includes:
        include_dirs.append(stdlib_base + inc)

    if compiler.kind == "clang":
        include_dirs.append(
            compiler_base + "lib/clang/17/include",
        )

    return include_dirs

def _get_stdlib_prefix(stdlib, target_os, target_cpu):
    stdlib_base = stdlib.headers[0].owner.workspace_root + "/lib"

    if stdlib.kind == "libc++":
        if target_os == "linux":
            if target_cpu == "x86_64":
                stdlib_base += "/x86_64-unknown-linux-gnu"
            elif target_cpu == "aarch64":
                stdlib_base += "/aarch64-unknown-linux-gnu"
            elif target_cpu == "riscv64":
                stdlib_base += "/riscv64-unknown-linux-gnu"

    return stdlib_base

def _get_link_paths(stdlib, compiler, target_os, target_cpu):
    compiler_base = compiler.binary.dirname + "/../"

    link_dirs = [_get_stdlib_prefix(stdlib, target_os, target_cpu)]

    if link_dirs[0] != compiler_base + "lib":
        link_dirs.append(compiler_base + "lib")

    return link_dirs

def _get_exec_rpath_prefix(ctx):
    if ctx.attr.target_os in ["linux"]:
        return "$EXECROOT/"
    elif ctx.attr.target_os in ["macos"]:
        return "@loader_path/../../../"
    return None

def _get_rpath_prefix(ctx):
    if ctx.attr.target_os in ["linux"]:
        return "$ORIGIN/"
    elif ctx.attr.target_os in ["macos"]:
        return "@loader_path/"
    return None

def _get_target_triple(target_cpu, target_os):
    if target_cpu == "x86_64" and target_os == "linux":
        return "x86_64-linux-gnu"
    elif target_cpu == "x86_64" and target_os == "macos":
        return "x86_64-apple-darwin"
    elif target_cpu == "aarch64" and target_os == "linux":
        return "aarch64-linux-gnu"
    elif target_cpu == "aarch64" and target_os == "macos":
        return "aarch64-apple-darwin"

    return "unknown-unknown-unknown"

def _get_clang_features(ctx):
    triple_feature = feature(
        name = "default_triple",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [flag_group(flags = [
                    "--target=" + _get_target_triple(ctx.attr.target_cpu, ctx.attr.target_os),
                ])],
            ),
        ],
    )

    weverything_feature = feature(
        name = "weverything",
        provides = ["extra_warnings"],
        requires = [feature_set(features = ["clang"])],
        flag_sets = [flag_set(
            actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
            flag_groups = [flag_group(flags = ["-Weverything"])],
        )],
    )

    module_interface_precompile_feature = feature(
        name = "module_interface_precompile",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(
                        flags = ["-x", "c++-module"],
                    ),
                ],
            ),
        ],
    )

    use_modules = feature(
        name = "c++20_modules",
        flag_sets = [
            flag_set(
                actions = all_cpp_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(flags = ["-fno-implicit-modules"]),
                    flag_group(
                        iterate_over = "cpp_precompiled_modules",
                        expand_if_available = "cpp_precompiled_modules",
                        flags = ["-fmodule-file=%{cpp_precompiled_modules}"],
                    ),
                ],
            ),
            flag_set(
                actions = [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(
                        flags = ["--precompile"],
                    ),
                ],
            ),
        ],
    )

    lld_feature = feature(
        name = "use_lld",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-fuse-ld=lld"],
                    ),
                ],
            ),
        ],
    )

    return [
        triple_feature,
        weverything_feature,
        module_interface_precompile_feature,
        lld_feature,
        use_modules,
    ]

def _get_action_configs(compiler, binutils):
    return [
        action_config(action_name = name, enabled = True, tools = [struct(type_name = "tool", tool = compiler.binary)])
        for name in all_c_compile_actions + all_cpp_compile_actions + all_link_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface]
    ] + [
        action_config(action_name = name, enabled = True, tools = [struct(type_name = "tool", tool = binutils.ar)])
        for name in [ACTION_NAMES.cpp_link_static_library]
    ] + [
        action_config(action_name = name, enabled = True, tools = [struct(type_name = "tool", tool = binutils.strip)])
        for name in [ACTION_NAMES.strip]
    ]

def _get_default_features(ctx, compiler, include_dirs, link_dirs):
    features = [
        feature(name = "clang", enabled = compiler.kind == "clang"),
        feature(name = "gcc", enabled = compiler.kind == "gcc"),
        feature(name = "dbg"),
        feature(name = "fastbuild"),
        feature(name = "host"),
        feature(name = "no_legacy_features"),
        feature(name = "nonhost"),
        feature(name = "opt"),
        feature(name = "supports_dynamic_linker", enabled = ctx.attr.target_cpu in ["x86_64"]),
        feature(name = "supports_pic", enabled = True),
        feature(name = "supports_start_end_lib", enabled = ctx.attr.target_cpu in ["x86_64"]),
        feature(name = "static_stdlib", enabled = True),
    ]

    default_flags_feature = get_default_flags(include_dirs, link_dirs, _get_exec_rpath_prefix(ctx), _get_rpath_prefix(ctx))

    features += [
        default_flags_feature,
        minimal_optimization_flags,
        default_optimization_flags,
        minimal_debug_info_flags,
        default_debug_info_flags,
        pic_feature,
        preserve_call_stacks,
        sysroot_feature,
        extra_warnings_flags,
        werror_flags,
        cpp20_feature,
        openmp_feature,
        default_archiver_flags_feature,
    ]

    features += get_cpu_flags(ctx.attr.target_cpu)

    return features

def _get_final_features():
    return [
        default_link_libraries_feature,
        final_flags_feature,
    ]

def bazel_toolchain_impl(ctx):
    """
    C++ toolchain for builtin Bazel rules

    Args:
        ctx: rule context

    Returns:
        C++ toolchain configuration
    """

    compiler = ctx.attr.compiler[CompilerInfo]

    # FIXME propagate linker flags
    # linker = ctx.attr.linker[LinkerInfo]
    binutils = ctx.attr.binutils[BinutilsInfo]
    stdlib = ctx.attr.stdlib[StdlibInfo]

    include_dirs = _get_include_paths(stdlib, compiler)
    link_dirs = _get_link_paths(stdlib, compiler, ctx.attr.target_os, ctx.attr.target_cpu)

    action_configs = _get_action_configs(compiler, binutils)

    features = _get_default_features(ctx, compiler, include_dirs, link_dirs)
    if compiler.kind == "clang":
        features += _get_clang_features(ctx)

    if ctx.attr.target_os in ["macos"]:
        features.append(darwin_default_feature)

    stdlib_base = _get_stdlib_prefix(stdlib, ctx.attr.target_os, ctx.attr.target_cpu)

    static_libcpp_flags = [
        "-lc",
        "-Wno-unused-command-line-argument",
        stdlib_base + "/libc++abi.a",
        stdlib_base + "/libc++.a",
        stdlib_base + "/libunwind.a",
        "-static-libgcc",
    ]

    dynamic_libcpp_flags = [
        "-Wl,-rpath,$EXECROOT/" + stdlib_base,
        "-lc",
        "-lc++abi",
        "-lc++",
        "-lunwind",
    ]

    libcpp_feature = feature(
        name = "libc++",
        enabled = stdlib.kind == "libc++",
        flag_sets = [
            flag_set(
                actions = all_compile_actions + [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [flag_group(flags = ["-nostdinc++", "-D_LIBCPP_ENABLE_EXPERIMENTAL"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["-nostdlib++"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = static_libcpp_flags)],
                with_features = [with_feature_set(features = ["static_stdlib"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = dynamic_libcpp_flags)],
                with_features = [with_feature_set(not_features = ["static_stdlib"])],
            ),
        ],
    )

    features.append(libcpp_feature)

    features += _get_final_features()

    sysroot = None

    # FIXME: completely seal the toolchain?
    include_dirs.append("/usr/include/")
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
        cc_target_os = ctx.attr.target_os,
        compiler = "clang",
        tool_paths = [],

        # These attributes aren't meaningful at all so just use placeholder
        # values.
        target_libc = "local",
        abi_version = "local",
        abi_libc_version = "local",
    )
