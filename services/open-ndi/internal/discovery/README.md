# discovery

mDNS discovery helpers using `github.com/grandcat/zeroconf`.

- `Advertise(instance, service, port)` publishes a service.
- `Find(service, timeout)` looks up the first matching service.