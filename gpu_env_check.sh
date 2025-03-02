#!/usr/bin/env bash
# 极简环境检测脚本(v5.1)
# 生成文件：system_report_$(hostname).txt

# 硬件检测
get_cpu() {
    cpu_info=$(lscpu | awk -F': +' '/Model name/ {print $2; exit}')
    [[ -z "$cpu_info" ]] && cpu_info=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
}

get_mem() {
    mem_total=$(free -h | awk '/Mem/{print $2}')
}

get_gpu() {
    if command -v nvidia-smi &>/dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | xargs)
    else
        gpu_info=$(lspci | grep -i 'vga\|3d\|display' | head -1 | cut -d: -f3- | xargs)
    fi
}

# 软件检测
get_system() {
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    kernel_ver=$(uname -r)
}

# Python检测
check_python() {
    if command -v python3 &>/dev/null; then
        py_version=$(python3 -V 2>&1)
        python3 -c "import torch; print('PyTorch:', torch.__version__)" 2>&1 | grep 'PyTorch:' || echo "PyTorch: 未安装"
    else
        py_version="Python3 未安装"
    fi
}

# 生成报告
generate_report() {
    echo "系统检测报告 $(date '+%Y-%m-%d %H:%M')"
    echo "================================="
    echo "[硬件信息]"
    echo "CPU: ${cpu_info:-未知}"
    echo "内存: ${mem_total:-未知}"
    echo "GPU: ${gpu_info:-未知}"
    echo ""
    echo "[系统信息]"
    echo "操作系统: ${os_name:-未知}"
    echo "内核版本: ${kernel_ver:-未知}"
    echo ""
    echo "[运行环境]"
    echo "${py_version:-Python环境未检测到}"
} > "system_report_$(hostname).txt"

main() {
    get_cpu
    get_mem
    get_gpu
    get_system
    check_python
    generate_report
    echo "检测完成 ➜ 查看报告: system_report_$(hostname).txt"
}

main "$@"
