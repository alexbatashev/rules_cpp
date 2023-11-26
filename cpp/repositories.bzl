load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive"
)


def download_toolchain():
  http_archive(
    name = "clang",
    urls = [
      "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.5/clang+llvm-17.0.5-arm64-apple-darwin22.0.tar.xz"
    ],
    strip_prefix = "clang+llvm-17.0.5-arm64-apple-darwin22.0",
    build_file = "//cpp/private:clang.BUILD",
  )