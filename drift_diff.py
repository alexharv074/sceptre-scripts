#!/usr/bin/env python3

import yaml
import sys

from difflib import unified_diff


def usage():
    print("Usage:")
    print("  sceptre-fx var_file.yaml detect-stack-drift > drift.yml")
    print(f"  {__file__} drift.yml")
    sys.exit(1)


def get_yaml(yaml_file):
    """
    Open a YAML file with multiple docs and return
    its contents as a dictionary.
    """
    with open(yaml_file, encoding="utf-8") as file_handle:
        gen = yaml.load_all(file_handle, Loader=yaml.BaseLoader)
        return_dict = next(gen)
        for d in gen:
            return_dict.update(d)

    return return_dict


def drift_diffs(docs):
    """
    Iterate data from sceptre-fx detect-stack-drifts
    and print out diffs reformatted as unified diffs.
    """
    sep = "-" * 10

    for stack_name, data in docs.items():
        header_printed = False

        if "StackResourceDriftStatus" in data:
            continue

        for drift in data["StackResourceDrifts"]:

            idx      = drift["LogicalResourceId"]
            status   = drift["StackResourceDriftStatus"]
            expected = drift["ExpectedProperties"]
            actual   = drift["ActualProperties"]

            if status == "IN_SYNC":
                continue

            expected_lines = yaml.dump(expected).split("\n")
            actual_lines   = yaml.dump(actual).split("\n")

            diffs = unified_diff(
                expected_lines,
                actual_lines,
                fromfile="deployed",
                tofile="manual_changes",
                lineterm=""
            )

            for diff in diffs:
                if not header_printed:
                    print(f"{sep} {stack_name}:{idx} {sep}")
                    header_printed = True

                print(diff)


def main():
    if sys.argv[1] == "-h":
        usage()
    else:
        input_file = sys.argv[1]

    docs = get_yaml(input_file)
    drift_diffs(docs)


main()
