#!/bin/sh

set -eu

bazel build //...
bazel aquery //... | grep "CppCompile"
bazel aquery //... | grep "CppLink"
