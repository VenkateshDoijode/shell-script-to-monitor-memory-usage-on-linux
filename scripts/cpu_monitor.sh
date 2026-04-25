#!/bin/bash
# =============================================================================
# cpu_monitor.sh — Dedicated CPU Monitor with historical graph
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/monitor.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
LOG_FILE="$LOG_DIR/cpu_$(date +%Y%m%d).log"
INTERVAL="${INTERVAL:-3}"
HISTORY_SIZE=40          # number of samples in sparkline
declare -a HISTORY=()

mkdir -p "$LOG_DIR"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

get_cpu_all_cores() {
  grep '^cpu' /proc/stat | awk '
  NR==1 { next }   # skip aggregate line
  {
    idle=$5; total=0
    for(i=2;i<=NF;i++) total+=$i
    pct = (total==0) ? 0 : 100 - (idle*100/total)
    printf "Core%-2d: %.1f%%\n", NR-2, pct
  }'
}

get_cpu_usage() {
  grep 'cpu ' /proc/stat | awk '{
    idle=$5; total=0
    for(i=2;i<=NF;i++) total+=$i
    printf "%.1f", 100 - (idle*100/total)
  }'
}

get_load_avg() {
  awk '{print $1, $2, $3}' /proc/loadavg
}

sparkline() {
  # Map values to block chars
  local blocks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  local line=""
  for v in "${HISTORY[@]}"; do
    local idx=$(( ${v%.*} * 7 / 100 ))
    (( idx > 7 )) && idx=7
    line+="${blocks[$idx]}"
  done
  echo "$line"
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CPU] $*" >> "$LOG_FILE"
}

alert_count=0

while true; do
  cpu=$(get_cpu_usage)
  cpu_int="${cpu%.*}"

  # maintain rolling history
  HISTORY+=("$cpu_int")
  (( ${#HISTORY[@]} > HISTORY_SIZE )) && HISTORY=("${HISTORY[@]:1}")

  read -r load1 load5 load15 <<< "$(get_load_avg)"
  nproc=$(nproc 2>/dev/null || echo 1)

  clear
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────┐"
  echo -e "│         CPU MONITOR  — $(date '+%H:%M:%S')        │"
  echo -e "└─────────────────────────────────────────┘${RESET}"
  echo

  # Colour threshold
  if (( cpu_int >= CPU_THRESHOLD )); then
    c=$RED; label="CRITICAL ⚠"
  elif (( cpu_int >= CPU_THRESHOLD - 20 )); then
    c=$YELLOW; label="WARNING  ⚡"
  else
    c=$GREEN;  label="NORMAL   ✔"
  fi

  # Big percentage
  echo -e "  Total CPU:  ${c}${BOLD}${cpu}%${RESET}   ${c}${label}${RESET}"
  echo

  # ASCII bar
  bar_width=40
  filled=$(( cpu_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar="["
  for ((i=0;i<filled;i++)); do bar+="█"; done
  for ((i=0;i<empty;i++));  do bar+="░"; done
  bar+="]"
  echo -e "  ${c}${bar}${RESET}"
  echo

  # Sparkline
  echo -e "  ${BOLD}History (${HISTORY_SIZE}s):${RESET}"
  echo -e "  ${CYAN}$(sparkline)${RESET}  ← now"
  echo

  # Load average
  echo -e "  ${BOLD}Load Average:${RESET}  1m: ${load1}  5m: ${load5}  15m: ${load15}"
  echo -e "  ${BOLD}CPU Cores:${RESET}     ${nproc} logical cores"
  echo

  # Per-core breakdown
  echo -e "  ${BOLD}Per-Core Usage:${RESET}"
  get_cpu_all_cores | while IFS= read -r line; do
    pct="${line##*: }"; pct="${pct%%%*}"
    pct_i="${pct%.*}"
    if (( pct_i >= 80 )); then cc=$RED
    elif (( pct_i >= 50 )); then cc=$YELLOW
    else cc=$GREEN; fi
    printf "    ${cc}%s${RESET}\n" "$line"
  done
  echo

  echo -e "  ${BOLD}Log:${RESET} $LOG_FILE  |  Threshold: ${CPU_THRESHOLD}%"
  echo -e "  Ctrl+C to stop | Interval: ${INTERVAL}s"

  # Log and alert
  log "cpu=${cpu}% load=${load1}/${load5}/${load15}"

  if (( cpu_int >= CPU_THRESHOLD )); then
    (( alert_count++ ))
    log "ALERT #${alert_count}: CPU ${cpu}% exceeded threshold ${CPU_THRESHOLD}%"
  fi

  sleep "$INTERVAL"
done
