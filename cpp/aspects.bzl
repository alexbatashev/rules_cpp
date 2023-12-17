load("@rules_cpp//cpp/private:common.bzl", "create_compilation_context", "generate_header_names", "get_compile_command_args")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

CompileCommandsInfo = provider(
    fields = {
        "target": "target that consumes these sources",
        "sources": "a list of sources with compile arguments",
    },
)

def _compile_commands_aspect_impl(target, ctx):
    headers = []

    if hasattr(ctx.attr, "hdrs"):
        headers = generate_header_names(ctx.attr.name, ctx.actions, ctx.bin_dir.path, ctx.attr.hdrs, ctx.attr.strip_include_prefix, ctx.attr.include_prefix)
    comp_ctx = create_compilation_context(ctx, headers, True)

    toolchain = ctx.rule.attr._cc_toolchain[cc_common.CcToolchainInfo]

    features = cc_common.configure_features(ctx = ctx, cc_toolchain = toolchain, requested_features = ctx.features + ["pic", "supports_pic"], unsupported_features = ctx.disabled_features)

    sources = []
    for src in comp_ctx.sources:
        args = get_compile_command_args(
            toolchain,
            source = src.path,
            features = features,
            include_directories = depset(comp_ctx.includes),
        )

        sources.append(struct(
            source = src,
            args = args,
            compiler = toolchain.compiler_executable,
        ))

    return CompileCommandsInfo(target = target, sources = sources)

compile_commands_aspect = aspect(
    implementation = _compile_commands_aspect_impl,
    attr_aspects = ["deps"],
    provides = [CompileCommandsInfo],
    fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
)
