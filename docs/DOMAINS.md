# Domains

Domain adalah bagian dari kontrak UX deployment Sakala: setiap aplikasi mendapatkan alamat yang dapat dibagikan tanpa user harus mengelola reverse proxy sendiri.

## Arah Domain Produk

```txt
sakala.dev             Website publik
sakala.dev/docs        Dokumentasi produk
app.sakala.dev         Sakala Console
api.sakala.dev         Sakala API/control plane
*.sakala.app           Generated application domains
```

Aplikasi pengguna sengaja berada di `sakala.app`, domain yang terpisah dari `sakala.dev`, supaya pemblokiran terhadap satu aplikasi berbahaya tidak ikut mengenai website, Console, dan API (ADR-016). Staging memakai `*.staging.sakala.app`. DNS publik, wildcard certificate, dan TLS hosted dikelola di `sakala-deployment`, bukan di repository ini.

## Domain Lokal

Lingkungan lokal menggunakan:

```txt
*.run.sakala.localhost
```

Route pertama yang disediakan adalah:

```txt
demo.run.sakala.localhost
```

Saat port default digunakan, aplikasi demo diakses melalui:

```txt
http://demo.run.sakala.localhost:8080
```

`.localhost` dipilih untuk menjaga eksperimen lokal terpisah dari domain publik dan untuk menghindari kebutuhan DNS development khusus.

## Naming Aplikasi

Slug aplikasi di domain nantinya harus:

- stabil untuk project/deployment yang sama sesuai policy API;
- aman digunakan sebagai label host;
- tidak mengandung secret atau identifier internal sensitif;
- dapat dicek terhadap collision sebelum route diaktifkan.
