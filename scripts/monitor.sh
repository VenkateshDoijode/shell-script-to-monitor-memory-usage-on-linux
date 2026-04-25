#!/bin/bash
# =============================================================================
# monitor.sh — CPU & Memory Monitor
# Author  : DevOps Engineer
# Version : 1.0.0
# =============================================================================

# ── Load config ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/monitor.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# ── Defaults (overridden by config) ──────────────────────────────────────────
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEM_THRESHOLD="${MEM_THRESHOLD:-85}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
LOG_FILE="$LOG_DIR/monitor_$(date +%Y%m%d).log"
ALERT_EMAIL="${ALERT_EMAIL:-}"
INTERVAL="${INTERVAL:-5}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
MAX_LOG_DAYS="${MAX_LOG_DAYS:-7}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

log() {
  local level="$1"; shift
  local msg="$*"
  local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

get_cpu_usage() {
  # Average CPU usage over 1 second sample
  grep 'cpu ' /proc/stat | awk '{
    idle=$5; total=0
    for(i=2;i<=NF;i++) total+=$i
    print 100 - (idle*100/total)
  }' | head -1
  # Fallback for macOS
  # top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%'
}

get_mem_usage() {
  # Returns: used_percent used_mb total_mb available_mb
  awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2}
  END{
    used=total-avail
    pct=(used/total)*100
    printf "%.1f %.0f %.0f %.0f", pct, used/1024, total/1024, avail/1024
  }' /proc/meminfo
}

get_top_cpu_processes() {
  ps aux --sort=-%cpu | awk 'NR==1 || NR<=6 {printf "%-8s %-6s %-6s %s\n",$1,$2,$3,$11}' | head -6
}

get_top_mem_processes() {
  ps aux --sort=-%mem | awk 'NR==1 || NR<=6 {printf "%-8s %-6s %-6s %s\n",$1,$2,$4,$11}' | head -6
}

send_email_alert() {
  local subject="$1"; local body="$2"
  if [[ -n "$ALERT_EMAIL" ]] && command -v mail &>/dev/null; then
    echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
    log "INFO" "Email alert sent to $ALERT_EMAIL"
  fi
}

send_slack_alert() {
  local msg="$1"
  if [[ -n "$SLACK_WEBHOOK" ]] && command -v curl &>/dev/null; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      --data "{\"text\":\"$msg\"}" > /dev/null
    log "INFO" "Slack alert sent"
  fi
}

rotate_logs() {
  find "$LOG_DIR" -name "monitor_*.log" -mtime +"$MAX_LOG_DAYS" -delete
}

draw_bar() {
  local pct="${1%.*}"; local width=30
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0;i<filled;i++)); do bar+="█"; done
  for ((i=0;i<empty;i++));  do bar+="░"; done
  echo "$bar"
}

print_header() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║          🖥  SYSTEM RESOURCE MONITOR  v1.0.0             ║"
  echo "╚══════════════════════════════════════════════════════════╝${RESET}"
  echo -e "  Host: ${BOLD}$(hostname)${RESET}  |  $(date '+%a %d %b %Y  %H:%M:%S')"
  echo "  Uptime:$(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}' | awk '{$1=$2=""; print}')"
  echo "──────────────────────────────────────────────────────────"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
run_monitor() {
  log "INFO" "Monitor started | CPU threshold: ${CPU_THRESHOLD}% | MEM threshold: ${MEM_THRESHOLD}%"
  rotate_logs

  while true; do
    # --- CPU ---
    cpu_raw=$(get_cpu_usage)
    cpu_pct=$(printf "%.1f" "$cpu_raw")
    cpu_int="${cpu_pct%.*}"

    # --- Memory ---
    read -r mem_pct mem_used mem_total mem_avail <<< "$(get_mem_usage)"
    mem_int="${mem_pct%.*}"

    # --- Display ---
    print_header

    # CPU block
    if (( cpu_int >= CPU_THRESHOLD )); then
      color=$RED; status="⚠ CRITICAL"
    elif (( cpu_int >= CPU_THRESHOLD - 15 )); then
      color=$YELLOW; status="⚡ WARNING "
    else
      color=$GREEN; status="✔ NORMAL  "
    fi

    echo -e "\n  ${BOLD}CPU Usage${RESET}"
    echo -e "  ${color}$(draw_bar "$cpu_int")${RESET}  ${color}${BOLD}${cpu_pct}%${RESET}  $status"

    # Memory block
    if (( mem_int >= MEM_THRESHOLD )); then
      mcolor=$RED; mstatus="⚠ CRITICAL"
    elif (( mem_int >= MEM_THRESHOLD - 15 )); then
      mcolor=$YELLOW; mstatus="⚡ WARNING "
    else
      mcolor=$GREEN; mstatus="✔ NORMAL  "
    fi

    echo -e "\n  ${BOLD}Memory Usage${RESET}"
    echo -e "  ${mcolor}$(draw_bar "$mem_int")${RESET}  ${mcolor}${BOLD}${mem_pct}%${RESET}  $mstatus"
    echo -e "  Used: ${mem_used} MB / ${mem_total} MB  |  Available: ${mem_avail} MB"

    # Top processes
    echo -e "\n  ${BOLD}Top CPU Consumers${RESET}"
    get_top_cpu_processes | while IFS= read -r line; do echo "  $line"; done

    echo -e "\n  ${BOLD}Top Memory Consumers${RESET}"
    get_top_mem_processes | while IFS= read -r line; do echo "  $line"; done

    echo -e "\n  ${BOLD}Log:${RESET} $LOG_FILE"
    echo -e "  Press ${BOLD}Ctrl+C${RESET} to stop | Refreshing every ${INTERVAL}s"

    # --- Log ---
    log "METRIC" "CPU=${cpu_pct}% MEM=${mem_pct}% (${mem_used}/${mem_total} MB)"

    # --- Alerts ---
    if (( cpu_int >= CPU_THRESHOLD )); then
      log "ALERT" "HIGH CPU: ${cpu_pct}% exceeds threshold ${CPU_THRESHOLD}%"
      send_email_alert "🚨 HIGH CPU on $(hostname)" "CPU at ${cpu_pct}% (threshold: ${CPU_THRESHOLD}%)\nTime: $(date)"
      send_slack_alert "🚨 *HIGH CPU* on \`$(hostname)\`: ${cpu_pct}% (threshold: ${CPU_THRESHOLD}%)"
    fi

    if (( mem_int >= MEM_THRESHOLD )); then
      log "ALERT" "HIGH MEM: ${mem_pct}% exceeds threshold ${MEM_THRESHOLD}%"
      send_email_alert "🚨 HIGH MEMORY on $(hostname)" "Memory at ${mem_pct}% — Used ${mem_used}MB / ${mem_total}MB\nTime: $(date)"
      send_slack_alert "🚨 *HIGH MEMORY* on \`$(hostname)\`: ${mem_pct}% (${mem_used}MB / ${mem_total}MB)"
    fi

    sleep "$INTERVAL"
  done
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-run}" in
  run)     run_monitor ;;
  once)    
    cpu_raw=$(get_cpu_usage); cpu_pct=$(printf "%.1f" "$cpu_raw")
    read -r mem_pct mem_used mem_total mem_avail <<< "$(get_mem_usage)"
    echo "CPU: ${cpu_pct}%  |  MEM: ${mem_pct}% (${mem_used}/${mem_total} MB)"
    log "METRIC" "CPU=${cpu_pct}% MEM=${mem_pct}% (${mem_used}/${mem_total} MB)"
    ;;
  *)       echo "Usage: $0 [run|once]"; exit 1 ;;
esac
