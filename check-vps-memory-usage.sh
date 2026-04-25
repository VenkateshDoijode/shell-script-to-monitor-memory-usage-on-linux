#!/bin/bash

# ====== CONFIG ======
TO="youremail@mailserver.com"
HOST=$(hostname)

RAM_THRESHOLD=45
CPU_THRESHOLD=70
DISK_THRESHOLD=80

COOLDOWN=900   # 15 minutes (in seconds)
LOCK_FILE="/tmp/monitor_alert.lock"

# ====== RATE LIMITING ======
NOW=$(date +%s)

if [ -f "$LOCK_FILE" ]; then
    LAST_SENT=$(cat "$LOCK_FILE")
    DIFF=$((NOW - LAST_SENT))

    if [ "$DIFF" -lt "$COOLDOWN" ]; then
        exit 0
    fi
fi

# ====== METRICS ======

# RAM usage %
RAM=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')

# CPU usage %
CPU=$(top -bn1 | awk '/Cpu/ {print int(100 - $8)}')

# Disk usage % (root partition)
DISK=$(df / | awk 'NR==2 {print int($5)}' | tr -d '%')

# ====== CHECK CONDITIONS ======
ALERT=0

if [ "$RAM" -ge "$RAM_THRESHOLD" ]; then ALERT=1; fi
if [ "$CPU" -ge "$CPU_THRESHOLD" ]; then ALERT=1; fi
if [ "$DISK" -ge "$DISK_THRESHOLD" ]; then ALERT=1; fi

# ====== SEND ALERT ======
if [ "$ALERT" -eq 1 ]; then

    SUBJECT="⚠️ Server Alert on $HOST at $(date)"
    MESSAGE=$(mktemp)

    {
        echo "SYSTEM ALERT REPORT"
        echo "=============================="
        echo "Host: $HOST"
        echo "Time: $(date)"
        echo ""

        echo "Usage Summary:"
        echo "------------------------------"
        echo "RAM  : $RAM%"
        echo "CPU  : $CPU%"
        echo "Disk : $DISK%"
        echo ""

        echo "Top Memory Processes:"
        echo "------------------------------"
        ps -eo pid,ppid,%mem,%cpu,cmd --sort=-%mem | head -n 10
        echo ""

        echo "Top CPU Processes:"
        echo "------------------------------"
        ps -eo pid,ppid,%mem,%cpu,cmd --sort=-%cpu | head -n 10
        echo ""

        echo "Disk Usage Details:"
        echo "------------------------------"
        df -h
        echo ""

        echo "Uptime:"
        echo "------------------------------"
        uptime

    } > "$MESSAGE"

    # Send email
    mail -s "$SUBJECT" "$TO" < "$MESSAGE"

    # Save timestamp (for cooldown)
    date +%s > "$LOCK_FILE"

    # Cleanup
    rm -f "$MESSAGE"
fi
