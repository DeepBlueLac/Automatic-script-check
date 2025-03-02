#!/usr/bin/env bash
# 深度学习环境检测脚本(v4.7)
# 输出文件：env_report_$(hostname).txt
set -e

# 硬件核心检测
get_hardware() {
    # CPU检测
    cpu_model=$(lscpu | awk -F': +' '/Model name/ {print $2; exit}')
    cpu_cores=$(nproc --all 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    
    # 内存检测
    mem_total=$(free -h | awk '/Mem/{printf "%.1f%s", $2, substr($3,1,1)}')
    
    # 存储检测
    disk_info=$(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | awk '
        $3 ~ /[a-zA-Z]/ {print $1"("$3")-"$2; exit}
        {print $1"-"$2; exit}')
}

# GPU环境检测
get_gpu_env() {
    # NVIDIA驱动检测
    if command -v nvidia-smi &>/dev/null; then
        gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | uniq | xargs)
        driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq)
    else
        gpu_model=$(lspci | grep -iE 'vga|3d|display' | cut -d: -f3- | head -1 | xargs)
        [[ -z "$gpu_model" ]] && gpu_model="Integrated Graphics"
    fi

    # CUDA工具链检测
    cuda_path=$(command -v nvcc 2>/dev/null || which nvcc 2>/dev/null || echo "未找到")
    if [[ -f "$cuda_path" ]]; then
        cuda_compiler_ver=$(${cuda_path} --version | grep release | awk '{print $6}')
    fi
}

# CUDA软件栈验证
validate_cuda() {
    # cuDNN完整性检查
    cudnn_check=$(find /usr/local/cuda /usr -name cudnn_version.h 2>/dev/null | head -1)
    if [[ -n "$cudnn_check" ]]; then
        cudnn_ver=$(grep -m1 CUDNN_MAJOR "$cudnn_check" | awk '{print $3"."$5"."$7}' | tr -d '\r')
    fi

    # 版本一致性验证
    if [[ "$pytorch_cuda_ver" && "$cuda_compiler_ver" ]]; then
        [[ "${pytorch_cuda_ver%.*}" == "${cuda_compiler_ver%.*}" ]] && 
            cuda_match="✔ 一致" || cuda_match="✘ 不一致"
    fi
}

# PyTorch环境检测
get_pytorch_info() {
    python3 -c "
import sys, torch, subprocess
try:
    print(f'''[PyTorch环境]
版本: {torch.__version__}
CUDA可用: {torch.cuda.is_available()}
GPU算力: {torch.cuda.get_device_capability() if torch.cuda.is_available() else 'N/A'}
PyTorch CUDA版本: {torch.version.cuda if hasattr(torch.version, 'cuda') else 'N/A'}''')
except Exception as e:
    print(f'[错误] PyTorch检测失败: {str(e)}')
    sys.exit(1)
" 2>&1 | while read -r line; do echo "    $line"; done
}

# 系统信息
get_system() {
    os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    kernel_ver=$(uname -r | cut -d'-' -f1)
    uptime_str=$(uptime -p 2>/dev/null || uptime | sed -E 's/^.*up[[:space:]]+//;s/,.*$//')
}

# 生成报告
generate_report() {
    {
        echo "深度学习环境检测报告 @ $(date '+%Y-%m-%d %H:%M')"
        echo "=========================================="
        echo "[硬件配置]"
        echo "CPU: ${cpu_model} (${cpu_cores}线程)"
        echo "内存: ${mem_total}"
        echo "存储: ${disk_info}"
        echo "GPU: ${gpu_model}"
        
        echo "\n[软件环境]"
        echo "操作系统: ${os_name}"
        echo "内核版本: ${kernel_ver}"
        echo "启动时长: ${uptime_str}"
        echo "NVIDIA驱动: ${driver_ver:-未安装}"
        
        echo "\n[CUDA验证]"
        echo "CUDA编译器路径: ${cuda_path:-未找到}"
        echo "CUDA编译器版本: ${cuda_compiler_ver:-N/A}"
        echo "版本一致性: ${cuda_match:-未检测}"
        echo "cuDNN版本: ${cudnn_ver:-未检测到}"
        
        echo "\n[PyTorch验证]"
        get_pytorch_info
    } | tee "env_report_$(hostname).txt"
}

main() {
    echo "▶ 开始环境检测..." >&2
    get_hardware
    get_gpu_env
    get_system
    validate_cuda
    generate_report
    echo "✔ 检测完成 → env_report_$(hostname).txt" >&2
}

main "$@"
