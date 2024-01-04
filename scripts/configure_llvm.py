import argparse
import platform
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--target_cpu", type=str, required=True)
parser.add_argument("--build_dir", type=str, required=True)

args = parser.parse_args()

llvm_tools = [
    "dsymutil",
    "llvm-ar",
    "llvm-cxxfilt",
    "llvm-cov",
    "llvm-dwarfdump",
    "llvm-nm",
    "llvm-objdump",
    "llvm-objcopy",
    "llvm-profdata",
    "llvm-ranlib",
    "llvm-readobj",
    "llvm-strip",
    "llvm-size",
    "llvm-symbolizer"
]

runtime_targets = []
targets_to_build = []

if platform.system() == "Linux":
    runtime_targets = [
        "x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu",
        "riscv64-unknown-linux-gnu",
    ]
    targets_to_build = ["X86",
                        "AArch64",
                        "NVPTX",
                        "AMDGPU",
                        "RISCV"]
elif platform.system() == "Darwin":
    runtime_targets = [args.target_cpu]
    targets_to_build = ["X86", "AArch64"]

cmake_args = [
    "cmake",
    "-GNinja",
    "-B",
    args.build_dir,
    "-S",
    "llvm/llvm",
    "-DCMAKE_C_COMPILER=clang",
    "-DCMAKE_CXX_COMPILER=clang++",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_INSTALL_PREFIX=\"\"",
    "-DLLVM_TARGETS_TO_BUILD={}".format(';'.join(targets_to_build)),
    "-DLLVM_RUNTIME_TARGETS={}".format(';'.join(runtime_targets)),
    "-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON",
    "-DLLVM_ENABLE_TERMINFO=OFF",
    "-DLLVM_ENABLE_ZLIB=OFF",
    "-DLLVM_ENABLE_ZSTD=OFF",
    "-DLLVM_ENABLE_RUNTIMES=libunwind;compiler-rt;libcxx;libcxxabi;openmp",
    "-DLLVM_ENABLE_PROJECTS=bolt;clang;clang-tools-extra;lld;pstl",
    "-DLLVM_STATIC_LINK_CXX_STDLIB=ON",
    "-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON",
    "-DLLVM_TOOLCHAIN_TOOLS={}".format(';'.join(llvm_tools)),
    "-DLLVM_DISTRIBUTIONS=ClangTidy;ClangDoc;ClangFormat;ClangdTool;BoltTool;LldTool;StdLib;Toolchain",
    "-DLLVM_ClangTidy_DISTRIBUTION_COMPONENTS=clang-tidy",
    "-DLLVM_ClangDoc_DISTRIBUTION_COMPONENTS=clang-doc",
    "-DLLVM_ClangFormat_DISTRIBUTION_COMPONENTS=clang-format",
    "-DLLVM_ClangdTool_DISTRIBUTION_COMPONENTS=clangd",
    "-DLLVM_BoltTool_DISTRIBUTION_COMPONENTS=bolt",
    "-DLLVM_LldTool_DISTRIBUTION_COMPONENTS=lld",
    "-DLLVM_StdLib_DISTRIBUTION_COMPONENTS=runtimes",
    "-DLLVM_Toolchain_DISTRIBUTION_COMPONENTS=clang;clang-format;clang-tidy;clang-resource-headers;bolt;runtimes;lld;{}".format(';'.join(llvm_tools)),
]

if platform.system() == "Darwin":
    cmake_args.append("-DRUNTIMES_BUILD_ALLOW_DARWIN=ON")

for rt in runtime_targets:
    cmake_args.extend([
        f"-DRUNTIMES_{rt}_OPENMP_LIBDIR_SUFFIX={rt}",
        f"-DRUNTIMES_{rt}_OPENMP_STANDALONE_BUILD=ON",
        f"-DRUNTIMES_{rt}_OPENMP_LLVM_TOOLS_DIR={args.build_dir}/bin",
        f"-DRUNTIMES_{rt}_LIBCXX_HERMETIC_STATIC_LIBRARY=ON",
        f"-DRUNTIMES_{rt}_LIBCXXABI_USE_LLVM_UNWINDER=ON",
        f"-DRUNTIMES_{rt}_LIBCXX_STATICALLY_LINK_ABI_IN_STATIC_LIBRARY=ON",
        f"-DRUNTIMES_{rt}_LIBCXXABI_STATICALLY_LINK_UNWINDER_IN_STATIC_LIBRARY=ON",
    ])

    if rt != "x86_64-unknown-linux-gnu":
        cmake_args.extend([
            f"-DRUNTIMES_{rt}_OPENMP_ENABLE_LIBOMPTARGET=OFF",
            f"-DRUNTIMES_{rt}_LIBOMP_OMPD_GDB_SUPPORT=OFF",
        ])

if not args.target_cpu.startswith("x86_64"):
    cmake_args.extend([
        f"-DLLVM_HOST_TRIPLE={args.target_cpu}",
    ])

print(' '.join(cmake_args))
subprocess.run(cmake_args, check=True, stdout=subprocess.PIPE)