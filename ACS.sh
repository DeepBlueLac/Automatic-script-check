#!/bin/bash
# 系统信息自动检测脚本（Ubuntu通用版）
# 生成文件：system_report_$(date +%Y%m%d).txt

# 硬件信息检测
cpu_info=$(lscpu | grep -E "Model name:|Architecture:|Socket(s):" | sed 's/^.*: *//' | tr '\n' '/' | sed 's/\/$//')
mem_total=$(free -h | awk '/Mem:/{print $2}')
mem_slots=$(sudo dmidecode -t memory 2>/dev/null | grep -c "Size:.*MB")
ssd_model=$(lsblk -d -o MODEL,SIZE,ROTA | awk '/0$/{print $1,$2}' | head -n1)
gpu_info=$(lspci | grep -i 'vga\|3d\|display' | cut -d'[' -f2- | sed 's/].*//' | head -n1)

# NVIDIA专用检测
nvidia_gpu=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -n1)
nvidia_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
cuda_version=$(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | cut -d',' -f1)

# 软件环境检测
os_info=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
kernel_version=$(uname -r)
docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
python_version=$(python3 --version 2>&1 | awk '{print $2}')
conda_version=$(conda --version 2>/dev/null | awk '{print $2}')

# 深度学习环境检测
pytorch_check=$(python3 -c "import torch; print(f'PyTorch {torch.__version__} | CUDA {torch.version.cuda or \"None\"}')" 2>/dev/null || echo "未安装PyTorch")
cudnn_version=$(find /usr/ -name cudnn_version.h 2>/dev/null | xargs grep 'define CUDNN_MAJOR' | awk '{print $3"."$5"."$7}' | head -n1)

# 生成报告文件
report_file="system_report_$(date +%Y%m%d).txt"
cat << EOF > "$report_file"
================ 系统检测报告 ================
检测时间: $(date '+%Y-%m-%d %H:%M:%S')

[硬件配置]
--------------------------------------------
CPU:        ${cpu_info:-无法获取}
内存:       ${mem_total} (物理插槽: ${mem_slots:-未知})
存储设备:   ${ssd_model:-无法检测SSD} SSD
显示适配器: ${nvidia_gpu:-$gpu_info}

[软件环境]
--------------------------------------------
操作系统:   ${os_info:-未知}
内核版本:   ${kernel_version:-无法获取}
Docker:     ${docker_version:-未安装}
Python:     ${python_version:-未安装}
Conda:      ${conda_version:-未安装}

[加速环境]
--------------------------------------------
NVIDIA驱动: ${nvidia_driver:-未检测到}
CUDA工具链: ${cuda_version:-未安装}
cuDNN版本:  ${cudnn_version:-未检测到}
PyTorch:    ${pytorch_check}

[诊断信息]
--------------------------------------------
* 内存使用: $(free -h | awk '/Mem/{print $3"/"$2 " ("$4" 可用)"}')
* 存储空间: $(df -h / | awk 'NR==2{print $4 " 可用 / 总 " $2}')
* 温度监控: $(sensors 2>/dev/null | grep 'Core' | head -n1 | awk '{print $3}' || echo "需安装lm-sensors")

EOF

# 执行提示
chmod +x "$report_file"
echo "检测完成！报告已保存至: $(pwd)/${report_file}"

# 验证提示
echo -e "\n[验证说明]"
echo "1. 若显示'未检测到NVIDIA组件'：请确认已安装官方驱动且未使用nouveau驱动"
echo "2. 部分检测需root权限，建议用『sudo -E bash 脚本名』执行"
echo "3. 如需完整硬件拓扑，请安装并执行『sudo lshw -html > hardware.html』"
