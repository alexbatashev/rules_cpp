load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_llvm_x64_linux = {
    "17.0.6": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/llvmorg-17.0.6-7bda1fa2055d2e0bced545433ffcc78f52d57315/llvmorg-17.0.6-linux-x86_64.tar.zst",
        ],
        "strip_prefix": "llvmorg-17.0.6-linux-x86_64",
        "sha256": "ec482ae8e4b2e96bfd350792dd74d97f9f0fdc559935255e8d5e597e5c79be1f",
    },
}

_llvm_aarch64_darwin = {
    "17.0.6": {
        "urls": [
            "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/clang+llvm-17.0.6-arm64-apple-darwin22.0.tar.xz",
        ],
        "strip_prefix": "clang+llvm-17.0.6-arm64-apple-darwin22.0",
        "sha256": "1264eb3c2a4a6d5e9354c3e5dc5cb6c6481e678f6456f36d2e0e566e9400fcad",
    },
}

def download_llvm(mctx, repo_name, version):
    clang_repo = {}
    if mctx.os.name == "linux" and mctx.os.arch == "amd64":
        clang_repo = _llvm_x64_linux
    elif mctx.os.name == "mac os x" and mctx.os.arch == "aarch64":
        clang_repo = _llvm_aarch64_darwin

    http_archive(
        name = repo_name,
        urls = clang_repo[version]["urls"],
        strip_prefix = clang_repo[version]["strip_prefix"],
        sha256 = clang_repo[version]["sha256"],
        build_file = "//cpp/private:llvm.BUILD",
    )
