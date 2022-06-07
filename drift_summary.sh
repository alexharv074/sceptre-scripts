#!/usr/bin/env bash

detection_ids=/tmp/detection_ids."$$"
detection_status=/tmp/detection_status."$$"
detection_statuses=/tmp/detection_statuses."$$"

> "$detection_statuses"

usage() {
  echo "Usage: $0"
  echo "Find all running stacks and produce drift summaries"
  exit 1
}

_list_stacks() {
  aws cloudformation list-stacks --output "text" --query \
    'StackSummaries[?StackStatus!=`DELETE_COMPLETE`].[StackName]' 
}

_detect_stack_drift() {
  aws cloudformation detect-stack-drift --stack-name "$1" \
    --query "StackDriftDetectionId" --output "text"
}

_describe_stack_drift_detection_status() {
  aws cloudformation describe-stack-drift-detection-status \
    --stack-drift-detection-id "$1" > "$detection_status"
}

_parallel_detect_stack_drift() {
  local detection_id stack_name

  _list_stacks | while read -r stack_name ; do
    read -r detection_id <<< "$(_detect_stack_drift "$stack_name")"
    echo "$stack_name,$detection_id" >> "$detection_ids"
  done
}

_seen_in() {
  grep -w "$1" "$2"
}

detect_drift() {
  _parallel_detect_stack_drift

  detection_in_progress=1
  while ((detection_in_progress)) ; do

    detection_in_progress=0
    while IFS="," read -r stack_name detection_id ; do

      if _seen_in "$detection_id" "$detection_statuses" ; then
        continue
      fi

      _describe_stack_drift_detection_status "$detection_id"

      read -r stack_drift_status detection_status <<< "$(
        jq -r '[.StackDriftStatus,.DetectionStatus] | join(" ")' \
          "$detection_status"
      )"

      if [[ "$detection_status" = "DETECTION_IN_PROGRESS" ]] ; then
        detection_in_progress=1 ; continue
      fi

      echo "$detection_id,$stack_drift_status" >> \
        "$detection_statuses"

    done < "$detection_ids"
  done
}

print_summary() {
  join -t, -1 2 -2 1 -o 1.1,2.2 \
    "$detection_ids" "$detection_statuses"
}

main() {
  [[ "$1" = "-h" ]] && usage
  [[ "$1" != "-p" ]] && detect_drift
  print_summary
}

main "$@"
