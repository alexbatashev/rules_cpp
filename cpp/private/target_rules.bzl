"""
Contains rules implementations for building C++ targets
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cpp//cpp/private:common.bzl", "HeadersInfo", "create_compilation_context", "get_compile_command_args", "resolve_linker_arguments")

def header_map_impl(ctx):
    """
    Generates a JSON header map for other C++ rules to use
    """

    headers = []
    includes = []
    header_paths = []
    for dep in ctx.attr.deps:
        headers.extend(dep[CcInfo].compilation_context.direct_public_headers)
        headers.extend(dep[CcInfo].compilation_context.direct_textual_headers)
        owner = ""
        if hasattr(dep.label, "repo_name"):
            owner += "@" + dep.label.repo_name
        owner += "//"
        if hasattr(dep.label, "package"):
            owner += dep.label.package
        if hasattr(dep.label, "name"):
            owner += ":" + dep.label.name

        for hdr in dep[CcInfo].compilation_context.direct_public_headers:
            header_paths.append({
                "owner": owner,
                "path": hdr.path,
            })
        for hdr in dep[CcInfo].compilation_context.direct_textual_headers:
            header_paths.append({
                "owner": owner,
                "path": hdr.path,
            })
        includes.extend(dep[CcInfo].compilation_context.includes.to_list())

    headers = depset(headers)
    includes = depset(includes)

    header_map = ctx.actions.declare_file(ctx.attr.name + ".json")
    map_json = json.encode_indent({"includes": includes.to_list(), "headers": header_paths})
    ctx.actions.write(
        output = header_map,
        content = map_json,
    )

    headers_db = ctx.actions.declare_file(ctx.attr.name + ".db")

    ctx.actions.run(
        mnemonic = "CppHeadersDb",
        executable = ctx.executable._headers_database,
        arguments = [header_map.path, headers_db.path],
        outputs = [headers_db],
        inputs = [header_map],
    )

    return DefaultInfo(files = depset([headers_db])), HeadersInfo(headers = headers, includes = includes)

def _strip_object_file(actions, toolchain, features, file):
    if cc_common.is_enabled(feature_configuration = features, feature_name = "dbg") or not cc_common.action_is_enabled(feature_configuration = features, action_name = ACTION_NAMES.strip):
        return file
    stripped = actions.declare_file(paths.replace_extension(file.path, ".stripped.o"))
    actions.run(
        outputs = [stripped],
        inputs = [file],
        mnemonic = "CppObjectStrip",
        executable = toolchain.strip_executable,
        arguments = [file.path, "--strip-unneeded", "-o", stripped.path],
    )
    return stripped

def _has_agressive_strip(features, _toolchain):
    # FIXME(alexbatashev): does not work with default toolchain
    if cc_common.is_enabled(feature_configuration = features, feature_name = "opt") and not cc_common.is_enabled(feature_configuration = features, feature_name = "no_agressive_strip"):
        return True
    return False

def _agressive_strip(actions, toolchain, features, input, output):
    if _has_agressive_strip(features, toolchain):
        actions.run(
            outputs = [output],
            inputs = [input],
            mnemonic = "CppFinalStrip",
            executable = toolchain.strip_executable,
            arguments = [input.path, "-s", "-o", output.path],
        )

def _generate_unused_info(ctx, src):
    unused = ctx.actions.declare_file(src.basename + ".unused")
    ctx.actions.run(
        inputs = [src] + ctx.files.headers_db,
        outputs = [unused],
        mnemonic = "CppListUnusedHeaders",
        executable = ctx.executable._unused_headers,
        arguments = [ctx.files.headers_db[0].path, src.path, unused.path],
    )

    return unused

def _compile_object_files(ctx, comp_ctx, toolchain, features):
    obj_files = []

    for src in comp_ctx.sources:
        outfile = ctx.actions.declare_file("_objs/" + src.basename + ".o")
        args = get_compile_command_args(
            toolchain,
            source = src.path,
            output = outfile.path,
            features = features,
            include_directories = comp_ctx.includes,
        )

        unused = _generate_unused_info(ctx, src)

        ctx.actions.run(
            outputs = [outfile],
            inputs = [src, unused] + comp_ctx.headers + comp_ctx.dependency_headers.to_list(),
            executable = toolchain.compiler_executable,
            arguments = args,
            mnemonic = "CppCompile",
            progress_message = "Compiling %{output}",
            unused_inputs_list = unused,
        )

        obj_files.append(_strip_object_file(ctx.actions, toolchain, features, outfile))

    return obj_files

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

    toolchain = find_cpp_toolchain(ctx)

    features = cc_common.configure_features(ctx = ctx, cc_toolchain = toolchain, requested_features = ctx.features + ["no_agressive_strip"], unsupported_features = ctx.disabled_features)

    headers = generate_headers(ctx.attr.name, ctx.actions, ctx.bin_dir.path, ctx.attr.hdrs, ctx.attr.strip_include_prefix, ctx.attr.include_prefix)
    comp_ctx = create_compilation_context(ctx, headers)

    obj_files = _compile_object_files(ctx, comp_ctx, toolchain, features)

    shlib = ctx.actions.declare_file(ctx.attr.lib_prefix + ctx.attr.name + ctx.attr.lib_suffix)
    compile_output = shlib
    if (_has_agressive_strip(features, toolchain)):
        compile_output = ctx.actions.declare_file(ctx.attr.lib_prefix + ctx.attr.name + "_full" + ctx.attr.lib_suffix)

    link_flags, lib_inputs = resolve_linker_arguments(ctx, toolchain, features, compile_output.path, True)

    for obj in obj_files:
        link_flags.append(obj.path)

    ctx.actions.run(
        outputs = [compile_output],
        inputs = obj_files + lib_inputs.to_list() + headers,
        executable = toolchain.compiler_executable,
        arguments = link_flags,
        mnemonic = "CppLink",
        progress_message = "Compiling %{output}",
    )

    _agressive_strip(ctx.actions, toolchain, features, compile_output, shlib)

    default_provider = DefaultInfo(files = depset([shlib]))

    compilation_ctx = cc_common.create_compilation_context(
        headers = depset(headers),
        includes = comp_ctx.includes,
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
