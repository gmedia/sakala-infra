# Security Policy

Sakala Infra is a local runtime playground and infrastructure contract for Sakala. It is not production infrastructure.

## Reporting

Do not open public issues for exploitable vulnerabilities. Report security concerns privately to the Sakala maintainers through the repository security policy when available, with reproduction steps and impact.

During the MVP phase, GMEDIA may help with security triage as founding sponsor and infrastructure supporter.

## Local Runtime Boundaries

- Do not commit real tokens, credentials, certificates, private keys, or `.env` files.
- Do not expose Docker socket access through Caddy, demo apps, or any web-facing service.
- Do not add production TLS, wildcard DNS, or public routing assumptions without an explicit architecture decision.
- Keep scripts idempotent and clear about destructive local state changes.

Detailed local runtime boundaries are documented in [docs/SECURITY.md](docs/SECURITY.md).
