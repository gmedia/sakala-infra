# Local Runtime

Dokumen ini menjelaskan cara menjalankan playground runtime lokal Sakala.

## Prasyarat

- Docker Engine aktif.
- Docker Compose plugin tersedia melalui `docker compose`.
- Bash dan Make tersedia.

## Menjalankan Runtime

```bash
cp .env.example .env
make up
make doctor
```

`make up` melakukan dua langkah:

1. Membuat network `sakala-edge` dan `sakala-runtime` bila belum ada.
2. Menjalankan Caddy dan `demo-static` melalui Docker Compose.

## Memeriksa Routing

```bash
curl http://localhost:8080
curl http://demo.run.sakala.localhost:8080
```

Endpoint pertama mengembalikan teks bahwa edge berjalan. Endpoint kedua mengembalikan halaman static aplikasi contoh melalui Caddy.

Port dapat disesuaikan tanpa mengubah Compose:

```dotenv
SAKALA_HTTP_PORT=8080
SAKALA_HTTPS_PORT=8443
```

## Menghentikan atau Mereset

```bash
make down
make reset
```

`make down` mempertahankan volume lokal Caddy. `make reset` menghapus volume tersebut, lalu memastikan network runtime tetap tersedia. Network tidak dihapus karena dapat sedang digunakan container runtime percobaan lain.

## Menambahkan Percobaan Aplikasi

Container yang ingin diteruskan Caddy harus:

- listening pada port internal yang diketahui;
- bergabung ke `sakala-runtime`;
- memiliki route lokal berbasis `*.run.sakala.localhost`.

Gunakan `templates/caddy-app-route.Caddyfile` sebagai referensi format, bukan sebagai route otomatis yang sudah aktif.
