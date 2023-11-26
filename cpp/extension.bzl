load("//cpp:repositories.bzl", "download_clang")

def _init_toolchain(ctx):
  for mod in ctx.modules:
    for compiler in mod.tags.compiler:
      if compiler.kind == "clang":
        download_clang(ctx, compiler.name, compiler.version)

_compiler = tag_class(
  attrs = {
    "name": attr.string(),
    "kind": attr.string(),
    "version": attr.string(),
  }
)

cpp = module_extension(
  implementation = _init_toolchain,
  tag_classes = {"compiler": _compiler},
)