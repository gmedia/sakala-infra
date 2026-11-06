# Sakala Infra Architecture

Dokumen ini menjelaskan fondasi lokal awal `sakala-infra`. Repository ini merupakan playground runtime untuk mengembangkan kontrak antara API, agent, Caddy, dan container aplikasi. Ia bukan rancangan deployment production final.

Sakala adalah project deployment open-source yang didukung GMEDIA sebagai founding sponsor dan infrastructure supporter. Dukungan ini membantu fase MVP tanpa mengubah prinsip Sakala sebagai project dengan roadmap, dokumentasi, issue, dan kontribusi terbuka.

## Posisi dalam Ekosistem

```txt
sakala-landing    Astro website publik dan dokumentasi
sakala-console    SvelteKit presentation layer di app.sakala.dev
sakala-api        Laravel control plane di api.sakala.dev
sakala-agent      Rust runtime agent: build, run, route, log, heartbeat
sakala-infra      Local edge/runtime playground dan kontrak integrasi
```

Console dan API tidak boleh menjalankan Docker atau mengakses Docker socket. Agent yang berjalan pada node runtime melakukan operasi tersebut dan melapor kembali ke API.

## Runtime Lokal Saat Ini

```txt
Browser
  |
  | demo.run.sakala.localhost:8080
  v
sakala-caddy
  |
  | sakala-runtime
  v
sakala-demo-static:8080
```

Compose menjalankan:

- `sakala-caddy`, edge proxy lokal berbasis `caddy:2-alpine`.
- `sakala-demo-static`, container HTTP kecil untuk membuktikan routing aplikasi.

## Network Contract

### `sakala-edge`

Network edge disiapkan untuk service yang menerima trafik masuk atau nantinya perlu berhubungan dengan gateway lokal. Pada tahap awal hanya Caddy yang bergabung.

### `sakala-runtime`

Network runtime menghubungkan Caddy dengan container aplikasi. `demo-static` berjalan hanya pada network ini dan tidak mempublikasikan port langsung ke host.

Kedua network dideklarasikan sebagai network eksternal Compose dan dibuat idempotently melalui `scripts/create-network.sh`. Model ini memungkinkan agent menambahkan container runtime ke `sakala-runtime` tanpa menggabungkan lifecycle setiap aplikasi ke file Compose inti.

## Caddy

Caddy adalah reverse proxy lokal. Konfigurasi awal:

- membatasi Admin API pada loopback di dalam container, tanpa mempublish portnya;
- mematikan automatic HTTPS untuk lingkungan lokal;
- merespons health sederhana pada `:80`;
- mengimport route dinamis dari `/etc/caddy/sites/*.Caddyfile`;
- meneruskan `demo.run.sakala.localhost` ke demo static app.

`sakala-agent` menulis satu file route per project ke `caddy/sites`, lalu menjalankan `caddy validate` dan `caddy reload` melalui `docker exec`. `templates/caddy-app-route.Caddyfile` mendefinisikan format route tersebut. Kontrak lengkapnya ada di [docs/AGENT_INTEGRATION.md](docs/AGENT_INTEGRATION.md).

## Domain Strategy

```txt
demo.run.sakala.localhost    route demo lokal saat ini
*.run.sakala.localhost       pola aplikasi lokal
*.run.sakala.dev             arah pola aplikasi production
```

Tidak ada asumsi TLS production dalam foundation ini. Port HTTPS disediakan agar kontrak port stabil saat eksperimen HTTPS lokal dibutuhkan kemudian.

## Integrasi Agent

Alur saat ini:

```txt
Console mengirim intent pengguna ke API
API membuat command deployment
Agent mengambil command dari API
Agent membangun/menjalankan container aplikasi
Agent menghubungkan container ke sakala-runtime
Agent memeriksa aplikasi dari dalam container Caddy
Agent menambahkan atau memperbarui route Caddy
Agent melaporkan event/log/status ke API
```

Perubahan agent harus menjaga isolasi container, penyimpanan secret, idempotensi command, dan tidak membuka Docker socket melalui Caddy atau aplikasi user.

## Production Direction

Arah production dapat mempertahankan Caddy sebagai edge dan pola `*.run.sakala.dev`, tetapi konfigurasi TLS, persistence, hardening, rolling update, resource control, recovery, dan observability harus dirancang terpisah berdasarkan kebutuhan tervalidasi. Repository ini tidak menjanjikan kesiapan production.
