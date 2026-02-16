# traffmonetizer-one-click-command-installation

## Language

[English](README.md) | [中文文档](README_zh.md)

## **Introduction**

The traffmonetizer is an option that allows users to earn money by sharing your traffic.

You'll receive $0.10 for the 1G traffic you share, and this script supports data center network or home bandwidth.

This is the **first one-click installation script of the whole network** to automatically install dependencies and pull and install the latest docker, and the script will continue to be improved according to the platform update.

It has below features:

1. Automatically install docker based on the system, and if docker are already installed, it will not installed again.

2. Automatically select and build the pulled docker image according to the architecture, without the need for you to manually modify the official case.

3. Use Watchtower for automatic mirror update without manual update and re-entry of parameters.

(Watchtower is a utility that automates the updating of Docker images and containers. It monitors all running containers and related images, and automatically pulls the latest image and uses parameters when initially deployed to restart the corresponding container.)

## Notes

- Verified on AMD64 and ARM
- Try it if you are interested via my --> [referrals](https://traffmonetizer.com/?aff=986423) <--, you will get 5 dollar.

## Install

### Interactive installation

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh
```

After the registration link is registered, copy the token in the upper left corner, run my script, paste the token, and press Enter to start the installation.

### One command installation

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh -t XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k=
```

Change to your token at the end of this command

### LXC installation (extract binary + service auto-detection)

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_lxc.sh -o tm_lxc.sh && chmod +x tm_lxc.sh && bash tm_lxc.sh -t XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k=
```

If `-t` is not passed, just run `bash tm_lxc.sh` and it will ask for token interactively.
The script auto-detects init system: systemd on Debian/Ubuntu, OpenRC on Alpine.

### Minimal Environment + Daemon (No systemd/Docker)

For environments **without systemd** or with **Docker restrictions** (Docker containers, WSL2, Alpine containers, etc).

#### Features
- No Docker required, no systemd needed
- Runs the binary directly
- Supports `start` (basic) and `daemon` (with auto-restart watchdog)
- PID file and log management built-in
- Simple shell script, no dependencies

#### Usage

1. Download the simple script:

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_simple.sh -o tm_simple.sh
chmod +x tm_simple.sh
```

2. Start the service (without watchdog):

```shell
./tm_simple.sh start YOUR_TOKEN
```

3. Or start with daemon mode (recommended for production):

```shell
./tm_simple.sh daemon YOUR_TOKEN
```

The daemon mode spawns a lightweight watchdog that checks every 30 seconds and auto-restarts the process if it crashes (up to 10 retries). Monitor logs: `/tmp/traffmonetizer_monitor.log`.

#### Commands

```shell
./tm_simple.sh start [token]     # Start service (token optional if provided)
./tm_simple.sh daemon [token]    # Start service + watchdog
./tm_simple.sh stop              # Stop service + watchdog
./tm_simple.sh stopmonitor       # Stop watchdog only
./tm_simple.sh status            # Show status
./tm_simple.sh logs              # Tail -f log file
./tm_simple.sh restart [token]   # Restart (with watchdog)
./tm_simple.sh help              # Show help
```

#### Files

- Main log: `/tmp/traffmonetizer.log`
- PID file: `/tmp/traffmonetizer.pid`
- Watchdog log: `/tmp/traffmonetizer_monitor.log`
- Watchdog PID: `/tmp/traffmonetizer_monitor.pid`

#### Notes
- The script expects `traffmonetizer.bin` in the same directory
- For custom paths, edit `BIN_PATH` in the script
- In containers/WSL, consider adding to startup scripts if persistence required
- Watchdog interval: 30s, max restart attempts: 10

### Low Memory / No Docker Scenarios (Local Binary)

If your LXC has low memory, or Docker daemon is unavailable inside the container, you can use the local binary directly:

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_lxc.sh -o tm_lxc.sh && chmod +x tm_lxc.sh
# Place the traffmonetizer.bin in the same directory as the script
bash tm_lxc.sh -t XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k=
```

Or specify binary path explicitly:

```shell
bash tm_lxc.sh -t XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k= -b /root/traffmonetizer.bin
```

The `tm_lxc.sh` now also supports **automatic binary download from GitHub** (defaults to the `traffmonetizer.bin` in this repo):
- If download succeeds: use that binary and skip Docker
- If download fails: fall back to Docker extraction mode

To customize the download URL:

```shell
bash tm_lxc.sh -t XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k= --binary-url https://example.com/traffmonetizer.bin
```

**Low memory in LXC/Alpine**: If the installation process gets **Killed** (usually OOM), choose one:
- Allocate at least **512MB memory** to the LXC container and retry
- Or add **swap** inside the container before running (script tries to create temporary swap if low memory detected)

## Uninstall

```shell
bash tm.sh -u
```

Uninstall service

## Experience

For a single IP, the daily income in Europe is 0.010~0.015 US dollars. 

It is estimated that there will be more in the United States. The daily income of a single IP is more than 0.013 and not more than 0.02.

**More monks and less porridge, the more people, the lower the income**

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/a.png)

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/b.png)

## Disclaimer

This program is for learning purposes only, not for profit, please delete it within 24 hours after downloading, not for any commercial use. The text, data and images are copyrighted, if reproduced, please indicate the source.

Use of this program is subject to the deployment disclaimer. Use of this program is subject to the laws and regulations of the country where the server is deployed, the country where it is located, and the country where the user is located, and the author of the program is not responsible for any misconduct of the user.
