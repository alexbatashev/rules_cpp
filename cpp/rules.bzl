load("//cpp/private:toolchain.bzl", "toolchain_impl")

_toolchain_attrs = {
    "binutils": attr.label(),
    "compiler": attr.label(),
    "linker": attr.label(),
    "stdlib": attr.label(),
    "target_cpu": attr.string(mandatory = True),
}

cpp_toolchain_config = rule(
    implementation = toolchain_impl,
    attrs = _toolchain_attrs,
    provides = [CcToolchainConfigInfo],
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
        ]
    )

    toolchains = {}

    for cpu in target_cpus:
        cpp_toolchain_config(
            name = name + "-" + cpu + "-config",
            compiler = compiler,
            linker = linker,
            stdlib = stdlib,
            binutils = binutils,
            target_cpu = cpu,
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