#!/bin/bash
# TraffMonetizer 简易运行脚本 (支持自动下载二进制)
# 适用于：无 systemd / Docker 受限环境（如容器、WSL、部分 VPS）
# 直接使用本地二进制文件运行，无需 Docker

set -e

# 颜色定义
RED='\033[31;1m'
GREEN='\033[32;1m'
YELLOW='\033[33;1m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BIN_PATH="./traffmonetizer.bin"
PID_FILE="/tmp/traffmonetizer.pid"
LOG_FILE="/tmp/traffmonetizer.log"
TOKEN=""
REMOTE_BIN_URL="https://raw.githubusercontent.com/6uu1/traffmonetizer-one-click-command-installation/main/traffmonetizer.bin"

# 确保有下载工具
ensure_download_tool() {
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return
    fi
    echo -e "${YELLOW}未检测到 curl/wget，正在安装 curl...${NC}"
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y curl
    elif command -v apk >/dev/null 2>&1; then
        apk update && apk add --no-cache curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    else
        echo -e "${RED}无法安装 curl，请手动安装 curl 或 wget${NC}"
        exit 1
    fi
}

# 尝试从 GitHub 下载二进制
try_download_binary() {
    if [[ -f "$BIN_PATH" ]]; then
        return
    fi

    echo -e "${YELLOW}未找到本地二进制，尝试从 GitHub 下载...${NC}"
    ensure_download_tool

    if command -v curl >/dev/null 2>&1; then
        if curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 "$REMOTE_BIN_URL" -o "$BIN_PATH"; then
            chmod +x "$BIN_PATH"
            echo -e "${GREEN}✓ 已从 GitHub 下载二进制${NC}"
            return
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -T 15 -t 3 -O "$BIN_PATH" "$REMOTE_BIN_URL"; then
            chmod +x "$BIN_PATH"
            echo -e "${GREEN}✓ 已从 GitHub 下载二进制${NC}"
            return
        fi
    fi

    echo -e "${RED}✗ 从 GitHub 下载失败${NC}"
    return 1
}

# 检查二进制文件
check_binary() {
    # 如果本地不存在，尝试下载
    if [[ ! -f "$BIN_PATH" ]]; then
        try_download_binary
    fi

    # 再次检查
    if [[ ! -f "$BIN_PATH" ]]; then
        echo -e "${RED}错误: 未找到 traffmonetizer.bin${NC}"
        echo "请确保二进制文件在当前目录，或检查网络连接"
        exit 1
    fi

    if [[ ! -x "$BIN_PATH" ]]; then
        chmod +x "$BIN_PATH"
    fi
}

# 检查是否已运行
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# 启动
start() {
    if is_running; then
        echo -e "${YELLOW}TraffMonetizer 已在运行${NC}"
        return 0
    fi

    if [[ -z "$TOKEN" ]]; then
        echo -n "请输入 Token: "
        read -r TOKEN
    fi

    if [[ -z "$TOKEN" ]]; then
        echo -e "${RED}错误: Token 不能为空${NC}"
        exit 1
    fi

    check_binary

    echo -e "${GREEN}正在启动 TraffMonetizer...${NC}"
    nohup "$BIN_PATH" start accept --token "$TOKEN" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 2

    if is_running; then
        echo -e "${GREEN}✓ 启动成功 (PID: $pid)${NC}"
        echo "日志文件: $LOG_FILE"
        echo "查看状态: tail -f $LOG_FILE"
    else
        echo -e "${RED}✗ 启动失败，请查看日志: $LOG_FILE${NC}"
        exit 1
    fi
}

# 停止
stop() {
    if ! is_running; then
        echo -e "${YELLOW}TraffMonetizer 未运行${NC}"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid=$(cat "$PID_FILE")
    echo -e "${YELLOW}正在停止 TraffMonetizer (PID: $pid)...${NC}"

    kill "$pid" 2>/dev/null || true

    # 等待进程结束
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}强制结束进程${NC}"
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    echo -e "${GREEN}✓ 已停止${NC}"
}

# 状态
status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}TraffMonetizer 正在运行${NC}"
        echo "PID: $pid"
        echo "日志: $LOG_FILE"

        # 显示最新日志
        if [[ -f "$LOG_FILE" ]]; then
            echo ""
            echo "=== 最近日志 ==="
            tail -5 "$LOG_FILE"
        fi
    else
        echo -e "${YELLOW}TraffMonetizer 未运行${NC}"
    fi
}

# 日志
logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        echo -e "${YELLOW}日志文件不存在${NC}"
    fi
}

# 使用帮助
usage() {
    cat <<EOF
TraffMonetizer 简易运行脚本

使用方法: $0 [命令] [选项]

命令:
  start [token]    启动服务 (可选的 token 参数)
  stop             停止服务
  restart          重启服务
  status           查看状态
  logs             查看实时日志
  help             显示此帮助

示例:
  $0 start XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k=
  $0 start          # 交互式输入 token
  $0 status
  $0 logs

注意: 此脚本适用于无 systemd 的环境（如 Docker 容器、WSL 等）
      会自动从 GitHub 下载二进制文件（如果本地不存在）
EOF
}

# 主程序
case "${1:-}" in
    start)
        TOKEN="${2:-}"
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1
        start
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    help|-h|--help|"")
        usage
        ;;
    *)
        echo -e "${RED}未知命令: $1${NC}"
        usage
        exit 1
        ;;
esac
