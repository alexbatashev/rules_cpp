#!/bin/sh

set -eu

bazel build //...
bazel run //:test

bazel run --crosstool_top=@llvm-17//:toolchain //:test
bazel run --crosstool_top=@llvm-17//:toolchain -c dbg //:test
bazel run --crosstool_top=@llvm-17//:toolchain -c opt //:test
bazel run --crosstool_top=@llvm-17//:toolchain --features=extra_warnings --features=werror //:test
bazel run --crosstool_top=@llvm-17//:toolchain --features=c++20 //:test
bazel run --crosstool_top=@llvm-17//:toolchain --features=static_stdlib //:test