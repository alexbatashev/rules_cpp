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
    "tool",
    "tool_path",
)
load(
    "//cpp/private:extra_actions.bzl",
    "EXTRA_ACTIONS",
    "all_c_compile_actions",
    "all_compile_actions",
    "all_cpp_compile_actions",
    "all_link_actions",
)
load(
    "//cpp/private:unix_toolchain_features.bzl",
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
load("//cpp/private:utils.bzl", "is_clang", "is_libcpp", "is_lld", "is_llvm")

def _get_tool_path(_target, path):
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
    elif target_cpu == "darwin" or target_cpu == "darwin_x64_64":
        return "x86_64-apple-darwin"
    elif target_cpu == "aarch64":
        return "aarch64-linux-gnu"
    elif target_cpu == "darwin_arm64":
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
                    "--target=" + _get_target_triple(ctx.attr.target_cpu),
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

    module_interface_precompile_feature = feature(
        name = "module_interface_precompile",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [EXTRA_ACTIONS.cpp_module_precompile_interface],
                flag_groups = [
                    flag_group(
                        flags = ["-x", "c++-module", "%{cpp_module_interface_file}"],
                        expand_if_available = "cpp_module_interface_file",
                    ),
                ],
            ),
        ],
    )

    return [
        triple_feature,
        weverything_feature,
        static_stdlib_feature,
        static_link_cpp_runtimes_feature,
        module_interface_precompile_feature,
    ]

def _get_tools(compiler, binutils, linker, stdlib):
    return [
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

def _get_action_configs(compiler, binutils, _linker):
    return [
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

def _get_default_features(ctx, compiler, std_compile_flags, include_dirs, link_dirs):
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

    default_flags_feature = get_default_flags(std_compile_flags, include_dirs, link_dirs, _get_exec_rpath_prefix(ctx), _get_rpath_prefix(ctx))

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
    """

    compiler = ctx.attr.compiler
    binutils = ctx.attr.binutils
    linker = ctx.attr.linker
    stdlib = ctx.attr.stdlib

    include_dirs = _get_include_paths(stdlib, compiler)
    link_dirs = _get_link_paths(stdlib, compiler)

    tool_paths = _get_tools(compiler, binutils, linker, stdlib)

    action_configs = _get_action_configs(compiler, binutils, linker)

    std_compile_flags = ["-std=c++17"]

    if is_libcpp(stdlib):
        std_compile_flags.append("-stdlib=libc++")
    else:
        std_compile_flags.append("-stdlib=libstdc++")

    features = _get_default_features(ctx, compiler, std_compile_flags, include_dirs, link_dirs)
    if is_clang(compiler):
        features += _get_clang_features()

    if ctx.attr.target_cpu in ["darwin", "darwin_arm64"]:
        features.append(darwin_default_feature)

    features += _get_final_features()

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
