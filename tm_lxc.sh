#!/usr/bin/env bash
set -euo pipefail

DOCKER_IMAGE="traffmonetizer/cli_v2:latest"
EXTRACT_CONTAINER="tm_extract"
INSTALL_DIR="/opt/tm"
BIN_PATH="${INSTALL_DIR}/traffmonetizer"
SERVICE_PATH="/etc/systemd/system/traffmonetizer.service"
OPENRC_SERVICE_PATH="/etc/init.d/traffmonetizer"
TOKEN=""
OS_FAMILY=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN_PATH=""
USE_LOCAL_BIN="0"
REMOTE_BIN_URL="https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/traffmonetizer.bin"

red() { echo -e "\033[31m\033[1m$*\033[0m"; }
green() { echo -e "\033[32m\033[1m$*\033[0m"; }
yellow() { echo -e "\033[33m\033[1m$*\033[0m"; }

usage() {
  cat <<'EOF'
用法:
  bash tm_lxc.sh -t <TOKEN>
  bash tm_lxc.sh --token <TOKEN>
  bash tm_lxc.sh -t <TOKEN> -b /path/to/traffmonetizer.bin
  bash tm_lxc.sh -t <TOKEN> --binary-url <URL>

说明:
  此脚本用于 LXC 环境，优先顺序如下：
  1) 使用 -b 指定的本地二进制
  2) 使用脚本同目录的 traffmonetizer.bin
  3) 自动从 GitHub 下载 traffmonetizer.bin
  4) 下载失败后回退到 Docker 提取二进制
  然后创建并启动服务（systemd 或 OpenRC）。

LXC/Alpine 内存不足时安装可能被系统 Kill（OOM）。建议：
  - 为容器分配至少 512MB 内存，或
  - 在容器内先添加 swap 后再运行本脚本（脚本在检测到低内存且无 swap 时会尝试自动创建临时 swap）。
EOF
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    red "请使用 root 运行此脚本。"
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--token)
        TOKEN="${2:-}"
        shift 2
        ;;
      -b|--binary)
        LOCAL_BIN_PATH="${2:-}"
        USE_LOCAL_BIN="1"
        shift 2
        ;;
      --binary-url)
        REMOTE_BIN_URL="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        red "未知参数: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "${TOKEN}" ]]; then
    read -r -p "请输入你的 TraffMonetizer Token: " TOKEN
  fi

  if [[ -z "${TOKEN}" ]]; then
    red "Token 不能为空。"
    exit 1
  fi

  # 未显式指定时，自动尝试脚本同目录下的 traffmonetizer.bin
  if [[ "${USE_LOCAL_BIN}" != "1" ]]; then
    if [[ -f "${SCRIPT_DIR}/traffmonetizer.bin" ]]; then
      LOCAL_BIN_PATH="${SCRIPT_DIR}/traffmonetizer.bin"
      USE_LOCAL_BIN="1"
    fi
  fi

  if [[ "${USE_LOCAL_BIN}" == "1" ]] && [[ ! -f "${LOCAL_BIN_PATH}" ]]; then
    red "指定的二进制文件不存在: ${LOCAL_BIN_PATH}"
    exit 1
  fi
}

ensure_download_tool() {
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return
  fi

  yellow "未检测到 curl/wget，正在安装下载工具..."
  if [[ "${OS_FAMILY}" == "alpine" ]]; then
    apk update
    apk add --no-cache curl
  else
    apt update
    apt install -y curl
  fi
}

try_download_binary() {
  # 已有本地二进制时不下载
  if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
    return
  fi

  yellow "尝试从 GitHub 下载二进制..."
  ensure_download_tool

  local tmp_bin
  tmp_bin="/tmp/traffmonetizer.bin.$$"

  if command -v curl >/dev/null 2>&1; then
    if curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 "${REMOTE_BIN_URL}" -o "${tmp_bin}"; then
      chmod +x "${tmp_bin}"
      LOCAL_BIN_PATH="${tmp_bin}"
      USE_LOCAL_BIN="1"
      green "已从 GitHub 下载二进制，后续将跳过 Docker。"
      return
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -T 15 -t 3 -O "${tmp_bin}" "${REMOTE_BIN_URL}"; then
      chmod +x "${tmp_bin}"
      LOCAL_BIN_PATH="${tmp_bin}"
      USE_LOCAL_BIN="1"
      green "已从 GitHub 下载二进制，后续将跳过 Docker。"
      return
    fi
  fi

  yellow "GitHub 二进制下载失败，将回退到 Docker 提取模式。"
}

detect_os() {
  if [[ -f /etc/alpine-release ]]; then
    OS_FAMILY="alpine"
    return
  fi
  if [[ -f /etc/debian_version ]] || [[ -f /etc/os-release ]]; then
    OS_FAMILY="debian"
    return
  fi
  red "暂不支持当前系统。仅支持 Debian/Ubuntu/Alpine。"
  exit 1
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
  else
    rc-update add docker default >/dev/null 2>&1 || true
    rc-service docker start
  fi
}

restart_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart docker
  else
    rc-service docker restart || {
      rc-service docker stop || true
      rc-service docker start
    }
  fi
}

# 检测可用内存（MB），无 /proc 时返回 0
get_available_mem_mb() {
  local avail
  avail=$(awk '/MemAvailable:/ { print int($2/1024) }' /proc/meminfo 2>/dev/null || echo "0")
  echo "${avail:-0}"
}

