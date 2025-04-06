package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// Core directories
const (
	obsAssetsDir     = "/root/obs-assets"
	obsConfigDir     = "/root/.config/obs-studio/basic"
	backupBaseDir    = "/root/obs-assets/backups"
	timestampFormat  = "2006-01-02_15-04-05"
	defaultStreamTag = "unnamed-stream"
)

// Backup OBS config and assets into obs-assets/backups/<stream-tag>
func backupOBS(streamTag string) {
	if streamTag == "" {
		streamTag = defaultStreamTag
	}

	timestamp := time.Now().Format(timestampFormat)
	backupPath := filepath.Join(backupBaseDir, fmt.Sprintf("%s_%s", streamTag, timestamp))

	log.Println("[obs-assets] Creating backup directory:", backupPath)
	if err := os.MkdirAll(backupPath, 0755); err != nil {
		log.Fatalf("Error creating backup directory: %v", err)
	}

	configBackup := filepath.Join(backupPath, "config")
	assetsBackup := filepath.Join(backupPath, "assets")

	// Copy OBS config
	err := exec.Command("cp", "-r", obsConfigDir, configBackup).Run()
	if err != nil {
		log.Fatalf("Failed to backup OBS config: %v", err)
	}

	// Copy all obs-assets (optional: skip node_modules or archive folders)
	err = exec.Command("cp", "-r", obsAssetsDir, assetsBackup).Run()
	if err != nil {
		log.Fatalf("Failed to backup obs-assets: %v", err)
	}

	log.Printf("[obs-assets] OBS configuration and overlays backed up to %s\n", backupPath)
}

// Optionally push backup to Git
func pushBackupToGitRepo() {
	cmd := exec.Command("sh", "-c", `
    cd /root/obs-assets &&
    git add backups &&
    git commit -m "Backup: $(date +'%Y-%m-%d %H:%M:%S')" &&
    git push origin main
  `)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		log.Printf("Git push failed: %v", err)
	}
}

func main() {
	// Optional: accept stream name as argument
	streamTag := ""
	if len(os.Args) > 1 {
		streamTag = os.Args[1]
	}

	// Step 1: Backup
	backupOBS(streamTag)

	// Step 2: Push to Git (optional)
	pushBackupToGitRepo()
}