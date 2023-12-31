"""
Compile input C++ files into object files
"""

load("//cpp/private:common.bzl", "get_compile_command_args")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _cpp_compile_impl(ctx, sources, headers, includes, modules, features, toolchain):
    obj_files = []

    compiler = cc_common.get_tool_for_action(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_compile,
    )

    extra_vars = {}

    if modules != None and len(modules) != 0:
        extra_vars = {
            "cpp_precompiled_modules": modules,
        }

    module_files = []

    for m in modules:
        module_files.append(m.file)

    for src in sources:
        outfile = ctx.actions.declare_file("_objs/" + src.basename + ".o")
        args = get_compile_command_args(
            toolchain,
            source = src.path,
            output = outfile.path,
            features = features,
            include_directories = includes,
            # extra_vars = extra_vars,
        )

        ctx.actions.run(
            outputs = [outfile],
            inputs = depset([src], transitive = [depset(headers), depset(module_files), toolchain.all_files]),
            executable = compiler,
            arguments = args,
            mnemonic = "CppCompile",
            progress_message = "Compiling %{output}",
        )

        obj_files.append(outfile)

    return obj_files

cpp_compile = subrule(
    implementation = _cpp_compile_impl,
)
