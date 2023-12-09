# Toolchain features

Bazel allows enabling additional features with `--features=feature-name` flag
on the CLI. Below is the documenation for all non-standard features supported
by these toolchains.

## Control warnings

- `extra_warnings` - enables extra compiler warnings. In particular for Unix-like targets:
   - `-Wall`
   - `-Wextra`
   - `-Wshadow`
   - `-Wnon-virtual-dtor`
   - `-Wold-style-cast`
   - `-Wcast-align`
   - `-Wunused`
   - `-Woverloaded-virtual`
   - `-Wpedantic`
   - `-Wconversion`
   - `-Wsign-conversion`
   - `-Wmisleading-indentation`
   - `-Wdouble-promotion`
   - `-Wformat=2`
- `weverything` - adds `-Weverything` flag, only available for Clang.
- `werror` - emit errors on warnings.

## Control debug info

- `preserve_call_stacks` - add flags to preserve call stack information. Useful for profiling.
- `minimal_debug_info_flags` - emit minimal debug information.

## Control standard library

- `static_stdlib` - force static linkage of C++ runtime.
- `c++20` - enable C++20 support.

## Parallel computation

- `openmp` - enable OpenMP support.