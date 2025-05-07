package control

import (
	"encoding/json"
	"log"
	"net"
)

// Config holds control-plane details.
type Config struct {
	ReceiverAddr string `json:"receiver_addr"`
}

// ListenAndServe blocks on TCP `addr`, reads a Config JSON from the receiver, and returns it.
func ListenAndServe(addr string) Config {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("control listen error: %v", err)
	}
	defer ln.Close()

	conn, err := ln.Accept()
	if err != nil {
		log.Fatalf("control accept error: %v", err)
	}
	defer conn.Close()

	var cfg Config
	if err := json.NewDecoder(conn).Decode(&cfg); err != nil {
		log.Fatalf("control decode error: %v", err)
	}
	log.Printf("Control: received config %+v\n", cfg)
	return cfg
}

// Connect dials the sender at `addr`, sends our desired UDP listen port,
// and returns the Config we sent (receiver address).
func Connect(addr string) Config {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		log.Fatalf("control dial error: %v", err)
	}
	defer conn.Close()

	// we will listen on UDP port 5000
	cfg := Config{ReceiverAddr: "0.0.0.0:5000"}
	if err := json.NewEncoder(conn).Encode(&cfg); err != nil {
		log.Fatalf("control encode error: %v", err)
	}
	log.Printf("Control: sent config %+v\n", cfg)
	return cfg
}