CppModuleInfo = provider(
    fields = {
        "module_name": "name of the exported module",
        "pcm": "file containing precompiled module",
        "objs": "compiled object files",
        "interface_source": "source file for the interface of the module",
        "partitions": "required dependencies",
    },
)
