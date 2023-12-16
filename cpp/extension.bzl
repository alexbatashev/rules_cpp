load("//cpp:repositories.bzl", "download_llvm", "setup_tools")

def _init_toolchain(ctx):
    for mod in ctx.modules:
        for llvm in mod.tags.llvm:
            download_llvm(ctx, llvm.name, llvm.version)
        for tools in mod.tags.tools:
            setup_tools(ctx, tools.name)

_llvm = tag_class(
    attrs = {
        "name": attr.string(),
        "version": attr.string(),
    },
)

_tools = tag_class(
    attrs = {
        "name": attr.string(),
    },
)

cpp = module_extension(
    implementation = _init_toolchain,
    tag_classes = {"llvm": _llvm, "tools": _tools},
)
