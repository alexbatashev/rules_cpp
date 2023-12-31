ToolInfo = provider(
    fields = {
        "executable": "tool",
        "runfiles": "runfiles",
    },
)

def _tool_impl(ctx):
    return ToolInfo(
        executable = ctx.files.executable[0],
        runfiles = ctx.runfiles(files = ctx.files.data),
    ), DefaultInfo(files = depset(ctx.files.executable + ctx.files.data))

tool = rule(
    implementation = _tool_impl,
    attrs = {
        "executable": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
    },
)
