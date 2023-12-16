load("//cpp/private:target_rules.bzl", "header_map_impl", "shlib_impl")
load("//cpp/private:toolchain.bzl", "toolchain_impl")

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
    "header_map": attr.label(),
    "includes": attr.string_list(),
    "lib_prefix": attr.string(mandatory = True),
    "lib_suffix": attr.string(mandatory = True),
    "_compiler": attr.label(
        default = "@bazel_tools//tools/cpp:toolchain",
        providers = [cc_common.CcToolchainInfo],
    ),
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
    },
)

_cpp_shared_library = rule(
    implementation = shlib_impl,
    attrs = _shlib_attrs,
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
        header_map = name + ".headers",
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
