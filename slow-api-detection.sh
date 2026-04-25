#!/bin/bash

LOG_FILE=${1:-app.log}
THRESHOLD=500  # milliseconds

# Assuming response time is last column
awk -v threshold="$THRESHOLD" '
{
  response_time = $NF   # last field
  if (response_time > threshold)
    print $0
}' "$LOG_FILE"

# Example log format:
# 2026-04-25 GET /api/user 200 650
