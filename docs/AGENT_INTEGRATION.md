# Integrasi Agent

Dokumen ini menjelaskan cara menyiapkan runtime lokal untuk `sakala-agent`, kontrak yang harus sama di kedua sisi, dan cara mendiagnosis kegagalan tanpa membaca source agent.

Kontrak ini mengikuti `sakala-agent` setelah v0.2.3, yaitu perilaku yang tercatat pada bagian `Unreleased` di changelog-nya. Bila dokumen ini berbeda dengan `docs/DOCKER_RUNTIME.md` atau `docs/AGENT_API.md` di repository agent, yang berlaku adalah repository agent.

Container Caddy pada `sakala-infra` adalah topologi lokal untuk MVP, bukan keputusan arsitektur production final. TLS, wildcard certificate, dan penempatan node dirancang terpisah.

## Pembagian Tanggung Jawab

| Komponen | Tanggung jawab | Tidak boleh |
| --- | --- | --- |
| `sakala-api` | Membuat command, menyimpan policy dan status, memutuskan recovery. | Menjalankan Docker atau mengakses Docker socket. |
| `sakala-agent` | Build, menjalankan container, menulis route, reload Caddy, melapor ke API. Berjalan sebagai proses host dan satu-satunya yang memakai Docker. | Menerima command lewat port inbound. |
| `sakala-infra` | Menyediakan network, container Caddy, folder route, dan script lokal. | Berisi business logic control plane. |
| Caddy | Menerima trafik dan meneruskannya ke container aplikasi. | Menerima Docker socket atau mempublish Admin API. |

Batas keamanan lengkap ada di [SECURITY.md](SECURITY.md), network di [NETWORKING.md](NETWORKING.md), dan konfigurasi Caddy di [CADDY.md](CADDY.md).

## Kontrak yang Harus Sama

Agent tidak membaca file `.env` milik repository ini, dan binary-nya memang tidak memuat dotenv. Nilai agent harus diberikan lewat environment proses atau CLI flag.

| Kontrak | Sisi `sakala-infra` | Sisi agent | Default agent cocok? |
| --- | --- | --- | --- |
| Container Caddy | `container_name: sakala-caddy` | `SAKALA_CADDY_CONTAINER` | Ya, `sakala-caddy` |
| Network aplikasi | `sakala-runtime` | `SAKALA_RUNTIME_NETWORK` | Ya, `sakala-runtime` |
| Folder route | `./caddy/sites`, dimount read-only ke `/etc/caddy/sites` | `SAKALA_CADDY_SITES_DIR` | **Tidak.** Default agent `/var/lib/sakala/caddy/sites`, jadi wajib diisi path absolut ke `caddy/sites` |
| Workspace build | Tidak diatur di sini | `SAKALA_RUNTIME_WORKSPACE` | Default `/var/lib/sakala/builds` butuh izin tulis, jadi isi dengan folder milik user untuk lokal |
| Runtime driver | Tidak diatur di sini | `SAKALA_RUNTIME_DRIVER` | Default `noop` tidak menyentuh Docker, jadi isi `docker` untuk memakai runtime ini |
| Image Caddy | `caddy:2-alpine`, menyertakan BusyBox `wget` | Probe readiness memakai `wget` | Wajib tersedia; `make doctor` memeriksanya |

