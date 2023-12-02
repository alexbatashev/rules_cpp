#!/bin/sh

set -eu

bazel build //...
bazel run //:test

bazel run --crosstool_top=@clang//:toolchain //:test
bazel run --crosstool_top=@clang//:toolchain -c dbg //:test
bazel run --crosstool_top=@clang//:toolchain -c opt //:test
bazel run --crosstool_top=@clang//:toolchain --features=extra_warnings --features=werror //:test
bazel run --crosstool_top=@clang//:toolchain --features=c++20 //:test
bazel run --crosstool_top=@clang//:toolchain --features=static_link_cpp_runtimes //:test