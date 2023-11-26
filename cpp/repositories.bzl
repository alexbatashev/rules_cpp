load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive"
)

_clang_x64_linux = {
  "17.0.5": {
    "urls": [
      "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.5/clang+llvm-17.0.5-x86_64-linux-gnu-ubuntu-22.04.tar.xz"
    ],
    "strip_prefix": "clang+llvm-17.0.5-x86_64-linux-gnu-ubuntu-22.04",
    "sha256": "5a3cedecd8e2e8663e84bec2f8e5522b8ea097f4a8b32637386f27ac1ca01818"
  }
}

_clang_aarch64_darwin = {
  "17.0.5": {
    "urls": [
      "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.5/clang+llvm-17.0.5-arm64-apple-darwin22.0.tar.xz"
    ],
    "strip_prefix": "clang+llvm-17.0.5-arm64-apple-darwin22.0",
    "sha256": "",
  }
}

def download_clang(mctx, repo_name, version):
  clang_repo = {}
  if mctx.os.name == "linux" and mctx.os.arch == "amd64":
    clang_repo = _clang_x64_linux
  elif mctx.os.name == "darwin" and mctx.os.arch == "aarch64":
    clang_repo = _clang_aarch64_darwin

  http_archive(
    name = repo_name,
    urls = clang_repo[version]["urls"],
    strip_prefix = clang_repo[version]["strip_prefix"],
    sha256 = clang_repo[version]["sha256"],
    build_file = "//cpp/private:clang.BUILD",
  )