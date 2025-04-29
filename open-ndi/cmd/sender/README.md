# sender

## What it does

1. Advertises `_openndi._udp.local` on port **9000** via mDNS.
2. Listens on TCP `:9000` for receiver to connect & send its UDP listen address.
3. Starts sending dummy UDP packets to that address.

## Run

```bash
go run github.com/youruser/open-ndi/cmd/sender
```

### Or after build:

```bash
./open-ndi-sender
```
