# templates/dnsmasq.conf.j2
# Configuration for dnsmasq DHCP server

# Listen on wlan0 interface only
interface=wlan0
# Don't use and ignore /etc/resolv.conf
no-resolv
# Don't poll /etc/resolv.conf for changes
no-poll
# Add local-only domains, queries sent here wont go upstream local=/camera-rig.local/
# Never forward queries for plain names, without dots or domain parts
domain-needed
# Never forward addresses in the non-routed address spaces
bogus-priv

# Assign IP addresses between 192.168.4.2 and 192.168.4.20
# with a 24h lease time
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h

# Set the gateway and DNS server to the RPi5 host IP
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1

# Static DNS entries for local services
address=/camera-rig.local/192.168.4.1
address=/rtmp.camera-rig.local/192.168.4.1
address=/obs.camera-rig.local/192.168.4.1
address=/blender.camera-rig.local/192.168.4.1

# Log DHCP operations for debugging
log-dhcp