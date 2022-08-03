#!/usr/bin/env bash

usage() {
  echo "Usage: $0 VAR_FILE [-h]"
  exit 1
}

_set_stack_names() {
  read -ra stack_names <<< "$(sceptre-fx "$var_file" stack-name | yq -r '. | join(" ")')"
}

_set_output_file() {
  output_file="$stack_name".change_set.json
}

_generate_change_set() {
  sceptre-fx "$var_file" change-set -f
}

_set_change_set_id() {
  change_set_id="$(aws cloudformation list-change-sets --stack-name "$stack_name" \
    --query "Summaries[].ChangeSetId" --output "text")"
}

_describe_change_set() {
  aws cloudformation describe-change-set --change-set-name "$change_set_id"
}

_wait_for_change_set() {
  local status
  local completed=0
  while ! ((completed)) ; do
    _describe_change_set > "$output_file"
    status="$(jq -r '.Status' "$output_file")"
    if [[ "$status" = "CREATE_IN_PROGRESS" ]] ; then
      sleep 2
    else
      completed=1
    fi
  done
}

create_change_set_diff() {
  local stack_name

  _set_stack_names
  _generate_change_set

  for stack_name in "${stack_names[@]}" ; do
    _set_change_set_id
    _set_output_file
    _wait_for_change_set
    echo "Output is in $output_file"
  done
}

main() {
  [[ -z "$1" ]] && usage
  [[ "$1" = "-h" ]] && usage
  var_file="$1"
  create_change_set_diff
}

main "$@"
