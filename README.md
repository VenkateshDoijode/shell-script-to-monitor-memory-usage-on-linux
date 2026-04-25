# 🖥️ Shell Script to Monitor Memory Usage on Linux

> A lightweight, production-ready collection of Bash scripts to monitor **RAM**, **CPU**, and **Disk** usage on Linux servers — with intelligent email alerting, cooldown-protected notifications, and a full log analysis toolkit.

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)](https://www.linux.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Script Reference](#-script-reference)
- [Configuration](#%EF%B8%8F-configuration)
- [Cron Automation](#-cron-automation)
- [Sample Output](#-sample-output)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🔍 Overview

This project provides a suite of Bash scripts for Linux server health monitoring and log analytics. The core monitoring script polls RAM, CPU, and Disk at runtime, evaluates each metric against configurable thresholds, and sends a consolidated email alert with full process details — with a built-in **cooldown mechanism** that prevents alert spam during sustained high-load events.

The supplementary log-analysis scripts can be used independently via cron or CI pipelines to parse application log files, extract error patterns, detect slow API calls, and generate daily summary reports.

---

## ✨ Features

- **Multi-metric monitoring** — RAM, CPU, and Disk usage in a single check
- **Smart cooldown alerting** — rate-limited to one alert per 15 minutes via lock file
- **Detailed email reports** — includes top processes by CPU and memory, full disk breakdown, and server uptime
- **Configurable thresholds** — set independent percentage limits for RAM, CPU, and Disk
- **Log analysis toolkit** — count errors/warnings, find frequent errors, filter by time range, detect slow APIs
- **Daily summary reports** — auto-generated log digests written to dated report files
- **Cron-ready** — all scripts designed for unattended scheduled execution
- **Zero dependencies** — uses only standard Linux utilities (`free`, `top`, `df`, `ps`, `awk`, `grep`, `mail`)

---

## 📁 Project Structure

```
shell-script-to-monitor-memory-usage-on-linux/
│
├── check-vps-memory-usage.sh     # Core monitor: RAM + CPU + Disk alerting
├── count-errors-warnings.sh      # Count ERROR / WARN / INFO lines in a log
├── daily-summary-report.sh       # Generate a dated daily log summary report
├── frequent-errors.sh            # Show top 10 most repeated error lines
├── logs-within-time-range.sh     # Filter log entries between two timestamps
├── slow-api-detection.sh         # Flag API responses exceeding a time threshold
├── install.sh                    # Automated setup with optional cron registration
├── .gitignore                    # Excludes logs, temp files, and .env
└── README.md                     # This file
```

---

## ✅ Prerequisites

| Requirement | Purpose | Notes |
|---|---|---|
| **Linux** | Runtime environment | Tested on Ubuntu, Debian, CentOS |
| **Bash ≥ 3.2** | Script interpreter | Pre-installed on all major distros |
| `free`, `top`, `df`, `ps` | System metrics | Part of `procps` / `util-linux` |
| `awk`, `grep`, `sort`, `uniq` | Log analysis | Part of `gawk` / `grep` (standard) |
| `mail` / `sendmail` | Email alerts | Install via `mailutils` or `postfix` |

### Install `mail` (if not present)

```bash
# Debian / Ubuntu
sudo apt-get install mailutils -y

# RHEL / CentOS
sudo yum install mailx -y
```

---

## ⚡ Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/shell-script-to-monitor-memory-usage-on-linux.git
cd shell-script-to-monitor-memory-usage-on-linux
```

### 2. Run the installer

```bash
chmod +x install.sh
./install.sh
```

The installer sets execute permissions on all scripts, creates the `logs/` directory, and optionally registers cron jobs for the alert daemon and daily report.

### 3. Configure your alert email and thresholds

Open `check-vps-memory-usage.sh` and edit the CONFIG block at the top:

```bash
TO="your-email@example.com"
RAM_THRESHOLD=45    # Alert when RAM usage exceeds 45%
CPU_THRESHOLD=70    # Alert when CPU usage exceeds 70%
DISK_THRESHOLD=80   # Alert when Disk usage exceeds 80%
COOLDOWN=900        # Minimum seconds between repeated alerts (15 min)
```

### 4. Run a manual check

```bash
./check-vps-memory-usage.sh
```

If any threshold is breached, an email is dispatched immediately with a full system report.

---

## 📖 Script Reference

---

### `check-vps-memory-usage.sh` — Core System Monitor

The primary monitoring script. Collects RAM, CPU, and Disk metrics in real time, compares each against its threshold, and sends a single consolidated email alert if any limit is exceeded. A lock file at `/tmp/monitor_alert.lock` stores the last alert timestamp and enforces the cooldown window — so if the server stays under load for 20 minutes, only one or two emails are sent, not hundreds.

**Alert email includes:**
- RAM %, CPU %, Disk % summary
- Top 10 processes by memory consumption
- Top 10 processes by CPU consumption
- Full `df -h` disk breakdown
- Server uptime

**Usage:**

```bash
# Manual run
./check-vps-memory-usage.sh

# Via cron (every 5 minutes)
*/5 * * * * /path/to/check-vps-memory-usage.sh
```

**Configuration variables (edit inside the script):**

| Variable | Default | Description |
|---|---|---|
| `TO` | *(required)* | Recipient email address |
| `RAM_THRESHOLD` | `45` | RAM usage % that triggers an alert |
| `CPU_THRESHOLD` | `70` | CPU usage % that triggers an alert |
| `DISK_THRESHOLD` | `80` | Disk usage % that triggers an alert |
| `COOLDOWN` | `900` | Seconds between repeated alerts |
| `LOCK_FILE` | `/tmp/monitor_alert.lock` | Cooldown state file |

---

### `count-errors-warnings.sh` — Log Level Counter

Parses a log file and reports the count of `ERROR`, `WARN`, and `INFO` lines — useful for a quick health snapshot of an application log.

**Usage:**

```bash
./count-errors-warnings.sh /var/log/myapp/app.log
```

**Output:**

```
Log Analysis Summary:
Errors   : 42
Warnings : 118
Info     : 5320
```

If no argument is provided, the script defaults to `app.log` in the current directory.

---

### `daily-summary-report.sh` — Daily Log Digest

Generates a summary report from a log file and writes it to a dated text file (`report_YYYY-MM-DD.txt`). Reports total line count, error count, and the top 5 most frequent unique errors. Ideal for a daily cron job at midnight or early morning.

**Usage:**

```bash
./daily-summary-report.sh /var/log/myapp/app.log
# → Writes: report_2026-04-25.txt
```

**Report contains:**
- Timestamp header
- Total log line count
- Total error count
- Top 5 most repeated unique error messages

---

### `frequent-errors.sh` — Top Error Patterns

Extracts all lines matching `error` (case-insensitive), deduplicates them, and displays the top 10 most frequent patterns ranked by occurrence. Useful for identifying recurring failure modes in production logs.

**Usage:**

```bash
./frequent-errors.sh /var/log/myapp/app.log
```

**Output example:**

```
  47 ERROR: connection timeout to db-host:5432
  31 ERROR: null pointer exception in UserService
  18 ERROR: failed to parse JSON response
```

---

### `logs-within-time-range.sh` — Time-Range Log Filter

Filters and prints log entries that fall within a specified start and end timestamp. Assumes log lines begin with a `YYYY-MM-DD HH:MM:SS` timestamp in the first two space-separated fields.

**Usage:**

```bash
# Edit START_TIME and END_TIME inside the script, then:
./logs-within-time-range.sh /var/log/myapp/app.log
```

**Expected log format:**

```
2026-04-25 10:05:12 ERROR something broke
2026-04-25 10:07:44 INFO  request processed
```

> **Tip:** Parameterise `START_TIME` and `END_TIME` as script arguments for more flexible use in pipelines.

---

### `slow-api-detection.sh` — Slow Response Detector

Scans a log file and prints all lines where the last field (response time in milliseconds) exceeds the configured threshold. Useful for identifying performance regressions in API access logs.

**Usage:**

```bash
./slow-api-detection.sh /var/log/nginx/access.log
```

**Configuration (inside the script):**

```bash
THRESHOLD=500    # Flag responses taking longer than 500ms
```

**Expected log format:**

```
2026-04-25 GET /api/user 200 650
2026-04-25 GET /api/orders 200 120
```

The script outputs only the slow lines — those where response time exceeds `THRESHOLD`.

---

## ⚙️ Configuration

All primary configuration lives inside the top of `check-vps-memory-usage.sh`. No external config file is required — edit the variables in the `# CONFIG` block directly.

For log analysis scripts, the target log file is passed as the first argument (`$1`) with a fallback default of `app.log`. Time range and threshold values are set inline at the top of each respective script.

---

## ⏰ Cron Automation

Run `./install.sh` for guided cron setup, or add entries manually:

```cron
# Monitor RAM/CPU/Disk every 5 minutes
*/5 * * * * /path/to/check-vps-memory-usage.sh

# Generate a daily log summary at 08:00 AM
0 8 * * * /path/to/daily-summary-report.sh /var/log/myapp/app.log >> /var/log/monitor/daily.log 2>&1

# Check for frequent errors every hour
0 * * * * /path/to/frequent-errors.sh /var/log/myapp/app.log >> /var/log/monitor/errors.log 2>&1
```

> Replace `/path/to/` with the absolute path to your cloned repository.

---

## 📊 Sample Output

### Email Alert (triggered when a threshold is breached)

```
Subject: ⚠️ Server Alert on web-01 at Fri Apr 25 14:00:00 UTC 2026

SYSTEM ALERT REPORT
==============================
Host: web-01
Time: Fri Apr 25 14:00:00 UTC 2026

Usage Summary:
------------------------------
RAM  : 78%
CPU  : 82%
Disk : 64%

Top Memory Processes:
------------------------------
PID    PPID   %MEM  %CPU  COMMAND
1234   1      12.4  0.1   /usr/bin/python3 app.py
5678   1      8.1   45.2  /usr/sbin/mysqld
...

Disk Usage Details:
------------------------------
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   32G   18G  64% /

Uptime:
------------------------------
 14:00:00 up 42 days, 3:14,  2 users,  load average: 2.31, 1.87, 1.45
```

---

## 🤝 Contributing

Contributions are welcome! Here are some areas where the project could be extended:

- Disk I/O and network bandwidth monitoring
- Slack / Microsoft Teams / PagerDuty webhook alerting
- Prometheus metrics export via text file collector
- Configurable external `.conf` file (instead of inline variables)
- macOS / BSD compatibility layer

To contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m "feat: add slack alerting"`
4. Push and open a Pull Request

---

## 📝 License

This project is licensed under the **MIT License** — free to use, modify, and distribute for personal and commercial purposes.

---

> **Author:** DevOps Engineer | **Platform:** Linux (Ubuntu / Debian / CentOS / RHEL) | **Shell:** Bash
