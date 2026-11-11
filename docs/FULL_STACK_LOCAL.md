# Full Stack Lokal

Panduan ini membawa kamu dari clone sampai aplikasi terdeploy di URL lokal seperti `http://namaproyek.run.sakala.localhost:8080`. Yang berjalan adalah komponen sungguhan: API, queue worker, scheduler, Reverb, PostgreSQL, Valkey, agent mode `connected` dengan driver `docker`, runtime Caddy, dan Console.

Kamu tidak memerlukan GitHub App, karena panduan ini memakai jalur **Public Git URL**. Repository ini hanya berisi script dan dokumentasi; semua secret dibuat di mesinmu saat script dijalankan dan tidak pernah di-commit.

```txt
Browser -> Console :5173 -> API :8000 -> PostgreSQL :15432, Valkey :16379
Browser <- Reverb :8081 <- queue worker
Agent (proses host) -> API :8000; Agent -> docker build, docker run, route Caddy
Browser -> runtime Caddy :8080 -> container aplikasi di sakala-runtime
```

## Prasyarat

| Kebutuhan | Dipakai oleh |
| --- | --- |
| Docker Engine, Compose plugin, Buildx | Runtime, PostgreSQL, Valkey, build aplikasi |
| Git, Make, curl, OpenSSL | Script dan agent |
| PHP 8.5 dengan ekstensi `pdo_pgsql` dan `redis`, Composer | API |
| Node.js 22.12 atau lebih baru, pnpm | Console |
| Rust (`rust-toolchain.toml` di `sakala-agent` memilih versinya) | Agent |
| Mesin x86_64, karena image sandbox Railpack hanya tersedia untuk arsitektur ini | Preflight agent |

