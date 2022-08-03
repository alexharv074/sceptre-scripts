#!/usr/bin/env bash

temp_file="temp.$$"

usage() {
  echo "Usage: $0 [-h]"
  exit 1
}

iam_roles() {
  local aws_account service_name environment_name \
    include_suffix role_name

  aws_account="$(yq -r '.AWSAccountId' common-env.yaml)"

  echo "VALUES ROLE_NAME" > "$temp_file"

  grep -lr 'path: iam-generic' . | while read -r values_file ; do
    read -r service_name environment_name include_suffix <<< "$(yq -r '
      . | [.ServiceName, .EnvironmentName, .IncludeEnvironmentRoleSuffix] | join (" ")
    ' "$values_file")"

    if [[ "$include_suffix" = "false" ]] ; then
      role_name="arn:aws:iam::$aws_account:role/$service_name"
    else
      role_name="arn:aws:iam::$aws_account:role/$service_name-$environment_name-role"
    fi

    echo "$values_file $role_name" >> "$temp_file"
  done

  column -t "$temp_file" && rm -f "$temp_file"
}

main() {
  [[ "$1" = "-h" ]] && usage
  [[ ! -e ./common-env.yaml ]] && usage
  iam_roles
}

main "$@"
