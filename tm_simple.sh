#!/bin/bash
# TraffMonetizer 简易运行脚本（守护进程版）
# 适用于：无 systemd / Docker 受限环境（如容器、WSL、部分 VPS）

set -e

RED='\033[31;1m'
GREEN='\033[32;1m'
YELLOW='\033[33;1m'
NC='\033[0m'

# ---------- 配置 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BIN_PATH="./traffmonetizer.bin"
PID_FILE="/tmp/traffmonetizer.pid"
LOG_FILE="/tmp/traffmonetizer.log"
MONITOR_PID_FILE="/tmp/traffmonetizer_monitor.pid"
MONITOR_LOG_FILE="/tmp/traffmonetizer_monitor.log"

# ---------- 基础函数 ----------
check_binary() {
    if [[ ! -f "$BIN_PATH" ]]; then
        echo -e "${RED}错误: 未找到 traffmonetizer.bin${NC}" >&2
        exit 1
    fi
    chmod +x "$BIN_PATH" 2>/dev/null || true
}

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

# ---------- 守护进程监控器 ----------
monitor_loop() {
    local check_interval=30
    local max_restarts=10
    local restart_count=0

    echo "Monitor started (PID: $$)" >> "$MONITOR_LOG_FILE"

    while true; do
        if ! is_running; then
            local current_pid
            current_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")

            echo "" >> "$MONITOR_LOG_FILE"
            echo "========================================" >> "$MONITOR_LOG_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Process NOT running! (last PID: ${current_pid:-none})" >> "$MONITOR_LOG_FILE"

            if [[ -f "$LOG_FILE" ]]; then
                echo "Last 20 log lines:" >> "$MONITOR_LOG_FILE"
                tail -20 "$LOG_FILE" >> "$MONITOR_LOG_FILE" || true
            fi

            if [[ -n "$TM_TOKEN" ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting..." >> "$MONITOR_LOG_FILE"
                nohup "$BIN_PATH" start accept --token "$TM_TOKEN" >> "$LOG_FILE" 2>&1 &
                local new_pid=$!
                echo "$new_pid" > "$PID_FILE"

                sleep 2
                if is_running; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restart SUCCESS (PID: $new_pid)" >> "$MONITOR_LOG_FILE"
                    restart_count=0
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restart FAILED" >> "$MONITOR_LOG_FILE"
                    ((restart_count++))
                fi
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cannot restart: TM_TOKEN not set" >> "$MONITOR_LOG_FILE"
            fi

            if [[ $restart_count -ge $max_restarts ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Max restart attempts reached. Giving up." >> "$MONITOR_LOG_FILE"
                break
            fi
        fi
        sleep $check_interval
    done
}

# 监控器入口
run_monitor() {
    TM_TOKEN="${1:-}"
    if [[ -z "$TM_TOKEN" ]]; then
        echo "Error: Token required for monitor" >&2
        exit 1
    fi
    cd "$SCRIPT_DIR"
    monitor_loop
}

# ---------- 主程序函数 ----------
start_simple() {
    if is_running; then
        echo -e "${YELLOW}TraffMonetizer 已在运行${NC}"
        return
    fi

    local token="${1:-}"
    if [[ -z "$token" ]]; then
        read -r -p "Enter Token: " token
    fi

    if [[ -z "$token" ]]; then
        echo -e "${RED}Token 不能为空${NC}" >&2
        exit 1
    fi

    check_binary

    echo -e "${GREEN}启动 TraffMonetizer...${NC}"
    nohup "$BIN_PATH" start accept --token "$token" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    sleep 2
    if is_running; then
        echo -e "${GREEN}✓ 启动成功${NC}"
        echo "日志: $LOG_FILE"
    else
        echo -e "${RED}✗ 启动失败，查看日志: $LOG_FILE${NC}" >&2
        exit 1
    fi
}

start_daemon() {
    local token="${1:-}"
    if [[ -z "$token" ]]; then
        read -r -p "Enter Token: " token
    fi

    if [[ -z "$token" ]]; then
        echo -e "${RED}Token 不能为空${NC}" >&2
        exit 1
    fi

    if is_running; then
        echo -e "${YELLOW}TraffMonetizer 已在运行${NC}"
        return
    fi

    check_binary

    echo -e "${GREEN}启动 TraffMonetizer + 守护进程...${NC}"
    nohup "$BIN_PATH" start accept --token "$token" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    sleep 2
    if is_running; then
        echo -e "${GREEN}✓ 主进程启动成功${NC}"
        echo "日志: $LOG_FILE"
        echo "监控器日志: $MONITOR_LOG_FILE"

        # 启动监控器
        nohup bash "$0" _monitor "$token" > /dev/null 2>&1 &
        echo $! > "$MONITOR_PID_FILE"
        echo -e "${GREEN}✓ 守护进程已启动${NC}"
        echo ""
        echo "命令:"
        echo "  状态: $0 status"
        echo "  日志: $0 logs"
        echo "  停监控: $0 stopmonitor"
        echo "  停止: $0 stop"
    else
        echo -e "${RED}✗ 启动失败${NC}" >&2
        exit 1
    fi
}

stop_service() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local mid=$(cat "$MONITOR_PID_FILE")
        kill "$mid" 2>/dev/null && rm -f "$MONITOR_PID_FILE"
    fi

    if is_running; then
        local pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        local c=0
        while kill -0 "$pid" 2>/dev/null && [[ $c -lt 10 ]]; do
            sleep 1
            ((c++))
        done
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    echo -e "${GREEN}✓ 已停止${NC}"
}

stop_monitor_only() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local mid=$(cat "$MONITOR_PID_FILE")
        kill "$mid" 2>/dev/null
        rm -f "$MONITOR_PID_FILE"
        echo -e "${GREEN}✓ 监控器已停止${NC}"
    else
        echo -e "${YELLOW}监控器未运行${NC}"
    fi
}

status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}TraffMonetizer 运行中${NC}"
        echo "PID: $pid"
        tail -5 "$LOG_FILE" 2>/dev/null || echo "无日志"
    else
        echo -e "${YELLOW}TraffMonetizer 未运行${NC}"
    fi
}

logs() {
    [[ -f "$LOG_FILE" ]] && tail -f "$LOG_FILE" || echo "日志不存在"
}

usage() {
    cat <<EOF
TraffMonetizer 简易运行脚本（守护进程版）

用法: $0 [命令] [token]

命令:
  start [token]      启动（无守护）
  daemon|start-daemon [token] 启动 + 守护进程（自动重启）
  stop               停止服务（含监控器）
  stopmonitor        只停止监控器
  status             查看状态
  logs               查看日志
  help               帮助

示例:
  $0 daemon XhRgiD9yuG+0wUe295CCwi5s3qLejoaYnLC3IkqJB1k=
  $0 start           # 交互输入 token
EOF
}

# ---------- 监控器专用入口 ----------
if [[ "${1:-}" == "_monitor" ]]; then
    run_monitor "${2:-}"
    exit $?
fi

# ---------- 主程序 ----------
case "${1:-}" in
    start) start_simple "${2:-}" ;;
    daemon|start-daemon) start_daemon "${2:-}" ;;
    stop) stop_service ;;
    stopmonitor) stop_monitor_only ;;
    restart)
        stop_service
        sleep 1
        start_daemon "${2:-}"
        ;;
    status) status ;;
    logs) logs ;;
    help|-h|--help|"") usage ;;
    *)
        echo -e "${RED}未知命令: $1${NC}"
        usage
        exit 1
        ;;
esac