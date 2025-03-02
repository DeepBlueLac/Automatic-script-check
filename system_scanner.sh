#!/usr/bin/env bash
# 全版本兼容系统检测脚本(v4.2)
# 输出文件：system_full_report_$(hostname).txt
set -eo pipefail

# 硬件检测（兼容WSL和物理机）
get_hardware() {
  cpu_model=$(lscpu | grep -m1 'Model name' | cut -d':' -f2 | xargs)
  cpu_cores=$(nproc --all 2>/dev/null || grep -c ^processor /proc/cpuinfo)
  mem_total=$(free -h | awk '/Mem/{printf "%.1f%s", $2, substr($3,1,1)}')
  disk_info=$(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | awk '
      $3 ~ /[a-zA-Z]/ {print $1"("$3")-"$2; exit}
      {print $1"-"$2; exit}')
}

# GPU检测（支持NVIDIA/AMD/集成显卡）
get_gpu() {
  if command -v nvidia-smi &>/dev/null; then
    gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | uniq | xargs)
    gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq)
  else
    gpu_model=$(lspci | grep -iE 'vga|3d|display' | cut -d: -f3- | head -1 | sed 's/^[ \t]*//;s/[[:space:]]\+/ /g')
    [[ -z "$gpu_model" ]] && gpu_model="Integrated Graphics"
  fi
}

# Python环境检测
get_python_env() {
  python3 - <<EOF 2>/dev/null || true
import torch, sys
print(f'''[Python环境]
PyTorch版本: {torch.__version__}
CUDA可用: {torch.cuda.is_available()}
GPU算力: {torch.cuda.get_device_capability() if torch.cuda.is_available() else 'N/A'}
PyTorch CUDA版本: {torch.version.cuda if hasattr(torch.version, 'cuda') else 'N/A'}
cuDNN版本: {torch.backends.cudnn.version() if torch.cuda.is_available() else 'N/A'}''')
EOF
}

# CUDA工具链检测
get_cuda_info() {
  # CUDA编译器路径检测
  nvcc_path=$(command -v nvcc 2>/dev/null || echo "未找到")
  [[ "$nvcc_path" == "未找到" ]] && nvcc_path=$(find_conda_nvcc)

  # 版本一致性检查
  if [[ "$nvcc_path" != "未找到" ]]; then
    nvcc_ver=$($nvcc_path --version | grep release | awk '{print $6}' | tr -d ',')
    cuda_env_ver=$(python3 -c "import torch; print(torch.version.cuda if hasattr(torch.version, 'cuda') else 'None')" 2>/dev/null || echo "N/A")
    [[ "$nvcc_ver" == "$cuda_env_ver" ]] && version_check="匹配" || version_check="不匹配 (系统: $nvcc_ver vs PyTorch: $cuda_env_ver)"
  fi

  # cuDNN完整性检查
  if [[ -f /usr/include/cudnn.h || -f /usr/local/cuda/include/cudnn.h ]]; then
    cudnn_check="已安装"
  elif python3 -c "import torch; print(torch.backends.cudnn.version())" &>/dev/null; then
    cudnn_check="通过PyTorch加载"
  else
    cudnn_check="未检测到"
  fi
}

find_conda_nvcc() {
  [[ -n "$CONDA_PREFIX" ]] && find "$CONDA_PREFIX" -name nvcc 2>/dev/null | head -1 || echo "未找到"
}

generate_report() {
  cat <<-EOF
	System Full Report @ $(date '+%Y-%m-%d %H:%M')
	--------------------------------------------
	[硬件配置]
	CPU: ${cpu_model} (${cpu_cores}线程)
	内存: ${mem_total}
	存储: ${disk_info}
	GPU: ${gpu_model}
	驱动: ${gpu_driver:-N/A}

	[系统信息]
	OS: $(lsb_release -sd 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
	内核: $(uname -r)
	运行时间: $(uptime -p 2>/dev/null || uptime | sed -E 's/^.*up[[:space:]]+//;s/,.*$//')

	[CUDA工具链]
	编译器路径: ${nvcc_path:-N/A}
	版本一致性: ${version_check:-N/A}
	cuDNN状态: ${cudnn_check}

	$(get_python_env)
	EOF
}

main() {
  echo "▶ 开始全面系统检测..." >&2
  get_hardware || { echo "[警告] 硬件检测失败"; }
  get_gpu || { echo "[警告] GPU检测异常"; }
  get_cuda_info
  generate_report | tee "system_full_report_$(hostname).txt"
  echo "✔ 检测完成 → system_full_report_$(hostname).txt" >&2
}

main "$@"
