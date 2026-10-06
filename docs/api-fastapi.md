# API: Python + FastAPI

> **Durasi estimasi:** 25–35 menit
>
> **Prasyarat:** [Phase 2](./fase-2-fondasi-server.md) sudah selesai

Python + FastAPI adalah pilihan termudah — syntax bersih, auto-generated Swagger docs, dan ideal untuk integrasi dengan library Python (AI/ML, data processing, scraping).

**Keunggulan:**
- Swagger UI otomatis di `/docs` — tidak perlu tulis dokumentasi API manual
- Type hints built-in — validasi input otomatis via Pydantic
- Async-first — performa lebih baik untuk I/O-bound tasks
- Ekosistem Python luas (numpy, pandas, langchain, requests, dll)

---

## Install Python & Dependencies

```bash
# Di Ubuntu PRoot
apt install python3 python3-pip python3-venv -y

# Verifikasi
python3 --version
pip3 --version
```

---

## Buat Aplikasi FastAPI

```bash
mkdir -p ~/apps/my-api-python
cd ~/apps/my-api-python

# Buat virtual environment (isolasi dependencies)
python3 -m venv venv
source venv/bin/activate

# Install FastAPI + Uvicorn (ASGI server)
pip install fastapi "uvicorn[standard]"
```

Buat file `main.py`:

```bash
nano main.py
```

Isi `main.py`:

```python
import re
import platform
import psutil
from datetime import datetime, timezone
from typing import Annotated

from fastapi import FastAPI, Path, HTTPException
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

app = FastAPI(
    title="Android Mini Server API",
    description="API yang berjalan di HP Android via FastAPI",
    version="1.0.0",
    # Nonaktifkan docs di production jika tidak diperlukan:
    # docs_url=None, redoc_url=None
)

# Middleware: batasi host yang diizinkan
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["localhost", "127.0.0.1", "*.kamu.com"]
)


@app.get("/")
def root():
    return {
        "message": "Hello from Android Server! 🤖",
        "server": "Python + FastAPI on Android",
        "time": datetime.now(timezone.utc).isoformat()
    }


@app.get("/api/status")
def status():
    mem = psutil.virtual_memory()
    return {
        "status": "online",
        "python_ver": platform.python_version(),
        "arch": platform.machine(),
        "platform": platform.system(),
        "memory": {
            "total_mb": round(mem.total / 1024 / 1024),
            "free_mb": round(mem.available / 1024 / 1024),
            "used_pct": mem.percent
        },
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@app.get("/api/hello/{name}")
def hello(
    name: Annotated[str, Path(min_length=1, max_length=50, pattern=r"^[a-zA-Z0-9]+$")]
):
    """
    Greeting endpoint dengan validasi otomatis via Pydantic.
    Parameter `name` hanya menerima huruf dan angka, 1-50 karakter.
    """
    return {
        "message": f"Halo, {name}! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋",
        "from": "Android Mini Server"
    }
```

Install psutil untuk monitoring memory:

```bash
pip install psutil
```

Simpan dependencies:

```bash
pip freeze > requirements.txt
```

---

## Test Lokal

```bash
# Masih di dalam venv
uvicorn main:app --host 127.0.0.1 --port 3000

# Test dari terminal lain
curl http://localhost:3000
curl http://localhost:3000/docs   # Swagger UI
```

Tekan `Ctrl+C` untuk stop, lalu lanjut ke pm2.

---

## Jalankan dengan pm2

pm2 perlu menjalankan uvicorn dengan path venv yang eksplisit:

```bash
deactivate  # Keluar dari venv dulu

pm2 start \
  /root/apps/my-api-python/venv/bin/uvicorn \
  --name my-api \
  --interpreter none \
  -- main:app --host 127.0.0.1 --port 3000 \
  --workers 1 \
  --no-access-log
```

> `--workers 1` direkomendasikan untuk HP Android — cukup untuk side project dan menghemat RAM.

Simpan dan verifikasi:

```bash
pm2 save
pm2 list
curl http://localhost:3000
```

---

## Swagger UI (Auto-generated Docs)

Setelah API berjalan dan diekspos via Cloudflare Tunnel, akses dokumentasi otomatis:

```
https://api.kamu.com/docs      ← Swagger UI (interaktif)
https://api.kamu.com/redoc     ← ReDoc (lebih rapi untuk dibaca)
```

> Untuk production, nonaktifkan docs dengan mengganti baris di konstruktor `FastAPI()`:
> ```python
> app = FastAPI(docs_url=None, redoc_url=None)
> ```

---

## Update Setelah Perubahan Kode

FastAPI tidak perlu di-build ulang — cukup restart pm2:

```bash
pm2 restart my-api
```

---

## Endpoint yang Tersedia

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /` | Info server + timestamp |
| `GET /api/status` | Memory, Python version, arch |
| `GET /api/hello/{name}` | Greeting dengan validasi Pydantic |
| `GET /docs` | Swagger UI interaktif |
| `GET /redoc` | ReDoc documentation |

---

## ✅ Checklist

```
[ ] python3 --version tampil tanpa error
[ ] pip install fastapi uvicorn psutil berhasil
[ ] uvicorn test lokal berjalan di port 3000
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] pm2 save berhasil
```

---

[← Kembali ke Phase 7](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
