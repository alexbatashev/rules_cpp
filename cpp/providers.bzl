"""Definitions of C++ rules providers"""
CppModuleInfo = provider(
    doc = "Information required to use a module in a C++ translation unit",
    fields = {
        "module_name": "name of the exported module",
        "pcm": "file containing precompiled module",
        "objs": "compiled object files",
        "interface_source": "source file for the interface of the module",
        "partitions": "required dependencies",
    },
)

StdlibInfo = provider(
    doc = "Information required for toolchain to discover C++ standard library",
    fields = {
        "headers": "standard C++ headers files and dependencies",
        "shared_libraries": "shared C++ runtime libraries",
        "static_libraries": "static C++ runtime libraries",
        "includes": "include directories",
        "kind": "libstdc++ or libc++",
    },
)

CompilerInfo = provider(
    doc = "Information required for toolchain to discover C++ compiler",
    fields = {
        "binary": "C++ compiler executable",
        "kind": "one of ['gcc', 'clang']",
    },
)

BinutilsInfo = provider(
    doc = "Tools required for working with binary files",
    fields = {
        "ar": "archiver tool",
        "assembler": "assembler",
        "objcopy": "objcopy tool",
        "strip": "strip tool",
        "dwp": "debug info fission tool",
    },
)

LinkerInfo = provider(
    doc = "Object linker",
    fields = {
        "kind": "linker kind",
        "binary": "linker executable",
    },
)
