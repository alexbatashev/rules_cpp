load("@rules_cpp//cpp:rules.bzl", "cpp_shared_library")

cc_library(
    name = "bar",
    srcs = ["src/bar.cpp"],
)

cpp_shared_library(
    name = "foo",
    srcs = ["src/foo.cpp"],
    deps = [":bar"],
)
