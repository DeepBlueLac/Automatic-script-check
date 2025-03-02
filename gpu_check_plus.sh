#!/bin/bash
# GPU环境全面检测脚本 v6.1 (Ubuntu全版本兼容)

# 初始化安全模式
set -eo pipefail
trap 'echo -e "\033[31m错误发生在第$LINENO行\033[0m"; exit 1' ERR
shopt -s inherit_errexit 2>/dev/null || true

# 颜色编码方案
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; RESET='\033[0m'

# 系统基础信息检测
get_system_info() {
  # 兼容旧版lsb_release
  if [ -f /etc/os-release ]; then
    OS_NAME=$(source /etc/os-release; echo "$PRETTY_NAME")
  else
    OS_NAME=$(uname -o)  
  fi
  KERNEL=$(uname -r)
}

# CUDA环境深度检测
check_cuda_env() {
  # NVCC路径检测
  NVCC_PATH=$(which nvcc 2>/dev/null || {
    [ -x "/usr/local/cuda/bin/nvcc" ] && echo "/usr/local/cuda/bin/nvcc" ||
    [ -x "$CONDA_PREFIX/bin/nvcc" ] && echo "$CONDA_PREFIX/bin/nvcc" ||
    echo "${RED}未检测到NVCC${RESET}"
  })

  # 版本一致性验证
  TORCH_CUDA=$(python3 -c "import torch; print(torch.version.cuda or 'CPU版')" 2>/dev/null || echo "${RED}未安装PyTorch${RESET}")
  SYS_CUDA=$($NVCC_PATH --version 2>/dev/null | grep release | cut -d' ' -f5 || echo "${RED}未获取到版本${RESET}")

  # cuDNN完整性检查
  CUDNN_HEADER=$(find /usr{/local,}/cuda/include $CONDA_PREFIX/include -name cudnn_version.h 2>/dev/null | head -1)
  if [ -n "$CUDNN_HEADER" ]; then
    CUDNN_VER=$(awk '
      /CUDNN_MAJOR/ {major=$3}
      /CUDNN_MINOR/ {minor=$3}
      /CUDNN_PATCH/ {patch=$3}
      END {if(major&&minor) printf("%d.%d.%d", major, minor, patch)}' $CUDNN_HEADER)
  else
    CUDNN_VER="${RED}未检测到cuDNN${RESET}"
  fi

  # 计算能力验证
  COMP_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | 
    awk -F. '{print $1$2}' | head -1 || echo "${RED}无法获取${RESET}")
}

# 生成检测报告
generate_report() {
  REPORT_FILE="GPU_Env_Report_$(date +%Y%m%d).log"
  cat << EOF | tee "$REPORT_FILE"

${BLUE}===== GPU环境深度检测报告 =====${RESET}
[ 生成时间 ] $(date '+%Y-%m-%d %H:%M:%S')
[ 系统信息 ] ${OS_NAME} | 内核: ${KERNEL}

${GREEN}── CUDA配置验证 ──${RESET}
NVCC路径:    ${NVCC_PATH}
系统CUDA:    ${SYS_CUDA}
PyTorch CUDA: ${TORCH_CUDA}
cuDNN版本:   ${CUDNN_VER}
计算能力:    ${COMP_CAP}

${GREEN}── 环境一致性检测 ──${RESET}
版本匹配:    $([ "${SYS_CUDA%%-*}" = "${TORCH_CUDA%%-*}" ] && 
             echo "${GREEN}一致${RESET}" || 
             echo "${RED}不一致${RESET} (系统:${SYS_CUDA} vs PyTorch:${TORCH_CUDA})")

${GREEN}── 完整性检查 ──${RESET}
CUDA编译器:  $([ -x "$NVCC_PATH" ] && echo "${GREEN}有效" || echo "${RED}无效")
cuDNN头文件: ${CUDNN_HEADER:-${RED}未找到}}
EOF
}

# 主执行流程
main() {
  echo -e "${BLUE}[ 开始环境检测 ]${RESET}"
  get_system_info
  check_cuda_env
  generate_report
  echo -e "\n${GREEN}检测完成 → 报告已保存到: ${REPORT_FILE}${RESET}"
}

main "$@"
