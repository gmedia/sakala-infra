# Caddy

Caddy berperan sebagai local edge proxy untuk membuktikan routing aplikasi Sakala tanpa mengasumsikan setup production.

## Konfigurasi Saat Ini

File aktif: `caddy/Caddyfile.local`.

Konfigurasi tersebut:

- menonaktifkan Caddy Admin API;
- menonaktifkan automatic HTTPS;
- menyediakan respons default pada HTTP port 80 di dalam container;
- meneruskan `demo.run.sakala.localhost` ke `sakala-demo-static:8080`.

Host mengekspos HTTP pada `${SAKALA_HTTP_PORT:-8080}` dan HTTPS pada `${SAKALA_HTTPS_PORT:-8443}`. HTTPS diekspos untuk kestabilan kontrak port, tetapi belum dipakai sebagai asumsi runtime.

Bind mount Caddyfile menggunakan opsi read-only dengan relabel SELinux (`:ro,Z`) agar container dapat membaca konfigurasi pada host Linux dengan SELinux enforcing.

## Mengetes Konfigurasi

```bash
make config
make up
curl http://demo.run.sakala.localhost:8080
```

## Arah Routing Dinamis

Ketika `sakala-agent` tersedia, agent diharapkan dapat:

1. Menjalankan container aplikasi pada `sakala-runtime`.
2. Menghasilkan atau memperbarui route berdasarkan domain deployment.
3. Meminta reload konfigurasi dengan mekanisme yang aman.
4. Melaporkan status route ke API.

Desain reload dan sumber konfigurasi dinamis belum diputuskan. Caddy tidak boleh diberi Docker socket hanya untuk melakukan discovery container.

## Template Route

`templates/caddy-app-route.Caddyfile` menunjukkan pola:

```txt
APP_SLUG.run.sakala.localhost -> APP_UPSTREAM
```

Template tersebut bukan endpoint aktif sampai diintegrasikan secara eksplisit ke konfigurasi Caddy.
