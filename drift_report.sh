#!/usr/bin/env bash

usage() {
  echo "Usage: [DRIFT_REPORT_PATH=search_path] $0 [-v VAR_FILE] [-s STACK_NAME [-p SEARCH_PATH]] [-h]"
  echo "produce drift summary based on either a"
  echo "var file or a stack name and search path pair"
  exit 1
}

_check_commands() {
  local cmd
  local not_found=0
  for cmd in "drift_diff.py" "yq" ; do
    if ! command -v "$cmd" > /dev/null ; then
      echo "$cmd not not_found in path"
      ((not_found++))
    fi
  done
  ((not_found)) && return "$not_found"
  true
}

_param_not_set() {
  echo "You must specify -v or -s and -p"
  usage
}

_both_params_set() {
  echo "Please use -v or -s but not both"
  usage
}

_path_not_set() {
  echo "You must specify -p with -s"
  usage
}

get_opts() {
  local OPTARG OPTIND opt

  [[ -n "$DRIFT_REPORT_PATH" ]] && \
    search_path="$DRIFT_REPORT_PATH"

  while getopts "v:s:p:h" opt ; do
    case "$opt" in
      h) usage ;;
      v) var_file="$OPTARG" ;;
      s) stack_names=("$OPTARG") ;;
      p) search_path="$OPTARG" ;;
      \?) echo "ERROR: Invalid option -$OPTARG"
          usage ;;
    esac
  done
  shift $((OPTIND-1))

  _check_commands

  [[ -z "$var_file" ]] && \
    [[ -z "$stack_names" ]] && \
      _param_not_set

  [[ -n "$var_file" ]] && \
    [[ -n "$stack_names" ]] && \
      _both_params_set

  [[ -n "$stack_names" ]] && \
    [[ -z "$search_path" ]] && \
      _path_not_set

  true
}

_var_file() {
  local file_name
  local pipe="pipe.$$"

  echo "Finding var file for $stack_names"

  mkfifo "$pipe"
  find "$search_path" -name "*.yaml" > "$pipe" &

  while read -r file_name ; do
    if sceptre-fx "$file_name" stack-name 2> /dev/null | yq -r '.[]' | grep -qw "$stack_names" ; then
      var_file="$file_name"
      echo "Using $var_file"
      return
    fi
  done < "$pipe"
  rm -f "$pipe"

  echo "Did not find a var file"
  exit 1
}

_stack_names() {
  read -ra stack_names <<< "$(sceptre-fx "$var_file" stack-name | yq -r '. | join(" ")')"
}

detect_drift() {
  sceptre-fx "$var_file" detect-stack-drift
}

extract_yaml() {
  python -c "\
import sys, yaml

file_name = sys.argv[1]
key = sys.argv[2]

with open(file_name, 'r') as file_handle:
  stream = file_handle.read()

for doc in stream.split('---')[1:]:
  data = yaml.safe_load(doc)
  keys = list(data.keys())
  stack_name = keys[0]
  if key == keys[0]:
    print('---\n' + doc)" "$1" "$2"
}

main() {
  local doc stack_name drift_file

  get_opts "$@"

  [[ -z "$var_file" ]] && _var_file
  [[ -z "$stack_name" ]] && _stack_names

  drift_file=/tmp/drift_file."$$"
  detect_drift > "$drift_file"

  for stack_name in "${stack_names[@]}" ; do
    drift_yml="$stack_name".drift.yml
    drift_diff="$stack_name".drift.diff
    extract_yaml "$drift_file" "$stack_name" > "$drift_yml"
    drift_diff.py "$drift_yml" > "$drift_diff"
    echo "Output is $drift_diff"
  done
}

main "$@"
