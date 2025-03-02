#!/usr/bin/env bash
# 深度学习环境极简检测脚本(v6.100)
# 生成报告：system_report_$(hostname)_$(date +%s).txt

# 硬件检测增强
detect_hardware() {
    # CPU型号检测
    cpu_info=$(lscpu 2>/dev/null | awk -F': +' '/Model name/ {print $2; exit}' || 
        grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)

    # 内存容量检测（兼容旧版本free）
    mem_total=$(free -h 2>/dev/null | awk '/Mem/{print $2}' || 
        grep MemTotal /proc/meminfo | awk '{printf "%.1fG", $2/1024/1024}')

    # GPU信息检测（同时支持NVIDIA/AMD/集显）
    if command -v nvidia-smi &>/dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1 | xargs)
    else
        gpu_info=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | cut -d: -f3- | xargs)
    fi
}

# 环境版本检测增强
detect_versions() {
    # CUDA路径检测（优先识别conda环境）
    if [ -n "$CONDA_PREFIX" ]; then
        cuda_path="$CONDA_PREFIX"
        nvcc_path=$(find "$cuda_path" -type f -name nvcc 2>/dev/null | head -1)
    else
        nvcc_path=$(which nvcc 2>/dev/null || echo "")
        cuda_path=$(dirname "$(dirname "$nvcc_path")" 2>/dev/null || echo "")
    fi

    # CUDA版本检测多路径
    cuda_system=$(nvcc --version 2>/dev/null | grep release | sed 's/.*release //' | cut -d, -f1 || 
        find /usr/local/cuda/version.txt -exec cat {} \; 2>/dev/null | cut -d' ' -f3)

    # PyTorch CUDA版本检测
    torch_cuda=$(python3 -c "import torch; print(torch.version.cuda or '未检测到CUDA')" 2>/dev/null || 
        echo "Python/PyTorch未安装")
}

# cuDNN完整性检测
check_cudnn() {
    # Conda环境检测
    if [ -n "$CONDA_PREFIX" ]; then
        cudnn_version=$(find "$CONDA_PREFIX/include" -name cudnn_version.h 2>/dev/null | 
            xargs grep CUDNN_MAJOR | awk '{print $3"."$5"."$7}' | sed 's/;//g')
    fi
    
    # 系统路径检测
    if [ -z "$cudnn_version" ]; then
        cudnn_version=$(find /usr/include /usr/local/cuda/include -name cudnn_version.h 2>/dev/null | 
            xargs grep CUDNN_MAJOR 2>/dev/null | awk '{print $3"."$5"."$7}' | sed 's/;//g' | head -1)
    fi

    [ -z "$cudnn_version" ] && cudnn_version="未检测到"
}

# 计算能力验证
check_compute_capability() {
    compute_cap=$(python3 -c "
import torch
if torch.cuda.is_available():
    prop = torch.cuda.get_device_properties(0)
    print(f'{prop.major}.{prop.minor}')
else:
    print('N/A')
" 2>/dev/null || echo "检测失败")
}

# 生成结构化报告
generate_report() {
    report_file="system_report_$(hostname)_$(date +%s).txt"
    {
        echo "深度学习环境检测报告 ($(date '+%Y-%m-%d %H:%M'))"
        echo "========================================"
        echo "[硬件配置]"
        echo "CPU架构: ${cpu_info:-未知}"
        echo "内存总量: ${mem_total:-未知}"
        echo "GPU信息: ${gpu_info:-未检测到独立显卡}"
        echo ""
        echo "[软件环境]"
        echo "操作系统: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
        echo "内核版本: $(uname -r)"
        echo ""
        echo "[CUDA环境]"
        echo "编译器路径: ${cuda_path:-未检测到}"
        echo "系统CUDA版本: ${cuda_system:-未安装}"
        echo "PyTorch CUDA版本: ${torch_cuda}"
        echo "cuDNN版本: ${cudnn_version}"
        echo "计算能力: ${compute_cap}"
        echo ""
        echo "[Python环境]"
        python3 -V 2>/dev/null || echo "Python3 未安装"
        command -v conda >/dev/null && echo "Conda版本: $(conda --version 2>/dev/null | cut -d' ' -f2)"
        python3 -c "import torch; print(f'PyTorch版本: {torch.__version__}')" 2>/dev/null || echo "PyTorch未安装"
    } > "$report_file"
    echo "检测完成 ➜ 查看报告: $report_file"
}

# 主执行流程
main() {
    detect_hardware
    detect_versions
    check_cudnn
    check_compute_capability
    generate_report
}

# 安全执行环境
if [ -n "$BASH_VERSION" ]; then
    main "$@"
else
    echo "请使用bash执行此脚本" >&2
    exit 1
fi
