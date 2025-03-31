package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"
)

// Paths for backup and source volumes
const (
	obsAssetsDir   = "/root/obs-assets"
	obsConfigDir   = "/root/.config/obs-studio/basic"
	backupDir      = "/data/obs-backup"
	timestampFormat = "2006-01-02_15-04-05"
)

// Backup OBS Config and Assets
func backupOBS() {
	timestamp := time.Now().Format(timestampFormat)
	backupPath := fmt.Sprintf("%s/%s", backupDir, timestamp)

	// Create backup directory
	err := os.MkdirAll(backupPath, 0755)
	if err != nil {
		log.Fatalf("Error creating backup directory: %v", err)
	}

	// Backup Config
	err = exec.Command("cp", "-r", obsConfigDir, fmt.Sprintf("%s/config", backupPath)).Run()
	if err != nil {
		log.Fatalf("Failed to backup OBS config: %v", err)
	}

	// Backup Assets
	err = exec.Command("cp", "-r", obsAssetsDir, fmt.Sprintf("%s/assets", backupPath)).Run()
	if err != nil {
		log.Fatalf("Failed to backup OBS assets: %v", err)
	}

	log.Printf("OBS Config and Assets backed up to %s\n", backupPath)
}

// Push to GitHub or Git Repo (Optional)
func pushToGitRepo() {
	cmd := exec.Command("sh", "-c", `
    cd /data/obs-backup &&
    git init &&
    git add . &&
    git commit -m "Backup $(date +'%Y-%m-%d %H:%M:%S')" &&
    git remote add origin https://github.com/yourusername/obs-backup.git &&
    git push -u origin main
  `)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		log.Printf("Error pushing to GitHub: %v", err)
	}
}

func main() {
	// Backup OBS Configs and Assets
	backupOBS()

	// Push to GitHub if needed
	pushToGitRepo()
}