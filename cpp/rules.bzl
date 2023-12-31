load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")
load("//cpp:aspects.bzl", "CompileCommandsInfo", "compile_commands_aspect")
load("//cpp:providers.bzl", "CppModuleInfo")
load("//cpp/private:target_rules.bzl", "binary_impl", "module_impl", "shlib_impl")
load("//cpp/private/actions:compile.bzl", "cpp_compile")
load("//cpp/private/actions:strip.bzl", "cpp_strip_binary", "cpp_strip_objects")
load("//cpp/private/toolchain:clang_toolchain.bzl", _declare_clang_toolchains = "declare_clang_toolchains")
load("//cpp/private/toolchain:cpp_toolchain_config_rule.bzl", _cpp_toolchain_config = "cpp_toolchain_config")
load(
    "//cpp/private/toolchain:rules.bzl",
    _binutils = "binutils",
    _compiler = "compiler",
    _linker = "linker",
    _stdlib = "standard_library",
)

_shlib_attrs = {
    "srcs": attr.label_list(allow_files = True),
    "hdrs": attr.label_list(allow_files = True),
    "deps": attr.label_list(providers = [CcInfo]),
    "strip_include_prefix": attr.string(),
    "include_prefix": attr.string(),
    "includes": attr.string_list(),
    "lib_prefix": attr.string(mandatory = True),
    "lib_suffix": attr.string(mandatory = True),
    "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    "_unused_headers": attr.label(
        default = "//cpp/tools:unused_headers",
        executable = True,
        cfg = "exec",
    ),
}

_bin_attrs = {
    "srcs": attr.label_list(allow_files = True),
    "deps": attr.label_list(providers = [[CcInfo], [CppModuleInfo]]),
    "includes": attr.string_list(),
    "bin_suffix": attr.string(mandatory = True),
    "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
}

_module_attrs = {
    "srcs": attr.label_list(allow_files = True),
    "deps": attr.label_list(providers = [[CcInfo], [CppModuleInfo]]),
    "partitions": attr.label_list(providers = [[CppModuleInfo]]),
    "module_name": attr.string(mandatory = True),
    "interface": attr.label(allow_files = True, mandatory = True),
    "includes": attr.string_list(),
    "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
}

_cpp_shared_library = rule(
    implementation = shlib_impl,
    attrs = _shlib_attrs,
    toolchains = use_cpp_toolchain(),
    fragments = ["cpp"],
    provides = [DefaultInfo, CcInfo],
    subrules = [cpp_compile, cpp_strip_objects, cpp_strip_binary],
)

_cpp_binary = rule(
    implementation = binary_impl,
    attrs = _bin_attrs,
    toolchains = use_cpp_toolchain(),
    fragments = ["cpp"],
    provides = [DefaultInfo],
    subrules = [
        cpp_compile,
        cpp_strip_objects,
        cpp_strip_binary,
    ],
    executable = True,
)

_cpp_test = rule(
    implementation = binary_impl,
    attrs = _bin_attrs,
    toolchains = use_cpp_toolchain(),
    fragments = ["cpp"],
    provides = [DefaultInfo],
    subrules = [
        cpp_compile,
        cpp_strip_objects,
        cpp_strip_binary,
    ],
    test = True,
)

compiler = _compiler
standard_library = _stdlib
binutils = _binutils
linker = _linker
cpp_toolchain_config = _cpp_toolchain_config
declare_clang_toolchains = _declare_clang_toolchains

def cpp_shared_library(name, srcs = [], hdrs = [], deps = [], strip_include_prefix = "", include_prefix = "", **kwargs):
    _cpp_shared_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        strip_include_prefix = strip_include_prefix,
        include_prefix = include_prefix,
        lib_prefix = select({
            "@bazel_tools//src/conditions:windows": "",
            "//conditions:default": "lib",
        }),
        lib_suffix = select({
            "@bazel_tools//src/conditions:windows": ".dll",
            "@bazel_tools//src/conditions:darwin": ".dylib",
            "//conditions:default": ".so",
        }),
        **kwargs
    )

def cpp_binary(name, **kwargs):
    _cpp_binary(
        name = name,
        bin_suffix = select({
            "@bazel_tools//src/conditions:windows": ".exe",
            "//conditions:default": "",
        }),
        **kwargs
    )

def cpp_test(name, **kwargs):
    _cpp_test(
        name = name,
        bin_suffix = select({
            "@bazel_tools//src/conditions:windows": ".exe",
            "//conditions:default": "",
        }),
        **kwargs
    )

def _collect_cpp_files_impl(ctx):
    sources = []
    for dep in ctx.attr.deps:
        local_sources = []
        for src in dep[CompileCommandsInfo].sources:
            local_sources.append(src.source)
        sources.append(depset(local_sources))

    content = ""
    for src in depset(transitive = sources).to_list():
        content += src.path + "\n"

    lst = ctx.actions.declare_file("sources.list")
    ctx.actions.write(output = lst, content = content)

    return DefaultInfo(files = depset([lst]))

collect_cpp_files = rule(
    implementation = _collect_cpp_files_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [compile_commands_aspect],
            providers = [CcInfo],
        ),
    },
)

cpp_module = rule(
    implementation = module_impl,
    attrs = _module_attrs,
    toolchains = use_cpp_toolchain(),
    fragments = ["cpp"],
    provides = [CppModuleInfo],
    subrules = [cpp_compile, cpp_strip_objects],
)

def clang_format(name, deps):
    supported_targets = [
        "cc_binary",
        "cc_library",
        "cc_test",
        "cpp_shared_library",
    ]

    resolved_deps = deps

    if len(deps) == 0:
        # FIXME(alexbatashev): this rule is very brittle.
        # Need to find another way to resolve the issue
        for rule_name, rule in native.existing_rules().items():
            if rule["kind"] in supported_targets:
                resolved_deps.append(rule_name)

    collect_cpp_files(
        name = name + ".sources",
        deps = resolved_deps,
    )

    native.py_binary(
        name = name,
        srcs = ["@rules_cpp//cpp/tools:run_clang_format.py"],
        main = "run_clang_format.py",
        args = [
            "$(location :" + name + ".sources)",
        ],
        data = [":" + name + ".sources"],
    )
