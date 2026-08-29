# Dynamic Site Routes

Folder ini adalah contract route dinamis yang ditulis oleh `sakala-agent` pada host dan dibaca read-only oleh container Caddy.

File route wajib memakai suffix `.Caddyfile`, hanya berisi hostname yang sudah divalidasi dan upstream container pada network `sakala-runtime`, serta tidak boleh memuat secret. Route demo tetap didefinisikan langsung di `../Caddyfile.local`.

Setelah file diperbarui secara atomik, agent menjalankan validasi dan reload dari dalam container:

```bash
docker exec sakala-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec sakala-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Admin API Caddy hanya listen pada loopback container dan tidak dipublish ke host maupun jaringan web.
