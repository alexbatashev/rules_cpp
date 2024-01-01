"""
Compile input C++ files into object files
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("//cpp/private:common.bzl", "get_compile_command_args")
load("//cpp/private:extra_actions.bzl", "EXTRA_ACTIONS")

def _cpp_compile_impl(ctx, sources, headers, includes, modules, features, toolchain, module_srcs = []):
    obj_files = []

    extra_vars = {
        "cpp_precompiled_modules": [],
    }

    module_files = []
    module_vars = []

    for m in modules:
        module_files.append(m["file"])
        module_files.append(m["source"])
        module_vars.append("{name}={file}".format(name = m["name"], file = m["file"].path))

    extra_vars["cpp_precompiled_modules"] = module_vars

    for src in sources:
        action_name = ACTION_NAMES.cpp_compile
        if src.extension in ["pcm"]:
            action_name = EXTRA_ACTIONS.cpp_module_compile
        compiler = cc_common.get_tool_for_action(
            feature_configuration = features,
            action_name = action_name,
        )

        outfile = ctx.actions.declare_file("_objs/" ctx.label.name + "/" + src.basename + ".o")
        args = get_compile_command_args(
            toolchain,
            source = src.path,
            output = outfile.path,
            features = features,
            include_directories = includes,
            extra_vars = extra_vars,
        )

        ctx.actions.run(
            outputs = [outfile],
            inputs = depset([src], transitive = [depset(headers), depset(module_files), toolchain.all_files, depset(module_srcs)]),
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
