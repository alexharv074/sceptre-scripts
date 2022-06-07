#!/usr/bin/env bash

usage() {
  echo "Usage: $0 VAR_FILE [-h]"
  exit 1
}

_set_stack_name() {
  stack_name="$(sceptre-fx "$var_file" stack-name | yq -r '.[]')"
}

_set_output_file() {
  output_file="$stack_name".change_set.json
}

_generate_change_set() {
  sceptre-fx "$var_file" change-set -f
}

_set_change_set_id() {
  change_set_id="$(aws cloudformation list-change-sets --stack-name \
    "$stack_name" --query "Summaries[].ChangeSetId" --output "text")"
}

_describe_change_set() {
  aws cloudformation describe-change-set --change-set-name "$change_set_id" > "$output_file"
}

create_change_set_diff() {
  _set_stack_name
  _set_output_file
  _generate_change_set
  _set_change_set_id
  _describe_change_set
}

main() {
  [[ -z "$1" ]] && usage
  [[ "$1" = "-h" ]] && usage
  var_file="$1"
  create_change_set_diff
  echo "Output is in $output_file"
}

main "$@"
