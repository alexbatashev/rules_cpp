#!/bin/sh

set -eu

bazel build //...
bazel run //:test