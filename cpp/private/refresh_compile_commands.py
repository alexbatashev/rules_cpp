import subprocess
import re
import os
import json


def get_bazel_root():
    info = subprocess.run(["bazel info"], shell=True, capture_output=True, text=True).stderr
    return re.search(r"The pertinent workspace directory is: \'(.*)\'", info).group(1)

def parse_actions(actions):
    actions = actions.split("\n\n")

    mappings = []

    for action in actions:
        if action == "":
            continue
        #print(action)
        #print(re.search(r"Inputs: \[(.*)\]", action))
        sources = []
        for src in re.search(r"Inputs: \[(.*)\]", action).group(1).split(","):
            if src.endswith('.cpp') or src.endswith('.c'):
                sources.append(src.strip())
        prefix = "Command Line: (exec "
        command_line = action[action.find(prefix) + len(prefix):]
        command_line = command_line[:command_line.find(")\n")]
        command_line = command_line.replace("\\\n", "")

        for src in sources:
            command_line = command_line.replace(src, "")

        command_line = command_line.split()

        for src in sources:
            mappings.append({"file": src, "arguments": command_line})

    return mappings


def save_compile_commands(mappings):
    compile_commands = []

    for m in mappings:
        compile_commands.append({"directory": os.getcwd(), "file": m['file'], "arguments": m['arguments']})

    with open('compile_commands.json', 'w', encoding='utf-8') as f:
        json.dump(compile_commands, f, indent=2)


base_path = get_bazel_root()
os.chdir(base_path)
actions = subprocess.run(["bazel aquery 'mnemonic(\"CppCompile\", (inputs(\".*cpp\", //...)))'"], shell=True, capture_output=True, text=True).stdout
mappings = parse_actions(actions)
save_compile_commands(mappings)