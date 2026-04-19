# Traffmonetizer One-Click Installation

[English](README.md) | [中文文档](README_zh.md)

## Introduction

[Traffmonetizer](https://traffmonetizer.com/?aff=986423) allows you to earn passive income by sharing your unused bandwidth.

You earn **$0.10 per 1GB** of traffic shared, supporting both data center and home networks.

This is the **first one-click installation script** that automatically handles all dependencies and Docker setup. Key features:

- Auto-installs Docker if not already present (skips if installed)
- Auto-selects the correct Docker image based on system architecture
- Auto-updates via [Watchtower](https://containrrr.dev/watchtower/) — no manual image pulls needed

> **Tested on:** AMD64 and ARM architectures

## Quick Start

Register at [traffmonetizer.com](https://traffmonetizer.com/?aff=986423) (get $5 bonus), then copy your token from the dashboard.

Choose an installation method below based on your environment:

| Environment | Script | Docker Required |
|-------------|--------|:---------------:|
| Standard VPS / Server | `tm.sh` | Yes |
| LXC Container | `tm_lxc.sh` | Optional |
| Docker / WSL2 / No systemd | `tm_simple.sh` | No |

## Installation

### Method 1: Standard (Docker-based) — `tm.sh`

Best for: **regular VPS, dedicated servers, cloud instances**

#### Interactive

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh
```

The script will prompt you to enter your token.

#### One-command

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh -t YOUR_TOKEN
```

Replace `YOUR_TOKEN` with your actual token.

---

### Method 2: LXC Container — `tm_lxc.sh`

Best for: **LXC/LXD containers** (Proxmox, etc.)

Auto-detects init system: systemd (Debian/Ubuntu) or OpenRC (Alpine).

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_lxc.sh -o tm_lxc.sh && chmod +x tm_lxc.sh && bash tm_lxc.sh -t YOUR_TOKEN
```

Omit `-t` to enter token interactively.

#### Binary mode (low memory / no Docker)

The script supports running without Docker by using the binary directly:

```shell
# Auto-download binary from GitHub (default behavior)
bash tm_lxc.sh -t YOUR_TOKEN

# Or specify a local binary
bash tm_lxc.sh -t YOUR_TOKEN -b /path/to/traffmonetizer.bin

# Or specify a custom download URL
bash tm_lxc.sh -t YOUR_TOKEN --binary-url https://example.com/traffmonetizer.bin
```

**Priority:** local binary > download from GitHub > Docker extraction

> **Low memory tip:** If the process gets **Killed** (OOM), either allocate at least **512MB** memory to the container, or add swap before running (the script auto-creates temporary swap when low memory is detected).

---

### Method 3: Minimal (No Docker / No systemd) — `tm_simple.sh`

Best for: **Docker containers, WSL2, Alpine containers**, or any environment without systemd or Docker access.

Features: no Docker needed, no systemd needed, built-in process management with start/stop/restart/status/logs.

#### Setup

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_simple.sh -o tm_simple.sh && chmod +x tm_simple.sh
```

#### Usage

```shell
./tm_simple.sh start YOUR_TOKEN   # Start with token
./tm_simple.sh start              # Start (interactive token input)
./tm_simple.sh status             # Check status
./tm_simple.sh logs               # View real-time logs
./tm_simple.sh stop               # Stop service
./tm_simple.sh restart            # Restart service
./tm_simple.sh help               # Show help
```

> **Notes:**
> - Requires `traffmonetizer.bin` in the current directory
> - Log file: `/tmp/traffmonetizer.log`, PID file: `/tmp/traffmonetizer.pid`
> - In container environments, use `nohup` or `screen`/`tmux` to keep the session alive
> - After container restart, manually restart the service or add to startup script

## Uninstall

```shell
bash tm.sh -u
```

## Earnings Reference

Single IP daily income (for reference only):

| Region | Daily Income (per IP) |
|--------|----------------------|
| Europe | $0.010 – $0.015 |
| US | $0.013 – $0.020 |

> The more users there are, the lower individual earnings become.

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/a.png)

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/b.png)

## Disclaimer

This program is for educational purposes only. Please delete within 24 hours of download. Not for commercial use. Text, data, and images are copyrighted — cite the source if reproduced.

Usage is subject to the laws and regulations of the server's location, the deployer's country, and the user's country. The author assumes no responsibility for any misuse.
