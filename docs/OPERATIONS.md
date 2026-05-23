# Operations

Panduan ini mencatat command rutin dan troubleshooting runtime lokal.

## Command Umum

```bash
make network   # membuat shared Docker networks bila belum ada
make up        # membangun/menjalankan Caddy dan demo app
make doctor    # memeriksa prerequisites dan status runtime aktif
make logs      # mengikuti log service Compose
make config    # merender dan memvalidasi konfigurasi Compose
make down      # menghentikan stack tanpa menghapus volume Caddy
make restart   # menghentikan lalu menjalankan kembali stack
make reset     # menghapus volume Caddy lokal dan menyiapkan network kembali
```

## Pemeriksaan Manual

```bash
docker compose ps
docker network inspect sakala-edge
docker network inspect sakala-runtime
curl http://localhost:8080
curl http://demo.run.sakala.localhost:8080
```

## Troubleshooting

### Port host sudah dipakai

Ubah `.env`:

```dotenv
SAKALA_HTTP_PORT=18080
SAKALA_HTTPS_PORT=18443
```

Lalu jalankan `make up` kembali dan akses domain menggunakan port baru.

### Network belum tersedia

Jalankan:

```bash
make network
make up
```

### Container Caddy tidak running

Periksa status dan log:

```bash
docker compose ps
docker compose logs caddy
```

Jalankan `make config` untuk melihat kesalahan Compose sebelum memulai ulang.
Konfigurasi default telah memakai relabel bind mount `:Z` untuk host dengan SELinux enforcing.

### State Caddy lokal perlu dibersihkan

```bash
make reset
make up
```

Perintah reset menghapus volume Caddy lokal. Ia tidak menghapus shared network yang mungkin masih dipakai container percobaan.
