# Security Boundaries

Sakala Infra saat ini adalah lingkungan pengembangan lokal. Setup ini membantu pengujian kontrak runtime, bukan memberikan hardening production.

## Batas Tanggung Jawab

- Dashboard mengelola metadata, policy, authorization, dan command.
- Agent nantinya menjalankan operasi host/runtime.
- Caddy menerima trafik aplikasi dan meneruskannya ke container runtime.
- Aplikasi user tidak dipercaya secara otomatis.

## Docker Socket

Tidak ada service web-facing yang boleh menerima mount Docker socket. Secara khusus, Caddy dan aplikasi demo tidak membutuhkan `/var/run/docker.sock`.

Agent pada tahap berikutnya mungkin membutuhkan kemampuan runtime tertentu, tetapi akses tersebut harus dibatasi, didokumentasikan, dan tidak diekspos melalui endpoint aplikasi.

## Secrets

- Jangan commit token, password, certificate, private key, atau `.env` aktual.
- `templates/app-container.env.example` hanya berisi contoh key non-rahasia.
- Environment variable aplikasi dan credential agent perlu mekanisme penyimpanan aman sebelum dipakai di luar lokal.

## TLS dan Domain

Automatic HTTPS dimatikan untuk runtime lokal. Repository ini tidak membuat asumsi certificate, wildcard DNS, atau termination TLS production.

## Hal yang Belum Dicakup

- isolasi workload multi-tenant;
- resource/cgroup limits;
- image provenance dan scanning;
- audit log operasi agent;
- token rotation;
- TLS production dan network firewall policy;
- backup dan disaster recovery.

Semua poin tersebut diperlukan sebelum penggunaan production atau workload tidak dipercaya.
