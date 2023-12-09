# rules_cpp
Bazel rules for C++ development

## Getting started

### Using as a module

Add the following to your `MODULE.bazel`:

```
bazel_dep(name = "rules_cpp", version = "0.0.0")
git_override(
    module_name = "rules_cpp",
    remote = "https://github.com/alexbatashev/rules_cpp",
)
```

### Setting up a toolchain

Add the following to `MODULE.bazel`:

```
cpp = use_extension("@rules_cpp//cpp:extension.bzl", "cpp")
cpp.llvm(
  name = "llvm-17",
  version = "17.0.6",
)
use_repo(cpp, "llvm-17")
```

Then use it with the command line:

```sh
bazel build --crosstool_top=@llvm-17//:toolchain //...
```