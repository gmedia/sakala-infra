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

Console dan API tidak boleh menjalankan Docker atau mengakses Docker socket. Di masa depan, agent yang berjalan pada node runtime akan melakukan operasi tersebut dan melapor kembali ke API.

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

- mematikan admin API;
- mematikan automatic HTTPS untuk lingkungan lokal;
- merespons health sederhana pada `:80`;
- meneruskan `demo.run.sakala.localhost` ke demo static app.

Konfigurasi route dinamis belum diterapkan. `templates/caddy-app-route.Caddyfile` mendefinisikan arah format route yang nanti dapat dihasilkan agent melalui mekanisme yang aman dan diaudit.

## Domain Strategy

```txt
demo.run.sakala.localhost    route demo lokal saat ini
*.run.sakala.localhost       pola aplikasi lokal
*.run.sakala.dev             arah pola aplikasi production
```

Tidak ada asumsi TLS production dalam foundation ini. Port HTTPS disediakan agar kontrak port stabil saat eksperimen HTTPS lokal dibutuhkan kemudian.

## Integrasi Agent Mendatang

Alur yang dituju:

```txt
Console mengirim intent pengguna ke API
API membuat command deployment
Agent mengambil command dari API
Agent membangun/menjalankan container aplikasi
Agent menghubungkan container ke sakala-runtime
Agent menambahkan atau memperbarui route Caddy
Agent melaporkan event/log/status ke API
```

Perubahan agent kelak harus menjaga isolasi container, penyimpanan secret, idempotensi command, dan tidak membuka Docker socket melalui Caddy atau aplikasi user.

## Production Direction

Arah production dapat mempertahankan Caddy sebagai edge dan pola `*.run.sakala.dev`, tetapi konfigurasi TLS, persistence, hardening, rolling update, resource control, recovery, dan observability harus dirancang terpisah berdasarkan kebutuhan tervalidasi. Repository ini tidak menjanjikan kesiapan production.
