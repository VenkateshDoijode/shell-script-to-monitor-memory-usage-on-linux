#!/bin/bash
# =============================================================================
# mem_monitor.sh — Detailed Memory Monitor
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/monitor.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

MEM_THRESHOLD="${MEM_THRESHOLD:-85}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/../logs}"
LOG_FILE="$LOG_DIR/mem_$(date +%Y%m%d).log"
INTERVAL="${INTERVAL:-5}"

mkdir -p "$LOG_DIR"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; RESET='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MEM] $*" >> "$LOG_FILE"; }

get_meminfo() {
  declare -A m
  while IFS=': ' read -r key val _; do
    m["$key"]="${val// /}"
  done < /proc/meminfo
  echo "${m[MemTotal]} ${m[MemFree]} ${m[MemAvailable]} ${m[Buffers]} ${m[Cached]} ${m[SwapTotal]} ${m[SwapFree]} ${m[Shmem]} ${m[SReclaimable]}"
}

to_mb() { echo $(( $1 / 1024 )); }
to_gb() { awk "BEGIN{printf \"%.2f\", $1/1048576}"; }

pct_bar() {
  local pct=$1 width=36 label=$2 color=$3
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar="["
  for ((i=0;i<filled;i++)); do bar+="█"; done
  for ((i=0;i<empty;i++));  do bar+="░"; done
  bar+="]"
  printf "  %-14s ${color}%s${RESET} %d%%\n" "$label" "$bar" "$pct"
}

while true; do
  read -r MemTotal MemFree MemAvail Buffers Cached SwapTotal SwapFree Shmem Reclaim \
    <<< "$(get_meminfo)"

  # Derived values (kB)
  MemUsed=$(( MemTotal - MemAvail ))
  PageCache=$(( Cached + Buffers ))
  AppUsed=$(( MemUsed - PageCache ))
  SwapUsed=$(( SwapTotal - SwapFree ))

  # Percentages
  mem_pct=$(( MemUsed * 100 / MemTotal ))
  swap_pct=0
  (( SwapTotal > 0 )) && swap_pct=$(( SwapUsed * 100 / SwapTotal ))
  cache_pct=$(( PageCache * 100 / MemTotal ))
  app_pct=$(( AppUsed * 100 / MemTotal ))

  # Colour
  if (( mem_pct >= MEM_THRESHOLD )); then c=$RED; label="CRITICAL ⚠"
  elif (( mem_pct >= MEM_THRESHOLD - 15 )); then c=$YELLOW; label="WARNING  ⚡"
  else c=$GREEN; label="NORMAL   ✔"; fi

  if (( swap_pct >= 50 )); then sc=$RED
  elif (( swap_pct >= 25 )); then sc=$YELLOW
  else sc=$GREEN; fi

  clear
  echo -e "${BOLD}${MAGENTA}┌────────────────────────────────────────────┐"
  echo -e "│       MEMORY MONITOR  — $(date '+%H:%M:%S')          │"
  echo -e "└────────────────────────────────────────────┘${RESET}"
  echo
  echo -e "  ${BOLD}Host:${RESET} $(hostname)   ${BOLD}Total RAM:${RESET} $(to_gb $MemTotal) GB ($(to_mb $MemTotal) MB)"
  echo

  # Summary line
  echo -e "  RAM Used: ${c}${BOLD}$(to_mb $MemUsed) MB / $(to_mb $MemTotal) MB${RESET}  —  ${c}${BOLD}${mem_pct}%${RESET}  ${c}${label}${RESET}"
  echo

  # Bars
  pct_bar "$mem_pct"   "Total Used"  "$c"
  pct_bar "$app_pct"   "App/Process" "$CYAN"
  pct_bar "$cache_pct" "Page Cache"  "$MAGENTA"
  pct_bar "$swap_pct"  "Swap Used"   "$sc"
  echo

  # Detailed table
  echo -e "  ${BOLD}── Detailed Breakdown ────────────────────────${RESET}"
  printf "  %-22s %10s MB  (%s GB)\n" "Total RAM"       "$(to_mb $MemTotal)"   "$(to_gb $MemTotal)"
  printf "  %-22s %10s MB  (%s GB)\n" "Used (total)"    "$(to_mb $MemUsed)"    "$(to_gb $MemUsed)"
  printf "  %-22s %10s MB\n"          "  └ App/Process" "$(to_mb $AppUsed)"
  printf "  %-22s %10s MB\n"          "  └ Page Cache"  "$(to_mb $PageCache)"
  printf "  %-22s %10s MB  (%s GB)\n" "Available"       "$(to_mb $MemAvail)"   "$(to_gb $MemAvail)"
  printf "  %-22s %10s MB\n"          "Shared (shmem)"  "$(to_mb $Shmem)"
  printf "  %-22s %10s MB\n"          "Reclaimable"     "$(to_mb $Reclaim)"
  echo   "  ─────────────────────────────────────────────"
  printf "  %-22s %10s MB  (%s GB)\n" "Swap Total"      "$(to_mb $SwapTotal)"  "$(to_gb $SwapTotal)"
  printf "  %-22s %10s MB\n"          "Swap Used"       "$(to_mb $SwapUsed)"
  printf "  %-22s %10s MB\n"          "Swap Free"       "$(to_mb $SwapFree)"
  echo

  # Top memory consumers
  echo -e "  ${BOLD}── Top Memory Consumers ──────────────────────${RESET}"
  ps aux --sort=-%mem | awk '
    NR==1 {printf "  %-10s %-7s %-7s %s\n","USER","PID","%MEM","COMMAND"}
    NR>1 && NR<=8 {printf "  %-10s %-7s %-7s %s\n",$1,$2,$4,$11}
  '
  echo
  echo -e "  ${BOLD}Log:${RESET} $LOG_FILE  |  Threshold: ${MEM_THRESHOLD}%"
  echo -e "  Ctrl+C to stop  |  Refreshing every ${INTERVAL}s"

  log "used=${mem_pct}% ($(to_mb $MemUsed)/$(to_mb $MemTotal) MB) swap=${swap_pct}%"
  (( mem_pct >= MEM_THRESHOLD )) && log "ALERT: Memory ${mem_pct}% exceeded threshold ${MEM_THRESHOLD}%"

  sleep "$INTERVAL"
done
