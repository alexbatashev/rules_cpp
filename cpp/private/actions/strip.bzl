"""
Utility subrules for making compiled binaries smaller
"""

def _cpp_strip_objects_impl(ctx, inputs, feature_config, toolchain):
    outputs = []

    if not cc_common.is_enabled(feature_configuration = feature_config, feature_name = "opt"):
        return inputs

    for obj in inputs:
        outfile = ctx.actions.declare_file(obj.path.replace("_objs", "_stripped"))

        args = ctx.actions.args()
        args.add("-o", outfile)
        args.add(obj)

        ctx.actions.run(
            outputs = [outfile],
            inputs = [obj],
            executable = toolchain.strip_executable,
            arguments = [args],
            mnemonic = "CppStripObject",
            progress_message = "Stripping %{output}",
        )

        outputs.append(outfile)

    return outputs

def _cpp_strip_binary_impl(ctx, input, output, toolchain):
    args = ctx.actions.args()
    args.add("-s")
    args.add("-o", output)
    args.add(input)

    ctx.actions.run(
        outputs = [output],
        inputs = [input],
        executable = toolchain.strip_executable,
        arguments = [args],
        mnemonic = "CppStripBinary",
        progress_message = "Stripping %{output}",
    )

cpp_strip_objects = subrule(
    implementation = _cpp_strip_objects_impl,
)

cpp_strip_binary = subrule(
    implementation = _cpp_strip_binary_impl,
)
