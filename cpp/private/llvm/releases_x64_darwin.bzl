"""LLVM Releases for macOS on x86_64"""

llvm_x64_darwin = {
    "main": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/main-ccf0b487943416578ca0a7abb5cf70e0e24a7957/main-macos-x86_64.tar.zst",
        ],
        "strip_prefix": "main-macos-x86_64",
        "sha256": "cf6444c8c638844d3b339e58cd52523f6057d71acba8d6c5af8810ebb5201f5e",
    },
    "17.0.6": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/llvmorg-17.0.6-ccf0b487943416578ca0a7abb5cf70e0e24a7957/llvmorg-17.0.6-macos-x86_64.tar.zst",
        ],
        "strip_prefix": "llvmorg-17.0.6-macos-x86_64",
        "sha256": "77d5d4654372425e82f20491ab8a7633cdbfed4911bf8af7404490187fbcdcdb",
    },
}
