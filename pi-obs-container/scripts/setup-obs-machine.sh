#!/bin/bash

# Update and install OBS Studio and dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y obs-studio ffmpeg vlc golang-go git

# Install OBS NDI Plugin and Runtime
wget https://github.com/Palakis/obs-ndi/releases/download/4.9.1/obs-ndi-4.9.1-Ubuntu20.04.deb
sudo dpkg -i obs-ndi-4.9.1-Ubuntu20.04.deb
wget https://github.com/obsproject/obs-studio/releases/download/27.2.4/NDI-runtime-4.5.1-Linux-x86_64.deb
sudo dpkg -i NDI-runtime-4.5.1-Linux-x86_64.deb

# Install obs-cli (Remote control via WebSockets)
git clone https://github.com/muesli/obs-cli.git
cd obs-cli
go build
sudo mv obs-cli /usr/local/bin/obs-cli
cd ..
rm -rf obs-cli

# Create OBS Scene Collection JSON
sudo tee /home/$USER/obs-scene.json > /dev/null <<EOF
{
  "name": "CDAProdScene",
  "sources": [
    {
      "name": "Looping_BG",
      "type": "ffmpeg_source",
      "settings": {
        "local_file": "/home/$USER/background.mp4",
        "is_looping": true
      }
    },
    {
      "name": "iPhone_Screen",
      "type": "ndi_source",
      "settings": {
        "source_name": "iPhone_Broadcast"
      }
    },
    {
      "name": "PiP_Camera",
      "type": "v4l2_input",
      "settings": {
        "device": "/dev/video0"
      }
    },
    {
      "name": "PiP_Frame",
      "type": "image_source",
      "settings": {
        "file": "/home/$USER/frame_overlay.png"
      }
    }
  ],
  "scene_order": ["Looping_BG", "iPhone_Screen", "PiP_Camera", "PiP_Frame"]
}
EOF

# Create systemd service to auto-launch OBS
sudo tee /etc/systemd/system/obs-autostart.service > /dev/null <<EOF
[Unit]
Description=Auto-start OBS Studio CDAProd Scene
After=network.target

[Service]
ExecStart=/usr/bin/obs --scene "CDAProdScene" --startstreaming
Restart=always
User=$USER
Group=$USER
WorkingDirectory=/home/$USER/
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start OBS autostart service
sudo systemctl daemon-reload
sudo systemctl enable obs-autostart.service

# Create obs-cli PiP setup script
sudo tee /home/$USER/add_pip.sh > /dev/null <<EOF
#!/bin/bash

obs-cli -s "127.0.0.1" -p "4444" AddSceneItem \\
  -scene "CDAProdScene" -source "PiP_Camera" \\
  -bounds_x 400 -bounds_y 300 -bounds_width 640 -bounds_height 360

obs-cli -s "127.0.0.1" -p "4444" AddSceneItem \\
  -scene "CDAProdScene" -source "PiP_Frame" \\
  -bounds_x 400 -bounds_y 300 -bounds_width 640 -bounds_height 360
EOF
chmod +x /home/$USER/add_pip.sh

# Create hotkeys file for OBS
sudo tee /home/$USER/.config/obs-studio/basic/profiles/Untitled/hotkeys.json > /dev/null <<EOF
{
    "OBSBasic.StartStreaming": [{"key": "OBS_KEY_F9"}],
    "OBSBasic.StopStreaming": [{"key": "OBS_KEY_F10"}],
    "OBSBasic.StartRecording": [{"key": "OBS_KEY_F11"}],
    "OBSBasic.StopRecording": [{"key": "OBS_KEY_F12"}]
}
EOF

echo "Setup complete! Reboot your system or run 'sudo systemctl start obs-autostart.service' to start OBS automatically."