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

If you do not pass `-t`, you can run `bash tm_lxc.sh` and enter the token interactively.
The script auto-detects init system: systemd on Debian/Ubuntu, OpenRC on Alpine.

## Uninstall

```shell
bash tm.sh -u
```

uninstall service

## Experience

For a single IP, the daily income in Europe is 0.010~0.015 US dollars. 

It is estimated that there will be more in the United States. The daily income of a single IP is more than 0.013 and not more than 0.02.

**More monks and less porridge, the more people, the lower the income**

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/a.png)

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/b.png)

## Disclaimer

This program is for learning purposes only, not for profit, please delete it within 24 hours after downloading, not for any commercial use. The text, data and images are copyrighted, if reproduced, please indicate the source.

Use of this program is subject to the deployment disclaimer. Use of this program is subject to the laws and regulations of the country where the server is deployed, the country where it is located, and the country where the user is located, and the author of the program is not responsible for any misconduct of the user.
