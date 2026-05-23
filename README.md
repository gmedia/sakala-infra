# Sakala Infra

**Sakala Infra** adalah local runtime playground dan kontrak infrastruktur awal untuk platform deployment **Sakala** dari **PT Media Sarana Data / GMEDIA**.

Repository ini menyediakan lingkungan minimal untuk menguji routing aplikasi dan integrasi `sakala-agent` di tahap berikutnya. Repository ini belum merupakan infrastruktur production.

## Scope Saat Ini

- Caddy sebagai local edge proxy.
- Network Docker bersama untuk edge dan runtime.
- Aplikasi static demo yang dapat diakses melalui subdomain lokal.
- Contoh aplikasi Node untuk pengujian runtime mendatang.
- Script dan Makefile untuk lifecycle lokal yang dapat diulang.

Tidak termasuk Kubernetes, Terraform, orchestration production, monitoring stack, dashboard application, maupun Docker socket pada service web-facing.

## Requirements

- Docker Engine dengan Docker Compose plugin.
- `make` dan shell Bash.
- Port lokal `8080` dan `8443` tersedia, atau disesuaikan melalui `.env`.

## Quickstart

```bash
cp .env.example .env
make up
make doctor
```

Buka endpoint berikut:

```txt
http://localhost:8080
http://demo.run.sakala.localhost:8080
```

Respons root menandakan Caddy aktif. Domain demo menampilkan aplikasi static melalui reverse proxy Caddy.

Perintah umum:

```bash
make logs
make config
make down
make reset
```

`make reset` menghapus volume lokal Caddy. Jalankan hanya saat state lokal memang ingin dihapus.

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
scripts/     Operasi lifecycle lokal
templates/   Template routing dan environment aplikasi
```

Baca [ARCHITECTURE.md](ARCHITECTURE.md) untuk batas sistem dan [docs/LOCAL_RUNTIME.md](docs/LOCAL_RUNTIME.md) untuk langkah operasional rinci.

## License

Sakala Infra dilisensikan berdasarkan Apache License 2.0. Lihat [LICENSE](LICENSE) dan [NOTICE](NOTICE).
