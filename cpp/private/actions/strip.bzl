"""
Utility subrules for making compiled binaries smaller
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _cpp_strip_objects_impl(ctx, inputs, feature_config, toolchain):
    outputs = []

    if not cc_common.is_enabled(feature_configuration = feature_config, feature_name = "opt"):
        return inputs

    strip = cc_common.get_tool_for_action(
        feature_configuration = feature_config,
        action_name = ACTION_NAMES.strip,
    )

    for obj in inputs:
        outfile = ctx.actions.declare_file(obj.path.replace("_objs", "_stripped"))

        args = ctx.actions.args()
        args.add("-o", outfile)
        args.add(obj)

        ctx.actions.run(
            outputs = [outfile],
            inputs = depset([obj], transitive = toolchain.all_files),
            executable = strip,
            arguments = [args],
            mnemonic = "CppStripObject",
            progress_message = "Stripping %{output}",
        )

        outputs.append(outfile)

    return outputs

def _cpp_strip_binary_impl(ctx, input, output, feature_config, toolchain):
    args = ctx.actions.args()
    args.add("-s")
    args.add("-o", output)
    args.add(input)

    strip = cc_common.get_tool_for_action(
        feature_configuration = feature_config,
        action_name = ACTION_NAMES.strip,
    )

    ctx.actions.run(
        outputs = [output],
        inputs = depset([input], transitive = toolchain.all_files),
        executable = strip,
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
