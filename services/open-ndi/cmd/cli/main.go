package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/Cdaprod/open-ndi/internal/discovery"
)

const (
	mdnsService      = "_openndi._udp"
	discoveryTimeout = 3 * time.Second
)

func main() {
	output := flag.String("o", "plain", "output format: plain | json")
	flag.Parse()

	addr, err := discovery.Find(mdnsService, discoveryTimeout)
	if err != nil {
		log.Fatalf("discovery failed: %v", err)
	}

	switch *output {
	case "json":
		result := map[string]string{"service": mdnsService, "address": addr}
		out, _ := json.MarshalIndent(result, "", "  ")
		fmt.Println(string(out))
	default:
		fmt.Printf("Found open-ndi sender at: %s\n", addr)
	}
}