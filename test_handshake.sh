#!/bin/bash

CLIENT="vpn-client"
RESULT="./perf_result_pqc/performance_report.tsv"
RUNS=5

mkdir -p ./perf_result_pqc

# 获取模式
MODE=$(docker logs "$CLIENT" 2>&1 | grep -q "PQC 模式" && echo "PQC" || echo "Baseline")
echo "🔍 当前模式: $MODE"

# 测试 handshake-only
TOTAL_MS=0
for i in $(seq 1 $RUNS); do
  START=$(date +%s%3N)
  docker exec "$CLIENT" /app/client --handshake-only >/dev/null
  #docker exec "$CLIENT" /app/client >/dev/null  尝试不加handshake参数测试时延是否有区别
  END=$(date +%s%3N)
  DELTA=$((END - START))
  echo "  [$i/$RUNS] $DELTA ms"
  TOTAL_MS=$((TOTAL_MS + DELTA))
done

AVG=$(echo "scale=2; $TOTAL_MS / $RUNS" | bc)
echo -e "Handshake\t$MODE\t$AVG" >> "$RESULT"
echo "✅ 平均握手时间: $AVG ms"
