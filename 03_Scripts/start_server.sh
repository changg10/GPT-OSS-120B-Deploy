#!/bin/bash
# =================================================================
# Script Name: start_server.sh
# Description: DGX Spark 环境 GPT-OSS-120B 推理服务一键启动脚本
# Version:     v1.0 
# Author:      昌国庆 (Leadtek)
# Date:        2025-12-23
# =================================================================

# --- 1. 基础配置 ---
IMAGE_NAME="nvcr.io/nvidia/tensorrt-llm/release:spark-single-gpu-dev"
CONTAINER_NAME="trtllm_gpt120b_server"
SERVER_PORT=8355

# Tiktoken 下载地址定义
URL_CL100K="https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken"
URL_O200K="https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken"

# --- 2. 路径计算 ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# [宿主机路径]
HOST_MODEL_DIR="$PROJECT_ROOT/02_Models/gpt-oss-120b"
HOST_TIKTOKEN_DIR="$PROJECT_ROOT/02_Models/tiktoken_cache"
HOST_CONFIG_FILE="$SCRIPT_DIR/extra-llm-api-config.yml"

# [容器内路径]
CTR_MODEL_DIR="/models/gpt-oss-120b"
CTR_TIKTOKEN_DIR="/app/tiktoken"
CTR_CONFIG_FILE="/app/extra_config.yml"

# --- 3. 环境与资源检查 ---
echo ">>> [Init] 正在初始化环境检查..."

# (A) 检查 Docker
if ! docker ps >/dev/null 2>&1; then
    echo "❌ 错误: 无法连接 Docker。请检查权限或服务状态。"
    exit 1
fi

# (B) 检查模型目录
if [ ! -d "$HOST_MODEL_DIR" ]; then
    echo "❌ 错误: 未找到模型目录: $HOST_MODEL_DIR"
    exit 1
fi

# (C) 检查配置文件
if [ ! -f "$HOST_CONFIG_FILE" ]; then
    echo "❌ 错误: 未找到配置文件: $HOST_CONFIG_FILE"
    exit 1
fi

# (D) 检查并自动下载 Tiktoken (新增逻辑) ==========================
echo ">>> [Check] 检查 Tiktoken 依赖文件..."

# 确保目录存在
if [ ! -d "$HOST_TIKTOKEN_DIR" ]; then 
    echo "   创建目录: $HOST_TIKTOKEN_DIR"
    mkdir -p "$HOST_TIKTOKEN_DIR"
fi

# 定义下载函数
download_if_missing() {
    local filename=$1
    local url=$2
    local filepath="$HOST_TIKTOKEN_DIR/$filename"

    if [ -f "$filepath" ]; then
        echo "   ✅ 已存在: $filename (跳过下载)"
    else
        echo "   ⬇️ 未找到 $filename，尝试自动下载..."
        
        # 检查 wget 是否存在
        if ! command -v wget &> /dev/null; then
            echo "   ❌ 错误: 系统未安装 wget，且文件缺失。请手动下载或安装 wget。"
            exit 1
        fi

        # 下载文件 (显示进度条)
        wget -q --show-progress -O "$filepath" "$url"
        
        if [ $? -ne 0 ]; then
            echo "   ❌ 下载失败，请检查网络或 URL。"
            exit 1
        fi
    fi
}

# 执行检查
download_if_missing "cl100k_base.tiktoken" "$URL_CL100K"
download_if_missing "o200k_base.tiktoken" "$URL_O200K"
# =================================================================

# --- 5. 启动服务 (前台模式) ---
echo ">>> [Stop] 清理旧容器..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

echo "=================================================="
echo "🚀 准备启动推理服务 ..."
echo "   按 Ctrl+C 可停止服务"
echo "--------------------------------------------------"
echo "   API 地址: http://localhost:$SERVER_PORT/v1"
echo "=================================================="
echo "⏳ 正在加载模型，请留意下方日志 (出现 Uvicorn running 即成功)..."
echo ""

docker run --rm -it \
  --name $CONTAINER_NAME \
  --gpus all \
  --ipc=host \
  --network host \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  -v "$HOST_MODEL_DIR":"$CTR_MODEL_DIR" \
  -v "$HOST_TIKTOKEN_DIR":"$CTR_TIKTOKEN_DIR" \
  -v "$HOST_CONFIG_FILE":"$CTR_CONFIG_FILE" \
  "$IMAGE_NAME" \
  bash -c "
    export TIKTOKEN_ENCODINGS_BASE='$CTR_TIKTOKEN_DIR' && \
    echo '>>> Starting TRT-LLM Server...' && \
    trtllm-serve \"$CTR_MODEL_DIR\" \
      --host 0.0.0.0 \
      --port $SERVER_PORT \
      --trust_remote_code \
      --extra_llm_api_options \"$CTR_CONFIG_FILE\"
  "

echo ""
echo ">>> 服务已停止。"