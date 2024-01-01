"""
Contains rules implementations for building C++ targets
"""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("//cpp:providers.bzl", "CppModuleInfo")
load("//cpp/private:common.bzl", "collect_external_headers", "collect_external_includes", "collect_module_objects", "collect_modules", "get_compile_command_args", "resolve_linker_arguments")
load("//cpp/private:extra_actions.bzl", "EXTRA_ACTIONS")
load("//cpp/private/actions:compile.bzl", "cpp_compile")
load("//cpp/private/actions:strip.bzl", "cpp_strip_binary", "cpp_strip_objects")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _has_agressive_strip(features, _toolchain):
    # FIXME(alexbatashev): does not work with default toolchain
    if cc_common.is_enabled(feature_configuration = features, feature_name = "opt") and not cc_common.is_enabled(feature_configuration = features, feature_name = "no_agressive_strip"):
        return True
    return False

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

    all_headers = headers + collect_external_headers(ctx.attr.deps)
    includes = depset([ctx.bin_dir.path + "/_virtual_includes/" + ctx.attr.name] + ctx.attr.includes, transitive = [collect_external_includes(ctx.attr.deps)])
    modules = collect_modules(ctx.attr.deps)

    obj_files = cpp_compile(ctx.files.srcs, all_headers, includes, modules, features, toolchain)
    obj_files = cpp_strip_objects(obj_files, features, toolchain) + collect_module_objects(ctx.attr.deps)

    shlib = ctx.actions.declare_file(ctx.attr.lib_prefix + ctx.attr.name + ctx.attr.lib_suffix)
    compile_output = shlib
    if _has_agressive_strip(features, toolchain):
        compile_output = ctx.actions.declare_file(ctx.attr.lib_prefix + ctx.attr.name + "_full" + ctx.attr.lib_suffix)

    link_flags, lib_inputs = resolve_linker_arguments(ctx, toolchain, features, compile_output.path, True)

    for obj in obj_files:
        link_flags.append(obj.path)

    linker = cc_common.get_tool_for_action(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_link_dynamic_library,
    )

    ctx.actions.run(
        outputs = [compile_output],
        inputs = depset(obj_files, transitive = [lib_inputs, toolchain.all_files]),
        executable = linker,
        arguments = link_flags,
        mnemonic = "CppLinkSharedLibrary",
        progress_message = "Compiling %{output}",
    )

    if _has_agressive_strip(features, toolchain):
        cpp_strip_binary(compile_output, compile_output, shlib, features, toolchain)

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

def module_impl(ctx):
    """
    Implements C++ rules for building C++ 20 modules

    Return a tuple of providers

    Args:
        ctx: rule context

    Returns:
        A tuple of providers
    """
    toolchain = find_cpp_toolchain(ctx)

    features = cc_common.configure_features(ctx = ctx, cc_toolchain = toolchain, requested_features = ctx.features + ["no_agressive_strip"], unsupported_features = ctx.disabled_features)

    headers = collect_external_headers(ctx.attr.deps)
    includes = depset(ctx.attr.includes, transitive = [collect_external_includes(ctx.attr.deps)])
    modules = collect_modules(ctx.attr.deps)

    extra_vars = {
        "cpp_precompiled_modules": [],
    }

    if len(modules) != 0:
        extra_vars = {
            "cpp_precompiled_modules": modules,
        }

    module_files = []

    for m in modules:
        print(m)
        module_files.append(m["file"])

    pcm = ctx.actions.declare_file("_pcm/" + ctx.attr.module_name + "-" + ctx.files.interface[0].basename[:-(len(ctx.files.interface[0].extension) + 1)] + ".pcm")

    precompile_args = get_compile_command_args(
        toolchain,
        source = ctx.files.interface[0].path,
        output = pcm.path,
        features = features,
        include_directories = includes,
        action_name = EXTRA_ACTIONS.cpp_module_precompile_interface,
        extra_vars = extra_vars,
    )

    compiler = cc_common.get_tool_for_action(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_compile,
    )

    ctx.actions.run(
        outputs = [pcm],
        mnemonic = "CppModulePrecompile",
        inputs = depset(ctx.files.interface, transitive = [depset(headers), depset(module_files), toolchain.all_files]),
        arguments = precompile_args,
        executable = compiler,
        progress_message = "Precompiling %{output}",
    )

    obj_files = cpp_compile(ctx.files.srcs + [pcm], headers, includes, modules, features, toolchain)
    obj_files = cpp_strip_objects(obj_files, features, toolchain) + collect_module_objects(ctx.attr.deps)

    return CppModuleInfo(
        module_name = ctx.attr.module_name,
        pcm = pcm,
        objs = obj_files,
    )

def binary_impl(ctx):
    """
    Implements C++ rules for building C++ 20 modules

    Return a tuple of providers

    Args:
        ctx: rule context

    Returns:
        A tuple of providers
    """
    toolchain = find_cpp_toolchain(ctx)

    features = cc_common.configure_features(ctx = ctx, cc_toolchain = toolchain, requested_features = ctx.features + ["no_agressive_strip"], unsupported_features = ctx.disabled_features)

    all_headers = collect_external_headers(ctx.attr.deps)
    includes = collect_external_includes(ctx.attr.deps)

    modules = collect_modules(ctx.attr.deps)

    obj_files = cpp_compile(ctx.files.srcs, all_headers, includes, modules, features, toolchain)
    obj_files = cpp_strip_objects(obj_files, features, toolchain) + collect_module_objects(ctx.attr.deps)

    bin = ctx.actions.declare_file(ctx.attr.name + ctx.attr.bin_suffix)
    compile_output = bin
    if _has_agressive_strip(features, toolchain):
        compile_output = ctx.actions.declare_file(ctx.attr.name + ".nonstripped" + ctx.attr.bin_suffix)

    link_flags, lib_inputs = resolve_linker_arguments(ctx, toolchain, features, compile_output.path, False)

    for obj in obj_files:
        link_flags.append(obj.path)

    ctx.actions.run(
        outputs = [compile_output],
        inputs = obj_files + lib_inputs.to_list(),
        executable = toolchain.compiler_executable,
        arguments = link_flags,
        mnemonic = "CppLinkExecutable",
        progress_message = "Linking %{output}",
    )

    if _has_agressive_strip(features, toolchain):
        cpp_strip_binary(compile_output, compile_output, bin, toolchain)

    default_provider = DefaultInfo(executable = bin)

    return default_provider
