#!/bin/bash
# =================================================================
# Script Name: download_model.sh
# Description: DGX Spark 环境 通用下载模型权重脚本
# Version:     v2.1 
# Author:      昌国庆 (Leadtek)
# Date:        2025-12-23
# =================================================================

# ============================================================
# 1. 配置区域 (只需修改这里即可适配不同模型)
# ============================================================

# ModelScope 上的模型 ID (例如: qwen/Qwen-72B-Chat 或 openai-mirror/gpt-oss-120b)
MODEL_ID="openai-mirror/gpt-oss-120b"

# 本地保存的文件夹名称 (模型将下载到 02_Models/这个名字下)
# 建议与模型本身名字保持一致，方便识别
MODEL_DIR_NAME="gpt-oss-120b"

# ============================================================
# 2. 自动定位路径 
# ============================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
TARGET_MODEL_DIR="$PROJECT_ROOT/02_Models"

# 拼接最终的绝对下载路径
FINAL_DOWNLOAD_PATH="$TARGET_MODEL_DIR/$MODEL_DIR_NAME"

echo "========================================================"
echo ">>> 项目根目录: $PROJECT_ROOT"
echo ">>> 目标模型 ID: $MODEL_ID"
echo ">>> 本地存储路径: $FINAL_DOWNLOAD_PATH"
echo "========================================================"

# ============================================================
# 3. 环境准备
# ============================================================
echo ">>> [Init] 正在检查 Python 环境..."

# 检查是否安装 python3
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: 未检测到 Python3，请先安装。"
    exit 1
fi

# 进入脚本目录
cd "$SCRIPT_DIR"

# 创建虚拟环境 (隐藏目录 .venv_downloader)
if [ ! -d ".venv_downloader" ]; then
    echo ">>> [Init] 创建临时虚拟环境..."
    python3 -m venv .venv_downloader
fi

# 激活虚拟环境
echo ">>> [Init] 激活虚拟环境..."
source .venv_downloader/bin/activate

# 安装 modelscope
echo ">>> [Init] 安装/更新 ModelScope 工具..."
# 使用清华源加速，并静默安装减少刷屏，只显示错误
pip install modelscope -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

# ============================================================
# 4. 执行下载
# ============================================================
echo ">>> [Download] 开始下载模型..."
echo ">>> 注意: 大模型文件体积较大，请保持网络畅通..."

# 确保 02_Models 目录存在
mkdir -p "$TARGET_MODEL_DIR"

# 执行下载命令
# 变量引用说明:
# --model: 使用配置的 MODEL_ID
# --local_dir: 使用计算出的 FINAL_DOWNLOAD_PATH
modelscope download --model "$MODEL_ID" --local_dir "$FINAL_DOWNLOAD_PATH"

# ============================================================
# 5. 收尾工作
# ============================================================
if [ $? -eq 0 ]; then
    echo ""
    echo "========================================================"
    echo "✅ SUCCESS: 模型已成功下载！"
    echo "📂 存放路径: $FINAL_DOWNLOAD_PATH"
    echo "========================================================"
else
    echo ""
    echo "========================================================"
    echo "❌ FAIL: 下载失败。"
    echo "   请检查网络连接或磁盘空间后重试。"
    echo "========================================================"
fi

# 退出虚拟环境
deactivate
