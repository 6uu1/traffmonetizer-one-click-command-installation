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

red() { echo -e "\033[31m\033[1m$*\033[0m"; }
green() { echo -e "\033[32m\033[1m$*\033[0m"; }
yellow() { echo -e "\033[33m\033[1m$*\033[0m"; }

usage() {
  cat <<'EOF'
用法:
  bash tm_lxc.sh -t <TOKEN>
  bash tm_lxc.sh --token <TOKEN>

说明:
  此脚本用于 LXC 环境，通过 Docker 拉取镜像并提取 traffmonetizer 二进制，
  然后创建并启动服务（systemd 或 OpenRC）。
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

install_docker() {
  yellow "[1/6] 安装 Docker..."
  if command -v docker >/dev/null 2>&1; then
    green "Docker 已安装，跳过安装。"
  else
    if [[ "${OS_FAMILY}" == "alpine" ]]; then
      apk update
      apk add --no-cache docker docker-cli-compose curl
      start_docker_service
    else
      curl -fsSL https://get.docker.com | sh
    fi
  fi
}

fix_lxc_storage_driver() {
  yellow "[2/6] 配置 LXC 下的 fuse-overlayfs..."
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
  need net docker
}
EOF
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
  install_docker
  fix_lxc_storage_driver
  extract_binary
  create_service
  start_service
  show_status
}

main "$@"
