import argparse
import subprocess
import os

parser = argparse.ArgumentParser()
parser.add_argument("file_list")

args = parser.parse_args()

inputs = open(args.file_list, 'r')
files = inputs.readlines()

os.chdir(os.environ['BUILD_WORKSPACE_DIRECTORY'])

for src in files:
  subprocess.run(["clang-format -i " + src], shell=True, capture_output=True, text=True).stdout