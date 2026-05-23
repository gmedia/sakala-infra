## Ringkasan

Jelaskan perubahan utama pada pull request ini secara singkat.

## Jenis Perubahan

- [ ] `feat` - kemampuan baru
- [ ] `fix` - perbaikan bug
- [ ] `docs` - dokumentasi
- [ ] `refactor` - perubahan struktur tanpa mengubah behavior
- [ ] `build` - container/build/config
- [ ] `ci` - automation repository
- [ ] `chore` - maintenance

## Area yang Terdampak

- [ ] Docker Compose
- [ ] Caddy / routing
- [ ] Networking
- [ ] Example runtime app
- [ ] Scripts / Makefile
- [ ] Templates
- [ ] Documentation
- [ ] Security boundary

## Cara Menguji

Tuliskan langkah atau command yang dijalankan:

```bash
make config
bash -n scripts/*.sh
```

## Checklist

- [ ] Commit mengikuti Conventional Commits (`type(scope): message`).
- [ ] Scope perubahan kecil dan jelas.
- [ ] Tidak ada secret, token, credential, private key, atau `.env` aktual.
- [ ] Tidak ada Docker socket yang diekspos ke Caddy atau aplikasi.
- [ ] Domain lokal tetap menggunakan `.localhost`.
- [ ] Script baru/diubah menggunakan `set -euo pipefail` dan aman dijalankan ulang.
- [ ] Dokumentasi diperbarui bila port, route, network, domain, atau lifecycle berubah.
- [ ] `make up` / `make doctor` diuji jika perilaku runtime berubah.

## Related Issue

Closes #