Nama container Caddy dan network bisa diganti lewat `SAKALA_CADDY_CONTAINER` dan `SAKALA_RUNTIME_NETWORK` di `.env` repository ini, misalnya supaya bisa berjalan di samping stack lain ([FULL_STACK_LOCAL.md](FULL_STACK_LOCAL.md#berjalan-di-samping-stack-lain)). Nilai agent harus ikut diubah ke nama yang sama; `make full-stack-agent-env` melakukannya. Contoh di dokumen ini memakai nama default.

## Menyiapkan dari Awal

Jalankan dari root `sakala-infra`:

```bash
cp .env.example .env
make up
make doctor
make test-runtime
```

`make doctor` lulus bila network, `sakala-caddy`, dan `wget` di dalamnya tersedia. `make test-runtime` membuktikan seluruh kontrak routing memakai resource sekali pakai, tanpa menyentuh stack yang baru dijalankan.

Lalu jalankan agent dari terminal yang sama. Langkah ini butuh Rust, karena `rust-toolchain.toml` di `sakala-agent` memilih versinya, dan clone `sakala-agent` di sebelah folder ini. Kombinasi `local` dan `docker` tidak mengambil command dari API. Gunanya memeriksa kesiapan node lewat preflight, reconciliation, dan health snapshot, bukan menjalankan deployment.

```bash
export SAKALA_AGENT_MODE=local
export SAKALA_RUNTIME_DRIVER=docker
export SAKALA_RUNTIME_NETWORK=sakala-runtime
export SAKALA_CADDY_CONTAINER=sakala-caddy
export SAKALA_CADDY_SITES_DIR="$PWD/caddy/sites"
export SAKALA_RUNTIME_WORKSPACE="$HOME/.local/share/sakala/builds"
export "$(make -s railpack-sandbox)"
mkdir -p "$SAKALA_RUNTIME_WORKSPACE"
(cd ../sakala-agent && cargo run -p sakala-agent)
```

Folder workspace harus sudah ada, karena check `workspace-disk` menjalankan `df` sebelum agent membuat folder itu. `make -s railpack-sandbox` membangun image sandbox Railpack dari `sakala-agent/docker/railpack-sandbox` dan mencetak pin `SAKALA_RAILPACK_IMAGE`, sehingga CLI Railpack tidak perlu terpasang di host. Driver `docker` juga membutuhkan Git dan Docker Buildx. Log JSON harus menampilkan `runtime preflight check passed` untuk `railpack-sandbox`, `caddy-routing`, `runtime-network`, `caddy-http-probe`, dan `caddy-sites`. Hentikan dengan `Ctrl+C`.

Deployment nyata membutuhkan `SAKALA_AGENT_MODE=connected` dan `sakala-api`, yang berada di luar cakupan dokumen ini.

## Nama, Network, dan Domain

Agent menamai container `sakala-app-<8 karakter pertama project id>-<deployment id>`, misalnya `sakala-app-ff66ed4a-4f1f21ef-730d-42d5-a46d-d965353cb993`. Nama itu juga menjadi hostname upstream di Docker DNS, sehingga harus muat dalam satu label DNS 63 karakter.

Container aplikasi hanya bergabung ke `sakala-runtime` dan tidak mempublish port ke host. Caddy bergabung ke `sakala-edge` dan `sakala-runtime`. Agent menambahkan label `dev.sakala.managed=true` beserta label project dan deployment, yang menjadi dasar discovery dan cleanup.

Agent mengisi `PORT` dengan `container_port`, dan aplikasi wajib listen di `0.0.0.0:$PORT`. Aplikasi yang hanya listen di `127.0.0.1` tidak bisa dijangkau Caddy. `PORT` dari payload yang berbeda dengan `container_port` ditolak dengan `runtime_port_conflict`.

Domain lokal memakai pola `*.run.sakala.localhost`. Setiap label hanya boleh berisi huruf kecil, angka, dan tanda hubung, dan tidak boleh diawali atau diakhiri tanda hubung.

## Format Route

Agent menulis satu file per project di `SAKALA_CADDY_SITES_DIR`, bernama `<project-id>.Caddyfile`:

```caddyfile
# Managed by sakala-agent for project <project-id> deployment <deployment-id>.
<domain>:80 {
	reverse_proxy <container>:<port>
}
```

Penulisannya atomik: isi ditulis ke `.<project-id>.Caddyfile.tmp`, lalu di-rename ke nama akhir. File sementara tidak cocok dengan import `*.Caddyfile`, sehingga Caddy tidak pernah membaca route yang setengah tertulis.

Baris pertama adalah penanda kepemilikan. Agent menolak menghapus file route yang tidak memiliki penanda itu.

## Validate dan Reload

Setelah menulis route, agent menjalankan dua perintah ini:

```bash
docker exec sakala-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec sakala-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Admin API hanya listen pada loopback di dalam container dan portnya tidak dipublish, jadi reload tidak membuka akses dari host maupun dari network aplikasi. Bila validate atau reload gagal, agent mengembalikan isi route sebelumnya.

## Health Check

Route baru aktif setelah aplikasi terbukti menjawab. Agent mengulang dua tahap ini sampai `start_timeout_seconds` habis:

1. **State Docker.** `restarting`, `exited`, `dead`, atau restart count yang naik berarti aplikasi crash, dan penantian langsung berhenti.
2. **Probe HTTP** ke `http://<container>:<port>/`, dijalankan dengan `docker exec sakala-caddy wget`. Status di bawah 500 berarti sehat, termasuk 404. Status 5xx terus dicoba sampai deadline.

Probe berjalan dari dalam Caddy karena jalur itu sama dengan jalur route, dan karena proses host tidak bisa menjangkau IP container pada rootless Docker. Perintah berikut sama dengan probe agent, dan dipakai di bagian troubleshooting:

```bash
docker exec --env "http_proxy=http://$APP_CONTAINER:3000" sakala-caddy \
  wget -Y on --server-response --spider -T 5 "http://$APP_CONTAINER:3000/"
```

Mode proxy (`-Y on`) mencegah redirect dari aplikasi membuat Caddy mengambil alamat lain. Konsekuensinya aplikasi menerima request line berbentuk absolut. Aplikasi yang merutekan dari URL mentah bisa membalas 404 atau 400, dan itu tetap dihitung sehat.

## Saat Deploy Gagal

Agent mengirim `error_code` yang menjelaskan penyebabnya, dengan pesan yang aman ditampilkan ke user:

| `error_code` | Kapan | Isi pesan |
| --- | --- | --- |
| `runtime_app_not_listening` | Sampai deadline tidak ada yang menjawab pada port. | Port, lama menunggu, dan kewajiban listen di `0.0.0.0:$PORT`. |
| `runtime_app_unhealthy` | Aplikasi hanya menjawab 5xx sampai deadline. | Port dan status terakhir. |
| `runtime_app_crashed` | Process keluar selama start. Satu restart saja sudah dihitung crash. | Exit code, atau keterangan bahwa Docker tidak lagi melaporkannya. |
| `runtime_app_out_of_memory` | Container dimatikan karena melewati batas memory. | Batas memory yang diterapkan. |
| `runtime_dependency_failed` | Probe tidak bisa berjalan: `wget` tidak ada, Caddy mati, atau nama container tidak ter-resolve. Kesalahannya ada di node, bukan di aplikasi. | Dependency yang bermasalah. |

**Candidate yang gagal tidak tersisa untuk diperiksa.** Agent lebih dulu mengirim hingga 100 baris terakhir output aplikasi ke API, baru menghapus container dan image-nya. Jadi `docker ps -a` tidak akan menemukan container itu, dan log terakhirnya dibaca dari log deployment di control plane. Untuk memeriksa secara langsung, jalankan image yang sama secara manual seperti pada bagian berikutnya.

Selama route belum berpindah, deployment lama tetap melayani trafik. Candidate yang gagal tidak mengubah route.

## Redeploy

Redeploy menjalankan candidate baru berdampingan dengan container lama. Setelah candidate sehat, agent menimpa file route project yang sama secara atomik, lalu validate dan reload. Reload yang berhasil adalah titik commit: sebelum titik itu kegagalan mempertahankan deployment lama, dan setelahnya hasil deploy tetap sukses.

Agent lalu menghentikan dan menghapus container lama. Bila langkah itu gagal atau melewati grace 30 detik, hasil command membawa `finalization_deferred=true`, dan API harus mengirim `StopProject` untuk deployment lama.

## Crash Setelah Deploy

Container berjalan dengan `--restart unless-stopped`, jadi Docker yang me-restart aplikasi. Agent tidak memutuskan recovery. Pada mode `connected`, heartbeat melaporkan workload ke `metadata.workloads.crashed_details` selama statusnya `restarting`, dan sampai ia bertahan hidup 5 menit setelah crash terakhir. Isinya `project_id`, `deployment_id`, `exit_code`, `oom_killed`, dan `finished_at`. Keputusan produk atas laporan itu berada di `sakala-api`.

Container `Exited` tidak dilaporkan sebagai crash, karena stop dan sleep juga berakhir di status itu.

Mode `local` tidak mengirim heartbeat ke API, sehingga `crashed_details` tidak terlihat di sana. Log-nya tetap menampilkan `recovered workload is not ready` saat startup dan `runtime workload health observed` setelahnya.

## Orphan dan Route Basi

Saat startup, agent memindai container berlabel `dev.sakala.managed=true`. Container dengan label yang hilang, atau berstatus `Created`, `Exited`, atau `Dead`, dilaporkan sebagai orphan dan **tidak dihapus otomatis**, karena agent tidak memiliki desired state dari API.

Route tanpa workload aktif dilaporkan sebagai `stale_routes` pada heartbeat. Penghapusannya hanya lewat command `CleanupRuntime` dengan `approved: true`, dan hanya untuk file bernama UUID yang memiliki penanda kepemilikan.

## Mencoba Flow Secara Manual

Langkah ini meniru yang dilakukan agent, tanpa API dan tanpa label `dev.sakala.managed`, sehingga agent tidak menganggapnya workload miliknya. Jalankan dari root repository dengan stack `make up` aktif dan port default. Sesuaikan `8080` bila `SAKALA_HTTP_PORT` diubah.

```bash
PROJECT_ID=ff66ed4a-6303-4be6-8ef4-63c28b112680
DEPLOYMENT_ID=4f1f21ef-730d-42d5-a46d-d965353cb993
APP_CONTAINER="sakala-app-${PROJECT_ID:0:8}-${DEPLOYMENT_ID}"
APP_DOMAIN=manual.run.sakala.localhost

docker build -t sakala-example-node-app examples/node-app
docker run -d --name "$APP_CONTAINER" --network sakala-runtime --env PORT=3000 sakala-example-node-app

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  docker exec --env "http_proxy=http://$APP_CONTAINER:3000" sakala-caddy \
    wget -Y on --server-response --spider -T 5 "http://$APP_CONTAINER:3000/" && break
  sleep 1
done

printf '# Manual route for project %s.\n%s:80 {\n\treverse_proxy %s:3000\n}\n' \
  "$PROJECT_ID" "$APP_DOMAIN" "$APP_CONTAINER" >"caddy/sites/.$PROJECT_ID.Caddyfile.tmp"
mv "caddy/sites/.$PROJECT_ID.Caddyfile.tmp" "caddy/sites/$PROJECT_ID.Caddyfile"
docker exec sakala-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec sakala-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

curl "http://$APP_DOMAIN:8080"
```

Probe diulang seperti yang dilakukan agent, karena aplikasi butuh waktu untuk mulai listen, sehingga `Connection refused` pada percobaan awal masih wajar. Percobaan terakhir harus mencetak `HTTP/1.1 200 OK`, dan `curl` harus mengembalikan JSON dari `sakala-example-node-app`. Bersihkan dengan urutan berikut, lalu domain yang sama kembali ke respons `Sakala Edge is running`:

```bash
rm -f "caddy/sites/$PROJECT_ID.Caddyfile"
docker exec sakala-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
docker rm -f "$APP_CONTAINER"
docker image rm sakala-example-node-app
curl "http://$APP_DOMAIN:8080"
```

## Troubleshooting

Perintah pada bagian ini memakai `$APP_CONTAINER` dan `$APP_DOMAIN` dari bagian sebelumnya.

### Deploy gagal dengan `runtime_app_not_listening`

**Penyebab:** aplikasi hanya listen di `127.0.0.1`, listen pada port selain `$PORT`, atau belum siap sampai deadline.

**Cek:** jalankan image yang sama pada `sakala-runtime`, lalu jalankan probe. Output `wget: can't connect to remote host ... Connection refused` berarti tidak ada yang listen pada alamat dan port itu.

**Perbaikan:** ubah aplikasi agar listen di `0.0.0.0:$PORT`. Bila aplikasi memang lambat, naikkan `start_timeout_seconds`. Batas atasnya adalah `SAKALA_START_TIMEOUT_SECONDS`.

### Deploy gagal dengan `runtime_app_unhealthy`

**Penyebab:** aplikasi menjawab, tetapi hanya dengan status 5xx sampai deadline. Biasanya konfigurasi atau dependency aplikasi belum benar.

**Cek:** probe mencetak baris seperti `HTTP/1.1 500 Internal Server Error`. Baca log deployment di control plane untuk output aplikasi.

**Perbaikan:** perbaiki aplikasi agar path `/` menjawab di bawah 500. Probe selalu meminta `/`, jadi halaman 404 tetap lolos.

### Deploy gagal dengan `runtime_app_crashed`

**Penyebab:** process aplikasi keluar selama start, misalnya karena start command salah atau variabel environment wajib tidak ada.

**Cek:** pada container yang dijalankan manual dengan `--restart unless-stopped`, Docker mengosongkan exit code begitu restart berhasil, jadi baca dari event:

```bash
docker inspect --format '{{.State.Status}} restarts={{.RestartCount}}' "$APP_CONTAINER"
docker events --since 5m --until 0s --filter "container=$APP_CONTAINER" --filter event=die --format '{{.Action}} {{.Actor.Attributes.exitCode}}'
docker logs --tail 50 "$APP_CONTAINER"
```

**Perbaikan:** perbaiki penyebab pada output aplikasi, lalu deploy ulang.

### Deploy gagal dengan `runtime_app_out_of_memory`

**Penyebab:** aplikasi melewati batas memory container, dan kernel mematikannya.

**Cek:** `docker inspect --format '{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' "$APP_CONTAINER"` mencetak `exit=137 oom=true`.

**Perbaikan:** kurangi pemakaian memory aplikasi, atau minta resource lebih besar lewat API. Batas atas node diatur `SAKALA_MAX_CONTAINER_MEMORY_MB`.

### Deploy gagal dengan `runtime_dependency_failed`

**Penyebab:** kesalahannya ada di node. `wget` tidak ada di image Caddy, container Caddy mati, atau Caddy tidak bisa me-resolve nama aplikasi karena tidak berada di network yang sama.

**Cek:**

```bash
make doctor
docker network inspect sakala-runtime --format '{{range .Containers}}{{.Name}} {{end}}'
```

Output network harus memuat `sakala-caddy`. Pada probe manual, `wget: bad address` berarti nama tidak ter-resolve.

**Perbaikan:** jalankan `make up`, pakai image `caddy:*-alpine`, dan samakan `SAKALA_RUNTIME_NETWORK` dengan network Caddy.

### Domain menampilkan `Sakala Edge is running`, bukan aplikasi

**Penyebab:** Caddy tidak memiliki route untuk domain itu. Agent menulis ke folder yang tidak dimount Caddy, atau Caddy belum di-reload.

**Cek:** bandingkan folder agent dengan isi yang dibaca Caddy:

```bash
echo "$SAKALA_CADDY_SITES_DIR"
docker inspect sakala-caddy --format '{{range .Mounts}}{{if eq .Destination "/etc/caddy/sites"}}{{.Source}}{{end}}{{end}}'
docker exec sakala-caddy ls /etc/caddy/sites
```

**Perbaikan:** isi `SAKALA_CADDY_SITES_DIR` dengan path absolut `caddy/sites`, restart agent, lalu jalankan `caddy reload` seperti di atas.

### Domain menjawab HTTP 502

**Penyebab:** route ada, tetapi upstream-nya tidak bisa dijangkau. Container sudah dihapus, berada di network lain, atau port pada route salah.

**Cek:**

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "http://$APP_DOMAIN:8080"
docker ps -a --filter "name=$APP_CONTAINER" --format '{{.Names}} {{.Status}}'
docker logs --tail 20 sakala-caddy
```

**Perbaikan:** jalankan ulang aplikasi pada `sakala-runtime`, atau hapus route basi lalu reload. Pada node yang dikelola agent, biarkan command `RefreshRoute` atau `CleanupRuntime` yang menanganinya.

### Agent berhenti dengan `runtime preflight found one or more fatal dependency failures`

**Penyebab:** satu check fatal gagal. Yang paling sering pada setup lokal adalah `railpack-sandbox`, karena `SAKALA_RAILPACK_IMAGE` kosong atau memakai tag, folder workspace belum ada sehingga `workspace-disk` gagal, `workspace` atau `caddy-sites` tidak bisa ditulis (`/var/lib/sakala/...: Permission denied`), atau `caddy-routing` gagal karena nama container salah.

**Cek:** cari baris `runtime preflight check failed` pada log agent. Field `check` menyebut nama check-nya, dan `detail` menyebut alasannya.

**Perbaikan:** jalankan `make railpack-sandbox` dan set nilai yang dicetaknya, pasang dependency yang kurang, isi `SAKALA_RUNTIME_WORKSPACE` dan `SAKALA_CADDY_SITES_DIR` dengan folder yang bisa ditulis, buat folder workspace dengan `mkdir -p`, dan jalankan `make up`. `caddy-http-probe` hanya warning, sehingga agent tetap start walaupun `wget` belum bisa dijalankan.

### `make up` gagal karena port sudah dipakai

**Penyebab:** proses atau container lain sudah memakai `8080` atau `8443`.

**Cek:** pesan Compose menyebut `port is already allocated` atau `address already in use`. Jalankan `ss -ltn | grep -E ':(8080|8443)\b'`.

**Perbaikan:** ubah `SAKALA_HTTP_PORT` dan `SAKALA_HTTPS_PORT` di `.env`, misalnya `18080` dan `18443`, lalu jalankan `make up` dan akses domain dengan port baru. Topologi agent tidak terpengaruh, karena agent bicara dengan Caddy lewat `docker exec`.

### Resource `sakala-it-*` tertinggal

**Penyebab:** `make test-runtime` dihentikan paksa dengan `SIGKILL`, sehingga trap cleanup tidak sempat berjalan. Exit biasa, `Ctrl+C`, dan `SIGTERM` tetap membersihkan semuanya.

**Cek:**

```bash
docker ps -a --filter name=sakala-it- --format '{{.Names}}'
docker network ls --filter name=sakala-it- --format '{{.Name}}'
docker volume ls --filter name=sakala-it- --format '{{.Name}}'
```

**Perbaikan:** hapus nama yang muncul dengan `docker rm -f`, `docker network rm`, dan `docker volume rm`. Prefix itu hanya dipakai test ini.
