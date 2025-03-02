#!/bin/bash
# 增强版系统检测脚本(v2.1)
# 生成文件：system_report_$(hostname)_$(date +%Y%m%d).log

set -eo pipefail  # 启用严格错误检测

# ================== 硬件检测模块 ==================
detect_hardware() {
    # CPU信息提取（支持不同厂商）
    cpu_info=$(lscpu | awk -F':' '
        /Model name/ {name=$2}
        /Socket\(s\)/ {sockets=$2}
        /Vendor ID/ {vendor=$2}
        END {
            if (vendor ~ /GenuineIntel/) {type="Intel"}
            else if (vendor ~ /AuthenticAMD/) {type="AMD"}
            else {type="Unknown"}
            gsub(/^[ \t]+/, "", name);
            printf "%s | %s | %s sockets", type, name, sockets
        }'
    )

    # 内存检测改进（支持ECC内存识别）
    mem_total=$(free -h | awk '/Mem:/{print $2}')
    mem_slots=$(sudo dmidecode -t memory 2>/dev/null | grep -c "Size:.*MB" || echo "0")
    ecc_status=$(sudo dmidecode -t memory 2>/dev/null | grep -q "Error Correction Type: None" && echo "Non-ECC" || echo "ECC")

    # 存储设备检测（区分NVMe和SATA）
    ssd_model=$(lsblk -d -o MODEL,SIZE,ROTA,TRAN | awk '
        /0$/ && $4 == "sata" {type="SATA SSD"; print $1,$2,type}
        /0$/ && $4 == "nvme" {type="NVMe SSD"; print $1,$2,type}
        /1$/ {type="HDD"; print $1,$2,type}' | head -n1
    )
}

# ================== NVIDIA专用检测 ==================
detect_nvidia() {
    # 多GPU支持
    nvidia_gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | tr '\n' '|')
    nvidia_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | uniq 2>/dev/null)
    
    # 容器环境兼容检测
    cuda_version=$(
        nvcc --version 2>/dev/null | sed -n 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/p' ||
        cat /usr/local/cuda/version.txt 2>/dev/null | awk '{print $3}' ||
        echo "未检测到"
    )
}

# ================== 软件环境检测 ==================
detect_software() {
    # 操作系统检测增强（支持更多发行版）
    os_info=$(
        lsb_release -ds 2>/dev/null ||
        cat /etc/*release | grep PRETTY_NAME | cut -d'"' -f2 ||
        echo "Unknown OS"
    )

    # Python环境检测（支持虚拟环境）
    python_env=$(
        if [[ -n "$VIRTUAL_ENV" ]]; then
            echo "$(python3 --version 2>&1 | awk '{print $2}') (虚拟环境)"
        else
            python3 --version 2>&1 | awk '{print $2}'
        fi
    )
}

# ================== 报告生成 ==================
generate_report() {
    report_file="system_report_$(hostname)_$(date +%Y%m%d).log"
    
    cat <<-EOF > "$report_file"
	============== 增强版系统检测报告 ==============
	生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
	主机名称: $(hostname)

	[硬件配置]
	--------------------------------------------
	CPU架构:   ${cpu_info:-检测失败}
	内存配置:  ${mem_total} (${ecc_status}) | 物理插槽: ${mem_slots}
	存储设备:  ${ssd_model:-检测失败}
	GPU信息:   ${nvidia_gpu:-未检测到NVIDIA GPU}

	[软件环境]
	--------------------------------------------
	操作系统:  ${os_info}
	内核版本:  $(uname -r)
	Python:    ${python_env:-未安装}
	Conda:     $(conda --version 2>/dev/null | awk '{print $2}' || echo "未安装")

	[加速环境]
	--------------------------------------------
	NVIDIA驱动: ${nvidia_driver:-未安装}
	CUDA版本:  ${cuda_version}
	cuDNN版本: $(find /usr/ -name cudnn_version.h 2>/dev/null | xargs grep -m1 CUDNN_MAJOR | awk '{print $3"."$5"."$7}')

	[系统状态]
	--------------------------------------------
	运行时间:  $(uptime -p | sed 's/up //')
	内存使用:  $(free -h | awk '/Mem/{print $3"/"$2 " ("$4" 可用)"}')
	存储空间:  $(df -h / | awk 'NR==2{print $4 " 可用 / 总 " $2}')
	温度监控:  $(
		sensors 2>/dev/null | awk '
			/Core/ {sum+=$3; count++} 
			END {if(count>0) printf "CPU: +%.1f°C (%d核)", sum/count, count}'
		) | GPU: $(
		nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | tr '\n' '|'
		)
	EOF
}

# ================== 主执行流程 ==================
main() {
    echo "=== 开始系统检测 ==="
    detect_hardware
    detect_nvidia
    detect_software
    generate_report
    
    echo -e "\n[检测完成]"
    echo "报告文件: $(pwd)/${report_file}"
    echo "验证命令: md5sum ${report_file}"
}

main "$@"
