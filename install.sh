#!/bin/bash
# =============================================================================
# install.sh — Setup devops-monitor on any Linux system
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✔${RESET} $*"; }
info() { echo -e "  ${CYAN}→${RESET} $*"; }

echo -e "\n${BOLD}${CYAN}  DevOps Monitor — Installer${RESET}\n"

# Make all scripts executable
info "Setting execute permissions..."
chmod +x "$SCRIPT_DIR"/scripts/*.sh
ok "Scripts are now executable"

# Create logs directory
info "Creating logs directory..."
mkdir -p "$SCRIPT_DIR/logs"
ok "Logs directory ready: $SCRIPT_DIR/logs"

# Verify /proc/stat availability (Linux check)
if [[ ! -f /proc/stat ]]; then
  echo -e "\n  ⚠  /proc/stat not found. This tool is designed for Linux."
  echo -e "     macOS users: edit scripts to use 'top -l 1' instead.\n"
fi

# Optionally install cron job
echo
read -rp "  Install cron job for alert daemon (every 5 min)? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
  CRON_CMD="*/5 * * * * $SCRIPT_DIR/scripts/alert.sh check >> $SCRIPT_DIR/logs/cron.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'alert.sh'; echo "$CRON_CMD" ) | crontab -
  ok "Cron job installed: $CRON_CMD"
else
  info "Cron job skipped. You can run scripts manually."
fi

# Optionally install daily report cron
read -rp "  Install daily report cron (08:00 AM)? [y/N] " yn2
if [[ "$yn2" =~ ^[Yy]$ ]]; then
  REPORT_CRON="0 8 * * * $SCRIPT_DIR/scripts/alert.sh report >> $SCRIPT_DIR/logs/reports.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'alert.sh report'; echo "$REPORT_CRON" ) | crontab -
  ok "Daily report cron installed (08:00 AM)"
fi

echo -e "\n${BOLD}  ✅  Installation complete!${RESET}\n"
echo "  Quick start:"
echo "    ./scripts/monitor.sh          → live dashboard (CPU + Memory)"
echo "    ./scripts/cpu_monitor.sh      → CPU-only monitor"
echo "    ./scripts/mem_monitor.sh      → Memory-only monitor"
echo "    ./scripts/alert.sh check      → one-time check"
echo "    ./scripts/alert.sh report     → daily summary report"
echo
echo "  Config: $SCRIPT_DIR/config/monitor.conf"
echo "  Logs  : $SCRIPT_DIR/logs/"
echo
