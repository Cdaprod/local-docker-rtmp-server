# cmd

Two entrypoints:

- **sender**: advertises via mDNS, waits on TCP port 9000 for a receiver, then streams UDP.
- **receiver**: browses via mDNS, connects over TCP to negotiate, then listens on UDP port 5000.

Or after building:

```bash
./open-ndi-sender
``` 




