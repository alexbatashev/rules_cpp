load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_llvm_x64_linux = {
    "17.0.6": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/llvmorg-17.0.6-31a6a2ac5144effba2c8bd42950c994ba54230ae/llvmorg-17.0.6-linux-x86_64.tar.zst",
        ],
        "strip_prefix": "llvmorg-17.0.6-linux-x86_64",
        "sha256": "a9f735bf262c2fd4805e3f66ee58ed5a7725978da7294d6654809a964f92ac82",
    },
}

_llvm_x64_darwin = {
    "17.0.6": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/llvmorg-17.0.6-31a6a2ac5144effba2c8bd42950c994ba54230ae/llvmorg-17.0.6-macos-x86_64.tar.zst",
        ],
        "strip_prefix": "llvmorg-17.0.6-macos-x86_64",
        "sha256": "f1d43ad89e6bcd5afe9cdbdd34e66f3301cccd00e82d3ae722092e1e04486902",
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
    elif mctx.os.name == "mac os x" and mctx.os.arch == "x86_64":
        clang_repo = _llvm_x64_darwin

    http_archive(
        name = repo_name,
        urls = clang_repo[version]["urls"],
        strip_prefix = clang_repo[version]["strip_prefix"],
        sha256 = clang_repo[version]["sha256"],
        build_file = "//cpp/private:llvm.BUILD",
    )

def _tools_impl(rctx):
    rctx.symlink(Label("//cpp/private:tools_rules.bzl"), "tools_rules.bzl")
    build = rctx.read(Label("//cpp/private:tools.BUILD"))
    rctx.file("WORKSPACE", executable = False)
    rctx.file("BUILD", content = build)

_tools = repository_rule(
    implementation = _tools_impl,
    configure = True,
)

def setup_tools(mctx, repo_name):
    _tools(
        name = repo_name,
    )
