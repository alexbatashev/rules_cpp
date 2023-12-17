def refresh_compile_commands(name):
    native.py_binary(
        name = name,
        main = "refresh_compile_commands.py",
        srcs = [
            "@rules_cpp//cpp/tools:refresh_compile_commands.py",
        ],
        imports = [""],
    )
