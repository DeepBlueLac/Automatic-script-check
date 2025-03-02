#!/usr/bin/env bash
# 全版本兼容系统检测脚本(v4.3)
# 输出文件：system_full_report_$(hostname).txt

# 关键修复：Bash版本兼容性处理
if [[ "$(echo "$BASH_VERSION" | cut -d. -f1)" -lt 4 ]]; then
  set -e  # 旧版Bash禁用pipefail
else
  set -eo pipefail
fi

# 硬件检测（增强兼容性）
get_hardware() {
  cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {print $2; exit}' | sed 's/^[ \t]*//;s/[[:space:]]\+/ /g')
  cpu_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "未知")
  
  # 内存检测兼容旧版free
  mem_total=$(free -m 2>/dev/null | awk '/Mem/{printf "%.1fG", $2/1024}' || echo "检测失败")

  # 存储检测优化
  disk_info=$(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | awk '
    $3 ~ /[a-zA-Z]/ {print $1"("$3")-"$2; exit}
    {print $1"-"$2; exit}' | head -1)
}

# GPU检测（安全增强版）
get_gpu() {
  if command -v nvidia-smi &>/dev/null; then
    gpu_model=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | uniq | xargs || echo "NVIDIA GPU检测失败")
    gpu_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | uniq)
  else
    gpu_model=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | cut -d: -f3- | head -1 | sed 's/^[ \t]*//;s/[[:space:]]\+/ /g')
    [[ -z "$gpu_model" ]] && gpu_model="集成显卡/未知"
  fi
}

# Python环境检测（安全执行）
get_python_env() {
  python3 - <<'EOF' 2>/dev/null || echo "[Python环境] 检测失败"
import sys, torch
try:
    cuda_avail = torch.cuda.is_available()
    print(f'''[Python环境]
PyTorch版本: {torch.__version__}
CUDA可用: {cuda_avail}
GPU算力: {torch.cuda.get_device_capability() if cuda_avail else 'N/A'}
PyTorch CUDA版本: {torch.version.cuda if hasattr(torch.version, 'cuda') else 'N/A'}
cuDNN版本: {torch.backends.cudnn.version() if cuda_avail else 'N/A'}''')
except Exception as e:
    print(f"[Python环境] 异常: {str(e)}")
EOF
}

# CUDA检测（多路径查找）
find_conda_nvcc() {
  local paths=(
    "${CONDA_PREFIX}/bin/nvcc"
    "$HOME/miniconda3/bin/nvcc"
    "/opt/conda/bin/nvcc"
  )
  for path in "${paths[@]}"; do
    [[ -x "$path" ]] && { echo "$path"; return; }
  done
  echo "未找到"
}

get_cuda_info() {
  nvcc_path=$(command -v nvcc 2>/dev/null || find_conda_nvcc)
  
  if [[ "$nvcc_path" != "未找到" ]]; then
    nvcc_ver=$("$nvcc_path" --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',' || echo "未知")
    cuda_env_ver=$(python3 -c "import torch; print(torch.version.cuda if hasattr(torch.version, 'cuda') else 'None')" 2>/dev/null || echo "N/A")
    [[ "$nvcc_ver" == "$cuda_env_ver" ]] && version_check="匹配" || version_check="不匹配 (系统: $nvcc_ver vs PyTorch: $cuda_env_ver)"
  fi

  # cuDNN检测优化
  cudnn_check=$(
    [[ -f /usr/include/cudnn.h ]] && echo "系统安装" ||
    python3 -c "import torch; print('PyTorch内置') if torch.cuda.is_available() else print('未检测到')" 2>/dev/null || echo "未知"
  )
}

generate_report() {
  cat <<-EOF
	System Full Report @ $(date '+%Y-%m-%d %H:%M')
	--------------------------------------------
	[硬件配置]
	CPU: ${cpu_model:-未知} (${cpu_cores}线程)
	内存: ${mem_total:-未知}
	存储: ${disk_info:-未知}
	GPU: ${gpu_model:-未知}
	驱动: ${gpu_driver:-N/A}

	[系统信息]
	OS: $( (lsb_release -sd || grep PRETTY_NAME /etc/os-release) 2>/dev/null | cut -d'"' -f2 )
	内核: $(uname -r)
	运行时间: $(uptime 2>/dev/null | sed -E 's/.*up[[:space:]]+//;s/,.*//;s/\s+//g')

	[CUDA工具链]
	编译器路径: ${nvcc_path:-N/A}
	版本一致性: ${version_check:-未检测}
	cuDNN状态: ${cudnn_check}

	$(get_python_env)
	EOF
}

main() {
  echo "▶ 开始系统检测..." >&2
  get_hardware
  get_gpu
  get_cuda_info
  generate_report | tee "system_full_report_$(hostname).txt"
  echo "✔ 检测完成 → system_full_report_$(hostname).txt" >&2
}

main "$@"
