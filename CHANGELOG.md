# Changelog

Semua perubahan penting pada project ini akan didokumentasikan dalam file ini.

Format dokumen mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan repository ini menggunakan [Semantic Versioning](https://semver.org/spec/v2.0.0.html) ketika release mulai diterbitkan.

## [Unreleased]

### Added

- File-per-project route directory untuk integrasi dinamis dengan `sakala-agent`.
- Placeholder Caddy site agar import glob valid sebelum deployment pertama.
- Integration test generated route, runtime network, Caddy response, dan route cleanup.
- Fondasi local runtime berbasis Docker Compose dan Caddy.
- Network contract `sakala-edge` dan `sakala-runtime`.
- Static demo app dan contoh Node app untuk eksperimen runtime.
- Script lifecycle, template route/environment, dan dokumentasi awal.

### Changed

- Caddy Admin API dibatasi ke loopback container dan tidak dipublish ke host.
- Caddy mengimpor read-only generated routes dari `caddy/sites` untuk validate/reload melalui agent.
- Dokumentasi ekosistem dan boundary diperbarui untuk arsitektur `sakala-console` dan `sakala-api` yang terpisah.
