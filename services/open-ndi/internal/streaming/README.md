# streaming

UDP-based data plane.

- `StartSender(ctx, cfg control.Config)` → sends UDP packets to cfg.ReceiverAddr until cancelled.
- `StartReceiver(ctx, cfg control.Config)` → listens on cfg.ReceiverAddr and logs packet sizes.