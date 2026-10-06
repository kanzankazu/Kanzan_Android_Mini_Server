# API: Kotlin + Ktor

> **Durasi estimasi:** 35–50 menit
>
> **Prasyarat:** [Phase 2](./fase-2-fondasi-server.md) sudah selesai

[Ktor](https://ktor.io/) adalah framework web asynchronous berbasis Kotlin — dibuat oleh JetBrains, sama tim di balik IntelliJ dan Android Studio.

**Keunggulan:**
- Kotlin — bahasa yang familiar bagi Android developer
- Coroutine-native — async/non-blocking secara alami tanpa callback hell
- Compiled JVM — lebih predictable dibanding Node.js untuk concurrent requests
- Type-safe routing dan serialization
- Cocok jika kamu sudah terbiasa dengan Android development

**Pertimbangan di HP Android:**
- JVM butuh ~150–250 MB RAM (lebih besar dari Go, sebanding dengan Node.js)
- Startup lebih lambat dibanding Go (~3–5 detik)
- Build butuh JDK + Gradle — install lebih berat dari Go atau Python

---

## Install JDK

```bash
# Di Ubuntu PRoot
apt update
apt install openjdk-17-jdk-headless -y

# Verifikasi
java -version
# Output: openjdk version "17.x.x" ... aarch64

javac -version
# Output: javac 17.x.x
```

---

## Install Gradle

```bash
# Download Gradle (cek versi terbaru di https://gradle.org/releases/)
wget https://services.gradle.org/distributions/gradle-8.7-bin.zip
unzip gradle-8.7-bin.zip -d /opt/gradle
rm gradle-8.7-bin.zip

# Tambah ke PATH
echo 'export PATH=$PATH:/opt/gradle/gradle-8.7/bin' >> ~/.bashrc
source ~/.bashrc

# Verifikasi
gradle --version
```

---

## Buat Proyek Ktor

```bash
mkdir -p ~/apps/my-api-ktor
cd ~/apps/my-api-ktor
```

Buat struktur direktori:

```bash
mkdir -p src/main/kotlin/com/example
mkdir -p src/main/resources
```

Buat `build.gradle.kts`:

```bash
nano build.gradle.kts
```

```kotlin
plugins {
    kotlin("jvm") version "1.9.24"
    kotlin("plugin.serialization") version "1.9.24"
    id("io.ktor.plugin") version "2.3.11"
    application
}

group = "com.example"
version = "1.0.0"

application {
    mainClass.set("com.example.ApplicationKt")
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("io.ktor:ktor-server-core-jvm")
    implementation("io.ktor:ktor-server-netty-jvm")
    implementation("io.ktor:ktor-server-content-negotiation-jvm")
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm")
    implementation("io.ktor:ktor-server-default-headers-jvm")
    implementation("io.ktor:ktor-server-call-logging-jvm")
    implementation("io.ktor:ktor-server-status-pages-jvm")
    implementation("ch.qos.logback:logback-classic:1.4.14")
}

ktor {
    fatJar {
        archiveFileName.set("my-api.jar")
    }
}
```

Buat `settings.gradle.kts`:

```bash
nano settings.gradle.kts
```

```kotlin
rootProject.name = "my-api-ktor"
```

Buat file aplikasi utama:

```bash
nano src/main/kotlin/com/example/Application.kt
```

```kotlin
package com.example

import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.plugins.defaultheaders.*
import io.ktor.server.plugins.statuspages.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class ApiResponse(
    val message: String,
    val server: String,
    val time: String
)

@Serializable
data class StatusResponse(
    val status: String,
    val runtime: RuntimeInfo,
    val timestamp: String
)

@Serializable
data class RuntimeInfo(
    val totalMemoryMb: Long,
    val freeMemoryMb: Long,
    val usedPct: Int,
    val availableProcessors: Int,
    val kotlinVersion: String
)

@Serializable
data class HelloResponse(
    val message: String,
    val from: String
)

@Serializable
data class ErrorResponse(val error: String)

fun main() {
    embeddedServer(
        Netty,
        port = 3000,
        host = "127.0.0.1"  // hanya via Nginx, tidak langsung dari luar
    ) {
        // Security headers
        install(DefaultHeaders) {
            header("X-Frame-Options", "SAMEORIGIN")
            header("X-Content-Type-Options", "nosniff")
            header("X-XSS-Protection", "1; mode=block")
            header("Referrer-Policy", "strict-origin-when-cross-origin")
        }

        // JSON serialization
        install(ContentNegotiation) {
            json(Json { prettyPrint = false; ignoreUnknownKeys = true })
        }

        // Generic error handler — jangan bocorkan stack trace ke client
        install(StatusPages) {
            exception<Throwable> { call, cause ->
                call.application.environment.log.error("Unhandled error", cause)
                call.respond(
                    HttpStatusCode.InternalServerError,
                    ErrorResponse("Internal server error")
                )
            }
            status(HttpStatusCode.NotFound) { call, _ ->
                call.respond(HttpStatusCode.NotFound, ErrorResponse("Not found"))
            }
        }

        routing {
            get("/") {
                call.respond(
                    ApiResponse(
                        message = "Hello from Android Server! 🤖",
                        server  = "Kotlin + Ktor on Android",
                        time    = java.time.Instant.now().toString()
                    )
                )
            }

            get("/api/status") {
                val rt         = Runtime.getRuntime()
                val totalMb    = rt.totalMemory() / 1024 / 1024
                val freeMb     = rt.freeMemory() / 1024 / 1024
                val usedPct    = ((totalMb - freeMb) * 100 / totalMb).toInt()

                call.respond(
                    StatusResponse(
                        status  = "online",
                        runtime = RuntimeInfo(
                            totalMemoryMb        = totalMb,
                            freeMemoryMb         = freeMb,
                            usedPct              = usedPct,
                            availableProcessors  = rt.availableProcessors(),
                            kotlinVersion        = KotlinVersion.CURRENT.toString()
                        ),
                        timestamp = java.time.Instant.now().toString()
                    )
                )
            }

            get("/api/hello/{name}") {
                val name = call.parameters["name"] ?: return@get call.respond(
                    HttpStatusCode.BadRequest, ErrorResponse("Name parameter required")
                )

                // Validasi: hanya huruf dan angka, 1-50 karakter
                if (!name.matches(Regex("^[a-zA-Z0-9]{1,50}$"))) {
                    return@get call.respond(
                        HttpStatusCode.BadRequest, ErrorResponse("Invalid name parameter")
                    )
                }

                call.respond(
                    HelloResponse(
                        message = "Halo, $name! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋",
                        from    = "Android Mini Server"
                    )
                )
            }
        }
    }.start(wait = true)
}
```

---

## Build Fat JAR

```bash
cd ~/apps/my-api-ktor

# Build — proses pertama kali ~5–10 menit (download dependencies)
gradle buildFatJar

# Verifikasi
ls -lh build/libs/my-api.jar
# Output: -rw-r--r-- 1 root root 12M my-api.jar
```

---

## Jalankan dengan pm2

```bash
pm2 start "java -jar /root/apps/my-api-ktor/build/libs/my-api.jar" --name my-api
pm2 save
```

Verifikasi:

```bash
pm2 list
curl http://localhost:3000
```

---

## Update Setelah Perubahan Kode

```bash
cd ~/apps/my-api-ktor

pm2 stop my-api
gradle buildFatJar
pm2 start my-api
```

---

## Endpoint yang Tersedia

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /` | Info server + timestamp |
| `GET /api/status` | Memory JVM, Kotlin version, CPU |
| `GET /api/hello/{name}` | Greeting dengan validasi regex |

---

## ✅ Checklist

```
[ ] java -version menampilkan aarch64
[ ] gradle --version tampil tanpa error
[ ] gradle buildFatJar berhasil menghasilkan my-api.jar
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] pm2 save berhasil
```

---

[← Kembali ke Phase 7](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
