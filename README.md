# 🖥️ Linux System Resource Monitor

A lightweight, terminal-based system monitoring suite for Linux — featuring real-time CPU & memory dashboards, threshold-based alerting via Email and Slack, daily summary reports, and a set of log analysis utilities. No external dependencies beyond standard POSIX tools.

---

## 📋 Table of Contents

- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
  - [Live Dashboards](#live-dashboards)
  - [Alert Engine](#alert-engine)
  - [Log Analysis Utilities](#log-analysis-utilities)
- [Alerting Channels](#-alerting-channels)
- [Log Management](#-log-management)
- [Cron Automation](#-cron-automation)
- [Screenshots](#-screenshots)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

| Feature | Description |
|---|---|
| **Combined Dashboard** | Live CPU + memory monitor with colour-coded status bars |
| **Memory Monitor** | Detailed RAM breakdown — app usage, page cache, swap, reclaimable |
| **CPU Monitor** | Per-core usage, load averages, rolling sparkline history graph |
| **Threshold Alerts** | Configurable CRITICAL / WARNING / NORMAL states |
| **Email Alerts** | Sends formatted alerts via `mail` when thresholds are breached |
| **Slack Alerts** | Posts alerts to a Slack channel via Incoming Webhook |
| **Daily Reports** | Aggregated min/max/avg CPU & memory statistics from log files |
| **Log Analysis** | Utilities for error counting, time-range filtering, and slow API detection |
| **Auto Log Rotation** | Removes log files older than a configurable number of days |
| **Rate-limited Alerts** | Cooldown mechanism prevents alert storms |

---

## 📁 Project Structure

```
shell-script-to-monitor-memory-usage-on-linux/
│
├── install.sh                    # One-command setup: permissions, dirs, cron
│
├── scripts/
│   ├── monitor.sh                # Combined CPU + Memory live dashboard
│   ├── mem_monitor.sh            # Memory-only detailed monitor
│   ├── cpu_monitor.sh            # CPU-only monitor with sparkline history
│   └── alert.sh                  # Alert & reporting engine (check / report / daemon)
│
├── config/
│   └── monitor.conf              # Central configuration file (thresholds, email, Slack)
│
├── check-vps-memory-usage.sh     # Standalone VPS health check with email alert
├── count-errors-warnings.sh      # Count ERROR / WARN / INFO lines in a log file
├── daily-summary-report.sh       # Generate a daily log summary report
├── frequent-errors.sh            # Show top 10 most frequent errors in a log
├── logs-within-time-range.sh     # Extract log entries within a time window
├── slow-api-detection.sh         # Detect slow API responses above a threshold (ms)
│
└── logs/                         # Auto-created; holds all monitor & alert logs
```

---

## 🔧 Prerequisites

- **OS:** Linux (reads `/proc/stat` and `/proc/meminfo`)
- **Shell:** Bash 4.0+
- **Tools:** `awk`, `ps`, `grep`, `df`, `free`, `uptime` — all present in standard Linux installs
- **Optional for alerts:**
  - `mail` / `sendmail` — for email alerts
  - `curl` — for Slack webhook alerts

> **macOS users:** The CPU scripts read `/proc/stat` which is Linux-only. Replace `get_cpu_usage()` with `top -l 1 | grep "CPU usage"` for macOS compatibility.

---

## 🚀 Installation

### 1. Clone the repository

```bash
git clone https://github.com/your-username/shell-script-to-monitor-memory-usage-on-linux.git
cd shell-script-to-monitor-memory-usage-on-linux
```

### 2. Run the installer

```bash
bash install.sh
```

The installer will:
- Set execute permissions on all scripts in `scripts/`
- Create the `logs/` directory
- Optionally install a cron job to run `alert.sh check` every 5 minutes
- Optionally install a daily report cron job at 08:00 AM

### 3. Configure (optional but recommended)

```bash
nano config/monitor.conf
```

Set your email, Slack webhook URL, and thresholds before running.

---

## ⚙️ Configuration

All settings live in `config/monitor.conf`. Every script sources this file at startup.

```bash
# ── Thresholds ──────────────────────────────────────────
CPU_THRESHOLD=80          # Alert when CPU usage exceeds this %
MEM_THRESHOLD=85          # Alert when memory usage exceeds this %

# ── Monitoring interval ─────────────────────────────────
INTERVAL=5                # Seconds between each metrics sample

# ── Logging ─────────────────────────────────────────────
LOG_DIR="./logs"          # Directory for log files
MAX_LOG_DAYS=7            # Days before old logs are deleted

# ── Email alerts ────────────────────────────────────────
ALERT_EMAIL=""            # e.g. devops@yourcompany.com

# ── Slack alerts ────────────────────────────────────────
SLACK_WEBHOOK=""          # e.g. https://hooks.slack.com/services/XXX/YYY/ZZZ
```

Leave `ALERT_EMAIL` and `SLACK_WEBHOOK` empty to disable those channels.

---

## 🖥️ Usage

### Live Dashboards

#### Combined CPU + Memory Monitor (recommended entry point)

```bash
./scripts/monitor.sh          # Live dashboard (default)
./scripts/monitor.sh once     # Single snapshot, then exit
```

**What you see:**
- Colour-coded CPU & memory progress bars
- NORMAL ✔ / WARNING ⚡ / CRITICAL ⚠ status
- Top CPU and memory consumer process tables
- Live log file path and refresh interval

---

#### Memory-Only Detailed Monitor

```bash
./scripts/mem_monitor.sh
```

**Displays:**
- Total used, app/process, page cache, and swap bars
- Full `/proc/meminfo` breakdown in MB and GB
- Top memory-consuming processes
- Refreshes every `INTERVAL` seconds (default: 5s)

**Memory status thresholds:**

| State | Condition |
|---|---|
| ✔ NORMAL | Usage < `MEM_THRESHOLD - 15`% |
| ⚡ WARNING | Usage ≥ `MEM_THRESHOLD - 15`% |
| ⚠ CRITICAL | Usage ≥ `MEM_THRESHOLD`% |

---

#### CPU-Only Monitor with History Graph

```bash
./scripts/cpu_monitor.sh
```

**Displays:**
- Total CPU percentage with ASCII progress bar
- Rolling 40-sample sparkline history (▁▂▃▄▅▆▇█)
- 1m / 5m / 15m load averages
- Per-core breakdown with individual colour coding
- Refreshes every `INTERVAL` seconds (default: 3s)

---

### Alert Engine

`alert.sh` supports three modes:

#### One-time Check

```bash
./scripts/alert.sh check
```

Reads current CPU and memory, prints a summary, and fires email + Slack alerts if any threshold is breached.

#### Daily Summary Report

```bash
./scripts/alert.sh report
```

Parses today's log file and prints a report showing min, max, and average CPU and memory usage, plus total alert count.

#### Background Daemon (for cron)

```bash
./scripts/alert.sh daemon
```

Runs silently in the background, checking metrics every `INTERVAL` seconds. Designed for use with cron or `systemd`.

---

### Standalone VPS Health Check

```bash
bash check-vps-memory-usage.sh
```

A self-contained script that checks RAM, CPU, and disk. If any metric exceeds its threshold, it emails a full report including top processes and disk usage. Uses a 15-minute cooldown lock to prevent alert spam.

Default thresholds in this script (edit at the top of the file):

| Metric | Default Threshold |
|---|---|
| RAM | 45% |
| CPU | 70% |
| Disk | 80% |

---

### Log Analysis Utilities

These standalone scripts accept a log file as the first argument (defaults to `app.log`).

#### Count errors and warnings

```bash
bash count-errors-warnings.sh [logfile]
```

Outputs a summary of ERROR, WARN, and INFO line counts.

#### Top frequent errors

```bash
bash frequent-errors.sh [logfile]
```

Shows the top 10 most repeated error messages, sorted by frequency.

#### Daily summary report from a log file

```bash
bash daily-summary-report.sh [logfile]
```

Saves a dated report file (`report_YYYY-MM-DD.txt`) with total log count, error count, and top 5 unique errors.

#### Filter logs by time range

```bash
bash logs-within-time-range.sh [logfile]
```

Extracts log entries between `START_TIME` and `END_TIME` (edit the variables at the top of the script). Expected log format: `YYYY-MM-DD HH:MM:SS LEVEL message`.

#### Detect slow API responses

```bash
bash slow-api-detection.sh [logfile]
```

Prints lines where the last field (response time in ms) exceeds the configured threshold (default: 500ms). Expected log format: `YYYY-MM-DD METHOD /path STATUS response_ms`.

---

## 📣 Alerting Channels

### Email

Requires `mail` or `sendmail` to be configured on the host. Set `ALERT_EMAIL` in `monitor.conf`:

```bash
ALERT_EMAIL="devops@yourcompany.com"
```

Alert emails include hostname, timestamp, usage percentages, and the top consuming processes.

### Slack

Create an [Incoming Webhook](https://api.slack.com/messaging/webhooks) in your Slack workspace and paste the URL:

```bash
SLACK_WEBHOOK="https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

---

## 📂 Log Management

All monitors write structured log files to `LOG_DIR` (default: `./logs/`):

| File | Contents |
|---|---|
| `logs/monitor_YYYYMMDD.log` | Combined CPU + memory metrics and alerts |
| `logs/mem_YYYYMMDD.log` | Memory-only metrics and alerts |
| `logs/cpu_YYYYMMDD.log` | CPU-only metrics and alerts |
| `logs/alert.log` | Alert engine events |
| `logs/report_YYYYMMDD.txt` | Daily summary reports |

Log entries follow the format:
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

Log rotation is automatic: files older than `MAX_LOG_DAYS` days are deleted each time `monitor.sh` starts.

---

## ⏰ Cron Automation

The installer can configure these cron jobs automatically. To add them manually:

```bash
crontab -e
```

```cron
# Run alert check every 5 minutes
*/5 * * * * /path/to/scripts/alert.sh check >> /path/to/logs/cron.log 2>&1

# Generate daily report at 08:00 AM
0 8 * * * /path/to/scripts/alert.sh report >> /path/to/logs/reports.log 2>&1
```

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m "Add your feature"`
4. Push to your branch: `git push origin feature/your-feature`
5. Open a Pull Request

Please keep scripts POSIX-compatible where possible and test on at least one Linux distribution before submitting.

---

## 📄 License

This project is open source. See [LICENSE](LICENSE) for details.

---

> **Tip:** Run `./install.sh` first — it sets up everything in under 30 seconds.
