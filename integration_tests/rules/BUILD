load("@rules_cpp//cpp:rules.bzl", "cpp_shared_library")

cc_library(
    name = "bar",
    srcs = [
        "src/bar.cpp",
        "src/bar.h",
    ],
    hdrs = ["src/bar.h"],
    include_prefix = "bar",
    strip_include_prefix = "src",
)

cpp_shared_library(
    name = "foo",
    srcs = ["src/foo.cpp"],
    hdrs = ["src/foo.hpp"],
    include_prefix = "foo",
    strip_include_prefix = "src",
    deps = [":bar"],
)

cc_binary(
    name = "main",
    srcs = ["src/main.cpp"],
    deps = [":foo"],
)
