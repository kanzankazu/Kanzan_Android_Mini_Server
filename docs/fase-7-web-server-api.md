# Phase 5: Use Case A — Web Server & API

> **Durasi estimasi:** 30–45 menit

Membuat API sederhana menggunakan Express.js, dijalankan via pm2, dan di-proxy oleh Nginx.

---

## Buat Aplikasi Express

```bash
cd ~/apps/my-api
npm init -y
npm install express
nano index.js
```

Isi `index.js`:

```javascript
const express = require('express');
const os      = require('os');

const app  = express();
const PORT = 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message : 'Hello from Android Server! 🤖',
    server  : 'Node.js + Express on Android',
    time    : new Date().toISOString()
  });
});

app.get('/api/status', (req, res) => {
  const uptimeSecs = process.uptime();
  const hours      = Math.floor(uptimeSecs / 3600);
  const minutes    = Math.floor((uptimeSecs % 3600) / 60);
  const seconds    = Math.floor(uptimeSecs % 60);

  res.json({
    status     : 'online',
    uptime     : `${hours}h ${minutes}m ${seconds}s`,
    memory     : {
      total_mb : Math.round(os.totalmem() / 1024 / 1024),
      free_mb  : Math.round(os.freemem() / 1024 / 1024),
      used_pct : Math.round((1 - os.freemem() / os.totalmem()) * 100)
    },
    cpu        : os.cpus()[0].model,
    platform   : os.platform(),
    arch       : os.arch(),
    node_ver   : process.version,
    timestamp  : new Date().toISOString()
  });
});

app.get('/api/hello/:name', (req, res) => {
  const { name } = req.params;
  res.json({
    message : `Halo, ${name}! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋`,
    from    : 'Android Mini Server'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${new Date().toISOString()}] Server berjalan di port ${PORT}`);
});
```

---

## Jalankan dengan pm2

```bash
pm2 start index.js --name my-api
```

Verifikasi:

```bash
pm2 list
curl http://localhost:3000
```

---

## Konfigurasi Nginx

Buat konfigurasi virtual host:

```bash
nano /etc/nginx/sites-available/my-api
```

Isi konfigurasi:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
    }
}
```

Aktifkan konfigurasi:

```bash
ln -s /etc/nginx/sites-available/my-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && service nginx reload
```

---

## Endpoint yang Tersedia

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /` | Info server + timestamp |
| `GET /api/status` | Uptime, memory, CPU, platform |
| `GET /api/hello/:name` | Greeting personal |

---

## ✅ Checklist Phase 5

```
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] curl http://localhost (port 80) mengembalikan JSON
[ ] API bisa diakses dari device lain di WiFi yang sama
```

---

[← Phase 6: Remote GUI](./fase-6-remote-gui.md) | [Kembali ke README](../README.md) | [Phase 8: Cloud Storage →](./fase-8-cloud-storage.md)
