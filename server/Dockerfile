# FROM debian:bullseye-slim
FROM debian:bookworm
# 安装必要的系统工具
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iptables iproute2 bash curl tcpdump iperf3 coreutils ca-certificates iputils-ping net-tools dnsutils telnet traceroute&& \
    ln -sf /bin/bash /bin/sh && \
    rm -rf /var/lib/apt/lists/*


WORKDIR /app

# 拷贝构建好的 server 主程序
# COPY main /app/server
COPY server/main /app/server

# 拷贝证书（用于 TLS 握手）
COPY ../certs/server.crt /app/certs/server.crt
COPY ../certs/server.key /app/certs/server.key

# 复制项目的其余文件
COPY server/ .

CMD ["/app/server"]

# FROM alpine:3.18

# 安装必要的系统工具
# RUN apk update && apk add --no-cache iptables iproute2 bash curl tcpdump iperf3 coreutils bc

# 设置工作目录
# WORKDIR /app

# 先复制 go.mod 和 go.sum 文件，以利用 Docker 缓存来加速依赖下载i
# COPY server/go.mod server/go.sum ./
# RUN go mod tidy

# 复制项目的其余文件
# COPY server/ .

# 构建可执行文件
# RUN go build -o main server.go

# 把构建好的可执行文件设置为可执行
# RUN chmod +x ./main

# 允许使用特权模式
# CMD ["./main"]