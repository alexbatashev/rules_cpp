#!/bin/sh

set -eu

bazel aquery //... | grep "CppCompile"
bazel aquery //... | grep "CppLink"
