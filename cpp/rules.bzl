load("//cpp/private:toolchain.bzl", "toolchain_impl")

_toolchain_attrs = {
    "compiler": attr.label(),
    "linker": attr.label(),
    "target_cpu": attr.string(mandatory = True),
}

cpp_toolchain_config = rule(
    implementation = toolchain_impl,
    attrs = _toolchain_attrs,
    provides = [CcToolchainConfigInfo],
)

def cpp_toolchain(name, compiler, linker, stdlib):
    cpp_toolchain_config(
        name = name + "-config",
        compiler = compiler,
        linker = linker,
        target_cpu = "k8",
    )

    native.filegroup(
        name = name + "-files",
        srcs = [
            compiler,
            linker,
            stdlib,
        ]
    )


    native.cc_toolchain(
        name = name + "-toolchain",
        all_files = name + "-files",
        ar_files = name + "-files",
        as_files = name + "-files",
        compiler_files = name + "-files",
        dwp_files = name + "-files",
        linker_files = name + "-files",
        objcopy_files = name + "-files",
        strip_files = name + "-files",
        supports_param_files = 1,
        toolchain_config = ":" + name + "-config",
        toolchain_identifier = name + "-toolchain",
    )

    native.cc_toolchain_suite(
        name = name,
        toolchains = {
            "k8": name + "-toolchain",
        },
    )