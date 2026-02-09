#!/usr/bin/env bash
#FROM https://github.com/spiritLHLS/traffmonetizer-one-click-command-installation

# Alpine 默认没有 bash，如果当前不是 bash 则自动安装并重新执行
if [ -z "$BASH_VERSION" ]; then
  if [ -f /etc/alpine-release ]; then
    apk add --no-cache bash >/dev/null 2>&1
    exec bash "$0" "$@"
  else
    echo "This script requires bash." && exit 1
  fi
fi

utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
if [[ -z "$utf8_locale" ]]; then
  echo "No UTF-8 locale found"
else
  export LC_ALL="$utf8_locale"
  export LANG="$utf8_locale"
  export LANGUAGE="$utf8_locale"
  echo "Locale set to $utf8_locale"
fi

# 定义容器名
NAME='tm'

# 自定义字体彩色，read 函数，安装依赖函数
red(){ echo -e "\033[31m\033[01m$1$2\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1$2\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1$2\033[0m"; }
reading(){ read -rp "$(green "$1")" "$2"; }

# 必须以root运行脚本
check_root(){
  [[ $(id -u) != 0 ]] && red " The script must be run as root, you can enter sudo -i and then download and run again." && exit 1
}

# 判断系统，并选择相应的指令集
check_operating_system(){
  CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
       "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
       "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
       "$(grep . /etc/redhat-release 2>/dev/null)"
       "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
      )

  for i in "${CMD[@]}"; do SYS="$i" && [[ -n $SYS ]] && break; done

  REGEX=("debian" "ubuntu" "raspbian" "centos|red hat|kernel|oracle linux|amazon linux|alma|rocky" "alpine")
  RELEASE=("Debian" "Ubuntu" "Raspbian" "CentOS" "Alpine")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "apt -y update" "yum -y update" "apk update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "apt -y install" "yum -y install" "apk add")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "apk del")

  for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done

  [[ -z $SYSTEM ]] && red " ERROR: The script supports Debian, Ubuntu, CentOS or Alpine systems only.\n" && exit 1
}

# 安装基础依赖
install_base_deps(){
  if [ "$SYSTEM" = "Alpine" ]; then
    apk add --no-cache curl >/dev/null 2>&1
  fi
}

# 判断宿主机的 IPv4 或双栈情况 没有拉取不了 docker
check_ipv4(){
  # 遍历本机可以使用的 IP API 服务商
  # 定义可能的 IP API 服务商
  API_NET=("ip.sb" "ipget.net" "ip.ping0.cc" "https://ip4.seeip.org" "https://api.my-ip.io/ip" "https://ipv4.icanhazip.com" "api.ipify.org")

  # 遍历每个 API 服务商，并检查它是否可用
  for p in "${API_NET[@]}"; do
    # 使用 curl 请求每个 API 服务商
    response=$(curl -s4m8 "$p")
    curl_exit=$?
    sleep 1
    # 检查请求是否失败，或者回传内容中是否包含 error
    if [ $curl_exit -eq 0 ] && ! echo "$response" | grep -q "error"; then
      # 如果请求成功且不包含 error，则设置 IP_API 并退出循环
      IP_API="$p"
      break
    fi
  done

  # 判断宿主机的 IPv4 、IPv6 和双栈情况
  ! curl -s4m8 $IP_API | grep -q '\.' && red " ERROR：The host must have IPv4. " && exit 1
}

# 判断 CPU 架构
check_virt(){
  ARCHITECTURE=$(uname -m)
  case "$ARCHITECTURE" in
    aarch64 ) ARCH=arm64v8;;
    armv7l ) ARCH=arm32v7;;
    x64|x86_64|amd64 ) ARCH=latest;;
    * ) red " ERROR: Unsupported architecture: $ARCHITECTURE\n" && exit 1;;
  esac
}

