#!/bin/bash
# =================================================================
# Script Name: start_webui.sh
# Description: DGX Spark 环境 UI 一键启动脚本
# Version:     v2.1 
# Author:      昌国庆 (Leadtek)
# Date:        2025-12-23
# =================================================================
set -e
CONTAINER_NAME="open-webui"

# --- [新增] 自动获取本机 IP ---
# 原理：查询路由表，获取本机对外通信的主要 IP 地址
CURRENT_IP=$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')

# 兜底：如果获取失败（极少情况），默认显示 localhost
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="localhost"
fi

echo "🚀 Starting Open WebUI (connected to TRT-LLM on localhost:8355)..."

# --- 自动清理逻辑 ---
# 检查是否已存在同名容器（无论运行中还是停止），如果有则强制删除
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo "🔄 检测到旧容器存在，正在清理..."
    docker rm -f ${CONTAINER_NAME}
fi

# 检查 TRT-LLM 是否已在监听 8355 (需要安装 netcat)
if command -v nc &> /dev/null; then
    if ! nc -z localhost 8355 2>/dev/null; then
        echo "⚠️ Warning: TRT-LLM server not detected on port 8355. WebUI may fail to connect."
    fi
else
    echo "⚠️ 'nc' command not found, skipping port check."
fi

# --- 启动容器 ---
# 注意：使用 --network host 模式时，WebUI 默认端口通常是 8080
docker run -d \
  --name ${CONTAINER_NAME} \
  --network host \
  -e OPENAI_API_BASE_URL="http://127.0.0.1:8355/v1" \
  -e OPENAI_API_KEY="EMPTY" \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

echo "✅ Open WebUI started."
# [修改] 这里直接使用变量显示真实 IP
echo "👉 Access at: http://${CURRENT_IP}:8080"
echo "💡 To stop: docker rm -f ${CONTAINER_NAME}"