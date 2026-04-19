# Traffmonetizer 一键安装脚本

[English](README.md) | [中文文档](README_zh.md)

## 介绍

[Traffmonetizer](https://traffmonetizer.com/?aff=986423) 是一个通过分享闲置带宽赚取被动收入的平台。

每分享 **1GB 流量可获得 $0.10**，支持数据中心网络和家庭带宽。

这是**全网第一个一键安装脚本**，自动安装所有依赖并部署最新 Docker 镜像。主要特点：

- 自动安装 Docker（已安装则跳过）
- 根据系统架构自动选择正确的 Docker 镜像
- 通过 [Watchtower](https://containrrr.dev/watchtower/) 自动更新镜像，无需手动操作

> **已验证平台：** AMD64 和 ARM 架构

## 快速开始

前往 [traffmonetizer.com](https://traffmonetizer.com/?aff=986423) 注册（获得 $5 奖励），然后从控制台复制你的 Token。

根据你的环境选择安装方式：

| 环境 | 脚本 | 需要 Docker |
|------|------|:-----------:|
| 普通 VPS / 服务器 | `tm.sh` | 是 |
| LXC 容器 | `tm_lxc.sh` | 可选 |
| Docker 容器 / WSL2 / 无 systemd | `tm_simple.sh` | 否 |

## 安装

### 方式一：标准安装（Docker） — `tm.sh`

适用于：**普通 VPS、独立服务器、云主机**

#### 交互式安装

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh
```

脚本会提示你输入 Token。

#### 一键安装

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh && chmod +x tm.sh && bash tm.sh -t YOUR_TOKEN
```

将 `YOUR_TOKEN` 替换为你的实际 Token。

---

### 方式二：LXC 容器安装 — `tm_lxc.sh`

适用于：**LXC/LXD 容器**（Proxmox 等）

脚本自动识别系统：Debian/Ubuntu 使用 systemd，Alpine 使用 OpenRC。

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_lxc.sh -o tm_lxc.sh && chmod +x tm_lxc.sh && bash tm_lxc.sh -t YOUR_TOKEN
```

不传 `-t` 参数则进入交互式输入。

#### 二进制模式（小内存 / 无 Docker）

脚本支持不依赖 Docker，直接使用二进制运行：

```shell
# 自动从 GitHub 下载二进制（默认行为）
bash tm_lxc.sh -t YOUR_TOKEN

# 指定本地二进制文件
bash tm_lxc.sh -t YOUR_TOKEN -b /path/to/traffmonetizer.bin

# 自定义下载地址
bash tm_lxc.sh -t YOUR_TOKEN --binary-url https://example.com/traffmonetizer.bin
```

**优先级：** 本地二进制 > 从 GitHub 下载 > Docker 提取

> **内存不足提示：** 如果安装过程中进程被 **Killed**（OOM），请选择：
> - 为 LXC 容器分配至少 **512MB** 内存后重试
> - 或先添加 swap 再运行（脚本检测到低内存时会尝试自动创建临时 swap）

---

### 方式三：极简安装（无 Docker / 无 systemd） — `tm_simple.sh`

适用于：**Docker 容器、WSL2、Alpine 容器**，以及任何没有 systemd 或 Docker 的环境。

特点：无需 Docker，无需 systemd，内置进程管理（启动/停止/重启/状态/日志）。

#### 下载

```shell
curl -L https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/tm_simple.sh -o tm_simple.sh && chmod +x tm_simple.sh
```

#### 使用

```shell
./tm_simple.sh start YOUR_TOKEN   # 启动（带 Token）
./tm_simple.sh start              # 启动（交互式输入 Token）
./tm_simple.sh status             # 查看运行状态
./tm_simple.sh logs               # 查看实时日志
./tm_simple.sh stop               # 停止服务
./tm_simple.sh restart            # 重启服务
./tm_simple.sh help               # 查看帮助
```

> **注意事项：**
> - 需要当前目录下存在 `traffmonetizer.bin`，不存在时会提示下载
> - 日志文件：`/tmp/traffmonetizer.log`，PID 文件：`/tmp/traffmonetizer.pid`
> - 容器环境建议使用 `nohup` 或 `screen`/`tmux` 保持会话
> - 容器重启后需手动重启服务，或添加到容器启动脚本中

## 卸载

```shell
bash tm.sh -u
```

## 收益参考

单 IP 日收益（仅供参考）：

| 地区 | 每日收入（单 IP） |
|------|-------------------|
| 欧洲 | $0.010 – $0.015 |
| 美国 | $0.013 – $0.020 |

> 人越多，收益越低。

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/a.png)

![](https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/backup/b.png)

2022.05 之后收益大幅下降，之前单 IP 每天有 $0.025 以上。（本脚本在平台适配 Linux 后第 15 天创建）

> **提示：** 提现前不要随意切换提现方式，切换可能导致部分已积攒额度丢失。

## 免责声明

本程序仅供学习了解，非盈利目的，请于下载后 24 小时内删除，不得用作任何商业用途。文字、数据及图片均有所属版权，如转载须注明来源。

使用本程序须遵守部署服务器所在地、所在国家和用户所在国家的法律法规，程序作者不对使用者任何不当行为负责。
