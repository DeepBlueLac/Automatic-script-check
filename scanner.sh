#!/usr/bin/env bash
# 极简系统检测脚本(v3.1)
# 输出文件：system_info_$(hostname).txt
set -eo pipefail

# 硬件检测核心参数
get_hardware() {
    # CPU信息（兼容物理/逻辑核心显示）
    cpu_model=$(lscpu | grep -m1 'Model name' | cut -d':' -f2 | xargs)
    cpu_cores=$(nproc --all 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    
    # 内存信息（优化MB/GB显示）
    mem_total=$(free -h | awk '/Mem/{printf "%.1f%s", $2, substr($3,1,1)}')
    
    # 存储信息（精确获取根分区）
    disk_info=$(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | awk '
        $3 ~ /[a-zA-Z]/ {print $1"("$3")-"$2; exit}
        {print $1"-"$2; exit}'
    )
}

# GPU检测（增强多显卡支持）
get_gpu() {
    if command -v nvidia-smi &>/dev/null; then
        gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | uniq | xargs)
        gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq)
    else
        gpu_model=$(lspci | grep -iE 'vga|3d|display' | cut -d: -f3- | 
                    head -1 | sed 's/^[ \t]*//;s/[[:space:]]\+/ /g')
    fi
    [[ -z "$gpu_model" ]] && gpu_model="Integrated Graphics"
}

# 系统信息检测（增强兼容性）
get_system() {
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    kernel_ver=$(uname -r | cut -d'-' -f1)
    uptime_str=$(uptime -p 2>/dev/null || uptime | 
                sed -E 's/^.*up[[:space:]]+//;s/,.*$//')
}

# 生成标准化报告
generate_report() {
    cat <<-EOF
	System Snapshot @ $(date '+%Y-%m-%d %H:%M')
	-----------------------------------------
	[CPU] ${cpu_model} (${cpu_cores} Threads)
	[RAM] ${mem_total} Total
	[Disk] ${disk_info}
	[GPU] ${gpu_model}
	${gpu_driver:+[Driver] $gpu_driver}

	[OS] ${os_name}
	[Kernel] ${kernel_ver}
	[Uptime] ${uptime_str}
	EOF
}

# 主执行流程（增强错误处理）
main() {
    echo "▶ 开始系统检测..." >&2
    get_hardware || { echo "硬件检测失败"; exit 1; }
    get_gpu || { echo "GPU检测异常"; exit 2; }
    get_system || { echo "系统信息错误"; exit 3; }
    
    generate_report | tee "system_info_$(hostname).txt"
    echo "✔ 检测完成 → system_info_$(hostname).txt" >&2
}

main "$@"
