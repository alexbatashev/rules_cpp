def _tools_impl(rctx):
    rctx.symlink(Label("//cpp/private:tools_rules.bzl"), "tools_rules.bzl")
    build = rctx.read(Label("//cpp/private:tools.BUILD"))
    rctx.file("WORKSPACE", executable = False)
    rctx.file("BUILD", content = build)

_tools = repository_rule(
    implementation = _tools_impl,
    configure = True,
)

def setup_tools(_mctx, repo_name):
    _tools(
        name = repo_name,
    )
