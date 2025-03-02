#!/bin/bash
# 极简系统检测脚本(v3.0)
# 输出文件：system_info_$(hostname).txt

# 硬件检测核心参数
get_hardware() {
    # CPU信息
    cpu_model=$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)
    cpu_cores=$(nproc)
    
    # 内存信息
    mem_total=$(free -h | awk '/Mem/{print $2}')
    
    # 存储信息
    disk_info=$(lsblk -dno NAME,SIZE,MODEL | awk '{print $1"("$3")-"$2}' | head -1)
}

# GPU检测（自动识别NVIDIA）
get_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | uniq)
        gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq)
    else
        gpu_model=$(lspci | grep -i 'vga\|3d\|display' | cut -d':' -f3 | head -1)
    fi
}

# 系统信息检测
get_system() {
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    kernel_ver=$(uname -r)
    uptime_str=$(uptime -p)
}

# 生成简洁报告
generate_report() {
    cat <<-EOF
	System Snapshot @ $(date '+%Y-%m-%d %H:%M')
	-----------------------------------------
	[CPU] ${cpu_model} (${cpu_cores} cores)
	[RAM] ${mem_total} 
	[Disk] ${disk_info}
	[GPU] ${gpu_model:-No dedicated GPU}
	${gpu_driver:+[Driver] $gpu_driver}

	[OS] ${os_name}
	[Kernel] ${kernel_ver}
	[Uptime] ${uptime_str}
	EOF
}

# 主执行流程
main() {
    get_hardware
    get_gpu
    get_system
    generate_report | tee "system_info_$(hostname).txt"
}

main "$@"
