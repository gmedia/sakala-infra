# Sakala Infra

**Sakala Infra** adalah local runtime playground dan kontrak infrastruktur awal untuk **Sakala**, project deployment open-source yang didukung **PT Media Sarana Data / GMEDIA** sebagai founding sponsor dan infrastructure supporter.

Repository ini menyediakan lingkungan minimal untuk menguji routing aplikasi dan integrasi `sakala-agent`. Repository ini belum merupakan infrastruktur production.

GMEDIA menyediakan dukungan awal berupa domain, infrastruktur, ruang eksperimen, dan dukungan teknis. Dukungan ini tidak mengubah prinsip Sakala sebagai project open-source dengan roadmap, dokumentasi, issue, dan kontribusi yang dikembangkan secara terbuka.

## Scope Saat Ini

- Caddy sebagai local edge proxy.
- Network Docker bersama untuk edge dan runtime.
- Aplikasi static demo yang dapat diakses melalui subdomain lokal.
- Contoh aplikasi Node untuk pengujian runtime.
- Integration test routing yang berjalan terisolasi dari container lain.
- Script dan Makefile untuk lifecycle lokal yang dapat diulang.

Tidak termasuk Kubernetes, Terraform, orchestration production, monitoring stack, aplikasi console/API, maupun Docker socket pada service web-facing.

## Requirements

- Docker Engine dengan Docker Compose plugin.
- `make`, shell Bash, dan `curl`.
- Port lokal `8080` dan `8443` tersedia, atau disesuaikan melalui `.env`.

## Quickstart

```bash
cp .env.example .env
make up
make doctor
```

`make doctor` memeriksa stack yang sedang berjalan, jadi jalankan setelah `make up`.

Buka endpoint berikut. Bila port diubah di `.env`, ganti `8080` dengan nilai `SAKALA_HTTP_PORT`.

```txt
http://localhost:8080
http://demo.run.sakala.localhost:8080
```

Respons root menandakan Caddy aktif. Domain demo menampilkan aplikasi static melalui reverse proxy Caddy.

Perintah umum:

```bash
make logs
make config
make test-runtime
make down
make reset
```

`make reset` menghentikan stack dan menghapus volume lokal Caddy. Jalankan hanya saat state lokal memang ingin dihapus, lalu jalankan `make up` untuk memulai lagi.

`make test-runtime` memvalidasi network, generated route, Caddy validate dan reload, respons domain, cleanup, dan fallback. Test memakai container, network, folder route, dan port bebas miliknya sendiri, sehingga aman dijalankan saat `make up` atau container lain sedang berjalan, dan tidak membutuhkan `make up` lebih dulu.

## Strategi Domain

Pola domain aplikasi yang dibangun sejak awal:

```txt
Local       : *.run.sakala.localhost
Production  : *.run.sakala.dev
```

Suffix `.localhost` dipakai agar percobaan lokal tidak membutuhkan konfigurasi DNS publik atau TLS production.

## Struktur Repository

```txt
caddy/       Konfigurasi edge proxy lokal
docs/        Kontrak dan panduan runtime
examples/    Container aplikasi contoh
scripts/     Operasi lifecycle lokal dan integration test
templates/   Template routing dan environment aplikasi
tests/       Override Compose untuk integration test
```

Baca [ARCHITECTURE.md](ARCHITECTURE.md) untuk batas sistem [docs/LOCAL_RUNTIME.md](docs/LOCAL_RUNTIME.md) untuk langkah operasional rinci, dan [docs/AGENT_INTEGRATION.md](docs/AGENT_INTEGRATION.md) untuk menjalankan dan mendiagnosis `sakala-agent` pada runtime ini, dan [docs/FULL_STACK_LOCAL.md](docs/FULL_STACK_LOCAL.md) untuk menjalankan seluruh Sakala dari clone sampai aplikasi terdeploy.

## License

Sakala Infra dilisensikan berdasarkan Apache License 2.0. Lihat [LICENSE](LICENSE) dan [NOTICE](NOTICE).
