<div align="center">

# 🖨️ WebPrinter

**Print and scan documents over your home network — no cloud, no app, just a browser.**

A tiny, self-hosted PHP app that turns any CUPS printer + network scanner (eSCL/AirScan) into a
simple web page and HTTP API. Built to run happily on a Raspberry Pi Zero, and just as happily in
Docker anywhere else.

[![Docker Build](https://github.com/bzhzion/webprinter/actions/workflows/docker_build.yml/badge.svg)](https://github.com/bzhzion/webprinter/actions/workflows/docker_build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GHCR](https://img.shields.io/badge/ghcr.io-bzhzion%2Fwebprinter-blue?logo=docker)](https://github.com/bzhzion/webprinter/pkgs/container/webprinter)

</div>

---

## Contents

- [Why](#why)
- [Features](#features)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Web UI](#web-ui)
- [History](#history)
- [HTTP API — Print](#http-api--print)
- [HTTP API — Scan (async)](#http-api--scan-async)
- [Security](#security)
- [Docker reference](#docker-reference)
- [Architecture](#architecture)
- [License](#license)

---

## Why

Most "print from your phone" solutions mean handing a document to a cloud service, or fighting
with AirPrint discovery across VLANs. WebPrinter is the opposite: one small PHP app, one Docker
container, talking directly to CUPS and to your scanner over eSCL. No account, no cloud, no data
leaving your network unless you want it to.

Configure as many printers and scanners as you have — WebPrinter doesn't care whether they're all
on the same LAN or reachable through a VPN, it just needs CUPS (for printing) and an eSCL endpoint
(for scanning) to talk to each one.

## Features

| | |
|---|---|
| 🖨️ **Print** | Upload a PDF (or JPEG/PNG/TIFF/text/PostScript) from a web form or drag & drop it in |
| 🖶 **Scan** | Pull a document off any eSCL/AirScan network scanner — no USB, no driver install |
| 🏷️ **Multiple devices** | Any number of printers and scanners, each with its own friendly public-facing name distinct from the technical CUPS queue name |
| 🕘 **History** | Every print and scan job (UI or API) logged with status, downloadable scans |
| 🔐 **HTTP API** | Bearer-token auth, print synchronously, scan asynchronously with status polling and an optional signed webhook |
| 🔒 **Security-first defaults** | CSRF, per-IP + per-session brute-force lockout, escaped shell args, whitelisted MIME/resolution/mode, security headers everywhere, weak-secret startup guards |
| 🐳 **One container** | Multi-arch image (`amd64`/`arm64`/`arm/v6`) — runs on a Pi Zero as comfortably as a homelab server |

## Quick start

```bash
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -e PRINTER_NAME=DeskJet_3630 \
  -e CUPS_SERVER=192.168.1.50 \
  -e API_TOKEN="$(openssl rand -hex 24)" \
  -e SCANNERS="DeskJet_3630=http://192.168.1.50/eSCL" \
  -v webprinter-data:/var/www/html/app/data \
  ghcr.io/bzhzion/webprinter:latest
```

Open `http://<host>:8081/index` — that's it. See [Configuration](#configuration) for every option,
and [Docker reference](#docker-reference) for more run examples (multiple printers, password
protection, bare-metal install).

## Configuration

Two equivalent ways to configure WebPrinter — pick one:

- **File**: `cp app/config.php.example app/config.php`, then edit it
- **Environment variables**: override the file per-key (handy for Docker) — see the [Docker reference](#docker-reference) for the full env var table

| Key | What it does |
|---|---|
| `printer_name` | Default CUPS queue name |
| `printers` | Optional. Flat list `['DeskJet_3630']`, or a map `queue_name => 'Display Label'` for a friendlier public name than the technical CUPS queue |
| `cups_server` / `cups_port` | Where CUPS lives — usually `localhost`, or the Docker host's LAN IP |
| `api_token` | Secret for `/api`, `/api-scan`, `/api-status`, `/download` — **change the placeholder**, refused below 16 characters |
| `max_file_size_mb` | Upload size cap |
| `allowed_mime_types` | Whitelist for uploaded files (default: PDF only) |
| `index_password` | Optional password for the web UI — plain text or a bcrypt hash |
| `scanners` | Optional map `scanner_name => 'http://ip/eSCL'` — omit entirely to hide the scan feature |

<details>
<summary><code>app/config.php</code> example</summary>

```php
return [
    'printer_name'       => 'DeskJet_3630',
    'printers'           => [
        'DeskJet_3630' => 'Living room printer',
        'OfficeLaser'  => 'Office printer',
    ],
    'cups_server'        => 'localhost',
    'cups_port'          => 631,
    'api_token'          => 'CHANGE_ME_SECRET_TOKEN',
    'max_file_size_mb'   => 20,
    'allowed_mime_types' => [
        'application/pdf',
        'application/postscript',
        'image/jpeg',
        'image/png',
        'image/tiff',
        'text/plain',
        'image/pwg-raster',
        'image/urf',
    ],
    'index_password'     => '',   // plain text or bcrypt hash
    'scanners'           => [
        'DeskJet_3630' => 'http://192.168.1.50/eSCL',
    ],
];
```
</details>

## Web UI

| Page | What it does |
|---|---|
| `/index` | Upload a PDF (or drag & drop) and print it — printer selector shown when more than one is configured |
| `/scan` | Pick a scanner, resolution (75–1200 dpi), color mode, and format, then scan — hidden if no `scanners` are configured |
| `/history` | Last 50 print + scan jobs, from both UI and API, with status and download links |
| `/health` | `{"status":"ok"}`, no auth — for Docker/reverse-proxy healthchecks |

If `index_password` is set, all of the above (except `/health`) require login. Login is
rate-limited (5 attempts → 5 minute lockout, enforced both per-session and per-IP).

## History

Every job — print or scan, from the UI or the API, including rejections (bad MIME type, unknown
device, too large) — is logged to `app/data/jobs.json`:

| Status | Meaning |
|---|---|
| `Envoyé` / `sent` | Accepted by CUPS |
| `En file` / `queued` | Still in the CUPS queue (checked live via `lpstat` on page load) |
| `En cours` / `scanning` | Scan in progress (async API) |
| `Terminé` / `done` | Left the print queue, or scan completed — downloadable if it's a scan |
| `Échec` / `failed` | Rejected by CUPS or the scanner |
| `Rejeté` / `rejected` | Rejected before reaching the device (bad MIME type, too large, unknown printer/scanner) |

Scanned files live under `app/data/scans/`. Mount a volume over `app/data` to keep history and
scans across container recreations (see [Docker reference](#docker-reference)).

## HTTP API — Print

```
POST /api
Authorization: Bearer <api_token>
Content-Type: multipart/form-data
```

| Field | Required | Notes |
|---|---|---|
| `file` | ✅ | The document to print |
| `printer` | — | Defaults to `printer_name`; `400` if not in the configured list |

```bash
curl -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "printer=DeskJet_3630" \
  -F "file=@document.pdf" \
  http://webprinter.local:8081/api
```

```jsonc
// 200 OK
{ "success": true, "message": "Print job sent", "job_id": "123" }
// error
{ "success": false, "message": "Error description" }
```

## HTTP API — Scan (async)

A scan can take well over a minute at high resolution, so `/api-scan` never blocks the request —
it starts the scan in a detached background process and hands back a job id immediately. Poll
`/api-status`, or set a `webhook_url` and let WebPrinter tell you when it's done.

```
POST /api-scan
Authorization: Bearer <api_token>
```

| Field | Required | Default |
|---|---|---|
| `scanner` | — | first configured scanner |
| `resolution` | — | `300` (75–1200 dpi) |
| `mode` | — | `Color` (`Color` / `Gray`) |
| `format` | — | `pdf` (`pdf` / `jpeg` / `png`) |
| `webhook_url` | — | none — see below |

```jsonc
// 202 Accepted
{
  "success": true,
  "message": "Scan started",
  "job_id": "a1b2c3d4e5f6",
  "status": "scanning",
  "status_url": "/api-status?id=a1b2c3d4e5f6"
}
```

**Check status** — `GET /api-status?id=<job_id>` (same Bearer token):

```jsonc
{
  "success": true,
  "job_id": "a1b2c3d4e5f6",
  "status": "done",           // scanning | done | failed
  "message": "Scan enregistré",
  "download_url": "/download?id=a1b2c3d4e5f6"   // null until done
}
```

**Fetch the result** — `GET /download?id=<job_id>`, with either the same Bearer token or a
logged-in UI session.

**Optional webhook** — pass `webhook_url` (any `http(s)://` URL) and WebPrinter `POST`s the same
payload as `/api-status` to it once the scan finishes, signed with
`X-WebPrinter-Signature: sha256=<hmac>` (HMAC-SHA256 of the raw JSON body, keyed with `api_token`)
so your receiver can verify it really came from this instance. Best-effort, single attempt, no
retry — fine for triggering an automation (n8n, a shortcut, a script), not for guaranteed delivery.

<details>
<summary>Full cURL round-trip</summary>

```bash
RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "scanner=DeskJet_3630" -F "resolution=300" -F "mode=Color" -F "format=pdf" \
  http://webprinter.local:8081/api-scan)
JOB_ID=$(echo "$RESP" | grep -o '"job_id":"[^"]*"' | cut -d'"' -f4)

# poll until status is done/failed
curl -s -H "Authorization: Bearer $API_TOKEN" \
  "http://webprinter.local:8081/api-status?id=$JOB_ID"

# then fetch the file
curl -s -H "Authorization: Bearer $API_TOKEN" \
  "http://webprinter.local:8081/download?id=$JOB_ID" -o scan.pdf
```
</details>

## Security

WebPrinter is small enough to read end-to-end, but here's what it already does for you:

- **Injection-safe by construction** — every `lp`/`scanimage` argument goes through
  `escapeshellarg()`; scanner/printer names, resolutions, color modes and formats are all checked
  against fixed whitelists before they ever reach a shell command
- **CSRF tokens** on every form (login, print, logout)
- **Brute-force lockout** on login — 5 attempts → 5-minute lockout, enforced *both* per-session and
  per-IP (dropping your session cookie doesn't reset the counter)
- **Weak-secret guards** — `/api` and `/api-scan` refuse to serve (`503`) if `api_token` is empty,
  left at the documented placeholder, or under 16 characters
- **Concurrency-safe scanning** — a non-blocking lock around the physical scanner means overlapping
  requests get a clean "scanner busy" instead of racing (and potentially wedging) real hardware
- **Security headers** (CSP, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`) on
  every response, including error pages
- **`display_errors` disabled** in the Docker image — no stack traces or file paths leaked on an
  uncaught error
- **`app/` is unreachable over HTTP** (`.htaccess` + a CLI-only guard on every file), `app/config.php`
  is git-ignored, tokens are compared with `hash_equals()` everywhere
- **`/download`** only ever serves a file that's referenced by a *completed* job in the history
  store — no arbitrary path access

Found something? Open an issue.

## Docker reference

### Environment variables

| Variable | Example |
|---|---|
| `PRINTER_NAME` | `DeskJet_3630` |
| `PRINTERS` | `DeskJet_3630=Living room,OfficeLaser=Office` (or plain `DeskJet_3630,OfficeLaser`) |
| `CUPS_SERVER` | `host.docker.internal` (Docker Desktop) or a LAN IP (Linux) |
| `CUPS_PORT` | `631` |
| `API_TOKEN` | a long random string |
| `MAX_FILE_SIZE_MB` | `20` |
| `ALLOWED_MIME_TYPES` | `application/pdf,image/png` |
| `INDEX_PASSWORD` | plain text or bcrypt hash |
| `SCANNERS` | `DeskJet_3630=http://192.168.1.50/eSCL,OfficeMFP=http://192.168.1.51/eSCL` |

Env vars override `app/config.php` when both are present. Printer/scanner names are restricted to
`[A-Za-z0-9._-]`; MIME types must be `type/subtype`; scanner URLs must be `http(s)://host[:port][/path]`.

### Run examples

```bash
# Minimal
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  ghcr.io/bzhzion/webprinter:latest

# Full config, one printer + one scanner
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -e PRINTER_NAME=DeskJet_3630 -e CUPS_SERVER=host.docker.internal -e CUPS_PORT=631 \
  -e API_TOKEN=CHANGE_ME_SECRET_TOKEN \
  -e SCANNERS=DeskJet_3630=http://192.168.1.50/eSCL \
  ghcr.io/bzhzion/webprinter:latest

# Multiple printers with friendly labels
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -e PRINTERS="DeskJet_3630=Living room,OfficeLaser=Office" \
  -e CUPS_SERVER=host.docker.internal \
  ghcr.io/bzhzion/webprinter:latest

# Password-protect the UI
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -e INDEX_PASSWORD=MySecret \
  ghcr.io/bzhzion/webprinter:latest

# Persist history + scanned files across recreations
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -v webprinter-data:/var/www/html/app/data \
  ghcr.io/bzhzion/webprinter:latest

# Mount a config file instead of env vars
docker run -d --name webprinter -p 8081:80 --restart unless-stopped \
  -v ./config.php:/var/www/html/app/config.php:ro \
  ghcr.io/bzhzion/webprinter:latest
```

Windows PowerShell: swap `-v ./config.php:...` for `-v ${PWD}\config.php:...`.

### Bare-metal / manual install

Requirements: Apache2 + PHP 8, CUPS configured with at least one working printer
(`lp -d <name> file.pdf` should already work), and — for scanning — `sane-utils` + `sane-airscan`
(`scanimage -L` should list your network scanner).

Enable clean URLs:

```bash
sudo a2enmod rewrite && sudo systemctl restart apache2
```

```apache
<Directory /var/www/html>
    AllowOverride All
</Directory>
```

### Image tags

`latest` tracks `main`. Branch, tag, and short-SHA tags are also published — see
[packages](https://github.com/bzhzion/webprinter/pkgs/container/webprinter).

## Architecture

```
index.php / scan.php / history.php   — web UI (session + CSRF)
api.php                              — POST /api (print, Bearer auth)
api-scan.php / api-status.php        — POST /api-scan, GET /api-status (async scan, Bearer auth)
download.php                         — GET /download (session or Bearer auth)
health.php                           — GET /health (no auth)

app/PrinterService.php               — builds & runs `lp` (escaped, whitelisted)
app/ScanService.php                  — regenerates /etc/sane.d/airscan.conf, resolves the live
                                         SANE device by name, runs `scanimage` (locked, whitelisted)
app/scan-worker.php                  — CLI-only background worker invoked by api-scan.php
app/JobStore.php                     — JSON-backed history (app/data/jobs.json) + scanned files
app/ConfigLoader.php                 — config file + env var loading/validation, shared HTTP helpers
app/UploadHandler.php                — MIME/size validation for uploaded files
app/RateLimiter.php                  — per-IP login lockout (flock-based)
```

No database, no message queue, no external dependencies beyond CUPS and SANE — everything is a
flat file under `app/data/`, gitignored and blocked from direct HTTP access.

## License

MIT — see [`LICENSE`](LICENSE). Created by Painteau for Breizhzion. Contributions welcome:
https://github.com/bzhzion/webprinter
