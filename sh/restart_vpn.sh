#!/bin/bash

echo "===== 重启并测试VPN ====="

# 停止现有容器
echo "停止并删除现有容器..."
docker-compose down

# 删除现有镜像以确保重新构建
echo "删除旧镜像..."
docker rmi tls-vpn-vpnserver tls-vpn-vpnclient 2>/dev/null || true

# 确保TUN模块已加载
echo "检查并加载TUN模块..."
if ! lsmod | grep -q "^tun "; then
  sudo modprobe tun
  echo "已加载TUN模块"
else
  echo "TUN模块已存在"
fi

# 确保TUN设备存在
echo "检查TUN设备..."
if [ ! -c /dev/net/tun ]; then
  sudo mkdir -p /dev/net
  sudo mknod /dev/net/tun c 10 200
  sudo chmod 600 /dev/net/tun
  echo "已创建TUN设备"
else
  echo "TUN设备已存在"
fi

# 重新构建并启动容器
echo "重新构建并启动VPN容器..."
docker-compose build
docker-compose up -d 

# 等待容器启动
echo "等待容器启动..."
sleep 5

# 检查容器状态
echo "检查容器状态..."
docker-compose ps

# 检查日志
echo "检查VPN服务器日志 (5行)..."
docker-compose logs --tail=5 vpnserver

echo "检查VPN客户端日志 (5行)..."
docker-compose logs --tail=5 vpnclient

# 运行网络测试
echo "运行网络连通性测试..."
./network_test.sh

echo "===== 完成 ====="