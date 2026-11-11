# Changelog

Semua perubahan penting pada project ini akan didokumentasikan dalam file ini.

Format dokumen mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan repository ini menggunakan [Semantic Versioning](https://semver.org/spec/v2.0.0.html) ketika release mulai diterbitkan.

## [Unreleased]

### Added

- File-per-project route directory untuk integrasi dinamis dengan `sakala-agent`.
- Placeholder Caddy site agar import glob valid sebelum deployment pertama.
- Integration test `make test-runtime` untuk network, generated route, Caddy validate dan reload, respons domain, cleanup, dan fallback, dengan resource sekali pakai dan trap cleanup.
- Dokumentasi integrasi agent pada `docs/AGENT_INTEGRATION.md`, termasuk failure behavior dan troubleshooting.
- `make doctor` memeriksa `wget` di `sakala-caddy`, yang dibutuhkan probe readiness `sakala-agent`.
- Panduan `docs/FULL_STACK_LOCAL.md` dari clone sampai aplikasi terdeploy, dengan `make railpack-sandbox`, `make full-stack-env`, dan `make full-stack-agent-env`.
- Fondasi local runtime berbasis Docker Compose dan Caddy.
- Network contract `sakala-edge` dan `sakala-runtime`.
- Static demo app dan contoh Node app untuk eksperimen runtime.
- Script lifecycle, template route/environment, dan dokumentasi awal.

### Changed

- Nama container Caddy dan demo, network edge dan runtime, serta tag image sandbox Railpack bisa diganti lewat `.env` dengan default yang sama, supaya stack lokal bisa berjalan di samping stack lain tanpa override Compose.
- `docs/FULL_STACK_LOCAL.md` menjelaskan cara membuat admin dengan `php artisan user:admin`, lama build pertama yang jujur, dan cara menguji backup lewat `make backup-test` di `sakala-deployment`.
- Caddy Admin API dibatasi ke loopback container dan tidak dipublish ke host.
- Caddy mengimpor read-only generated routes dari `caddy/sites` untuk validate/reload melalui agent.
- Dokumentasi ekosistem dan boundary diperbarui untuk arsitektur `sakala-console` dan `sakala-api` yang terpisah.
- `make test-runtime` tidak lagi memakai stack `make up`, port `.env`, atau folder `caddy/sites`, sehingga aman dijalankan bersama container lain.
- `scripts/full-stack-env.sh` membuat cookie session host-only di `api.sakala.localhost` dan memberi parent domain hanya pada `XSRF-TOKEN`, sehingga session tidak terkirim ke aplikasi di `*.run.sakala.localhost`.
- `scripts/create-network.sh` menerima nama network sebagai argumen; tanpa argumen tetap menyiapkan `sakala-edge` dan `sakala-runtime`.

### Fixed

- `ARCHITECTURE.md` tidak lagi menyebut Admin API dimatikan dan route dinamis belum diterapkan.
