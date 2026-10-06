# API: Go + Gin

> **Durasi estimasi:** 30–45 menit
>
> **Prasyarat:** [Phase 2](./fase-2-fondasi-server.md) sudah selesai

Go + Gin adalah pilihan terbaik untuk performa dan efisiensi RAM. Menghasilkan single binary ~10 MB yang berjalan sangat cepat — cocok untuk HP dengan RAM terbatas.

**Keunggulan di HP Android:**
- RAM hanya ~15–20 MB (vs ~80 MB untuk Node.js)
- Startup <0.1 detik
- Single binary, tidak ada `node_modules` yang makan ratusan MB storage
- Compiled — error ketahuan saat build, bukan saat runtime

---

## Install Go

```bash
# Di Ubuntu PRoot
# Cek versi terbaru di https://go.dev/dl/ — pilih yang linux-arm64
wget https://go.dev/dl/go1.22.4.linux-arm64.tar.gz
tar -C /usr/local -xzf go1.22.4.linux-arm64.tar.gz
rm go1.22.4.linux-arm64.tar.gz

# Tambah Go ke PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
source ~/.bashrc

# Verifikasi
go version
# Output: go version go1.22.4 linux/arm64
```

---

## Buat Aplikasi Gin

```bash
mkdir -p ~/apps/my-api-go
cd ~/apps/my-api-go

# Inisialisasi Go module
go mod init my-api

# Install Gin
go get github.com/gin-gonic/gin
```

Buat file `main.go`:

```bash
nano main.go
```

Isi `main.go`:

```go
package main

import (
	"net/http"
	"regexp"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	// Set mode production — nonaktifkan debug output
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()

	// Logger dan recovery middleware
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Security headers middleware
	r.Use(func(c *gin.Context) {
		c.Header("X-Frame-Options", "SAMEORIGIN")
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Next()
	})

	// Routes
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Hello from Android Server! 🤖",
			"server":  "Go + Gin on Android",
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
	})

	r.GET("/api/status", func(c *gin.Context) {
		var mem runtime.MemStats
		runtime.ReadMemStats(&mem)

		c.JSON(http.StatusOK, gin.H{
			"status":   "online",
			"go_ver":   runtime.Version(),
			"arch":     runtime.GOARCH,
			"platform": runtime.GOOS,
			"memory": gin.H{
				"alloc_mb":    mem.Alloc / 1024 / 1024,
				"sys_mb":      mem.Sys / 1024 / 1024,
				"num_gc":      mem.NumGC,
			},
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	})

	r.GET("/api/hello/:name", func(c *gin.Context) {
		name := c.Param("name")

		// Validasi: hanya huruf, angka, 1-50 karakter
		matched, _ := regexp.MatchString(`^[a-zA-Z0-9]{1,50}$`, name)
		if !matched {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid name parameter",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message": "Halo, " + name + "! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋",
			"from":    "Android Mini Server",
		})
	})

	// Bind ke 127.0.0.1 — hanya bisa diakses via Nginx, tidak langsung dari luar
	r.Run("127.0.0.1:3000")
}
```

---

## Build Binary

```bash
cd ~/apps/my-api-go

# Build untuk ARM64 Linux (sesuai arsitektur HP Android)
GOOS=linux GOARCH=arm64 go build -o my-api .

# Verifikasi binary terbuat
ls -lh my-api
# Output: -rwxr-xr-x 1 root root 8.5M my-api
```

---

## Jalankan dengan pm2

```bash
pm2 start /root/apps/my-api-go/my-api --name my-api
pm2 save
```

Verifikasi:

```bash
pm2 list
curl http://localhost:3000
```

---

## Update Setelah Perubahan Kode

Karena Go adalah compiled language, setiap perubahan kode harus di-build ulang:

```bash
cd ~/apps/my-api-go

# Stop dulu
pm2 stop my-api

# Build ulang
go build -o my-api .

# Start kembali
pm2 start my-api
```

---

## Endpoint yang Tersedia

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /` | Info server + timestamp |
| `GET /api/status` | Memory stats, Go version, arch |
| `GET /api/hello/:name` | Greeting dengan validasi regex |

---

## ✅ Checklist

```
[ ] go version menampilkan linux/arm64
[ ] go build berhasil menghasilkan binary
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] pm2 save berhasil
```

---

[← Kembali ke Phase 7](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
