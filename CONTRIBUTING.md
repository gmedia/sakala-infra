# Contributing to Sakala Infra

Sakala Infra menyediakan lingkungan runtime lokal minimal untuk mengembangkan routing aplikasi dan integrasi agent Sakala. Kontribusi harus mempertahankan setup yang sederhana, dapat diulang, dan mudah dipahami contributor baru.

## Prinsip Kontribusi

1. Pertahankan scope lokal dan MVP-friendly.
2. Jaga batas: dashboard adalah control plane, agent menjalankan runtime, infra menyediakan kontrak lingkungan.
3. Hindari tooling atau orkestrasi production sebelum ada kebutuhan tervalidasi.
4. Jangan commit secret atau mengekspose Docker socket ke service web-facing.
5. Dokumentasikan perubahan terhadap network, domain, route, port, dan command.

## Setup Lokal

```bash
cp .env.example .env
make up
make doctor
```

Gunakan `make down` untuk menghentikan runtime. `make reset` menghapus volume Caddy lokal dan harus digunakan secara sengaja.

## Konvensi Script dan Config

- Shell script harus menggunakan `set -euo pipefail`.
- Shell script harus idempotent sejauh operasi yang didefinisikan.
- Config lokal tidak boleh mengasumsikan certificate production.
- Aplikasi contoh harus tetap kecil dan fokus pada pengujian routing/runtime.
- Perubahan Compose harus tetap dapat divalidasi dengan `make config`.

## Conventional Commits

Semua commit menggunakan **Conventional Commits 1.0.0**:

```txt
<type>[optional scope]: <description>
```

Contoh:

```txt
chore(infra): initialize local runtime foundation
feat(examples): add node runtime health response
fix(caddy): proxy local generated domain correctly
docs(security): clarify docker socket boundary
```

Tipe yang digunakan:

```txt
feat fix docs style refactor perf test build ci chore revert
```

## Pull Request Checklist

- [ ] Scope PR kecil dan jelas.
- [ ] Commit mengikuti Conventional Commits.
- [ ] Tidak ada secret, credential, token, atau private key.
- [ ] Tidak ada Docker socket pada service web-facing.
- [ ] `make config` berhasil.
- [ ] `bash -n scripts/*.sh` berhasil jika script berubah.
- [ ] Runtime diuji melalui `make up` dan `make doctor` jika perilaku container berubah.
- [ ] Dokumentasi diperbarui jika kontrak runtime berubah.

## Melaporkan Masalah

Gunakan issue template yang sesuai dan sertakan versi Docker, output command yang relevan, serta langkah reproduksi tanpa menyertakan informasi sensitif.
