# Security Boundaries

Sakala Infra saat ini adalah lingkungan pengembangan lokal. Setup ini membantu pengujian kontrak runtime, bukan memberikan hardening production.

## Batas Tanggung Jawab

- Console menjadi client browser tanpa hak akses runtime.
- API mengelola metadata, policy, authorization, dan command.
- Agent nantinya menjalankan operasi host/runtime.
- Caddy menerima trafik aplikasi dan meneruskannya ke container runtime.
- Aplikasi user tidak dipercaya secara otomatis.

## Docker Socket

Tidak ada service web-facing yang boleh menerima mount Docker socket. Secara khusus, Caddy dan aplikasi demo tidak membutuhkan `/var/run/docker.sock`.

Agent adalah satu-satunya proses yang boleh menjalankan operasi Docker pada runtime node. Akses tersebut harus dibatasi, didokumentasikan, dan tidak diwariskan ke console, API, Caddy, atau aplikasi user.

## Caddy Reload

Caddy Admin API hanya bind ke loopback di dalam container dan tidak dipublish ke host. Agent menulis file route pada host secara atomik, lalu menjalankan `caddy validate` dan `caddy reload` melalui `docker exec`. Mount `caddy/sites` pada Caddy bersifat read-only dan Caddy tidak menerima Docker socket.

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
