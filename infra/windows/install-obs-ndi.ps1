# ================================
# INSTALL NDI TOOLS + FIREWALL RULES + OBS + NDI PLUGIN + distroav
# ================================

# Check if NDI Tools installed
$ndiToolsPath = "C:\Program Files\NewTek\NDI 5 Tools"

if (-not (Test-Path $ndiToolsPath)) {
    Write-Host "`n[+] Installing NDI Runtime..."
    winget install --id NDI.NDIRuntime --silent --accept-package-agreements --accept-source-agreements

    Write-Host "`n[+] Installing NDI Tools..."
    winget install --id NDI.NDITools --silent --accept-package-agreements --accept-source-agreements

    Write-Host "`n[✓] NDI Runtime and Tools installed."
} else {
    Write-Host "`n[✓] NDI Tools already installed at: $ndiToolsPath"
}

# Add Firewall Rules for NDI
Write-Host "`n[+] Configuring Windows Firewall rules for NDI..."

$ruleNames = @("NDI TCP Inbound", "NDI UDP Inbound", "NDI TCP Outbound", "NDI UDP Outbound")
$ports = "49152-65535"

New-NetFirewallRule -DisplayName $ruleNames[0] -Direction Inbound  -Protocol TCP -LocalPort  $ports -Action Allow -Profile Any -Program Any -Enabled True -Group "NDI"
New-NetFirewallRule -DisplayName $ruleNames[1] -Direction Inbound  -Protocol UDP -LocalPort  $ports -Action Allow -Profile Any -Program Any -Enabled True -Group "NDI"
New-NetFirewallRule -DisplayName $ruleNames[2] -Direction Outbound -Protocol TCP -RemotePort $ports -Action Allow -Profile Any -Program Any -Enabled True -Group "NDI"
New-NetFirewallRule -DisplayName $ruleNames[3] -Direction Outbound -Protocol UDP -RemotePort $ports -Action Allow -Profile Any -Program Any -Enabled True -Group "NDI"

Write-Host "`n[✓] Firewall rules added for NDI on ports $ports."

# Install OBS Studio
Write-Host "`n[+] Installing OBS Studio..."
winget install --id OBSProject.OBSStudio --silent --accept-package-agreements --accept-source-agreements

# Download and install OBS-NDI Plugin
$pluginUrl = "https://github.com/obs-ndi/obs-ndi/releases/download/4.11.0/obs-ndi-4.11.0-Windows-Installer.exe"
$pluginPath = "$env:TEMP\obs-ndi-installer.exe"
Invoke-WebRequest -Uri $pluginUrl -OutFile $pluginPath
Start-Process -FilePath $pluginPath -ArgumentList "/S" -Wait

Write-Host "`n[✓] OBS Studio and NDI Plugin installed."

# Optional: Install distroav
Write-Host "`n[+] Installing distroav (if available in winget)..."
winget install --id distroav.distroav --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n[✓] Installation complete. OBS, NDI, and firewall rules are ready."