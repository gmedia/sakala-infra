# Domains

Domain adalah bagian dari kontrak UX deployment Sakala: setiap aplikasi mendapatkan alamat yang dapat dibagikan tanpa user harus mengelola reverse proxy sendiri.

## Arah Domain Produk

```txt
sakala.dev             Domain utama produk
app.sakala.dev         Dashboard/control plane
docs.sakala.dev        Dokumentasi produk
*.run.sakala.dev       Generated application domains
```

Domain production di atas merupakan arah desain. Repository ini belum mengelola DNS publik, wildcard certificate, atau TLS production.

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

- stabil untuk project/deployment yang sama sesuai policy dashboard;
- aman digunakan sebagai label host;
- tidak mengandung secret atau identifier internal sensitif;
- dapat dicek terhadap collision sebelum route diaktifkan.
