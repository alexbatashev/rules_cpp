filegroup(
  name = "clang",
  srcs = glob([
    "bin/llvm-objcopy*",
    "bin/llvm-strip*",
    "bin/llvm-nm*",
    "bin/llvm-ar*",
    "bin/llvm-strings*",
    "bin/clang*",
    "lib/clang/**/*",
    "lib/*LTO*",
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
  srcs = glob([
    "bin/lld",
    "bin/ld.lld"
  ]),
  visibility = ["//visibility:public"],
)

filegroup(
  name = "libcpp",
  srcs = glob([
    "include/c++/**/*",
    "lib/*c++*",
  ]),
  visibility = ["//visibility:public"],
)