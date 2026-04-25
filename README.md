# 🖥 devops-monitor

> Production-ready shell scripts to monitor **CPU** and **Memory** on Linux servers — with live dashboards, alerting, per-core breakdown, and daily reports.

---

## 📁 Project Structure

```
devops-monitor/
├── scripts/
│   ├── monitor.sh        # All-in-one live dashboard (CPU + Memory)
│   ├── cpu_monitor.sh    # Dedicated CPU monitor (sparkline history, per-core)
│   ├── mem_monitor.sh    # Detailed memory monitor (breakdown + swap)
│   └── alert.sh          # Alerting engine (email + Slack + reports)
├── config/
│   └── monitor.conf      # All configuration in one place
├── logs/                 # Auto-created, rotated daily
├── install.sh            # One-command setup (permissions + cron)
└── README.md
```

---

## ⚡ Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/devops-monitor.git
cd devops-monitor
chmod +x install.sh && ./install.sh
```

Then run:

```bash
./scripts/monitor.sh          # Live CPU + Memory dashboard
./scripts/cpu_monitor.sh      # CPU-only monitor with sparkline
./scripts/mem_monitor.sh      # Memory deep-dive
./scripts/alert.sh check      # One-time check with alerting
./scripts/alert.sh report     # Daily summary report
```

---

## 🛠 Scripts

### `monitor.sh` — Combined Dashboard
Real-time CPU + Memory monitoring with colour-coded alerts and top process listings.

| Argument | Description                             |
|----------|-----------------------------------------|
| `run`    | (default) Live dashboard loop           |
| `once`   | Single snapshot to stdout + log         |

```bash
./scripts/monitor.sh        # live
./scripts/monitor.sh once   # one-shot
```

---

### `cpu_monitor.sh` — CPU Monitor
- Total CPU % with colour-coded status
- Scrolling **sparkline** (40-sample history)
- **Per-core** breakdown
- Load average (1m / 5m / 15m)

---

### `mem_monitor.sh` — Memory Monitor
- Total / Used / Available / Page Cache / Swap bars
- Detailed numeric table (MB + GB)
- Top memory consumers
- Shared memory & reclaimable breakdown

---

### `alert.sh` — Alert Engine

| Command  | Description                                |
|----------|--------------------------------------------|
| `check`  | One-time check; fires email/Slack if high  |
| `report` | Prints min/max/avg stats from today's log  |
| `daemon` | Silent loop (ideal for cron)               |

---

## ⚙️ Configuration (`config/monitor.conf`)

```bash
CPU_THRESHOLD=80       # Alert when CPU exceeds this %
MEM_THRESHOLD=85       # Alert when RAM exceeds this %
INTERVAL=5             # Seconds between samples
LOG_DIR=./logs         # Log output directory
MAX_LOG_DAYS=7         # Days before log rotation

ALERT_EMAIL=""         # e.g. devops@company.com
SLACK_WEBHOOK=""       # Slack Incoming Webhook URL
```

---

## 📬 Alerting

### Email
Requires `mail` or `sendmail` to be configured.

```bash
ALERT_EMAIL="ops@company.com"
```

### Slack
Create an [Incoming Webhook](https://api.slack.com/messaging/webhooks) and paste the URL:

```bash
SLACK_WEBHOOK="https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

---

## ⏰ Cron Examples

```cron
# Check every 5 minutes
*/5 * * * * /path/to/devops-monitor/scripts/alert.sh check >> /path/to/logs/cron.log 2>&1

# Daily report at 8 AM
0 8 * * * /path/to/devops-monitor/scripts/alert.sh report >> /path/to/logs/reports.log 2>&1

# Continuous log (collect metrics every minute silently)
* * * * * /path/to/devops-monitor/scripts/monitor.sh once >> /dev/null 2>&1
```

Install via `./install.sh` to set these up automatically.

---

## 📊 Sample Log Output

```
[2026-04-25 14:00:01] [METRIC] CPU=12.4% MEM=61.3% (4994/8192 MB)
[2026-04-25 14:00:06] [METRIC] CPU=78.1% MEM=84.2% (6898/8192 MB)
[2026-04-25 14:00:06] [ALERT]  HIGH CPU: 78.1% exceeds threshold 80%
[2026-04-25 14:00:06] [ALERT]  HIGH MEM: 84.2% exceeds threshold 85%
```

---

## ✅ Requirements

| Requirement | Notes                              |
|-------------|------------------------------------|
| Linux       | Uses `/proc/stat` and `/proc/meminfo` |
| Bash ≥ 4    | All features tested on bash 4+     |
| `ps`, `awk` | Standard on all Linux distros      |
| `curl`      | Optional — needed for Slack alerts |
| `mail`      | Optional — needed for email alerts |

> **macOS users:** Replace `grep 'cpu ' /proc/stat` with `top -l 2 | grep "CPU usage" | tail -1`.

---

## 📝 License

MIT License — free to use, modify, and distribute.

---

## 🤝 Contributing

PRs welcome! Ideas for improvement:
- Disk I/O monitoring
- Network bandwidth tracking
- PagerDuty / Teams integration
- Prometheus metrics export endpoint
