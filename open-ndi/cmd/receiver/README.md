# receiver

## What it does

1. Discovers `_openndi._udp.local` sender via mDNS.
2. Connects over TCP to sender on port **9000**, sends its UDP listen address.
3. Starts listening on UDP port **5000** and logs received packets.

## Run

```bash
go run github.com/youruser/open-ndi/cmd/receiver
``` 

### Or after build:

```bash
./open-ndi-receiver
``` 