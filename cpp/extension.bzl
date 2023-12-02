load("//cpp:repositories.bzl", "download_llvm")

def _init_toolchain(ctx):
  for mod in ctx.modules:
    for llvm in mod.tags.llvm:
        download_llvm(ctx, llvm.name, llvm.version)

_llvm = tag_class(
  attrs = {
    "name": attr.string(),
    "version": attr.string(),
  }
)

cpp = module_extension(
  implementation = _init_toolchain,
  tag_classes = {"llvm": _llvm},
)