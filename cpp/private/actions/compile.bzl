"""
Compile input C++ files into object files
"""

load("//cpp/private:common.bzl", "get_compile_command_args")

def _cpp_compile_impl(ctx, sources, headers, includes, features, toolchain):
    obj_files = []

    for src in sources:
        outfile = ctx.actions.declare_file("_objs/" + src.basename + ".o")
        args = get_compile_command_args(
            toolchain,
            source = src.path,
            output = outfile.path,
            features = features,
            include_directories = includes,
        )

        ctx.actions.run(
            outputs = [outfile],
            inputs = [src] + headers,
            executable = toolchain.compiler_executable,
            arguments = args,
            mnemonic = "CppCompile",
            progress_message = "Compiling %{output}",
        )

        obj_files.append(outfile)

    return obj_files

cpp_compile = subrule(
    implementation = _cpp_compile_impl,
)
