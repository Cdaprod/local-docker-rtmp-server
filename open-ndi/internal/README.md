# internal/

The `internal/` directory contains shared, non-exported libraries for the open-ndi project.

Each package here follows Go's `internal` visibility rule: 
> Code in `internal/` can only be imported by the top-level module (e.g., `github.com/youruser/open-ndi`), protecting implementation details from being imported externally.

## Structure

```text
internal/
├── control/
│   ├── control.go
│   └── README.md
├── discovery/
│   ├── discovery.go
│   └── README.md
└── streaming/
├── streaming.go
└── README.md
``` 

## Packages

### `control/`

Handles the **TCP-based control plane**:
- Negotiates stream endpoints (e.g., receiver address, ports).
- `ListenAndServe()` for sender-side TCP listener.
- `Connect()` for receiver-side TCP client.

[See control/README.md →](./control/README.md)

---

### `discovery/`

Manages **LAN service discovery** using **mDNS (zeroconf)**:
- Sender advertises itself on the local network.
- Receiver discovers available senders dynamically.
  
[See discovery/README.md →](./discovery/README.md)

---

### `streaming/`

Implements the **UDP-based data plane**:
- Sender sends streaming data as UDP packets.
- Receiver listens for incoming UDP streams.

[See streaming/README.md →](./streaming/README.md)

---

## Design Philosophy

- **Minimal Control Plane** (TCP)
- **Efficient Data Plane** (UDP)
- **Service Discovery** via industry-standard mDNS
- **Loose Coupling** between components (no external dependencies beyond minimal libraries)

This layout ensures open-ndi remains modular, testable, and easy to extend for future features like encryption, multi-receiver broadcasting, or compression.

---

## Notes

- The `internal/` folder is **private** to this module.  
- If external reusability is desired later, refactor into `/pkg/` or standalone libraries.