# 输入 traffmonetizer 的个人 token
input_token(){
  [ -z $TMTOKEN ] && reading " Enter your token, something end with =, if you do not find it, open https://traffmonetizer.com/?aff=986423: " TMTOKEN
}

container_build(){
  # 宿主机安装 docker
  green "\n Install docker.\n "
  if ! docker info >/dev/null 2>&1; then
    echo -e " \n Install docker \n "
    if [ "$SYSTEM" = "CentOS" ]; then
      ${PACKAGE_UPDATE[int]}
      ${PACKAGE_INSTALL[int]} yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &&
      ${PACKAGE_INSTALL[int]} docker-ce docker-ce-cli containerd.io
      systemctl enable --now docker
    elif [ "$SYSTEM" = "Alpine" ]; then
      ${PACKAGE_UPDATE[int]}
      ${PACKAGE_INSTALL[int]} docker docker-cli-compose
      rc-update add docker default
      service docker start
    else
      ${PACKAGE_UPDATE[int]}
      ${PACKAGE_INSTALL[int]} docker.io
    fi
  fi

  # 删除旧容器（如有）
  docker ps -a | awk '{print $NF}' | grep -qw "$NAME" && yellow " Remove the old traffmonetizer container.\n " && docker rm -f "$NAME" >/dev/null 2>&1

  # 创建容器
  yellow " Create the traffmonetizer container.\n "
  docker run -d --name $NAME --restart=unless-stopped traffmonetizer/cli_v2:$ARCH start accept --token "$TMTOKEN" >/dev/null 2>&1

}

# 显示结果
result(){
  docker ps -a | grep -q "$NAME" && green " Install success.\n" || red " install fail.\n"
}

# 检测虚拟化类型
detect_virtualization(){
  VIRT_TYPE=""
  
  # 方法1: systemd-detect-virt (最可靠)
  if command -v systemd-detect-virt &>/dev/null; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_TYPE" = "none" ]; then
      VIRT_TYPE="Bare Metal / 物理机"
    fi
    return
  fi
  
  # 方法2: 检查 /proc/vz 目录 (OpenVZ)
  if [ -d /proc/vz ]; then
    VIRT_TYPE="OpenVZ"
    return
  fi
  
  # 方法3: lscpu 中的 Hypervisor vendor
  if command -v lscpu &>/dev/null; then
    VIRT_TYPE=$(lscpu 2>/dev/null | grep -i 'hypervisor vendor' | awk -F: '{print $2}' | xargs)
    [ -n "$VIRT_TYPE" ] && return
  fi
  
  # 方法4: /proc/cpuinfo 中的 hypervisor flag
  if grep -q 'hypervisor' /proc/cpuinfo 2>/dev/null; then
    VIRT_TYPE="VM (Unknown Type)"
    return
  fi
  
  # 方法5: dmidecode 获取系统制造商
  if command -v dmidecode &>/dev/null; then
    VIRT_TYPE=$(dmidecode -s system-product-name 2>/dev/null | head -1)
    [ -n "$VIRT_TYPE" ] && return
  fi
  
  # 如果都无法检测
  VIRT_TYPE="Unknown"
}

