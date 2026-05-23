# Networking

Sakala Infra memakai dua Docker network bernama dan eksplisit. Network dibuat di luar lifecycle Compose agar container yang nantinya dikelola agent dapat bergabung secara independen.

## `sakala-edge`

`sakala-edge` adalah network untuk lapisan penerima trafik. Pada foundation ini, Caddy menjadi satu-satunya anggota yang dibutuhkan.

Tujuan jangka lanjut dapat mencakup service gateway internal, tetapi perubahan tersebut harus diputuskan secara eksplisit dan tidak diperlukan untuk MVP lokal.

## `sakala-runtime`

`sakala-runtime` adalah network komunikasi antara proxy dan aplikasi runtime:

```txt
sakala-caddy -> sakala-demo-static
```

`demo-static` tidak mempublikasikan port ke host. Akses ke aplikasi dilakukan melalui Caddy, sehingga pola ini mewakili arah generated application route.

## Lifecycle Network

```bash
make network
```

Command ini memanggil script idempotent: network yang sudah ada dipertahankan, sedangkan network yang belum ada dibuat.

Compose mendeklarasikan kedua network sebagai `external: true`. Karena itu `make down` dan `make reset` tidak menghapus network shared. Perilaku ini disengaja agar menghentikan edge stack tidak menghapus konektivitas container percobaan lain secara diam-diam.

## Batas Keamanan

- Hanya service yang memerlukan akses runtime yang boleh bergabung ke `sakala-runtime`.
- Container aplikasi tidak perlu bergabung ke `sakala-edge`.
- Network bukan boundary keamanan lengkap; hardening production, resource limits, dan isolasi workload belum dicakup repository ini.
