load("//cpp:repositories.bzl", "download_toolchain")

def _init_toolchain(_ctx):
  download_toolchain()

cpp = module_extension(
  implementation = _init_toolchain
)