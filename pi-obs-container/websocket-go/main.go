package main

import (
	"fmt"
	"log"
	"github.com/gorilla/websocket"
)

const (
	websocketURL = "ws://localhost:4455"
	password     = "cda123" // Set password if enabled
)

func main() {
	// Connect to OBS WebSocket
	conn, _, err := websocket.DefaultDialer.Dial(websocketURL, nil)
	if err != nil {
		log.Fatal("Error connecting to WebSocket:", err)
	}
	defer conn.Close()

	// Authenticate if needed
	if password != "" {
		authPayload := map[string]interface{}{
			"request-type": "Authenticate",
			"auth":         password,
		}
		conn.WriteJSON(authPayload)
	}

	// Create Scene 1
	createScene(conn, "Scene1")
	// Add Sources
	addSourceToScene(conn, "Scene1", "Camera1", "v4l2_input")
	addSourceToScene(conn, "Scene1", "ScreenCapture", "xcomposite_input")

	// Create Scene 2
	createScene(conn, "Scene2")
	// Add Sources
	addSourceToScene(conn, "Scene2", "Camera2", "v4l2_input")
	addSourceToScene(conn, "Scene2", "Media", "ffmpeg_source")

	// Switch to Scene 1
	switchToScene(conn, "Scene1")

	fmt.Println("Scenes and sources configured successfully!")
}

func createScene(conn *websocket.Conn, sceneName string) {
	payload := map[string]interface{}{
		"request-type": "CreateScene",
		"sceneName":    sceneName,
	}
	err := conn.WriteJSON(payload)
	if err != nil {
		log.Println("Error creating scene:", err)
	}
}

func addSourceToScene(conn *websocket.Conn, sceneName, sourceName, sourceType string) {
	payload := map[string]interface{}{
		"request-type": "AddInput",
		"sceneName":    sceneName,
		"inputName":    sourceName,
		"inputKind":    sourceType,
		"sceneItemEnabled": true,
	}
	err := conn.WriteJSON(payload)
	if err != nil {
		log.Println("Error adding source to scene:", err)
	}
}

func switchToScene(conn *websocket.Conn, sceneName string) {
	payload := map[string]interface{}{
		"request-type": "SetCurrentProgramScene",
		"sceneName":    sceneName,
	}
	err := conn.WriteJSON(payload)
	if err != nil {
		log.Println("Error switching to scene:", err)
	}
}