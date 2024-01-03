"""Utilities for downloading LLVM toolchains"""

load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)
load("//cpp/private/llvm:releases_aarch64_darwin.bzl", "llvm_aarch64_darwin")
load("//cpp/private/llvm:releases_x64_darwin.bzl", "llvm_x64_darwin")
load("//cpp/private/llvm:releases_x64_linux.bzl", "llvm_x64_linux")

def download_llvm(mctx, repo_name, version):
    """Download entire LLVM toolchain

    Args:
        mctx: module context
        repo_name: name of the repository that'll be made available to the user
        version: either main or a supporter released LLVM version
    """

    clang_repo = {}
    if mctx.os.name == "linux" and mctx.os.arch == "amd64":
        clang_repo = llvm_x64_linux
    elif mctx.os.name == "mac os x" and mctx.os.arch == "aarch64":
        clang_repo = llvm_aarch64_darwin
    elif mctx.os.name == "mac os x" and mctx.os.arch == "x86_64":
        clang_repo = llvm_x64_darwin

    http_archive(
        name = repo_name,
        urls = clang_repo[version]["urls"],
        strip_prefix = clang_repo[version]["strip_prefix"],
        sha256 = clang_repo[version]["sha256"],
        build_file = "//cpp/private:llvm.BUILD",
    )
