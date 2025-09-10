#!/bin/bash

echo "📶 抓取 VPN 隧道 (tun0) 报文"
echo "=============================="

CAP_FILE="tun0-capture.pcap"
CAP_PATH="/app/$CAP_FILE"
LOCAL_SAVE="./$CAP_FILE"

# 检查 tun0 是否存在
if ! docker exec vpn-client ip link show tun0 >/dev/null 2>&1; then
  echo "❌ vpn-client 中未检测到 tun0，VPN 可能未建立"
  exit 1
fi

# 启动 tcpdump（后台 20 包）
echo "📡 在 vpn-client 的 tun0 接口启动抓包..."
docker exec vpn-client rm -f "$CAP_PATH" >/dev/null 2>&1 || true
docker exec vpn-client sh -c "tcpdump -i tun0 -w $CAP_PATH -c 20" &
TCPDUMP_PID=$!

echo "💡 请现在在另一个终端执行 ping、curl 等测试命令"
echo "⏳ 抓包进行中，等待 20 个包..."

wait $TCPDUMP_PID

# 导出文件
echo "📦 导出抓包文件..."
docker cp vpn-client:$CAP_PATH "$LOCAL_SAVE"

if [ -f "$LOCAL_SAVE" ]; then
  echo "✅ VPN 隧道报文抓取成功，文件位置：$LOCAL_SAVE"
  echo "💡 可用 Wireshark 打开，分析是否为加密后的 IP 封装包"
else
  echo "❌ 抓包文件导出失败"
  exit 1
fi
