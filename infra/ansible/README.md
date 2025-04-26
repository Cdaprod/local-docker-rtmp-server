# Camera Rig Network Setup with Ansible

This repository contains Ansible playbooks to set up a camera rig network using a Raspberry Pi 5 as the host and Raspberry Pi Zero W 2 as peripherals. The setup includes Docker deployment, WiFi Access Point configuration, and WireGuard VPN for secure remote connectivity.

## Architecture Overview

This setup follows a hexagonal architecture pattern with the following components:

1. **RPi5 Host**: 
   - Acts as a Docker host running the RTMP server and associated services
   - Provides a WiFi Access Point for local connectivity
   - Runs a WireGuard VPN server for secure remote access
   - Serves as the central hub for all media processing

2. **RPiZW2 Peripheral**:
   - Connects to the RPi5 host via WiFi and/or VPN
   - Provides service discovery via Avahi
   - Serves as a peripheral device (camera, sensor, etc.)

## Prerequisites

- Ansible 2.9 or later
- Raspberry Pi 5 with Raspberry Pi OS
- Raspberry Pi Zero W 2 with Raspberry Pi OS
- SSH access to both devices

## Directory Structure

```
camera-rig-ansible/
├── inventory.yml
├── camera_rig_network_setup.yml
├── test_camera_rig_deployment.yml
└── templates/
    ├── hostapd.conf.j2
    ├── dnsmasq.conf.j2
    ├── wg0.conf.j2
    ├── peripheral_wg0.conf.j2
    ├── env.j2
    └── camera-rig.service.j2
```

## Setup Instructions

1. Clone this repository:
   ```bash
   git clone <this-repo-url>
   cd camera-rig-ansible
   ```

2. Update the `inventory.yml` file with your actual Raspberry Pi IP addresses and credentials.

3. Create the template files in the `templates/` directory using the provided examples.

4. Run the deployment playbook:
   ```bash
   ansible-playbook -i inventory.yml camera_rig_network_setup.yml
   ```

5. Test the deployment:
   ```bash
   ansible-playbook -i inventory.yml test_camera_rig_deployment.yml
   ```

## Network Configuration

### WiFi Access Point
- SSID: CameraRig
- Security: WPA2-PSK
- IP Range: 192.168.4.0/24

### VPN Configuration
- Protocol: WireGuard
- Host IP: 10.200.200.1/24
- Peripheral IP: 10.200.200.2/24

### Docker Network
- Network Name: camera_network
- Subnet: 172.20.0.0/16

## Services

The following services are deployed on the RPi5 host:

- RTMP Server
- OBS Studio
- Blender
- Metadata Service
- Video Processing Pipeline

## Adding New Devices

To add a new peripheral device to the network:

1. Add the device to the `rpizw2_peripherals` group in the inventory file
2. Run the deployment playbook to configure it
3. The device will automatically discover the host via Avahi/mDNS

## Troubleshooting

- If the WiFi AP doesn't start, check `/var/log/syslog` for hostapd errors
- For VPN connection issues, check `/var/log/syslog` for WireGuard logs
- To debug Docker containers, use `make logs <service-name>`

## Acknowledgments

This setup is based on the repository at https://github.com/Cdaprod/local-docker-rtmp-server