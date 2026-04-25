#!/bin/bash

LOG_FILE=${1:-app.log}
REPORT_FILE="report_$(date +%F).txt"

echo "Log Report - $(date)" > "$REPORT_FILE"
echo "------------------------" >> "$REPORT_FILE"

# Total lines
echo "Total Logs: $(wc -l < "$LOG_FILE")" >> "$REPORT_FILE"

# Error count
echo "Errors: $(grep -i error "$LOG_FILE" | wc -l)" >> "$REPORT_FILE"

# Unique errors
echo "Top Errors:" >> "$REPORT_FILE"
grep -i error "$LOG_FILE" | sort | uniq -c | sort -nr | head -5 >> "$REPORT_FILE"

echo "Report generated: $REPORT_FILE"