# 显示 VPS 配置信息
show_vps_info(){
  green "\n ===================== VPS 配置信息 =====================\n"
  
  # 检测虚拟化类型
  detect_virtualization
  yellow " 虚拟化类型: $VIRT_TYPE\n"
  
  # 操作系统
  yellow " 操作系统  : $SYS\n"
  
  # CPU 架构
  yellow " CPU 架构  : $ARCHITECTURE\n"
  
  # CPU 型号
  if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    [ -n "$CPU_MODEL" ] && yellow " CPU 型号  : $CPU_MODEL\n"
  fi
  
  # CPU 核心数
  CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
  [ -n "$CPU_CORES" ] && yellow " CPU 核心数: $CPU_CORES\n"
  
  # 内存信息（详细）
  if command -v free &>/dev/null; then
    MEM_INFO=$(free -m 2>/dev/null | grep Mem)
    TOTAL_MEM=$(echo "$MEM_INFO" | awk '{print $2}')
    USED_MEM=$(echo "$MEM_INFO" | awk '{print $3}')
    FREE_MEM=$(echo "$MEM_INFO" | awk '{print $4}')
    AVAIL_MEM=$(echo "$MEM_INFO" | awk '{print $7}')
    
    if [ -n "$TOTAL_MEM" ]; then
      yellow " 内存信息  : 总计 ${TOTAL_MEM} MB / 已用 ${USED_MEM} MB / 可用 ${AVAIL_MEM} MB\n"
    fi
  fi
  
  # SWAP 信息
  if command -v free &>/dev/null; then
    SWAP_INFO=$(free -m 2>/dev/null | grep Swap)
    TOTAL_SWAP=$(echo "$SWAP_INFO" | awk '{print $2}')
    USED_SWAP=$(echo "$SWAP_INFO" | awk '{print $3}')
    FREE_SWAP=$(echo "$SWAP_INFO" | awk '{print $4}')
    
    if [ -n "$TOTAL_SWAP" ] && [ "$TOTAL_SWAP" -gt 0 ]; then
      yellow " SWAP 信息 : 总计 ${TOTAL_SWAP} MB / 已用 ${USED_SWAP} MB / 可用 ${FREE_SWAP} MB\n"
    else
      yellow " SWAP 信息 : 未配置 SWAP\n"
    fi
  fi
  
  # 磁盘信息（详细）
  if command -v df &>/dev/null; then
    DISK_INFO=$(df -h / 2>/dev/null | tail -1)
    TOTAL_DISK=$(echo "$DISK_INFO" | awk '{print $2}')
    USED_DISK=$(echo "$DISK_INFO" | awk '{print $3}')
    AVAIL_DISK=$(echo "$DISK_INFO" | awk '{print $4}')
    USE_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')
    
    if [ -n "$TOTAL_DISK" ]; then
      yellow " 磁盘信息  : 总计 ${TOTAL_DISK} / 已用 ${USED_DISK} / 可用 ${AVAIL_DISK} / 使用率 ${USE_PERCENT}\n"
    fi
  fi
  
  # 内核版本
  KERNEL_VER=$(uname -r 2>/dev/null)
  [ -n "$KERNEL_VER" ] && yellow " 内核版本  : $KERNEL_VER\n"
  
  # IPv4 地址
  if [ -n "$IP_API" ]; then
    IPV4_ADDR=$(curl -s4m8 "$IP_API" 2>/dev/null)
    [ -n "$IPV4_ADDR" ] && yellow " IPv4 地址 : $IPV4_ADDR\n"
  fi
  
  # IPv6 地址
  IPV6_APIS=("https://api64.ipify.org" "https://v6.ident.me" "https://ipv6.icanhazip.com")
  for ipv6_api in "${IPV6_APIS[@]}"; do
    IPV6_ADDR=$(curl -s6m8 "$ipv6_api" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$IPV6_ADDR" ] && echo "$IPV6_ADDR" | grep -q ":"; then
      yellow " IPv6 地址 : $IPV6_ADDR\n"
      break
    fi
  done
  
  green " =========================================================\n"
}

# 卸载
uninstall(){
  docker rm -f $(docker ps -a | grep -w "$NAME" | awk '{print $1}')
  docker rmi -f $(docker images | grep traffmonetizer/cli | awk '{print $3}')
  green "\n Uninstall containers and images complete.\n"
  exit 0
}

# 传参
while getopts "UuT:t:" OPTNAME; do
  case "$OPTNAME" in
    'U'|'u' ) uninstall;;
    'T'|'t' ) TMTOKEN=$OPTARG;;
  esac
done

# 主程序
check_root
check_operating_system
install_base_deps
check_ipv4
check_virt
show_vps_info
input_token
container_build
result