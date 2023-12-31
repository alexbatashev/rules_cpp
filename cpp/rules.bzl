load("//cpp/private:target_rules.bzl", "header_map_impl", "shlib_impl", "module_impl")
load("//cpp/private:toolchain.bzl", "toolchain_impl")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")
load("//cpp:aspects.bzl", "CompileCommandsInfo", "compile_commands_aspect")

CppModuleInfo = provider(
    fields = {
        "module_name": "name of the exported module",
        "pcm": "file containing precompiled module",
    }
)

_toolchain_attrs = {
    "toolchain_prefix": attr.string(mandatory = True),
    "binutils": attr.label(),
    "compiler": attr.label(),
    "linker": attr.label(),
    "stdlib": attr.label(),
    "target_cpu": attr.string(mandatory = True),
    "host_cpu": attr.string(mandatory = True),
}

_shlib_attrs = {
    "srcs": attr.label_list(allow_files = True),
    "hdrs": attr.label_list(allow_files = True),
    "deps": attr.label_list(providers = [CcInfo]),
    "strip_include_prefix": attr.string(),
    "include_prefix": attr.string(),
    "headers_db": attr.label(),
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

_module_attrs = {
    "srcs": attr.label_list(allow_files = True),
    "deps": attr.label_list(prividers = [[CcInfo], [CppModuleInfo]]),
    "interface": attr.label(allow_files = True),
    "includes": attr.string_list(),
    "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
}

cpp_toolchain_config = rule(
    implementation = toolchain_impl,
    attrs = _toolchain_attrs,
    provides = [CcToolchainConfigInfo],
)

_cpp_header_map = rule(
    implementation = header_map_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "hdrs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [CcInfo]),
        "strip_include_prefix": attr.string(),
        "include_prefix": attr.string(),
        "_headers_database": attr.label(
            default = "//cpp/tools:headers_database",
            executable = True,
            cfg = "exec",
        ),
    },
)

_cpp_shared_library = rule(
    implementation = shlib_impl,
    attrs = _shlib_attrs,
    toolchains = use_cpp_toolchain(),
    fragments = ["cpp"],
    provides = [DefaultInfo, CcInfo],
)

def cpp_shared_library(name, srcs = [], hdrs = [], deps = [], strip_include_prefix = "", include_prefix = "", **kwargs):
    _cpp_header_map(
        name = name + ".headers",
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        strip_include_prefix = strip_include_prefix,
        include_prefix = include_prefix,
    )
    _cpp_shared_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        strip_include_prefix = strip_include_prefix,
        include_prefix = include_prefix,
        headers_db = name + ".headers",
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

def cpp_toolchain(name, compiler, linker, stdlib, static_stdlib, binutils, target_cpus):
    native.filegroup(
        name = name + "-files",
        srcs = [
            compiler,
            linker,
            stdlib,
            static_stdlib,
            binutils,
        ],
    )

    toolchains = {}

    for cpu in target_cpus:
        cpp_toolchain_config(
            name = name + "-" + cpu + "-config",
            toolchain_prefix = name,
            compiler = compiler,
            linker = linker,
            stdlib = stdlib,
            binutils = binutils,
            target_cpu = cpu,
            host_cpu = cpu,
        )

        native.cc_toolchain(
            name = name + "-" + cpu + "-toolchain",
            all_files = name + "-files",
            ar_files = name + "-files",
            as_files = name + "-files",
            compiler_files = name + "-files",
            dwp_files = name + "-files",
            linker_files = name + "-files",
            objcopy_files = name + "-files",
            strip_files = name + "-files",
            static_runtime_lib = static_stdlib,
            supports_param_files = 1,
            toolchain_config = ":" + name + "-" + cpu + "-config",
            toolchain_identifier = name + "-" + cpu + "-toolchain",
        )

        toolchains[cpu] = name + "-" + cpu + "-toolchain"

    native.cc_toolchain_suite(
        name = name,
        toolchains = toolchains,
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
    provides = [CppModuleInfo],
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
