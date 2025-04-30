# Infra Scripts

This directory contains infrastructure configuration and local bootstrap tooling.

## Commands

- `make hosts` -- Injects local DNS entries into `/etc/hosts`
- `make firewall` -- Applies nftables-based DevOps firewall rules
- `make bootstrap` -- One-shot dev environment setup

## Notes

- You must run all commands with root (use `sudo`)
- Firewall config uses **nftables** (Ubuntu 22.04+ ready)
- Hosts file entries follow the `*.cdaprod.dev` pattern