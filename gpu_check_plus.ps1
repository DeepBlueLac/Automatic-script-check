# GPU Environment Detection Script for PowerShell v1.0
# Report file: system_report_$(hostname)_$(Get-Date -Format "yyyyMMdd_HHmmss").txt

Write-Host "Starting GPU Environment Detection..." -ForegroundColor Green
Write-Host "========================================"

# Hardware Detection
function Get-HardwareInfo {
    Write-Host "Detecting Hardware..." -ForegroundColor Yellow
    
    # CPU Information
    $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
    $global:cpu_info = $cpu.Name.Trim()
    
    # Memory Information  
    $memory = Get-WmiObject -Class Win32_ComputerSystem
    $global:mem_total = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2).ToString() + "GB"
    
    # GPU Information
    try {
        $gpu_output = nvidia-smi --query-gpu=name,driver_version --format=csv,noheader,nounits 2>$null
        if ($gpu_output) {
            $global:gpu_info = $gpu_output.Split(',')[0].Trim()
            $global:gpu_driver = $gpu_output.Split(',')[1].Trim()
        } else {
            $gpu_wmi = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" } | Select-Object -First 1
            $global:gpu_info = $gpu_wmi.Name
            $global:gpu_driver = "NVIDIA Driver Not Detected"
        }
    } catch {
        $global:gpu_info = "GPU Detection Failed"
        $global:gpu_driver = "Unknown"
    }
}

# System Information Detection
function Get-SystemInfo {
    Write-Host "Detecting System Info..." -ForegroundColor Yellow
    
    $global:os_version = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    $global:os_build = (Get-WmiObject -Class Win32_OperatingSystem).BuildNumber
}

# CUDA Environment Detection
function Get-CudaInfo {
    Write-Host "Detecting CUDA Environment..." -ForegroundColor Yellow
    
    # Detect nvcc version
    try {
        $nvcc_output = nvcc --version 2>$null
        if ($nvcc_output) {
            $global:cuda_compiler = ($nvcc_output | Select-String "release").ToString().Split("release")[1].Split(",")[0].Trim()
        } else {
            $global:cuda_compiler = "Not Installed"
        }
    } catch {
        $global:cuda_compiler = "Not Detected"
    }
    
    # Detect CUDA Path
    $cuda_paths = @("C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA", "C:\Program Files (x86)\NVIDIA GPU Computing Toolkit\CUDA")
    $global:cuda_path = "Not Found"
    foreach ($path in $cuda_paths) {
        if (Test-Path $path) {
            $versions = Get-ChildItem $path -Directory | Sort-Object Name -Descending
            if ($versions) {
                $global:cuda_path = $versions[0].FullName
                break
            }
        }
    }
}

# Python Environment Detection
function Get-PythonInfo {
    Write-Host "Detecting Python Environment..." -ForegroundColor Yellow
    
    # Python Version
    try {
        $python_output = python --version 2>$null
        if ($python_output) {
            $global:python_version = $python_output
        } else {
            $global:python_version = "Not Installed"
        }
    } catch {
        $global:python_version = "Not Detected"
    }
    
    # Conda Environment
    try {
        $conda_output = conda --version 2>$null
        if ($conda_output) {
            $global:conda_version = $conda_output
        } else {
            $global:conda_version = "Not Installed"
        }
    } catch {
        $global:conda_version = "Not Detected"
    }
    
    # PyTorch Detection
    try {
        $pytorch_output = python -c "import torch; print(f'PyTorch Version: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}'); print(f'PyTorch CUDA Version: {torch.version.cuda}')" 2>$null
        if ($pytorch_output) {
            $global:pytorch_info = $pytorch_output
        } else {
            $global:pytorch_info = "PyTorch Not Installed"
        }
    } catch {
        $global:pytorch_info = "PyTorch Detection Failed"
    }
}

# Generate Report
function Generate-Report {
    Write-Host "Generating Detection Report..." -ForegroundColor Yellow
    
    $hostname = $env:COMPUTERNAME
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $report_file = "system_report_${hostname}_${timestamp}.txt"
    
    $report_content = @"
Deep Learning Environment Detection Report ($(Get-Date -Format "yyyy-MM-dd HH:mm"))
========================================
[Hardware Configuration]
CPU Architecture: $global:cpu_info
Memory Total: $global:mem_total
GPU Information: $global:gpu_info
GPU Driver: $global:gpu_driver

[System Information]
Operating System: $global:os_version
System Build: $global:os_build

[CUDA Environment]
CUDA Compiler Version: $global:cuda_compiler
CUDA Installation Path: $global:cuda_path

[Python Environment]
Python Version: $global:python_version
Conda Version: $global:conda_version

[Deep Learning Framework]
$global:pytorch_info
"@
    
    $report_content | Out-File -FilePath $report_file -Encoding UTF8
    
    Write-Host "========================================"
    Write-Host "Detection Complete!" -ForegroundColor Green
    Write-Host "Report saved to: $report_file" -ForegroundColor Cyan
    Write-Host "========================================"
    
    # Display Report Content
    Write-Host "`nReport Content:" -ForegroundColor Magenta
    Write-Host $report_content
    
    return $report_file
}

# Main Execution Flow
function Main {
    Get-HardwareInfo
    Get-SystemInfo
    Get-CudaInfo
    Get-PythonInfo
    $report_file = Generate-Report
    
    Write-Host "`nTo re-run detection, execute: .\gpu_check_plus.ps1" -ForegroundColor Gray
}

# Execute Main Function
Main 