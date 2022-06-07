# Sceptre helpers

This repo contains helpers for Sceptre specifically for analysing stack drifts.

## drift_summary.sh

Find all stacks in an AWS account and run drift detection on each. Produce a CSV-formatted summary that can be opened in Excel.

```text
▶ bash drift_summary.sh -h
Usage: drift_summary.sh
Find all running stacks and produce drift summaries
```

## drift_diff.py

Take the output of Sceptre drift detection and present the actual diffs as in unified diff format.

```text
▶ python drift_diff.py -h
Usage:
  sceptre-fx var_file.yaml detect-stack-drift > drift.yml
  drift_diff.py drift.yml
```

## drift_report.sh

Given either a stack_name (slow) or a var file, automate detecting drift on that stack and then producing a drift diff.

```text
▶ bash drift_report.sh -h
Usage: drift_report.sh [-v VAR_FILE] [-s STACK_NAME -p SEARCH_PATH] [-h]
produce drift summary based on either a
var file or a stack name and search path pair
```
