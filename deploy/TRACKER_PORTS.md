# MTcar VPS ports

Application/API:
- 80/tcp
- 443/tcp

SSH:
- your chosen SSH port

Tracker protocol range used by the current Docker Compose:
- 5001-5200/tcp
- 5001-5200/udp

Only keep the range you actually need in the VPS firewall. If an admin-created
device profile uses a port outside this range, Docker/firewall must expose that
port before the tracker can connect.

The number of configured protocol ports is not the main capacity constraint;
online devices, packet rate, database load and report traffic matter more.
