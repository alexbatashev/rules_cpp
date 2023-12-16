"""
Contains rules implementations for building C++ targets
"""

load("@rules_cpp//cpp/private:common.bzl", "get_compile_command_args", "resolve_includes", "resolve_linker_arguments")

HeadersInfo = provider(
    fields = {
        "headers": "a depset of all header files",
        "includes": "a depset of all include paths",
    },
)

def header_map_impl(ctx):
    """
    Generates a JSON header map for other C++ rules to use
    """

    headers = []
    includes = []
    for dep in ctx.attr.deps:
        headers.extend(dep[CcInfo].compilation_context.direct_public_headers)
        includes.extend(dep[CcInfo].compilation_context.includes.to_list())

    headers = depset(headers)
    includes = depset(includes)

    header_paths = []
    for hdr in headers.to_list():
        header_paths.append(hdr.path)

    header_map = ctx.actions.declare_file(ctx.attr.name + ".json")
    map_content = json.encode({"includes": includes.to_list(), "headers": header_paths})
    map_content = map_content.replace("\"", "\\\"")
    ctx.actions.run_shell(
        outputs = [header_map],
        command = "printf \"" + map_content + "\" > " + header_map.path,
    )

    return DefaultInfo(files = depset([header_map])), HeadersInfo(headers = headers, includes = includes)

def generate_headers(name, actions, bin_dir, hdrs, strip_include_prefix, include_prefix):
    headers = []
    for hdr in hdrs:
        for file in hdr.files.to_list():
            if not file.path.startswith(strip_include_prefix):
                fail("Path " + file.path + " does not start with prefix " + strip_include_prefix)
            target_path = "_virtual_includes/" + name + "/" + file.path.replace(strip_include_prefix, include_prefix)
            out = actions.declare_file(target_path)
            actions.symlink(output = out, target_file = file)
            headers.append(out)
    return headers

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

    features = cc_common.configure_features(ctx = ctx, cc_toolchain = toolchain, requested_features = ctx.features + ["pic", "supports_pic"], unsupported_features = ctx.disabled_features)

    obj_files = []

    dep_includes = ctx.attr.header_map[HeadersInfo].includes
    dep_headers = ctx.attr.header_map[HeadersInfo].headers

    includes = resolve_includes(ctx, dep_includes)

    headers = generate_headers(ctx.attr.name, ctx.actions, ctx.bin_dir.path, ctx.attr.hdrs, ctx.attr.strip_include_prefix, ctx.attr.include_prefix)

    for src in ctx.files.srcs:
        outfile = ctx.actions.declare_file("_objs/" + src.basename + ".o")
        args = get_compile_command_args(src, outfile, toolchain, features, include_directories = includes)
        obj_files.append(outfile)

        ctx.actions.run(
            outputs = [outfile],
            inputs = ctx.files.srcs + dep_headers.to_list(),
            executable = toolchain.compiler_executable,
            arguments = args,
            mnemonic = "CppCompile",
            progress_message = "Compiling %{output}",
        )

    shlib = ctx.actions.declare_file("lib" + ctx.attr.name + ".so")
    link_flags, lib_inputs = resolve_linker_arguments(ctx, toolchain, features, shlib.path, True)

    for obj in obj_files:
        link_flags.append(obj.path)

    ctx.actions.run(
        outputs = [shlib],
        inputs = obj_files + lib_inputs.to_list() + headers,
        executable = toolchain.compiler_executable,
        arguments = link_flags,
        mnemonic = "CppLink",
        progress_message = "Compiling %{output}",
    )

    default_provider = DefaultInfo(files = depset([shlib]))

    compilation_ctx = cc_common.create_compilation_context(
        headers = depset(headers),
        includes = includes,
    )
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
