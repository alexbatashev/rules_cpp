"""
This file defines C++ toolchain configuration rule
"""

load("//cpp/private/toolchain:config_impl.bzl", "bazel_toolchain_impl")

_toolchain_attrs = {
    "toolchain_prefix": attr.string(mandatory = True),
    "compiler": attr.label(mandatory = True),
    "linker": attr.label(mandatory = True),
    "binutils": attr.label(mandatory = True),
    "stdlib": attr.label(mandatory = True),
    "target_cpu": attr.string(mandatory = True),
    "target_os": attr.string(mandatory = True),
    "host_cpu": attr.string(mandatory = True),
}

cpp_toolchain_config = rule(
    implementation = bazel_toolchain_impl,
    attrs = _toolchain_attrs,
    provides = [CcToolchainConfigInfo],
)
