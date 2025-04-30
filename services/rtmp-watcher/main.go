package main

import (
	"fmt"
	"log"
	"net"
	"strings"
)

const listenPort = ":1935"

func main() {
	fmt.Println("RTMP Watcher starting on port", listenPort)
	listener, err := net.Listen("tcp", listenPort)
	if err != nil {
		log.Fatalf("Failed to bind to port %s: %v", listenPort, err)
	}
	defer listener.Close()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Connection accept error: %v", err)
			continue
		}

		go handleRTMP(conn)
	}
}

func handleRTMP(conn net.Conn) {
	defer conn.Close()

	buf := make([]byte, 2048)
	n, err := conn.Read(buf)
	if err != nil {
		log.Printf("Failed reading: %v", err)
		return
	}

	data := string(buf[:n])
	if strings.Contains(data, "connect") || strings.Contains(data, "publish") {
		log.Printf("[RTMP Detected] Raw: %s", strings.TrimSpace(data))
	} else {
		log.Printf("Unrecognized connection attempt")
	}
}