CppModuleInfo = provider(
    fields = {
        "module_name": "name of the exported module",
        "pcm": "file containing precompiled module",
        "objs": "compiled object files",
        "partitions": "required dependencies",
    },
)
