# API: Node.js + Express

> **Durasi estimasi:** 20–30 menit
>
> **Prasyarat:** Node.js sudah terinstall di [Phase 2](./fase-2-fondasi-server.md)

Node.js + Express adalah pilihan default — tidak perlu install runtime baru karena Node.js sudah ada dari Phase 2.

---

## Buat Aplikasi Express

```bash
cd ~/apps/my-api
npm init -y
npm install express helmet express-rate-limit joi
nano index.js
```

Isi `index.js`:

```javascript
const express   = require('express');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const Joi       = require('joi');
const os        = require('os');

const app  = express();
const PORT = 3000;

// Security headers
app.use(helmet());
app.use(express.json({ limit: '10kb' }));

// Rate limiting — max 100 request per 15 menit per IP
const limiter = rateLimit({
  windowMs        : 15 * 60 * 1000,
  max             : 100,
  message         : { error: 'Too many requests, please try again later.' },
  standardHeaders : true,
  legacyHeaders   : false,
});
app.use(limiter);

// Routes
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
    status    : 'online',
    uptime    : `${hours}h ${minutes}m ${seconds}s`,
    memory    : {
      total_mb : Math.round(os.totalmem() / 1024 / 1024),
      free_mb  : Math.round(os.freemem() / 1024 / 1024),
      used_pct : Math.round((1 - os.freemem() / os.totalmem()) * 100)
    },
    cpu       : os.cpus()[0].model,
    platform  : os.platform(),
    arch      : os.arch(),
    node_ver  : process.version,
    timestamp : new Date().toISOString()
  });
});

// Validasi input dengan Joi
const nameSchema = Joi.string().alphanum().min(1).max(50).required();

app.get('/api/hello/:name', (req, res) => {
  const { error, value } = nameSchema.validate(req.params.name);

  if (error) {
    return res.status(400).json({ error: 'Invalid name parameter' });
  }

  res.json({
    message : `Halo, ${value}! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋`,
    from    : 'Android Mini Server'
  });
});

// Generic error handler — jangan bocorkan stack trace ke client
app.use((err, req, res, next) => {
  console.error(`[${new Date().toISOString()}] Error:`, err.message);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`[${new Date().toISOString()}] Server berjalan di port ${PORT}`);
});
```

> `127.0.0.1` (bukan `0.0.0.0`) — app hanya bisa diakses via Nginx, tidak langsung dari luar.

---

## Jalankan dengan pm2

```bash
pm2 start index.js --name my-api
pm2 save
```

Verifikasi:

```bash
pm2 list
curl http://localhost:3000
```

---

## Endpoint yang Tersedia

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /` | Info server + timestamp |
| `GET /api/status` | Uptime, memory, CPU, platform |
| `GET /api/hello/:name` | Greeting dengan validasi input |

---

## Set Production Mode

```bash
# Via pm2 environment
pm2 start index.js --name my-api --env production

# Atau tambahkan ke ~/.bashrc di Ubuntu PRoot
echo "export NODE_ENV=production" >> ~/.bashrc
```

---

## ✅ Checklist

```
[ ] npm install berhasil tanpa error
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] pm2 save berhasil
```

---

[← Kembali ke Phase 7](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
