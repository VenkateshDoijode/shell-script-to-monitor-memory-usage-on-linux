#!/bin/bash
# =============================================================================
# alert.sh — Standalone alerting & reporting engine
# Usage:
#   ./alert.sh check          → one-time check + alert if thresholds breached
#   ./alert.sh report         → print daily summary from log files
#   ./alert.sh daemon         → run continuous alert daemon (no UI, for cron)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/monitor.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEM_THRESHOLD="${MEM_THRESHOLD:-85}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
INTERVAL="${INTERVAL:-60}"
REPORT_FILE="$LOG_DIR/report_$(date +%Y%m%d).txt"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERT] $*" | tee -a "$LOG_DIR/alert.log"; }

# ── Data collectors ────────────────────────────────────────────────────────────
cpu_pct() {
  grep 'cpu ' /proc/stat | awk '{
    idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i
    printf "%.1f", 100-(idle*100/total)
  }'
}

mem_info() {
  awk '/MemTotal/{t=$2} /MemAvailable/{a=$2}
  END{u=t-a; printf "%.1f %.0f %.0f", (u/t)*100, u/1024, t/1024}' /proc/meminfo
}

# ── Alert senders ─────────────────────────────────────────────────────────────
send_email() {
  local subject="$1"; local body="$2"
  if [[ -n "$ALERT_EMAIL" ]] && command -v mail &>/dev/null; then
    echo -e "$body" | mail -s "$subject" "$ALERT_EMAIL"
    log "Email sent → $ALERT_EMAIL: $subject"
  else
    log "Email skipped (ALERT_EMAIL not set or 'mail' not found)"
  fi
}

send_slack() {
  local msg="$1"
  if [[ -n "$SLACK_WEBHOOK" ]] && command -v curl &>/dev/null; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      --data "{\"text\":\"$msg\"}" > /dev/null
    log "Slack alert sent"
  fi
}

send_all() {
  local title="$1"; local body="$2"
  send_email "$title" "$body"
  send_slack "$title\n$body"
}

# ── One-time check ─────────────────────────────────────────────────────────────
do_check() {
  local cpu; cpu=$(cpu_pct)
  local cpu_i="${cpu%.*}"
  read -r mem_pct mem_used mem_total <<< "$(mem_info)"
  local mem_i="${mem_pct%.*}"

  echo "── Resource Check: $(date) ──"
  echo "  CPU  : ${cpu}%   (threshold: ${CPU_THRESHOLD}%)"
  echo "  RAM  : ${mem_pct}%  ${mem_used}/${mem_total} MB   (threshold: ${MEM_THRESHOLD}%)"

  local triggered=0

  if (( cpu_i >= CPU_THRESHOLD )); then
    echo "  ⚠  CPU ALERT: ${cpu}% ≥ ${CPU_THRESHOLD}%"
    send_all "🚨 [$(hostname)] HIGH CPU: ${cpu}%" \
      "Host: $(hostname)\nTime: $(date)\nCPU Usage: ${cpu}% (threshold: ${CPU_THRESHOLD}%)\n\nTop CPU processes:\n$(ps aux --sort=-%cpu | head -6)"
    log "CPU alert fired: ${cpu}%"
    triggered=1
  fi

  if (( mem_i >= MEM_THRESHOLD )); then
    echo "  ⚠  MEM ALERT: ${mem_pct}% ≥ ${MEM_THRESHOLD}%"
    send_all "🚨 [$(hostname)] HIGH MEMORY: ${mem_pct}%" \
      "Host: $(hostname)\nTime: $(date)\nMemory Usage: ${mem_pct}% — ${mem_used}MB / ${mem_total}MB (threshold: ${MEM_THRESHOLD}%)\n\nTop memory processes:\n$(ps aux --sort=-%mem | head -6)"
    log "MEM alert fired: ${mem_pct}%"
    triggered=1
  fi

  (( triggered == 0 )) && log "Check OK: CPU=${cpu}% MEM=${mem_pct}%"
}

# ── Daily report ──────────────────────────────────────────────────────────────
do_report() {
  local today; today=$(date +%Y%m%d)
  local log="$LOG_DIR/monitor_${today}.log"

  echo "══════════════════════════════════════════════" | tee "$REPORT_FILE"
  echo "  DAILY SYSTEM REPORT — $(date '+%d %b %Y')"    | tee -a "$REPORT_FILE"
  echo "  Host: $(hostname)"                            | tee -a "$REPORT_FILE"
  echo "══════════════════════════════════════════════" | tee -a "$REPORT_FILE"

  if [[ ! -f "$log" ]]; then
    echo "  No log file found: $log" | tee -a "$REPORT_FILE"
    return 1
  fi

  local cpu_vals; cpu_vals=$(grep 'METRIC' "$log" | grep -oP 'CPU=\K[0-9.]+')
  local mem_vals; mem_vals=$(grep 'METRIC' "$log" | grep -oP 'MEM=\K[0-9.]+')

  if [[ -n "$cpu_vals" ]]; then
    local cpu_max cpu_min cpu_avg
    cpu_max=$(echo "$cpu_vals" | sort -n | tail -1)
    cpu_min=$(echo "$cpu_vals" | sort -n | head -1)
    cpu_avg=$(echo "$cpu_vals" | awk '{s+=$1;c++} END{printf "%.1f",s/c}')
    echo ""                                                   | tee -a "$REPORT_FILE"
    echo "  CPU Usage"                                        | tee -a "$REPORT_FILE"
    echo "    Max   : ${cpu_max}%"                            | tee -a "$REPORT_FILE"
    echo "    Min   : ${cpu_min}%"                            | tee -a "$REPORT_FILE"
    echo "    Avg   : ${cpu_avg}%"                            | tee -a "$REPORT_FILE"
  fi

  if [[ -n "$mem_vals" ]]; then
    local mem_max mem_min mem_avg
    mem_max=$(echo "$mem_vals" | sort -n | tail -1)
    mem_min=$(echo "$mem_vals" | sort -n | head -1)
    mem_avg=$(echo "$mem_vals" | awk '{s+=$1;c++} END{printf "%.1f",s/c}')
    echo ""                                                   | tee -a "$REPORT_FILE"
    echo "  Memory Usage"                                     | tee -a "$REPORT_FILE"
    echo "    Max   : ${mem_max}%"                            | tee -a "$REPORT_FILE"
    echo "    Min   : ${mem_min}%"                            | tee -a "$REPORT_FILE"
    echo "    Avg   : ${mem_avg}%"                            | tee -a "$REPORT_FILE"
  fi

  local alert_count; alert_count=$(grep -c 'ALERT' "$log" 2>/dev/null || echo 0)
  echo ""                                                     | tee -a "$REPORT_FILE"
  echo "  Total Alerts Today : ${alert_count}"               | tee -a "$REPORT_FILE"
  echo "  Report saved       : $REPORT_FILE"                 | tee -a "$REPORT_FILE"
  echo "══════════════════════════════════════════════"       | tee -a "$REPORT_FILE"
}

# ── Daemon mode (silent, for cron) ─────────────────────────────────────────────
do_daemon() {
  log "Alert daemon started (interval: ${INTERVAL}s)"
  while true; do
    do_check > /dev/null
    sleep "$INTERVAL"
  done
}

# ── Entry point ────────────────────────────────────────────────────────────────
case "${1:-check}" in
  check)  do_check ;;
  report) do_report ;;
  daemon) do_daemon ;;
  *)      echo "Usage: $0 [check|report|daemon]"; exit 1 ;;
esac
