#!/bin/bash

echo "🔐 自动抓取 TLS 握手数据包"
echo "============================"

CAP_FILE="tls-capture.pcap"
CAP_PATH="/app/$CAP_FILE"
LOCAL_SAVE="./$CAP_FILE"

# 确认 tcpdump 是否安装
if ! docker exec vpn-server which tcpdump >/dev/null 2>&1; then
  echo "❌ server 容器未安装 tcpdump，请确认 Dockerfile 或容器中安装了"
  exit 1
fi

# 删除旧抓包文件
docker exec vpn-server rm -f "$CAP_PATH" >/dev/null 2>&1

echo "📡 启动 tcpdump 抓包 (限制 20 个数据包)..."
# 注意：此 tcpdump 会阻塞，直到抓完 20 个数据包
docker exec vpn-server tcpdump -i eth0 port 443 -w "$CAP_PATH" -c 20 &
TCPDUMP_CONTAINER_PID=$!

sleep 1

echo "🔁 重启 vpnclient 容器，触发 TLS 握手..."
docker-compose restart vpnclient >/dev/null

echo "⏳ 等待抓包完成..."
wait $TCPDUMP_CONTAINER_PID

echo "📦 导出抓包文件..."
docker cp vpn-server:$CAP_PATH "$LOCAL_SAVE"

if [ -f "$LOCAL_SAVE" ]; then
  echo "✅ TLS 报文抓取成功，文件位置：$LOCAL_SAVE"
  echo "💡 可用 Wireshark 打开查看握手（ClientHello、ServerHello、证书等）"
else
  echo "❌ 抓包文件导出失败"
  exit 1
fi
