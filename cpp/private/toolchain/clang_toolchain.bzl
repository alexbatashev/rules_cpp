"""
This file contains utilities to declare standard hermetic Clang toolchains
"""

load("//cpp/private/toolchain:cpp_toolchain_config_rule.bzl", "cpp_toolchain_config")

def declare_clang_toolchains(name, compiler, linker, stdlib, binutils):
    """Declare toolchains and cross-toolchains for host platform

    Args:
        name: a name prefix for the toolchain
        compiler: a Clang compiler instance
        linker: a generic linker that Clang can invoke
        stdlib: a target providing standard C++ library
        binutils: a target providing standard binutil tools, like ar or objcopy
    """
    native.filegroup(
        name = name + "-files",
        srcs = [
            compiler,
            linker,
            stdlib,
            binutils,
        ],
    )

    PLATFORMS = [
        struct(
            os = "@platforms//os:linux",
            target_cpu = "@platforms//cpu:x86_64",
        ),
        struct(
            os = "@platforms//os:linux",
            target_cpu = "@platforms//cpu:aarch64",
        ),
        struct(
            os = "@platforms//os:linux",
            target_cpu = "@platforms//cpu:armv7",
        ),
        struct(
            os = "@platforms//os:linux",
            target_cpu = "@platforms//cpu:riscv32",
        ),
        struct(
            os = "@platforms//os:linux",
            target_cpu = "@platforms//cpu:riscv64",
        ),
        struct(
            os = "@platforms//os:macos",
            target_cpu = "@platforms//cpu:aarch64",
        ),
        struct(
            os = "@platforms//os:macos",
            target_cpu = "@platforms//cpu:x86_64",
        ),
    ]

    for p in PLATFORMS:
        cpu = Label(p.target_cpu).name
        os = Label(p.os).name
        prefix = "{name}-{os}-{cpu}".format(name = name, os = os, cpu = cpu)

        cpp_toolchain_config(
            name = prefix + "-config",
            toolchain_prefix = name,
            compiler = compiler,
            linker = linker,
            stdlib = stdlib,
            binutils = binutils,
            target_cpu = cpu,
            host_cpu = cpu,
            target_os = os,
        )

        native.cc_toolchain(
            name = prefix + "-toolchain",
            all_files = ":" + name + "-files",
            ar_files = binutils,
            as_files = binutils,
            compiler_files = ":" + name + "-files",
            dwp_files = binutils,
            linker_files = ":" + name + "-files",
            objcopy_files = binutils,
            strip_files = binutils,
            static_runtime_lib = stdlib,
            supports_param_files = 1,
            toolchain_config = ":" + prefix + "-config",
            toolchain_identifier = prefix + "-toolchain",
        )

        native.toolchain(
            name = prefix,
            target_compatible_with = [
                p.os,
                p.target_cpu,
            ],
            toolchain = ":" + prefix + "-toolchain",
            toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        )
