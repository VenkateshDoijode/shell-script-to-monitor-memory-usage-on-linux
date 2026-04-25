#!/bin/bash

# File to analyze (pass as argument or hardcode)
LOG_FILE=${1:-app.log}

# Check if file exists
if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found!"
  exit 1
fi

# Count different log levels
ERROR_COUNT=$(grep -i "error" "$LOG_FILE" | wc -l)
WARN_COUNT=$(grep -i "warn" "$LOG_FILE" | wc -l)
INFO_COUNT=$(grep -i "info" "$LOG_FILE" | wc -l)

# Display results
echo "Log Analysis Summary:"
echo "Errors   : $ERROR_COUNT"
echo "Warnings : $WARN_COUNT"
echo "Info     : $INFO_COUNT"
