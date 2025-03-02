#!/usr/bin/env bash
# 深度学习环境检测脚本(v4.0)
# 输出文件：gpu_env_report_$(hostname).txt
set -eo pipefail

# 硬件及驱动检测
get_gpu_info() {
    # GPU型号检测
    if command -v nvidia-smi &>/dev/null; then
        gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | uniq | xargs)
        driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq)
    else
        gpu_model=$(lspci | grep -iE 'vga|3d|display' | cut -d: -f3- | head -1 | xargs)
    fi
    [[ -z "$gpu_model" ]] && gpu_model="未检测到独立显卡"

    # CUDA编译器检测
    cuda_compiler_path=$(which nvcc 2>/dev/null || echo "/usr/local/cuda/bin/nvcc")
    [[ -f "$cuda_compiler_path" ]] || cuda_compiler_path="未找到nvcc"
}

# CUDA环境验证
validate_cuda() {
    # CUDA版本一致性检查
    if [[ -f "/usr/local/cuda/version.txt" ]]; then
        system_cuda=$(awk '{print $3}' /usr/local/cuda/version.txt)
    else
        system_cuda=$(nvcc --version 2>/dev/null | grep release | awk '{print $5}' | tr -d ',') || true
    fi

    # cuDNN完整性检查
    cudnn_check=$(find /usr -name 'cudnn_version.h' 2>/dev/null | head -1 || echo "")
    [[ -n "$cudnn_check" ]] && cudnn_version=$(grep CUDNN_MAJOR "$cudnn_check" | awk '{print $3}' | paste -sd '.')
}

# PyTorch环境检测
get_pytorch_info() {
    python3 -c "
try:
    import torch
    print(f'''PYTORCH_DATA
{torch.__version__}
{torch.cuda.is_available()}
{'-'.join(map(str, torch.cuda.get_device_capability()))}
{torch.version.cuda}
{torch.backends.cudnn.version() or '未知'}''')
except Exception as e:
    print(f'PYTORCH_ERROR: {str(e)}')
" | awk '
    /^PYTORCH_DATA/ {mode=1; next}
    /^PYTORCH_ERROR:/ {print $0 > "/dev/stderr"; exit 1}
    mode {data[NR]=$0}
    END {
        if (NR>=4) {
            print "pytorch_ver=" data[1]
            print "cuda_available=" data[2]
            print "compute_capability=" data[3]
            print "pytorch_cuda_ver=" data[4]
            print "cudnn_ver=" data[5]
        }
    }' > pytorch_vars
    source pytorch_vars 2>/dev/null || true
    rm -f pytorch_vars
}

# 生成综合报告
generate_report() {
    cat <<-EOF
	深度学习环境检测报告 @ $(date '+%Y-%m-%d %H:%M')
	-----------------------------------------------
	[硬件配置]
	GPU型号: ${gpu_model}
	驱动版本: ${driver_version:-未知}

	[环境路径]
	CUDA编译器路径: ${cuda_compiler_path}

	[版本一致性]
	系统CUDA版本: ${system_cuda:-未检测到}
	PyTorch CUDA版本: ${pytorch_cuda_ver:-未关联}
	${system_cuda:+版本一致性状态: $([ "$system_cuda" = "$pytorch_cuda_ver" ] && echo "✔ 一致" || echo "⚠ 不一致")}

	[加速库完整性]
	cuDNN版本: ${cudnn_version:-未知} ${cudnn_version:+${cudnn_ver:+($cudnn_ver)}}

	[功能验证]
	CUDA可用状态: ${cuda_available:-检测失败}
	GPU算力等级: ${compute_capability:-N/A}
	计算功能验证: $([ "${cuda_available}" = "True" ] && echo "✔ 通过基础测试" || echo "✖ 不可用")
	EOF
}

main() {
    echo "▶ 开始深度学习环境检测..." >&2
    get_gpu_info
    validate_cuda
    get_pytorch_info || echo "⚠ PyTorch检测异常" >&2
    
    generate_report | tee "gpu_env_report_$(hostname).txt"
    echo "✔ 检测完成 → gpu_env_report_$(hostname).txt" >&2
}

main "$@"
