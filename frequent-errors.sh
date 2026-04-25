#!/bin/bash

LOG_FILE=${1:-app.log}

# Extract only error lines, sort, count duplicates, and show top 10
grep -i "error" "$LOG_FILE" \
| sort \
| uniq -c \
| sort -nr \
| head -10

# Explanation:
# grep      -> filter error lines
# sort      -> group identical lines
# uniq -c   -> count occurrences
# sort -nr  -> highest count first
# head      -> top 10
