#!/bin/bash

CLIENT="vpn-client"
SERVER="vpn-server"

echo ""
echo "📋 VPN 状态全面检测报告"
echo "=============================="

# ---------- [1] TLS 检查 ----------
echo ""
echo "🔐 [1] TLS 握手状态（$CLIENT → $SERVER:443）"

# TLS_OUTPUT=$(docker exec "$CLIENT" curl -sk --max-time 5 https://vpn-server:443 2>&1)
TLS_OUTPUT=$(docker exec "$CLIENT" curl -v --cacert /app/certs/server.crt --max-time 5 https://vpn-server:443 2>&1)
if echo "$TLS_OUTPUT" | grep -q "TLSv1.3"; then
  echo "✅ TLS 握手成功"
else
  echo "❌ TLS 握手失败"
  echo "⛔ 返回信息如下："
  echo "$TLS_OUTPUT"
fi

# ---------- [2] 公网 IP 比较 ----------
echo ""
echo "🌍 [2] 公网 IP 是否来自 VPN Server"

HOST_IP=$(curl -s ifconfig.me)
CLIENT_IP=$(docker exec "$CLIENT" curl -s ifconfig.me)

echo "宿主机    : $HOST_IP"
echo "vpn-client: $CLIENT_IP"

if [ "$HOST_IP" != "$CLIENT_IP" ] && [ -n "$CLIENT_IP" ]; then
  echo "✅ vpn-client 使用了独立出口（与宿主机不同）"
  echo "   → 极可能通过 VPN Server 出网"
else
  echo "❌ vpn-client 与宿主机出口一致，未走 VPN"
fi

# ---------- [3] 默认路由 ----------
echo ""
echo "🔁 [3] vpn-client 默认路由检查"

DEFAULT_IF=$(docker exec "$CLIENT" ip route | grep '^default' | awk '{print $5}')
if [ "$DEFAULT_IF" = "tun0" ]; then
  echo "✅ 默认路由通过 tun0（VPN 隧道）"
else
  echo "❌ 默认路由未指向 VPN（当前: $DEFAULT_IF）"
fi

# ---------- [4] traceroute ----------
echo ""
echo "🧭 [4] traceroute 路径检查（第一跳应为 10.0.0.1）"

# 安装 traceroute（仅在第一次时安装）
if ! docker exec "$CLIENT" which traceroute >/dev/null 2>&1; then
  echo "⚠️  traceroute 不存在，正在安装..."
  docker exec "$CLIENT" bash -c "apt-get update && apt-get install -y traceroute"
fi

TRACE_FIRST=$(docker exec "$CLIENT" traceroute -n -m 3 8.8.8.8 2>/dev/null | sed -n 2p | awk '{print $2}')
if [ "$TRACE_FIRST" = "10.0.0.1" ]; then
  echo "✅ 第一跳为 VPN Server"
else
  echo "❌ 第一跳不是 VPN（当前: $TRACE_FIRST）"
fi

# ---------- [5] VPN Server IP 转发 + NAT ----------
echo ""
echo "📶 [5] VPN Server IP 转发 & NAT 检查"

IP_FORWARD=$(docker exec "$SERVER" cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
NAT_RULE=$(docker exec "$SERVER" iptables -t nat -S POSTROUTING 2>/dev/null | grep MASQUERADE)

if [ "$IP_FORWARD" = "1" ]; then
  echo "✅ IP 转发已启用"
else
  echo "❌ IP 转发未启用"
fi

if [ -n "$NAT_RULE" ]; then
  echo "✅ NAT MASQUERADE 规则已存在"
else
  echo "❌ NAT MASQUERADE 规则缺失"
fi

# ---------- [6] 抓包文件检测 ----------
echo ""
echo "🧪 [6] 抓包文件是否存在"

TLS_PCAP="tls-capture.pcap"
TUN_PCAP="tun0-capture.pcap"

[ -f "$TLS_PCAP" ] && echo "✅ 存在 TLS 抓包文件 ($TLS_PCAP)" || echo "⚠️  TLS 抓包文件不存在"
[ -f "$TUN_PCAP" ] && echo "✅ 存在 tun0 抓包文件 ($TUN_PCAP)" || echo "⚠️  tun0 抓包文件不存在"

echo ""
echo "🎯 状态检测完成"