# LXC/Alpine 低内存时：建议 swap 或分批安装以降低 OOM 概率
ensure_alpine_memory() {
  local need_swap=256
  local avail
  avail=$(get_available_mem_mb)
  if [[ "${avail}" -lt 350 ]] && [[ "${avail}" -gt 0 ]]; then
    yellow "当前可用内存约 ${avail}MB，安装 Docker 可能被系统因内存不足而终止（OOM）。"
    if ! grep -qE '^/dev/|swap' /proc/swaps 2>/dev/null; then
      yellow "未检测到 swap。正在创建 ${need_swap}MB 的 swap 文件以降低 OOM 风险..."
      if dd if=/dev/zero of=/tmp/tm_swap.img bs=1M count="${need_swap}" 2>/dev/null && \
         chmod 600 /tmp/tm_swap.img && mkswap /tmp/tm_swap.img >/dev/null 2>&1 && swapon /tmp/tm_swap.img 2>/dev/null; then
        green "已临时启用 ${need_swap}MB swap。安装完成后可执行: swapoff /tmp/tm_swap.img && rm -f /tmp/tm_swap.img"
      else
        red "创建 swap 失败。请宿主机为 LXC 增加内存（建议 ≥512MB）或在该容器内手动添加 swap 后重试。"
        exit 1
      fi
    else
      yellow "检测到已有 swap。若仍被 Killed，请为 LXC 分配更多内存（建议 ≥512MB）后重试。"
    fi
  fi
}

install_docker() {
  yellow "[1/6] 安装 Docker..."
  if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
    green "检测到本地二进制，跳过 Docker 安装。"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    green "Docker 已安装，跳过安装。"
  else
    if [[ "${OS_FAMILY}" == "alpine" ]]; then
      ensure_alpine_memory
      apk update
      # 分批安装以降低单次 apk 内存占用，避免 LXC 小内存时被 OOM 杀死
      apk add --no-cache curl || { red "安装 curl 失败（若被 Killed 多为内存不足，请增加 LXC 内存或添加 swap 后重试）"; exit 1; }
      apk add --no-cache docker || { red "安装 docker 失败（若被 Killed 多为内存不足，请增加 LXC 内存或添加 swap 后重试）"; exit 1; }
      apk add --no-cache docker-cli-compose || { red "安装 docker-cli-compose 失败"; exit 1; }
      start_docker_service
    else
      curl -fsSL https://get.docker.com | sh
    fi
  fi
}

fix_lxc_storage_driver() {
  yellow "[2/6] 配置 LXC 下的 fuse-overlayfs..."
  if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
    green "本地二进制模式无需 Docker 存储驱动，跳过。"
    return
  fi
  if [[ "${OS_FAMILY}" == "alpine" ]]; then
    apk update
    apk add --no-cache fuse-overlayfs
  else
    apt update
    apt install -y fuse-overlayfs
  fi
  mkdir -p /etc/docker
  echo '{"storage-driver":"fuse-overlayfs"}' > /etc/docker/daemon.json
  start_docker_service
  restart_docker_service
}

extract_binary() {
  yellow "[3/6] 从镜像提取二进制..."
  if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
    yellow "检测到本地二进制，直接安装..."
    mkdir -p "${INSTALL_DIR}"
    cp -f "${LOCAL_BIN_PATH}" "${BIN_PATH}"
    chmod +x "${BIN_PATH}"
    green "已安装本地二进制: ${LOCAL_BIN_PATH}"
    return
  fi
  if ! docker info >/dev/null 2>&1; then
    red "Docker daemon 不可用，无法从镜像提取二进制。"
    red "请先确保 Docker 正常运行，或把 traffmonetizer.bin 放到脚本同目录后重试。"
    exit 1
  fi
  docker rm -f "${EXTRACT_CONTAINER}" >/dev/null 2>&1 || true
  docker pull "${DOCKER_IMAGE}"
  docker create --name "${EXTRACT_CONTAINER}" "${DOCKER_IMAGE}"
  mkdir -p "${INSTALL_DIR}"
  docker cp "${EXTRACT_CONTAINER}:/usr/local/bin/cli" "${BIN_PATH}"
  chmod +x "${BIN_PATH}"
  docker rm "${EXTRACT_CONTAINER}"
}

create_service() {
  yellow "[4/6] 创建服务..."
  if command -v systemctl >/dev/null 2>&1; then
    cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=TraffMonetizer
After=network.target

[Service]
Type=simple
ExecStart=${BIN_PATH} start accept --token ${TOKEN}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  else
    cat > "${OPENRC_SERVICE_PATH}" <<EOF
#!/sbin/openrc-run
name="traffmonetizer"
description="TraffMonetizer service"
command="${BIN_PATH}"
command_args="start accept --token ${TOKEN}"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
EOF
    if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
      cat >> "${OPENRC_SERVICE_PATH}" <<'EOF'
  need net
}
EOF
    else
      cat >> "${OPENRC_SERVICE_PATH}" <<'EOF'
  need net docker
}
EOF
    fi
    chmod +x "${OPENRC_SERVICE_PATH}"
  fi
}

start_service() {
  yellow "[5/6] 启动服务..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable --now traffmonetizer
  else
    rc-update add traffmonetizer default >/dev/null 2>&1 || true
    rc-service traffmonetizer restart || rc-service traffmonetizer start
  fi
}

show_status() {
  yellow "[6/6] 查看服务状态..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status traffmonetizer --no-pager
  else
    rc-service traffmonetizer status
  fi
  green "安装完成。"
}

main() {
  require_root
  detect_os
  parse_args "$@"
  try_download_binary
  if [[ "${USE_LOCAL_BIN}" == "1" ]]; then
    yellow "二进制模式：跳过 Docker 安装与存储驱动配置步骤。"
  else
    install_docker
    fix_lxc_storage_driver
  fi
  extract_binary
  create_service
  start_service
  show_status
}

main "$@"
