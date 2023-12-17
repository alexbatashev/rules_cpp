import subprocess
import os
import json
import argparse


def parse_actions(actions):
    actions = json.loads(actions)

    mappings = []

    for action in actions['actions']:
        srcs = []
        outputs = []
        arguments = []

        for idx, arg in enumerate(action['arguments']):
            if arg == "-o":
                outputs.append(action['arguments'][idx + 1])
            if arg.endswith('.cpp') or arg.endswith('.c') or arg.endswith('.h') or arg.endswith('.hpp'):
                srcs.append(arg)
            arguments.append(arg)
        
        if len(srcs) != 1 or len(outputs) != 1:
            continue
        mappings.append({"file": srcs[0], "arguments": arguments, "output": outputs[0]})

    return mappings


def save_compile_commands(mappings):
    compile_commands = []

    for m in mappings:
        compile_commands.append({
            "directory": os.getcwd(), 
            "file": m['file'], 
            "arguments": m['arguments'], 
            "output": m['output']
        })

    with open('compile_commands.json', 'w', encoding='utf-8') as f:
        json.dump(compile_commands, f, indent=2)


parser = argparse.ArgumentParser()
parser.add_argument("--output_base", type=str, required=False, default="")
args = parser.parse_args()

os.chdir(os.environ['BUILD_WORKSPACE_DIRECTORY'])
output_base = " "

if args.output_base != "":
    output_base = "--output_base=" + args.output_base

actions = subprocess.run(["bazel" + output_base + "aquery 'mnemonic(\"CppCompile\", (inputs(\".*cpp\", //...)))' --output=jsonproto"], shell=True, capture_output=True, text=True).stdout
mappings = parse_actions(actions)
save_compile_commands(mappings)