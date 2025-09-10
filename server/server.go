package main

import (
	"crypto/tls"
	"flag"
	"log"
	"net"
	"os/exec"
	"strings"
	"sync"

	"github.com/songgao/water"
)

var pqcEnabled = flag.Bool("pqc", false, "启用后量子密钥交换模式（X25519+Kyber768）")

const (
	TUN_NAME = "tun0"
	TUN_IP   = "10.0.0.1"
	PORT     = "443"
	MTU      = 1500
)

func main() {
	flag.Parse()

	cert, err := tls.LoadX509KeyPair("/app/certs/server.crt", "/app/certs/server.key")
	if err != nil {
		log.Fatalf("证书加载失败: %v", err)
	}

	curves := []tls.CurveID{tls.X25519}
	if *pqcEnabled {
		log.Println("🔐 启用 PQC 模式（X25519 + Kyber768）")
		curves = []tls.CurveID{tls.X25519Kyber768Draft00, tls.X25519}
	} else {
		log.Println("🔐 启用 Baseline 模式（仅 X25519）")
	}

	config := &tls.Config{
		Certificates:     []tls.Certificate{cert},
		MinVersion:       tls.VersionTLS13,
		CurvePreferences: curves,
	}

	listener, err := tls.Listen("tcp", ":"+PORT, config)
	if err != nil {
		log.Fatalf("监听失败: %v", err)
	}
	defer listener.Close()
	log.Printf("🔐 VPN Server 已启动在 0.0.0.0:%s", PORT)

	ifce, err := createTunInterface()
	if err != nil {
		log.Fatalf("TUN 创建失败: %v", err)
	}
	enableIPForwarding()
	setupNAT()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("连接接收失败: %v", err)
			continue
		}
		go handleClient(conn, ifce)
	}
}

func createTunInterface() (*water.Interface, error) {
	config := water.Config{DeviceType: water.TUN}
	config.Name = TUN_NAME
	ifce, err := water.New(config)
	if err != nil {
		return nil, err
	}
	exec.Command("ip", "addr", "add", TUN_IP+"/24", "dev", TUN_NAME).Run()
	exec.Command("ip", "link", "set", TUN_NAME, "up").Run()
	log.Printf("TUN 接口已启用: %s", TUN_NAME)
	return ifce, nil
}

func enableIPForwarding() {
	exec.Command("sysctl", "-w", "net.ipv4.ip_forward=1").Run()
	log.Println("✅ 启用 IP 转发")
}

/*func setupNAT() {
	out, _ := exec.Command("sh", "-c", "ip route | grep default | awk '{print $5}'").Output()
	iface := strings.TrimSpace(string(out)) // ⚠️ 必须加 trim
	cmd := exec.Command("iptables", "-t", "nat", "-A", "POSTROUTING", "-s", "10.0.0.0/24", "-o", iface, "-j", "MASQUERADE")
	cmd.Run()
	log.Printf("✅ 设置 NAT (POSTROUTING MASQUERADE on %s)", iface)
}*/

func setupNAT() {
	// 获取容器 eth0 的 IP（出口地址）
	out, err := exec.Command("sh", "-c", "ip -4 addr show dev eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}'").Output()
	if err != nil {
		log.Printf("❌ 获取 eth0 IP 失败: %v", err)
		return
	}
	ip := strings.TrimSpace(string(out))
	log.Printf("💡 eth0 IP: %s", ip)

	// 清空原 NAT 表
	exec.Command("iptables", "-t", "nat", "-F", "POSTROUTING").Run()

	// 显式使用 SNAT，而非 MASQUERADE
	err = exec.Command("iptables", "-t", "nat", "-A", "POSTROUTING", "-s", "10.0.0.0/24", "-j", "SNAT", "--to-source", ip).Run()
	if err != nil {
		log.Printf("❌ 设置 SNAT 失败: %v", err)
		return
	}

	log.Printf("✅ 设置 NAT (SNAT → %s)", ip)
}

func handleClient(conn net.Conn, ifce *water.Interface) {
	defer conn.Close()
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		buf := make([]byte, MTU)
		for {
			n, err := conn.Read(buf)
			if err != nil {
				log.Println("客户端读取失败:", err)
				return
			}
			ifce.Write(buf[:n])
		}
	}()

	go func() {
		defer wg.Done()
		buf := make([]byte, MTU)
		for {
			n, err := ifce.Read(buf)
			if err != nil {
				log.Println("TUN 读取失败:", err)
				return
			}
			conn.Write(buf[:n])
		}
	}()

	wg.Wait()
	log.Printf("🔌 客户端断开连接: %s", conn.RemoteAddr())
}
