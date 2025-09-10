#!/bin/bash

RESULT="./perf_result_pqc/performance_report.tsv"
CLIENT="vpn-client"
SERVER="vpn-server"

# mkdir -p ./perf_result_pqc
mkdir -p ./perf_result_pqc
MODE=$(docker logs "$CLIENT" 2>&1 | grep -q "PQC 模式" && echo "PQC" || echo "Baseline")

for CON in "$CLIENT" "$SERVER"; do
  CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" "$CON" | tr -d '%')
  MEM=$(docker stats --no-stream --format "{{.MemUsage}}" "$CON" | awk '{print $1}')
  echo -e "CPU-$CON\t$MODE\t$CPU" >> "$RESULT"
  echo -e "MEM-$CON\t$MODE\t$MEM" >> "$RESULT"
done
echo "✅ CPU / MEM 数据采集完成"
