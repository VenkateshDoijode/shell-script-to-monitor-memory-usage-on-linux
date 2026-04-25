#!/bin/bash

LOG_FILE=${1:-app.log}
START_TIME="2026-04-25 10:00:00"
END_TIME="2026-04-25 11:00:00"

# Extract logs between time range
awk -v start="$START_TIME" -v end="$END_TIME" '
{
  log_time = $1 " " $2   # assuming timestamp in first 2 columns
  if (log_time >= start && log_time <= end)
    print $0
}' "$LOG_FILE"

# Works if logs are in format:
# 2026-04-25 10:05:12 ERROR something broke
