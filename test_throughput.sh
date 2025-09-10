#!/bin/bash

# 配置变量
CLIENT="vpn-client"
SERVER="vpn-server"
mkdir -p ./perf_result_pqc

RESULT="./perf_result_pqc/performance_report.tsv"
LOG="./perf_result_pqc/iperf_test.log"

: > "$LOG"

echo "📦 开始 VPN 吞吐性能测试" | tee -a "$LOG"

# 🔍 检测当前模式
MODE=$(docker logs "$CLIENT" 2>&1 | grep -q "PQC 模式" && echo "PQC" || echo "Baseline")
echo "🔍 当前模式: $MODE" | tee -a "$LOG"

# ✅ 检查 TUN 连通性
PING=$(docker exec "$CLIENT" ping -c 1 -W 2 10.0.0.1 2>/dev/null | grep "1 received")
if [[ -z "$PING" ]]; then
  echo "❌ 无法 ping 通 vpn-server 的 TUN 地址 (10.0.0.1)，请检查 TUN 隧道是否创建" | tee -a "$LOG"
  echo -e "Throughput\t$MODE\tFAIL(ping)" >> "$RESULT"
  exit 1
fi

echo "✅ TUN 连接正常（10.0.0.2 → 10.0.0.1）" | tee -a "$LOG"

# 🛠️ 确保 server 上无旧进程（kill -9 避免缺 pkill）
PID=$(docker exec "$SERVER" sh -c "pidof iperf3 || true")
if [[ ! -z "$PID" ]]; then
  echo "🔄 清理旧 iperf3 进程（PID: $PID）" | tee -a "$LOG"
  docker exec "$SERVER" kill -9 $PID
fi

# 🚀 后台启动 server，监听一次性
echo "🚀 启动 iperf3 server（vpn-server）"

# 先杀旧的
docker exec "$SERVER" pkill iperf3 >/dev/null 2>&1 || true

# 在后台启动，并在新终端中运行以保持稳定
docker exec "$SERVER" nohup iperf3 -s > /dev/null 2>&1 &

sleep 2


# 📈 client 侧发起测试

echo "⏳ vpn-client 发起 iperf3 测试..."

RESULT_DIR="./perf_result_pqc"
mkdir -p "$RESULT_DIR"

docker exec "$CLIENT" iperf3 -c 10.0.0.1 -t 5 -p 5201 2>&1 | tee "$RESULT_DIR/iperf_client.txt"
IPERF_OUT=$(cat "$RESULT_DIR/iperf_client.txt")

echo "✅ iperf3 测试完成，准备分析结果"

# 精确匹配 receiver 行并提取单位
LINE=$(echo "$IPERF_OUT" | grep -i 'receiver' | tail -n 1)

if [[ -z "$LINE" ]]; then
  echo "❌ iperf3 无有效 receiver 输出，无法计算吞吐率" | tee -a "$LOG"
  echo -e "Throughput\t$MODE\tFAIL(receiver)" >> "$RESULT"
  exit 1
fi

VALUE=$(echo "$LINE" | awk '{for(i=1;i<=NF;i++) if ($i ~ /Mbits\/sec/) print $(i-1)}')  # 得到 483
UNIT="Mbits/sec"   # 得到 Mbits/sec

# 单位换算
if [[ "$UNIT" == "Kbits/sec" ]]; then
  VALUE=$(echo "scale=2; $VALUE / 1000" | bc)
elif [[ "$UNIT" != "Mbits/sec" ]]; then
  echo "❌ 未识别单位：$UNIT（原始行: $LINE）" | tee -a "$LOG"
  echo -e "Throughput\t$MODE\tFAIL(unit:$UNIT)" >> "$RESULT"
  exit 1
fi

echo "✅ 吞吐率：$VALUE Mbps" | tee -a "$LOG"
echo -e "Throughput\t$MODE\t$VALUE" >> "$RESULT"