Port host yang dipakai adalah `5173`, `8000`, `8080`, `8081`, `8443`, `15432`, dan `16379`. Kalau `8080` terpakai, lihat [Ubah port edge](#ubah-port-edge). Kalau mesinmu sudah menjalankan stack Sakala lain, lihat juga [Berjalan di samping stack lain](#berjalan-di-samping-stack-lain).

Browser Chromium dan Firefox serta `curl` me-resolve `*.localhost` ke loopback tanpa konfigurasi. Browser lain mungkin butuh entri `/etc/hosts` untuk setiap domain.

## 1. Clone

Semua repository harus bersebelahan:

```bash
mkdir sakala && cd sakala
for repo in sakala-infra sakala-api sakala-console sakala-agent; do
  git clone "https://github.com/gmedia/$repo.git"
done
cd sakala-infra
```

Semua perintah di bawah dijalankan dari `sakala-infra`, kecuali yang pindah folder sendiri.

## 2. Bangun Image Sandbox Railpack

Agent tidak menjalankan Railpack di host, karena menganalisis repository bisa menjalankan kode repository itu. Railpack berjalan di container sekali pakai dari image sandbox. Tanpa `SAKALA_RAILPACK_IMAGE` yang dipin dengan `sha256:`, check `railpack-sandbox` pada preflight gagal dan driver `docker` menolak start, walaupun project-mu memakai Dockerfile. Tag ditolak.

```bash
make railpack-sandbox
```

Perintah ini membangun `sakala-agent/docker/railpack-sandbox`, lalu mencetak `SAKALA_RAILPACK_IMAGE=sha256:...`. Resepnya memin Railpack `v0.23.0`, yang cocok dengan default `SAKALA_RAILPACK_FRONTEND` di agent, dan memverifikasi checksum rilisnya. Tidak perlu sudo, dan CLI Railpack tidak perlu terpasang di host.

Kamu tidak perlu menyalin nilainya. Langkah 7 membangun ulang dari cache dan menulisnya ke `sakala-agent/.env`. Kalau kamu sudah punya image sendiri yang dipin dengan `sha256:` atau `registry/nama@sha256:`, set `SAKALA_RAILPACK_IMAGE` sebelum `make full-stack-agent-env`, dan pembangunan dilewati.

## 3. Buat File Env

```bash
make full-stack-env
```

Script menyalin `.env.example` tiap repository ke `.env`, mengubah nilai yang perlu berbeda untuk setup ini, dan membuat `DB_PASSWORD`, `REVERB_APP_KEY`, serta `REVERB_APP_SECRET`. Aman dijalankan ulang: secret yang sudah ada dipertahankan, dan `.env` lama disalin sekali ke `.env.backup`. Daftar nilainya dijelaskan di [Nilai yang Diubah Script](#nilai-yang-diubah-script).

## 4. Jalankan Runtime

```bash
make up
make doctor
```

Ini menjalankan `sakala-caddy` dan network `sakala-runtime`, atau nama yang kamu pilih di [Berjalan di samping stack lain](#berjalan-di-samping-stack-lain). `curl http://localhost:8080` harus menjawab `Sakala Edge is running`.

## 5. Siapkan API

```bash
cd ../sakala-api
composer install
docker compose up -d --wait pgsql valkey
composer setup
cd ../sakala-infra
```

`docker compose` di sini memakai `compose.yaml` milik API, tetapi hanya menjalankan PostgreSQL dan Valkey. `composer setup` membuat `APP_KEY`, menjalankan migrasi, dan membuat `storage:link`. Jalankan sekali, karena menjalankannya lagi mengganti `APP_KEY` dan membuat session lama tidak berlaku.

## 6. Jalankan Proses API

Buka empat terminal di `sakala-api`. Semuanya harus tetap berjalan.

```bash
PHP_CLI_SERVER_WORKERS=4 php artisan serve --host=127.0.0.1 --port=8000 --no-reload
```

```bash
php artisan queue:work --tries=1 --sleep=1 --timeout=120
```

```bash
php artisan schedule:work
```

```bash
composer reverb
```

Queue worker meneruskan event deployment ke Reverb. Jangan memakai `composer queue` di sini: `queue:listen` mem-boot PHP untuk setiap job, sehingga status dan log di Console tertinggal belasan detik. Scheduler memberikan command ke node setiap menit, jadi tanpa scheduler deployment berhenti di antrean. Empat worker PHP mencegah request Console dan agent saling menunggu.

**Setiap kali mengubah `.env` API, restart keempat proses ini.** Mereka membaca konfigurasi hanya saat start.

Cek dengan `curl -sS -o /dev/null -w '%{http_code}\n' http://api.sakala.localhost:8000/up`, yang harus mencetak `200`.

## 7. Jalankan Agent

Dari `sakala-infra`, daftarkan node sekali:

```bash
make full-stack-agent-env
```

Perintah ini membangun image sandbox bila perlu, memanggil `php artisan agent:provision`, menulis ID dan token node ke `sakala-agent/.env` dengan mode `0600`, dan menambahkan konfigurasi runtime termasuk `SAKALA_RAILPACK_IMAGE`. Token hanya muncul sekali dan API hanya menyimpan hash-nya. Menjalankan ulang tidak membuat node baru selama file itu masih memuat token.

Di terminal baru, jalankan agent. Binary-nya tidak memuat `.env` sendiri, jadi file itu harus di-source:

```bash
cd ../sakala-agent
set -a; . ./.env; set +a
cargo run -p sakala-agent
```

Build pertama butuh beberapa menit. Agent siap saat log menampilkan `runtime preflight check passed` untuk semua check dan tidak berhenti. Node muncul sebagai online di API dalam satu heartbeat.

## 8. Jalankan Console

Di terminal baru:

```bash
cd ../sakala-console
pnpm install
pnpm dev
```

Console terbuka di `http://app.sakala.localhost:5173`. Gunakan alamat itu, bukan `localhost:5173`, karena Console membaca `XSRF-TOKEN` yang terikat pada `.sakala.localhost`. Cookie session sendiri host-only di `api.sakala.localhost`, jadi tidak sampai ke aplikasi di `*.run.sakala.localhost`. File `.env` API dari sebelum perubahan ini perlu dijalankan ulang lewat `scripts/full-stack-env.sh`, lalu login lagi.

## 9. Deploy Aplikasi Pertama

1. Buka `http://app.sakala.localhost:5173/register`, pilih email, lalu buat akun.
2. Email berjalan dengan `MAIL_MAILER=log`, jadi tautan verifikasi ada di log API. Ambil dari `sakala-api`:

   ```bash
   grep -ao 'http[^ "<>]*auth/email/verify[^ "<>]*' storage/logs/laravel.log | tail -1 | sed -e 's/&amp;/\&/g' -e 's/=3D/=/g'
   ```

   Buka tautan itu, lalu login. Kalau kamu juga butuh akses admin, lihat [Akun admin](#akun-admin), yang bisa sekaligus membuat akun terverifikasi tanpa langkah ini.
3. Selesaikan onboarding, lalu buka `http://app.sakala.localhost:5173/projects/new`.
4. Pilih **Public Git URL**, isi `https://github.com/gmedia/sakala-infra`, lalu **Lanjut**.
5. Isi nama proyek, dan isi **Root directory** dengan `examples/node-app`. Folder itu berisi Dockerfile sederhana yang listen di `0.0.0.0:$PORT`. Klik **Buat Proyek**.
6. Klik **Deploy sekarang**. Log build mengalir langsung di halaman deployment, dan status berakhir sukses.
7. Buka URL proyek di halaman proyek, misalnya `http://namaproyek.run.sakala.localhost:8080/`. Hasilnya JSON dari `sakala-example-node-app`.

### Berapa lama build-nya

Build pertama mengunduh image dasar, jadi lamanya bergantung pada koneksimu dan bisa beberapa menit. Contoh di atas menarik `node:22-alpine`. Proyek yang dibangun Railpack juga mengunduh image frontend, builder, dan runtime Railpack.

Kalau kamu memakai builder network host dari [Bila build sangat lambat](#bila-build-sangat-lambat), builder itu punya cache sendiri yang terpisah dari image di `docker images`. Build pertama lewat builder itu mengunduh ulang image dasar, walaupun image yang sama sudah ada di mesinmu, dan bisa terlihat diam beberapa saat di langkah `load metadata` atau `resolve`. Itu unduhan, bukan macet. Log deployment menampilkan langkah yang sedang berjalan.

Setelah image dasar ada di cache, deploy ulang commit yang sama hanya membangun lapisan yang berubah. Pada contoh di atas itu tinggal hitungan detik, sekitar 10 detik di mesin penulis panduan ini, tetapi angkanya berbeda per mesin dan per proyek.

## Akun Admin

Endpoint admin di API, misalnya daftar node di `/api/agent/v1/agents` dan suspend proyek di `/api/v1/admin/projects/{id}/suspend`, hanya menerima akun dengan role `admin`. Console belum punya halaman admin, jadi endpoint itu dipanggil lewat API dengan session akun tersebut. Registrasi selalu membuat akun biasa. Jadikan akunmu admin dari `sakala-api`:

```bash
cd ../sakala-api
php artisan user:admin email-kamu@contoh.test
```

Atau buat akun admin baru yang langsung terverifikasi, sehingga tidak perlu mengambil tautan verifikasi dari log. Kata sandinya ditanyakan tanpa ditampilkan:

```bash
php artisan user:admin admin@sakala.localhost --create --name="Admin Lokal"
```

Tanpa `--create`, email yang belum terdaftar ditolak, dan akun yang sudah ada hanya diubah role-nya tanpa menyentuh kata sandinya. Role baru berlaku mulai request berikutnya, tanpa login ulang. Opsi lengkapnya ada di `docs/DEVELOPMENT.md` pada `sakala-api`.

## Nilai yang Diubah Script

Nilai ini dicatat supaya kamu tahu penyebabnya bila mengubah setup, atau mengisinya sendiri tanpa script.

| File dan key | Nilai | Mengapa |
| --- | --- | --- |
| API `SAKALA_PROJECT_DEFAULT_DOMAIN` | `run.sakala.localhost` | Default kode adalah `run.sakala.dev`, dan domain itu tidak mengarah ke mesinmu. |
| API `SAKALA_PROJECT_URL_SCHEME` | `http` | Default kode adalah `https`, sedangkan runtime lokal tidak memakai TLS. |
| API `SAKALA_PROJECT_URL_PORT` | `8080` | Harus sama dengan `SAKALA_HTTP_PORT`. Kalau kosong, Console menampilkan URL tanpa port yang tidak bisa dibuka. |
| API `BROADCAST_CONNECTION` | `reverb` | Nilai `log` membuat status dan log deployment tidak realtime. |
| API `REVERB_PORT`, `REVERB_SERVER_PORT` | `8081` | Default `8080` bentrok dengan port edge runtime Caddy. |
| API `REVERB_ALLOWED_ORIGINS` | `app.sakala.localhost,localhost` | Reverb menolak koneksi WebSocket dari hostname lain. Isi dengan hostname, bukan URL. |
| API `REVERB_APP_ID`, `REVERB_APP_KEY`, `REVERB_APP_SECRET` | Dibuat script | Kosong di `.env.example`. Secret tidak pernah keluar dari API. |
| Console `PUBLIC_REVERB_KEY` | Disalin dari `REVERB_APP_KEY` | Harus sama persis. Kalau kosong, realtime Console mati tanpa error. |
| Console `PUBLIC_REVERB_HOST`, `PUBLIC_REVERB_PORT`, `PUBLIC_REVERB_SCHEME` | `localhost`, `8081`, `http` | Alamat Reverb yang dilihat browser. |
| API `DB_HOST`, `REDIS_HOST` | `127.0.0.1` | PHP berjalan di host, jadi tidak mengenal hostname `pgsql` dan `valkey`. |
| API `DB_PORT`, `FORWARD_DB_PORT`, `REDIS_PORT`, `FORWARD_VALKEY_PORT` | `15432`, `16379`, hanya pada `127.0.0.1` | Menghindari PostgreSQL dan Redis lain di port default. Valkey lokal tanpa password, jadi tidak boleh terbuka ke LAN. |
| API `MAIL_MAILER` | `log` | Tidak perlu Mailpit. Email verifikasi dan reset password masuk ke `storage/logs/laravel.log`. |
| API `SAKALA_AVATAR_STORAGE` | `local` | Avatar disimpan di `storage/app/public` lewat `storage:link`. Tanpa nilai ini API memakai bucket S3 dan `AWS_*`, sehingga upload avatar gagal. |

Kalau nilai Console berubah, restart `pnpm dev`. Vite membaca `.env` saat start.

Env `sakala-agent/.env` berisi `SAKALA_AGENT_ID`, `SAKALA_AGENT_TOKEN`, `SAKALA_AGENT_MODE=connected`, `SAKALA_API_URL=http://127.0.0.1:8000`, `SAKALA_RUNTIME_DRIVER=docker`, `SAKALA_RAILPACK_IMAGE`, `SAKALA_RUNTIME_NETWORK`, `SAKALA_CADDY_CONTAINER`, `SAKALA_CADDY_SITES_DIR`, dan `SAKALA_RUNTIME_WORKSPACE`. Kontrak antara agent dan runtime dijelaskan di [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md).

## Yang Perlu GitHub App

Jalur Public Git URL hanya membaca repository publik, dan cukup untuk panduan ini. Biarkan semua `GITHUB_APP_*` kosong.

GitHub App baru diperlukan untuk login dengan GitHub, tab repository milik user, repository private, dan auto-deploy lewat webhook. Credential-nya milik pemilik App, jadi tidak tersedia di sini. Cara mengisinya ada di `docs/CONFIGURATION.md` pada `sakala-api`. Login Google juga opsional dan tetap nonaktif selama `GOOGLE_*` kosong.

## Kuota GitHub

Tanpa token, API memakai kuota anonim GitHub: **60 request per jam per alamat IP**, dan kuota itu dibagi dengan semua yang keluar dari IP yang sama, termasuk kantor atau VPN. Saat habis, membaca repository dan branch di Console mulai gagal.

Sebaiknya isi `GITHUB_PUBLIC_API_TOKEN` di `sakala-api/.env`, lalu restart proses API. Buat [fine-grained token](https://github.com/settings/personal-access-tokens/new) dengan akses **Public repositories** saja, tanpa permission tambahan. Cek sisa kuota dengan `curl -sS https://api.github.com/rate_limit`.

## Bila Build Sangat Lambat

Pada sebagian mesin, seperti WSL2 dan VPN, bridge Docker jauh lebih lambat daripada network host, sehingga `docker buildx` terlihat macet saat mengunduh. Pakai builder dengan network host dan arahkan agent ke builder itu:

```bash
docker buildx create --name sakala-local-builder --driver docker-container --driver-opt network=host --bootstrap
export BUILDX_BUILDER=sakala-local-builder
```

Jalankan `export` di terminal agent sebelum `cargo run`, karena process `docker` milik agent mewarisinya. Log build lalu menampilkan `building with "sakala-local-builder"`. Builder ini hanya berlaku untuk build. Langkah build punya akses ke network host, jadi pakai hanya untuk repository yang kamu percaya. Hapus dengan `docker buildx rm sakala-local-builder`. Jangan menurunkan `mtu` Docker sebagai perbaikan tanpa mengukurnya.

## Berjalan di Samping Stack Lain

Secara default runtime memakai nama tetap: container `sakala-caddy` dan `sakala-demo-static`, network `sakala-edge` dan `sakala-runtime`, serta tag image `sakala-railpack-sandbox`. Kalau mesinmu sudah menjalankan stack Sakala lain dengan nama itu, `make up` gagal karena namanya bentrok. Isi nama lain di `sakala-infra/.env`, tanpa override Compose:

| Variabel | Default | Dipakai oleh |
| --- | --- | --- |
| `SAKALA_CADDY_CONTAINER` | `sakala-caddy` | Compose, `make doctor`, dan `sakala-agent/.env` |
| `SAKALA_DEMO_CONTAINER` | `sakala-demo-static` | Compose. Caddy menjangkaunya lewat nama service `demo-static`, jadi route demo tetap jalan |
| `SAKALA_EDGE_NETWORK` | `sakala-edge` | Compose, `make network`, `make doctor` |
| `SAKALA_RUNTIME_NETWORK` | `sakala-runtime` | Compose, `make network`, `make doctor`, dan `sakala-agent/.env` |
| `SAKALA_RAILPACK_SANDBOX_TAG` | `sakala-railpack-sandbox` | `make railpack-sandbox` dan `make full-stack-agent-env` |
| `COMPOSE_PROJECT_NAME` | nama folder, biasanya `sakala-infra` | Compose, untuk nama volume Caddy. Ubah kalau stack lain juga di-clone ke folder bernama `sakala-infra` |

Contoh:

```dotenv
SAKALA_CADDY_CONTAINER=sakala2-caddy
SAKALA_DEMO_CONTAINER=sakala2-demo-static
SAKALA_EDGE_NETWORK=sakala2-edge
SAKALA_RUNTIME_NETWORK=sakala2-runtime
COMPOSE_PROJECT_NAME=sakala2-infra
SAKALA_HTTP_PORT=18080
SAKALA_HTTPS_PORT=18443
```

Script membaca nilai dari environment shell lebih dulu, lalu dari `.env`, lalu default, sama seperti Compose. Agent tidak membaca `.env` ini, jadi jalankan `make full-stack-agent-env` setelah mengubah nama supaya `SAKALA_CADDY_CONTAINER` dan `SAKALA_RUNTIME_NETWORK` di `sakala-agent/.env` ikut berubah, lalu start ulang agent. Port API, Reverb, PostgreSQL, dan Valkey juga perlu berbeda dari stack lain; lihat [Ubah port edge](#ubah-port-edge). `make test-runtime` tidak terpengaruh, karena selalu memakai nama sekali pakai sendiri.

## Ubah Port Edge

Ubah `SAKALA_HTTP_PORT` di `sakala-infra/.env`, lalu jalankan `make full-stack-env`, restart proses API, dan jalankan `make up`. Script menyamakan `SAKALA_PROJECT_URL_PORT` dengan nilai itu. Untuk Reverb, PostgreSQL, atau Valkey, lihat variabel di awal `scripts/full-stack-env.sh`.

## Troubleshooting

| Gejala | Penyebab | Cek | Perbaikan |
| --- | --- | --- | --- |
| Agent berhenti dengan `runtime preflight found one or more fatal dependency failures` | `SAKALA_RAILPACK_IMAGE` kosong, memakai tag, atau image-nya tidak ada di mesin ini, stack belum jalan, atau folder tidak bisa ditulis | Baris `runtime preflight check failed` di log agent | Langkah 2 dan 4, lalu start ulang agent |
| Agent berhenti dengan `401 Unauthorized` pada `/api/agent/v1/node-state` | Token salah, atau database dibuat ulang setelah provisioning | Pesan error di terminal agent | Hapus `sakala-agent/.env`, lalu jalankan `make full-stack-agent-env` |
| Deployment berhenti di antrean | Scheduler atau agent mati | Terminal `schedule:work` dan agent | Jalankan ulang prosesnya |
| Status dan log tidak bergerak sampai halaman dimuat ulang | Reverb atau queue worker mati, atau key tidak sama | `PUBLIC_REVERB_KEY` sama dengan `REVERB_APP_KEY`; error WebSocket di console browser | Jalankan `make full-stack-env`, restart proses API dan `pnpm dev` |
| Login berhasil lalu kembali ke halaman login, atau CORS error | Console dibuka lewat `localhost` atau `127.0.0.1` | Alamat di browser | Buka `http://app.sakala.localhost:5173` |
| URL proyek di Console tidak terbuka karena tanpa port atau memakai `https` | `SAKALA_PROJECT_URL_PORT` atau `SAKALA_PROJECT_URL_SCHEME` salah, atau API belum direstart setelah `.env` diubah | Kedua nilai itu di `sakala-api/.env` | Jalankan `make full-stack-env` dan restart proses API. URL dihitung saat diminta, jadi proyek lama ikut benar |
| URL proyek menjawab `Sakala Edge is running` | Route belum aktif atau deployment gagal | `ls caddy/sites` dan status deployment | Lihat [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md#troubleshooting) |
| Upload avatar gagal dengan `AVATAR_STORAGE_UNAVAILABLE` | `SAKALA_AVATAR_STORAGE` bukan `local` dan S3 tidak tersedia | Nilai itu di `sakala-api/.env` | Isi `local`, jalankan `php artisan storage:link`, restart proses API |
| Browser sesekali menampilkan `ERR_NETWORK_CHANGED` tepat saat deployment selesai | Kemungkinan besar Docker baru mengubah interface network mesin, dan Chromium membatalkan navigasi yang sedang berjalan | Muat ulang halaman | Tidak perlu tindakan |
| Console gagal membaca repository publik | Kuota GitHub anonim habis | `curl -sS https://api.github.com/rate_limit` | Isi `GITHUB_PUBLIC_API_TOKEN` |

Kegagalan aplikasi seperti `runtime_app_not_listening` dijelaskan di [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md#saat-deploy-gagal).

## Menguji Backup Secara Lokal

Backup dan restore production ada di repository `sakala-deployment`, bukan di sini. Script-nya bisa diuji di mesinmu tanpa server:

```bash
cd ../sakala-deployment
make backup-test
```

`make backup-test` menjalankan `scripts/test-backup.sh` terhadap container sementara bernama `sakala-backup-test-*`: PostgreSQL, RustFS, dan penerima SSH sungguhan. Script ini membuat backup, memulihkannya ke database baru, dan memeriksa bahwa kunci yang salah serta dump yang terpotong ditolak. Semua resource-nya dihapus di akhir, dan stack Full Stack Lokal ini tidak disentuh.

Yang dibutuhkan: Docker, [`age`](https://github.com/FiloSottile/age), `curl`, `rsync`, dan `ssh`. Run pertama mengunduh `postgres:17-alpine`, `rustfs/rustfs`, dan `ubuntu:26.04`. Kalau image API yang disebut `SAKALA_TEST_API_IMAGE` ada di mesinmu, script juga menjalankan migrasi sungguhan dan membuktikan `APP_KEY` bisa membaca nilai yang dipulihkan. Tanpa image itu, bagian tersebut dilewati dan ditandai `skip` di output, jadi bacalah output-nya, jangan hanya exit code. Clone `sakala-deployment` di sebelah repository lain kalau belum ada.

## Berhenti dan Membersihkan

Hentikan semua terminal dengan `Ctrl+C`. Container aplikasi yang dibuat agent tetap berjalan sampai dihapus. Perintah berikut menghapus semua workload Sakala di mesin ini, jadi pastikan tidak ada node lain yang sengaja kamu jalankan, lalu jalankan dari `sakala-infra`:

```bash
docker ps -aq --filter label=dev.sakala.managed=true | xargs -r docker rm -f -v
find caddy/sites -maxdepth 1 -name '*-*-*-*-*.Caddyfile' -delete
make down
(cd ../sakala-api && docker compose down --volumes)
```

`docker compose down --volumes` menghapus database lokal, sehingga `sakala-agent/.env` tidak lagi berlaku. Hapus file itu sebelum provisioning berikutnya. Untuk menjaga datanya, hilangkan `--volumes`.
