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

1. Membuat network `sakala-edge` dan `sakala-runtime` bila belum ada. Namanya bisa diganti lewat `SAKALA_EDGE_NETWORK` dan `SAKALA_RUNTIME_NETWORK` di `.env`; lihat [FULL_STACK_LOCAL.md](FULL_STACK_LOCAL.md#berjalan-di-samping-stack-lain).
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

## Integrasi Agent

Untuk pengujian executor Docker lokal, arahkan agent ke folder route host:

```dotenv
SAKALA_RUNTIME_DRIVER=docker
SAKALA_RUNTIME_NETWORK=sakala-runtime
SAKALA_CADDY_SITES_DIR=/absolute/path/to/sakala-infra/caddy/sites
SAKALA_CADDY_CONTAINER=sakala-caddy
```

Agent menulis route secara atomik, menjalankan `caddy validate`, lalu `caddy reload` dari dalam container. Jangan membuka port `2019` dan jangan memasang Docker socket ke Caddy.

Kontrak lengkap, failure behavior, dan troubleshooting ada di [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md). Untuk menjalankan API, Console, dan agent sekaligus sampai aplikasi terdeploy, ikuti [FULL_STACK_LOCAL.md](FULL_STACK_LOCAL.md).

## Integration Test

```bash
make test-runtime
```

Test membuat network, menjalankan Caddy dari `docker-compose.yml`, menjalankan container aplikasi sekali pakai yang hanya bergabung ke network runtime, lalu membuat route dari `templates/caddy-app-route.Caddyfile`. Setelah `caddy validate` dan `caddy reload`, test meminta domain melalui port edge dan mencocokkan token unik dari container itu. Terakhir test menghapus route dan container, lalu memastikan fallback edge kembali aktif.

Test juga memeriksa bahwa generator menolak hostname dan upstream yang salah, Caddy menolak route rusak, Caddy tidak menerima Docker socket, Admin API tidak bisa dijangkau dari host maupun network aplikasi, dan probe readiness agent bekerja pada image Caddy lokal.

Semua resource test memakai prefix `sakala-it-<pid>-<acak>`, volume Compose miliknya sendiri, dan folder route sementara. Test tidak membaca `.env`, tidak membutuhkan `make up`, dan tidak menyentuh stack `make up` yang sedang berjalan, `caddy/sites`, atau container lain. Trap `EXIT` menghapus semuanya saat test lulus, gagal, atau menerima `Ctrl+C` dan `SIGTERM`, lalu test gagal bila masih ada resource yang tersisa. Image dasar `caddy:2-alpine` dan `busybox:1.37` tetap tersimpan di cache Docker.

Port edge berupa port bebas pada `127.0.0.1`, sehingga port yang sudah terpakai tidak menjadi masalah. Port dapat ditentukan bila perlu. Test gagal dengan pesan yang jelas bila port itu sudah terpakai.

```bash
SAKALA_TEST_HTTP_PORT=18080 SAKALA_TEST_HTTPS_PORT=18443 make test-runtime
```

Untuk membuktikan cleanup, hentikan test setelah langkah tertentu. Test akan gagal dengan exit code bukan nol dan tetap membersihkan resource-nya:

```bash
SAKALA_TEST_FAIL_AFTER=route-active make test-runtime
```

Nilai yang diterima: `contract`, `networks`, `caddy`, `boundaries`, `app`, `route-validation`, `route-active`, `probe`, `bad-route`, `route-removed`, dan `app-removed`.
