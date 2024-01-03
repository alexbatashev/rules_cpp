"""LLVM Releases for Linux on x86_64"""

llvm_x64_linux = {
    "main": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/main-ccf0b487943416578ca0a7abb5cf70e0e24a7957/main-linux-x86_64.tar.zst",
        ],
        "strip_prefix": "main-linux-x86_64",
        "sha256": "72c78822c16c594bd1886394eaf0eeaf8ced95a6f2ea9c67664f9a9e599a277c",
    },
    "17.0.6": {
        "urls": [
            "https://github.com/alexbatashev/rules_cpp/releases/download/llvmorg-17.0.6-31a6a2ac5144effba2c8bd42950c994ba54230ae/llvmorg-17.0.6-linux-x86_64.tar.zst",
        ],
        "strip_prefix": "llvmorg-17.0.6-linux-x86_64",
        "sha256": "a9f735bf262c2fd4805e3f66ee58ed5a7725978da7294d6654809a964f92ac82",
    },
}
