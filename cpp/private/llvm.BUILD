load("@rules_cpp//cpp:rules.bzl", "cpp_toolchain")

filegroup(
  name = "clang",
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

filegroup(
  name = "openmp",
  srcs = glob([
    "lib/*omp*",
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "lld",
  srcs = [
    "bin/lld",
    "bin/ld.lld"
  ],
  visibility = ["//visibility:public"],
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

cpp_toolchain(
  name = "toolchain",
  compiler = ":clang",
  linker = ":lld",
  stdlib = ":libc++",
  static_stdlib = ":static_libc++",
  binutils = ":binutils",
  target_cpus = [
    "k8",
    "aarch64",
    "darwin_arm64",
    "darwin_x86_64",
    "darwin",
  ]
)