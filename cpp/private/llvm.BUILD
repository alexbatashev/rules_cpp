load("@rules_cpp//cpp:rules.bzl", "declare_clang_toolchains")
load("@rules_cpp//cpp/private:tool.bzl", "tool")

filegroup(
  name = "clang-files",
  srcs = glob([
    "bin/clang*",
    "lib/clang/**/*",
    "lib/*LTO*",
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "binutils",
  srcs = glob([
    "bin/llvm-objcopy*",
    "bin/llvm-dwp*",
    "bin/llvm-cov*",
    "bin/llvm-strip*",
    "bin/llvm-nm*",
    "bin/llvm-ar*",
    "bin/llvm-strings*",
  ]),
  visibility = ["//visibility:public"],
)

tool(
  name = "strip",
  executable = "bin/llvm-strip",
)

tool(
  name = "ar",
  executable = "bin/llvm-ar",
)

filegroup(
  name = "openmp",
  srcs = glob([
    "lib/*omp*",
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "lld-files",
  srcs = [
    "bin/lld",
    "bin/ld.lld"
  ],
  visibility = ["//visibility:public"],
)

tool(
  name = "lld",
  executable = "bin/lld",
  visibility = ["//visibility:public"],
  data = [":lld-files"]
)

filegroup(
  name = "libc++",
  srcs = glob([
    "include/c++/**/*",
    "include/x86_64-unknown-linux-gnu/**/*",
    "lib/*c++*",
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "static_libc++",
  srcs = glob([
    "lib/**/libc++.a",
    "lib/**/libc++abi.a",
    "lib/**/libunwind.a",
  ]),
  visibility = ["//visibility:public"],
)

tool(
  name = "clang",
  executable = "bin/clang",
  data = [
    ":clang-files",
    ":binutils",
    ":lld",
    ":openmp",
    ":lld",
    ":libc++",
    ":static_libc++",
  ]
  visibility = ["//visibility:public"],
)

declare_clang_toolchains(
  name = "toolchain",
  compiler = ":clang",
  linker = ":lld",
  stdlib = ":libc++",
  static_stdlib = ":static_libc++",
  binutils = ":binutils",
  strip = ":strip",
  archiver = ":ar",
)