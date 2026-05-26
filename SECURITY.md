# Security Policy

## Attack Surface Considerations

zoptia0netlink interfaces directly with the Linux netlink subsystem. Many netlink operations require `CAP_NET_ADMIN` or root privileges. Users of this library should be aware of the following:

- Netlink operations can modify host network configuration (interfaces, routes, addresses, neighbors). Ensure that only trusted code paths invoke mutation operations.
- Running integration tests requires root privileges and will create, modify, and delete network resources on the host.
- Applications using this library should follow the principle of least privilege and drop elevated permissions as soon as netlink operations are complete.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | Yes                |

## Reporting a Vulnerability

If you discover a security vulnerability in zoptia0netlink, please report it responsibly. **Do not open a public GitHub issue.**

Instead, send an email to:

**security@zoptia.com**

Please include:

- A description of the vulnerability.
- Steps to reproduce the issue.
- The potential impact.
- Any suggested fixes, if applicable.

## Response Timeline

- **Acknowledgment**: Within 48 hours of receiving your report.
- **Assessment**: Within 7 days, we will provide an initial assessment of the vulnerability, its severity, and our planned response.
- **Resolution**: We will work to address confirmed vulnerabilities as quickly as possible, and will coordinate with you on disclosure timing.

We appreciate your help in keeping zoptia0netlink and its users safe.
