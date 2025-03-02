# 极简系统检测工具

### 快速开始

# GPU环境检测脚本使用指南

## 📋 脚本功能
### 核心检测项目
- **硬件配置**  
  ✅ CPU型号识别  
  ✅ 内存容量检测  
  ✅ GPU型号检测（支持NVIDIA/AMD/Intel多平台）

- **系统环境**  
  🐧 Linux发行版信息  
  ⚙️ 内核版本检测  
  📦 WSL2环境识别

- **开发环境**  
  🐍 Python3版本检测  
  🔥 PyTorch框架验证

## 🚀 快速启动
### 一键执行方案
```bash
# 远程执行（推荐）
git clone (https://github.com/DeepBuleLake/Automatic-script-check.git)
cd Automatic-script-check
dos2unix gpu_env_check.sh
检测完成 ➜ 查看报告: system_report_******.txt


📊 报告样例
系统检测报告 2025-03-02 17:16
=================================
[硬件信息]
CPU: AMD Ryzen 9 5950X 16-Core Processor
内存: 31Gi
GPU: NVIDIA GeForce RTX 2080 Ti

[系统信息]
操作系统: Ubuntu 22.04.1 LTS
内核版本: 5.15.167.4-microsoft-standard-WSL2

[运行环境]
Python 3.12.9
PyTorch: 2.5.1
