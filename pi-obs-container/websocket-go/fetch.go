package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/gorilla/websocket"
)

type OBSMessage struct {
	Op int             `json:"op"`
	D  json.RawMessage `json:"d"`
}

func main() {
	url := "ws://localhost:4455"
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		log.Fatal("Connection error:", err)
	}
	defer conn.Close()

	// 1. Wait for HELLO (op 0)
	var hello OBSMessage
	if err := conn.ReadJSON(&hello); err != nil {
		log.Fatal("Failed to read hello:", err)
	}
	if hello.Op != 0 {
		log.Fatal("Expected Hello message")
	}

	// 2. Send IDENTIFY (op 1)
	identify := map[string]interface{}{
		"op": 1,
		"d": map[string]interface{}{
			"rpcVersion": 1,
		},
	}
	conn.WriteJSON(identify)

	// 3. Wait for IDENTIFIED (op 2)
	var identified OBSMessage
	if err := conn.ReadJSON(&identified); err != nil {
		log.Fatal("Failed to identify:", err)
	}
	if identified.Op != 2 {
		log.Fatal("Expected Identified response")
	}
	fmt.Println("Connected to OBS WebSocket v5!")

	// 4. Send GetSceneList request (op 6)
	reqID := fmt.Sprintf("req-%d", time.Now().UnixNano())
	sceneRequest := map[string]interface{}{
		"op": 6,
		"d": map[string]interface{}{
			"requestType": "GetSceneList",
			"requestId":   reqID,
		},
	}
	conn.WriteJSON(sceneRequest)

	// 5. Read the response
	for {
		var msg OBSMessage
		if err := conn.ReadJSON(&msg); err != nil {
			log.Fatal("Error reading message:", err)
		}

		if msg.Op == 7 {
			// Successful response to a request
			var response struct {
				RequestType string `json:"requestType"`
				RequestId   string `json:"requestId"`
				ResponseData struct {
					Scenes []struct {
						SceneName string `json:"sceneName"`
					} `json:"scenes"`
				} `json:"responseData"`
			}
			if err := json.Unmarshal(msg.D, &response); err == nil && response.RequestType == "GetSceneList" {
				fmt.Println("Scenes:")
				for _, s := range response.ResponseData.Scenes {
					fmt.Println("- ", s.SceneName)
				}
				break
			}
		}
	}
}