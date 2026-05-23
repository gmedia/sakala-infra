# AGENTS.md - Sakala Infra

Dokumen ini berlaku untuk AI agents, Codex CLI, automation tools, dan contributor yang bekerja pada `sakala-infra`.

## Project Identity

- Project: **Sakala Infra**
- Product: **Sakala**
- Organization: **PT Media Sarana Data / GMEDIA**
- License: **Apache License 2.0**
- User-facing documentation: **Bahasa Indonesia**
- File, service, variable, dan script identifiers: **English**

Sakala Infra adalah local runtime playground dan infrastructure contract. Ia bukan production infrastructure dan bukan control plane.

## Boundaries

Repository ini boleh berisi:

- Docker Compose untuk runtime lokal;
- konfigurasi Caddy lokal;
- container aplikasi contoh;
- shell script operasional lokal;
- template kontrak agent/runtime;
- dokumentasi infrastruktur.

Repository ini tidak boleh memperkenalkan tanpa keputusan arsitektur baru:

- Kubernetes, Terraform, Ansible, monitoring stack, atau orchestration production;
- Node tooling untuk lint/format repository;
- rahasia, token, credential, atau private key;
- TLS production assumptions;
- Docker socket pada service web-facing;
- business logic yang merupakan tanggung jawab dashboard.

## Runtime Rules

- Gunakan `.localhost` untuk domain lokal.
- Gunakan pola aplikasi lokal `*.run.sakala.localhost`.
- Pertahankan arah production `*.run.sakala.dev` hanya sebagai kontrak dokumentasi sampai deployment production dirancang.
- `sakala-edge` digunakan untuk edge-facing runtime.
- `sakala-runtime` digunakan untuk koneksi proxy ke container aplikasi.
- Caddy tidak boleh membutuhkan akses Docker socket.

## Script Rules

- Semua script Bash harus memakai `#!/usr/bin/env bash` dan `set -euo pipefail`.
- Script harus aman dijalankan ulang.
- Operasi yang menghapus volume atau state harus diberi penjelasan jelas di dokumentasi.
- Prefer `docker compose` plugin, bukan executable lama `docker-compose`.
- Gunakan Makefile sebagai pintu masuk command umum.

## Documentation Rules

Update dokumentasi bila mengubah:

- port, domain, network, atau service Compose;
- route Caddy;
- script lifecycle;
- template agent/runtime;
- asumsi keamanan;
- langkah quickstart.

## Commit Convention

Gunakan Conventional Commits 1.0.0:

```txt
<type>[optional scope]: <description>
```

Tipe yang diperbolehkan:

```txt
feat fix docs style refactor perf test build ci chore revert
```

Scope yang umum:

```txt
infra caddy runtime networking scripts docs examples security
```

Contoh:

```txt
chore(infra): initialize local runtime foundation
feat(caddy): add generated app route include
docs(networking): document agent runtime attachment
fix(scripts): keep network creation idempotent
```

## Verification

Untuk perubahan umum, jalankan pemeriksaan yang relevan:

```bash
make config
bash -n scripts/*.sh
make up
make doctor
make down
```

Jangan menjalankan operasi destruktif terhadap state user tanpa instruksi eksplisit atau tanpa menjelaskan dampaknya.
