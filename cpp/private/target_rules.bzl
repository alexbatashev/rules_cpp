"""
Contains rules implementations for building C++ targets
"""

load("@rules_cpp//cpp/private:common.bzl", "get_compile_command_args", "resolve_linker_arguments")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def shlib_impl(ctx):
    """
    Implements C++ rules for building shared libraries

    Return a list of providers

    Args:
        ctx: rule context

    Returns:
        A tuple of providers
    """

    toolchain = ctx.attr._compiler[cc_common.CcToolchainInfo]
    
    features = cc_common.configure_features(ctx=ctx, cc_toolchain=toolchain, requested_features=ctx.features, unsupported_features=ctx.disabled_features)

    obj_files = []

    for src in ctx.files.srcs:
        outfile = ctx.actions.declare_file("_objs/" + src.basename + ".o")
        args = get_compile_command_args(src, outfile, toolchain, features)
        obj_files.append(outfile)

        ctx.actions.run(
            outputs = [outfile],
            inputs = ctx.files.srcs,
            executable = toolchain.compiler_executable,
            arguments = args,
            mnemonic = "CppCompile",
            progress_message = "Compiling %{output}"
        )

    shlib = ctx.actions.declare_file("lib" + ctx.attr.name + ".so")
    link_flags, lib_inputs = resolve_linker_arguments(ctx, toolchain, features, shlib.path, True)

    for obj in obj_files:
        link_flags.append(obj.path)

    ctx.actions.run(
        outputs = [shlib],
        inputs = obj_files + lib_inputs.to_list(),
        executable = toolchain.compiler_executable,
        arguments = link_flags,
        mnemonic = "CppLink",
            progress_message = "Compiling %{output}"
    )

    default_provider = DefaultInfo(files = depset([shlib]))
    
    compilation_ctx = cc_common.create_compilation_context()
    lib_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = features,
        cc_toolchain = toolchain,
        dynamic_library = shlib,
    )
    linker_input = cc_common.create_linker_input(
        owner = Label(ctx.attr.name),
        libraries = depset([lib_to_link]),
    )
    linking_ctx = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )

    cc_info = CcInfo(compilation_context = compilation_ctx, linking_context = linking_ctx)

    return default_provider, cc_info