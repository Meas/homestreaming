# Homestreaming

<div align="center">

**A self-hosted media streaming stack — the automation, the storage, and the streaming, all behind a single reverse proxy.**

![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-reverse%20proxy-009639?style=flat-square&logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

</div>

---

## Overview

Homestreaming is a Docker Compose stack that turns a single machine into a complete, private media platform. It downloads, organizes, and streams movies, TV, and music — and it does it all behind **one Nginx reverse proxy** that exposes every service under a stable path (`/jf/`, `/sonarr/`, `/radarr/`, …).

That path-based design is the defining choice of this project. Most self-hosted stacks assume subdomains (`jellyfin.example.com`), which require DNS control and wildcard certificates. Homestreaming instead routes by URL path, so the entire stack works over a flat network address — a LAN IP, a Tailscale/ZeroTier node, or `localhost` — with no DNS setup at all. Point a VPN at the host and every service is reachable from anywhere.

### Highlights

- **One entry point.** Every web UI is reached through Nginx — no management interface is exposed to the host directly. A dashboard at the root URL links to them all.
- **Zero-DNS access.** Path routing works over any flat address — ideal for Tailscale and other mesh VPNs.
- **Hands-off automation.** Sonarr, Radarr, and Lidarr find, fetch, and file media automatically via Prowlarr and qBittorrent.
- **Instant hardlinks.** A deliberate single-mount volume layout lets the *arr apps hardlink from downloads into the library — no wasteful copies, no double disk usage.
- **Request-driven.** Seerr gives users a Netflix-style interface to browse and request titles that the stack then acquires on its own.
- **HTTP or HTTPS by a single switch.** One environment variable selects the Nginx config.
- **DNS-level ad blocking.** AdGuard Home is included for network-wide filtering.

---

## Architecture

Every service runs on a private Docker bridge network (`app-network`) and is reachable **only** through Nginx. The proxy rewrites each `/service/` prefix to the container's internal port.

```
                          ┌───────────────────────────┐
        Client ──────────▶│           Nginx           │  :80 / :443
   (LAN / Tailscale)      │   path-based reverse proxy │
                          └─────────────┬─────────────┘
                                        │  /service/ → container
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼               ▼
   ┌─────────┐    ┌──────────┐   ┌───────────┐   ┌──────────┐    ┌──────────┐
   │ Jellyfin│    │  Seerr   │   │  Sonarr   │   │ Prowlarr │    │ AdGuard  │
   │  /jf/   │    │ /seerr/  │   │  Radarr   │   │/prowlarr/│    │  /ag/    │
   │         │    │          │   │  Lidarr   │   │          │    │  DNS :53 │
   └────┬────┘    └────┬─────┘   └─────┬─────┘   └────┬─────┘    └──────────┘
        │              │               │              │
        │      requests│         search │       indexers│──▶ FlareSolverr
        │              ▼               ▼              │       (Cloudflare)
        │        ┌──────────┐   ┌───────────┐         │
        │        │  Sonarr/ │   │qBittorrent│◀────────┘
        │        │  Radarr  │──▶│   /qbt/   │
        │        └──────────┘   └─────┬─────┘
        │                             │ hardlink
        ▼                             ▼
   ┌───────────────────────────────────────────────┐
   │              $STORAGE_ROOT  (one mount)         │
   │   downloads/  ──hardlink──▶  media/{movies,     │
   │                                 shows, music}   │
   └───────────────────────────────────────────────┘

   Optional  ── soularr-tools profile ──▶  slskd (/slskd/) + soularr → Soulseek P2P
```

**How media flows**

1. A user requests a title in **Seerr**, or an *arr app monitors for one automatically.
2. **Sonarr / Radarr / Lidarr** ask **Prowlarr** to search its configured indexers (with **FlareSolverr** handling any Cloudflare-protected ones).
3. The chosen release is handed to **qBittorrent**, which downloads into `$STORAGE_ROOT/downloads`.
4. The *arr app **hardlinks** the finished file into `$STORAGE_ROOT/media`, renamed and organized — the torrent keeps seeding, but the library uses no extra space.
5. **Jellyfin** picks up the new file and streams it to any device.

The optional **slskd + soularr** pair adds Soulseek (P2P) as a music source, driven by Lidarr's wanted list.

---

## Services

| Service | Path | Image | Role |
|---|---|---|---|
| **Nginx** | — | `nginx:mainline-alpine` | Reverse proxy and single entry point |
| **Jellyfin** | `/jf/` | `jellyfin/jellyfin` | Media server / streaming |
| **Seerr** | `/seerr/` | `seerr/seerr` | Request & discovery frontend |
| **Sonarr** | `/sonarr/` | `ghcr.io/hotio/sonarr` | TV automation |
| **Radarr** | `/radarr/` | `ghcr.io/hotio/radarr` | Movie automation |
| **Lidarr** | `/lidarr/` | `ghcr.io/hotio/lidarr` | Music automation |
| **Prowlarr** | `/prowlarr/` | `ghcr.io/hotio/prowlarr` | Indexer aggregation |
| **qBittorrent** | `/qbt/` | `lscr.io/linuxserver/qbittorrent` | Torrent download client |
| **AdGuard Home** | `/ag/` | `adguard/adguardhome` | Network-wide DNS ad blocking |
| **FlareSolverr** | *(internal)* | `ghcr.io/flaresolverr/flaresolverr` | Cloudflare bypass for Prowlarr |
| **slskd** | `/slskd/` | `slskd/slskd` | Soulseek client *(optional profile)* |
| **soularr** | *(internal)* | `ghcr.io/mrusse/soularr` | Lidarr → Soulseek bridge *(optional profile)* |

slskd and soularr only start under the `soularr-tools` profile (see [Soulseek downloading](#soulseek-downloading-optional)). FlareSolverr and soularr have no web path — they are used by other services internally.

---

## Prerequisites

- **Docker Engine** and the **Docker Compose plugin**.
- Host ports **80** and **443** free (Nginx), and **53** free if you use AdGuard's DNS server.
- A storage location with room for your library, ideally on **one filesystem** (see [Storage layout](#storage-layout)).

---

## Quick start

**1. Clone**

```bash
git clone https://github.com/Meas/homestreaming.git
cd homestreaming
```

**2. Configure**

```bash
cp .env.example .env
```

Edit `.env` and set at minimum `STORAGE_ROOT`, `TZ`, and (for HTTPS) `NGINX_CONFIG_NAME`. See [Configuration](#configuration).

**3. Launch**

```bash
docker compose up -d
```

**4. Open the stack**

Browse to `http://<host>/` for the dashboard, which links to every service (`/jf/` for Jellyfin, `/sonarr/` for Sonarr, and so on) — where `<host>` is `localhost`, your LAN IP, or your Tailscale address. Then follow the [First-run setup](#first-run-setup) to wire the services together.

---

## Configuration

All configuration lives in `.env`. Copy it from `.env.example` and adjust:

| Variable | Description | Default |
|---|---|---|
| `STORAGE_ROOT` | Absolute path to your storage root. All downloads and media live under it. | `/mnt/your-drive` |
| `TZ` | Timezone, e.g. `Europe/Sarajevo`. | `Europe/Sarajevo` |
| `PUID` / `PGID` | User/group IDs that own the config and media files. | `1000` / `1000` |
| `NGINX_CONFIG_NAME` | Nginx config to load: `http-only` or `https`. | `http-only` |
| `NGINX_HOST_PORT` | Host port mapped to Nginx HTTP. | `80` |
| `NGINX_HTTPS_PORT` | Host port mapped to Nginx HTTPS. | `443` |
| `NGINX_SHARE_FILES` | Optional host directory served as downloadable files at `/files/`. Leave blank to disable. | *(empty)* |
| `JELLYFIN_CONFIG_PATH` | Jellyfin config volume. | `./jellyfin/config` |
| `JELLYFIN_CACHE_PATH` | Jellyfin cache volume. | `./jellyfin/cache` |
| `QBITTORRENT_CONFIG_PATH` | qBittorrent config volume. | `./qbittorrent/config` |
| `QBITTORRENT_WEBUI_PORT` | qBittorrent's internal WebUI port (proxied at `/qbt/`). | `8080` |
| `QBITTORRENT_TORRENTING_PORT` | qBittorrent's listening port for peers. | `12854` |

> Per-service config is bind-mounted from `./<service>/config` in the repo and is git-ignored — your keys and databases never get committed.

### HTTP or HTTPS

The stack ships two interchangeable Nginx configs, selected by `NGINX_CONFIG_NAME`:

- **`http-only`** — plain HTTP on port 80. Good for a trusted LAN or when TLS is terminated upstream (e.g. Tailscale already encrypts the tunnel).
- **`https`** — serves TLS on 443 using the certificate pair at `./nginx/certs/default.crt` / `default.key`, while still answering on 80. The port-80 block redirects to HTTPS *only* for a host that has its own cert at `/etc/ssl/certs/available/<host>.crt`; with just the default cert, both HTTP and HTTPS stay reachable.

For HTTPS, drop your certificate and key into `./nginx/certs/` as `default.crt` / `default.key`. A self-signed pair for testing:

```bash
mkdir -p nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/default.key \
  -out nginx/certs/default.crt
```

Then set `NGINX_CONFIG_NAME=https` and restart Nginx:

```bash
docker compose up -d nginx
```

---

## Storage layout

`STORAGE_ROOT` must be an **absolute path on a single filesystem**. Sonarr, Radarr, and Lidarr each mount `STORAGE_ROOT` as one `/data` volume, so `/data/downloads` and `/data/media` sit on the same mount. This is what lets them **hardlink** completed downloads into the library instead of copying — instant, and using no extra disk. Splitting downloads and media across separate mounts silently breaks hardlinking and doubles your storage use.

Expected structure (created on first run):

```
$STORAGE_ROOT/
├── downloads/                    ← qBittorrent downloads
│   └── slskd/
│       ├── downloads/            ← slskd + soularr completed
│       └── incomplete/           ← slskd in progress
└── media/                        ← Jellyfin library root
    ├── videos/
    │   ├── movies/               ← Radarr root folder
    │   └── shows/                ← Sonarr root folder
    └── music/                    ← Lidarr root folder
```

Inside the containers these map to:

| Container path | Used by | Host path |
|---|---|---|
| `/data` | Sonarr, Radarr, Lidarr | `$STORAGE_ROOT` |
| `/downloads` | qBittorrent | `$STORAGE_ROOT/downloads` |
| `/media` | Jellyfin | `$STORAGE_ROOT/media` |

---

## Networking & ports

Only Nginx and AdGuard publish ports to the host. Every other service is reachable **only through the proxy** on the internal Docker network — a small but real security benefit, since nothing else is exposed.

| Host port | Service | Protocol | Purpose |
|---|---|---|---|
| `80` | Nginx | TCP | HTTP (all service paths) |
| `443` | Nginx | TCP | HTTPS (when `NGINX_CONFIG_NAME=https`) |
| `53` | AdGuard Home | TCP + UDP | DNS server |

> **qBittorrent peer port:** `QBITTORRENT_TORRENTING_PORT` (default `12854`) is *not* published to the host in the default compose file, so inbound peer connections rely on your VPN/NAT setup. If you need to accept inbound peers directly, add a `ports:` mapping for it in `docker-compose.yaml`.

If ports 80/443/53 are already taken, change `NGINX_HOST_PORT` / `NGINX_HTTPS_PORT` in `.env`, or remap AdGuard's `53` in `docker-compose.yaml`.

---

## First-run setup

The services start empty and need to be connected to each other once. Do it in this order.

### 1 · Jellyfin — `/jf/`

1. Open `http://<host>/jf/` and complete the setup wizard.
2. Add libraries pointing at the in-container paths:
   - Movies → `/media/videos/movies`
   - Shows → `/media/videos/shows`
   - Music → `/media/music`
3. Create user accounts as needed.

### 2 · qBittorrent — `/qbt/`

1. Open `http://<host>/qbt/`. The linuxserver image prints a temporary admin password in its logs on first boot:
   ```bash
   docker compose logs qbittorrent | grep -i password
   ```
2. Log in, change the password, and set the default save path to `/downloads`.

### 3 · Prowlarr — `/prowlarr/`

1. Open `http://<host>/prowlarr/` and create the admin account.
2. Add the indexers you have access to.
3. Under **Settings → Apps**, add Sonarr, Radarr, and Lidarr so Prowlarr can push indexers to them (use each app's container name as the host, e.g. `http://sonarr:8989`).
4. If an indexer sits behind Cloudflare, add a **FlareSolverr** proxy under **Settings → Indexer Proxies** pointing at `http://flaresolverr:8191`.

### 4 · Sonarr / Radarr / Lidarr

For each of the three (`/sonarr/`, `/radarr/`, `/lidarr/`):

1. Create the admin account.
2. **Download client** (Settings → Download Clients → qBittorrent):
   - Host `qbittorrent`, Port `8080`.
3. **Remote path mapping** (Settings → Download Clients → Remote Path Mappings):

   | Host | Remote path | Local path |
   |---|---|---|
   | `qbittorrent` | `/downloads` | `/data/downloads` |

4. **Root folder** (Settings → Media Management):

   | App | Root folder |
   |---|---|
   | Sonarr | `/data/media/videos/shows` |
   | Radarr | `/data/media/videos/movies` |
   | Lidarr | `/data/media/music` |

5. Confirm indexers arrived from Prowlarr, then run a test search.

### 5 · Seerr — `/seerr/`

1. Open `http://<host>/seerr/` and sign in with your Jellyfin account.
2. Connect the Jellyfin server and select the libraries to sync.
3. Connect Sonarr and Radarr so requests are sent straight to them.

### 6 · AdGuard Home — `/ag/` *(optional)*

1. Open `http://<host>/ag/setup/` and complete the wizard.
2. Point your router's or clients' DNS at the host to enable network-wide filtering.

---

## Soulseek downloading (optional)

slskd and soularr add Soulseek as a music source and only run under the `soularr-tools` profile. slskd uses remote configuration (`SLSKD_REMOTE_CONFIGURATION=true`), so you configure your Soulseek credentials from its web UI at `/slskd/`. soularr reads Lidarr's wanted list on an interval (`SCRIPT_INTERVAL`, default 300s) and searches Soulseek for matches.

```bash
# Start (also provided as ./start-soularr.sh)
docker compose --profile soularr-tools up -d

# Follow soularr's activity
docker compose logs -f soularr

# Stop just these two (also provided as ./stop-soularr.sh)
docker compose rm -fs soularr slskd
```

soularr's `config.ini` lives in `./soularr/config`. See the [soularr docs](https://github.com/mrusse/soularr) for its format.

---

## Everyday operations

```bash
# Start / stop the whole stack
docker compose up -d
docker compose down

# Restart one service
docker compose restart sonarr

# Logs
docker compose logs -f                # everything
docker compose logs -f jellyfin       # one service

# Update to the latest images
docker compose pull
docker compose up -d

# Shell into a container
docker compose exec sonarr bash
```

Back up the git-ignored `./<service>/config` directories to preserve your settings — they hold every app's database and API keys.

---

## Customizing the proxy

Routing rules are split so the two server configs can share them:

- `nginx/conf.d/http-only.conf` — the plain-HTTP server block.
- `nginx/conf.d/https.conf` — the HTTP→HTTPS redirect plus the TLS server block.
- `nginx/includes/proxy_services.conf` — every `location /service/` block, included by both of the above.

To add or change a route, edit `proxy_services.conf` and restart Nginx. A couple of routes need extra care and are already handled there:

- **Jellyfin** uses a WebSocket at `/jf/socket`, given its own location block with `Upgrade`/`Connection` headers and long timeouts.
- **Seerr** is a Next.js app served under a `basePath` of `/seerr`; the config uses `sub_filter` rules to rewrite its hardcoded asset paths.

---

## Troubleshooting

**502 Bad Gateway** — the upstream container isn't up. Check `docker compose ps` and the service's logs; Nginx resolves upstreams by container name, so a stopped container yields a 502.

**Media not showing in Jellyfin** — verify the file landed under `/media/...`, that `PUID`/`PGID` own it, then trigger a library scan.

**Downloads copy instead of hardlink (double disk usage)** — downloads and media are on different filesystems. Both must live under the single `STORAGE_ROOT` mount so `/data/downloads` and `/data/media` share one filesystem.

**Prowlarr can't reach an indexer** — check the indexer status page; if it's Cloudflare-protected, confirm the FlareSolverr proxy is configured (`http://flaresolverr:8191`).

**slskd / soularr not running** — they only exist under the `soularr-tools` profile. Start them with `docker compose --profile soularr-tools up -d`.

**"Missing root folder" after moving storage** — the *arr apps store a root-folder path on each item as well as globally. After changing storage, use the bulk editor to update all items, then reselect the root folder on any collections/series/artists that still point at the old path.

---

## Project layout

```
homestreaming/
├── docker-compose.yaml          # the whole stack
├── .env.example                 # configuration template
├── nginx/
│   ├── conf.d/                  # http-only.conf, https.conf
│   ├── includes/                # proxy_services.conf (shared routes)
│   ├── html/                    # landing-page dashboard served at /
│   └── certs/                   # TLS cert + key (git-ignored)
├── start-soularr.sh             # bring up the soularr-tools profile
├── stop-soularr.sh              # tear down slskd + soularr
└── <service>/config/            # per-service state (git-ignored)
```

---

## Legal

Homestreaming is infrastructure. It ships with **no indexers, no content, and no credentials** — you supply those. The automation tools it bundles can access copyrighted material through indexers and P2P networks; using them to obtain content you don't have the right to is on you.

- Respect the copyright laws where you live.
- Only download and store content you own or are licensed to.
- Configure Prowlarr with indexers and accounts you're entitled to use.
- Follow Soulseek's terms when sharing via slskd/soularr.

The author accepts no responsibility for how this software is used.

---

## License

Released under the [MIT License](LICENSE.md). © 2026 Feđa Durmić.

Built on the excellent work of [Jellyfin](https://jellyfin.org), the [Servarr](https://wiki.servarr.com/) project (Sonarr / Radarr / Lidarr / Prowlarr), [qBittorrent](https://www.qbittorrent.org/), [slskd](https://github.com/slskd/slskd), [soularr](https://github.com/mrusse/soularr), [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr), and [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome).
