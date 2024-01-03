load("@rules_cpp//cpp:rules.bzl", 
  "declare_clang_toolchains",
  "compiler",
  "standard_library",
  "binutils",
  "linker",
)

filegroup(
  name = "openmp",
  srcs = glob([
    "lib/*omp*",
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "clang-files",
  srcs = glob([
    "bin/clang*",
    "lib/clang/**/*",
    "lib/*LTO*",
    "lib/libclang*",
    "lib/libLLVM*",
  ]),
)

compiler(
  name = "clang",
  kind = "clang",
  binary = "bin/clang",
  deps = [":clang-files", ":openmp"]
)

binutils(
  name = "binutils",
  ar = "bin/llvm-ar",
  assembler = "bin/clang",
  objcopy = "bin/llvm-objcopy",
  strip = "bin/llvm-strip",
  dwp = "bin/llvm-dwp",
  deps = glob([
    "bin/llvm-*",
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

linker(
  name = "lld",
  kind = "lld",
  binary = "bin/ld.lld",
  deps = [":lld-files"],
  visibility = ["//visibility:public"],
)

standard_library(
  name = "libc++",
  kind = "libc++",
  headers = glob([
    "include/c++/**/*",
    "include/x86_64-unknown-linux-gnu/**/*",
  ]),
  shared_libraries = glob([
    "lib/**/*c++*.so",
    "lib/**/*c++*.dylib",
  ]),
  static_libraries = glob([
    "lib/**/libc++.a",
    "lib/**/libc++abi.a",
    "lib/**/libunwind.a",
  ]),
  includes = [
      "include/c++/v1",
      "include/x86_64-unknown-linux-gnu/c++/v1",
  ]
)

declare_clang_toolchains(
  name = "toolchain",
  compiler = ":clang",
  linker = ":lld",
  stdlib = ":libc++",
  binutils = ":binutils",
)