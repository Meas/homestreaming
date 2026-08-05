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
| **Immich** | *(port `2283`)* | `ghcr.io/immich-app/immich-server` | Photo & video library |
| **Immich Postgres** | *(internal)* | `ghcr.io/immich-app/postgres` | Immich metadata + AI vectors |
| **Immich Redis** | *(internal)* | `valkey/valkey` | Immich job queue |
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

Immich is the one service **not** on a path — it only works at the root of a host, so it gets its own port instead (see [Photos with Immich](#photos-with-immich)).

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
├── immich/                       ← Immich photo library (fully managed)
└── media/                        ← Jellyfin library root
    ├── videos/
    │   ├── movies/               ← Radarr root folder
    │   └── shows/                ← Sonarr root folder
    └── music/                    ← Lidarr root folder
```

`immich/` is managed entirely by Immich — originals, thumbnails and transcodes. **Copying files into it by hand does nothing**; Immich never scans it. Photos get in through the mobile app or the CLI (see [Photos with Immich](#photos-with-immich)). It sits outside `media/` so Jellyfin's library root stays clean.

Inside the containers these map to:

| Container path | Used by | Host path |
|---|---|---|
| `/data` | Sonarr, Radarr, Lidarr | `$STORAGE_ROOT` |
| `/downloads` | qBittorrent | `$STORAGE_ROOT/downloads` |
| `/media` | Jellyfin | `$STORAGE_ROOT/media` |
| `/data` | Immich | `$STORAGE_ROOT/immich` |

> **Immich's database is the exception to `STORAGE_ROOT`.** It lives at `./immich/postgres` in the repo, on local disk, because Postgres is not supported on network shares. If your `STORAGE_ROOT` is a NAS mount, this matters.

---

## Networking & ports

Only Nginx and AdGuard publish ports to the host. Every other service is reachable **only through the proxy** on the internal Docker network — a small but real security benefit, since nothing else is exposed.

| Host port | Service | Protocol | Purpose |
|---|---|---|---|
| `80` | Nginx | TCP | HTTP (all service paths) |
| `443` | Nginx | TCP | HTTPS (when `NGINX_CONFIG_NAME=https`) |
| `2283` | Nginx | TCP | Immich (`IMMICH_HOST_PORT`) |
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

## Photos with Immich

Immich is a photo and video library with AI-powered search and face recognition. It runs alongside the rest of the stack but differs from it in two ways worth knowing up front.

**It is not on a path.** Immich [only works at the root of a host](https://docs.immich.app/administration/reverse-proxy) — `/img/` and friends are not supported, and no amount of rewriting makes the mobile app work under one. So Nginx serves it on its own port instead: `http://<host>:2283`. That port follows `NGINX_CONFIG_NAME`, so it's HTTPS when the rest of the stack is.

**It manages its own storage.** Everything lives under `$STORAGE_ROOT/immich` — originals, thumbnails, transcodes. Copying files into that folder by hand does nothing; Immich does not scan it. Photos get in through the mobile app, the web UI, or the CLI.

**Its database is the one thing not on `STORAGE_ROOT`.** Postgres is unsupported on network shares, so it lives at `./immich/postgres`, on the host's local disk. This is also what makes Immich portable between machines: the photos sit on shared storage and never move, so [relocating Immich](#moving-immich-to-another-machine) means moving only a database dump.

### Setup

```bash
# Create the directory first, or Docker creates it owned by root
mkdir -p "$STORAGE_ROOT"/immich

docker compose up -d immich-server
```

Open `http://<host>:2283` and create the admin account. Then, **before importing anything**, go to **Administration → Settings → Storage Template** and enable it. This makes files land at `library/<user>/2019/2019-08-14/IMG_1234.jpg` instead of opaque hashed paths — so your library stays navigable on disk without Immich's help. Enabling it later means re-shuffling every file via the Storage Template Migration job, so it's much cheaper to do now.

Immich has no `PUID`/`PGID` support — it runs as root and owns everything under `$STORAGE_ROOT/immich`.

### Importing an existing photo collection

**There is no drop folder.** Your existing photos stay exactly where they are — the CLI reads them from that location and uploads them over HTTP, and Immich decides where they land under `$STORAGE_ROOT/immich`. Nothing needs to be moved or staged beforehand.

Use the CLI. `--album` turns each source folder into an album, so your existing directory structure is preserved as organisation rather than lost:

```bash
# Dry run first — shows what would be uploaded, changes nothing
docker run --rm -v /path/to/photos:/import:ro \
  -e IMMICH_INSTANCE_URL=http://<host>:2283/api \
  -e IMMICH_API_KEY=<key from Account Settings → API Keys> \
  ghcr.io/immich-app/immich-cli:latest upload --recursive --album --dry-run /import

# Then for real: drop --dry-run
```

Files are hashed before upload and the server deduplicates independently, so re-running is safe and interrupted imports can simply be resumed.

> **Keep the source folder until you've verified the import.** The CLI has a `--delete` flag that removes local files as it goes — useful if you're short on disk, since a straight import needs room for a second full copy. But it is destructive and irreversible: only reach for it once a dry run looks right, and never on your only copy.

### Adding other users

**Administration → Users → Create user** (email, name, password, optional storage quota). Only the first registered user is an admin — everyone created afterwards is a regular user with no access to the Administration section at all, so no extra configuration is needed to keep server settings private.

Immich is **per-user ownership**: each account has its own library, and one user's uploads are invisible to another by default. Two ways to overlap, neither of which grants delete rights over someone else's assets:

- **Partner sharing** — a full-library view of another user's timeline. One-way, so both parties must share to see each other. View and download only, and it excludes people/facial-recognition data: each user builds and names their own set of people.
- **Shared albums** — invite users as *Viewer* or *Editor*. An Editor can add assets, but cannot remove assets owned by the album owner.

> **Remote access:** Immich is only reachable on the tailnet. Other users' phones need Tailscale installed and access to your tailnet, or app backup will silently only work on the home network.

### AI processing on the GPU box

Smart search and face detection are the expensive parts, and they run in a separate container that can live on a different machine. It is **stateless** — no photos, no database, just a model cache. The server sends it an image preview over HTTP and gets back a CLIP embedding and face bounding boxes, which it stores in its own database.

This stack ships **no ML container in `docker-compose.yaml`**. It lives in `immich/remote-ml.yml` and runs on the GPU box:

```bash
./immich/start-immich-ml.sh     # pulls, then starts
./immich/stop-immich-ml.sh
```

Point Immich at it once: **Administration → Settings → Machine Learning → Add URL**. This is stored in Immich's database, not in `.env` — the `IMMICH_MACHINE_LEARNING_URL` environment variable is deprecated.

Use the GPU box's **Tailscale IP**, e.g. `http://100.108.78.65:3003`, and use it even when Immich is running on that same machine. Two reasons:

- **It survives the move.** The same URL works whether Immich runs on the GPU box or the Pi, so migrating changes nothing here.
- **Hostnames are unreliable here.** The lookup happens inside the `immich-server` container, which resolves via Docker's embedded DNS forwarding to the host — and if this stack's AdGuard is your resolver, it won't know Tailscale MagicDNS names. A raw tailnet IP is stable for the life of the device and involves no DNS at all.

Verify before trusting it:

```bash
curl http://100.108.78.65:3003/ping    # expect: pong
```

> **If that hangs, it's almost always the firewall.** On Windows + WSL2, Docker Desktop publishes the port to the Windows host (so the tailnet IP works), but Windows Firewall rules are sometimes scoped to the private-network profile only, and the Tailscale adapter may not be classified as private.

**Keep `IMMICH_VERSION` identical on both machines** — mismatched versions misbehave. `immich/start-immich-ml.sh` pulls before starting for exactly this reason, so bumping the version in `.env` is enough.

Since inference runs on a GPU, raise the CLIP model from the small default under **Settings → Machine Learning → Smart Search**. `ViT-SO400M-16-SigLIP2-384__webli` tops Immich's curated English list and is comfortable on any discrete GPU; it is markedly better than the default at scene descriptions and niche queries. Models are downloaded at runtime from [huggingface.co/immich-app](https://huggingface.co/immich-app) into the `model-cache` volume — the image tag only picks the runtime, so no image change is needed to switch.

For OCR, prefer `PP-OCRv5_server` over the `_mobile` default — the larger pair needs roughly 12GB of VRAM. Leave **facial recognition** on `buffalo_l`: it is already the strongest model available, and `antelopev2` is a downgrade despite the name.

Changing any of these means re-processing the whole library from the Jobs page (**Smart Search → All**, and likewise for OCR), so set them *before* the initial import and it costs nothing.

### When the GPU box is off

ML jobs simply fail. That's harmless: a failed job doesn't mark the asset as processed, so it stays queued as "missing" and gets picked up later. Browsing, uploading and thumbnail generation are unaffected — those all run on the Immich host.

If the failed-job counter bothers you, switch **Settings → Machine Learning → Enabled** off between sessions. It costs nothing except having to remember to switch it back on — and forgetting means the Missing jobs below silently do nothing.

So the routine, whenever you next power the GPU box up:

1. **Settings → Machine Learning → Enabled** on, if you turned it off
2. GPU box: `./immich/start-immich-ml.sh`
3. **Administration → Jobs**: run **Smart Search → Missing**, then **Face Detection → Missing**
4. Wait for both queues to drain
5. GPU box: `./immich/stop-immich-ml.sh` — you can shut it down now
6. **Jobs → Facial Recognition → Missing**

Step 5 needs no GPU: facial *recognition* is the clustering pass over vectors already in the database. Only *detection* and smart search need the remote container.

### Moving Immich to another machine

Bootstrapping on a fast machine and then handing off to a slow one is a supported path, and cheap here — **because only the database moves.**

That works because of one invariant: Immich stores **container-internal** paths, not host paths. Both machines mount their storage at `/data`, so every asset row stays valid even though `STORAGE_ROOT` differs between them. Keep the photos on shared storage from the very first import and they never move at all; the dump is only metadata, embeddings and face vectors, so it's small and quick regardless of library size.

> **Dump the database — never copy `./immich/postgres`.** A Postgres data directory is not portable across architectures, and x86-64 → arm64 is exactly that. `pg_dump` output is plain SQL and is portable; the data directory is not.

> **Only one Immich may run against a given `STORAGE_ROOT`.** After the handover, do not start the old instance again — two servers writing to the same storage with diverging databases will corrupt the library. Stop the old one before starting the new, and keep its database directory only as a rollback.

On the source machine:

```bash
docker compose stop immich-server          # quiesce the DB first
docker exec -t immich-postgres pg_dump --clean --if-exists \
  --dbname=immich --username=postgres | gzip > immich-dump.sql.gz
```

On the target machine — clone this repo, carry `.env` across, and set `STORAGE_ROOT` to wherever that machine sees the same storage. `IMMICH_DB_PASSWORD` does not need to match the source: `pg_dump` of a single database carries no roles, so it only has to be consistent within the target's own `.env`. `IMMICH_VERSION` **does** have to match.

```bash
docker compose create                       # create, do not start
docker start immich-postgres && sleep 10

gunzip --stdout immich-dump.sql.gz \
  | docker exec -i immich-postgres psql --dbname=immich \
      --username=postgres --single-transaction --set ON_ERROR_STOP=on

docker compose up -d
```

The restore requires a database Immich has **never started against** — if `immich-server` has already run and created a schema, `docker compose down -v` first. Run the same `IMMICH_VERSION` on both ends, or the restored schema won't match the binary.

Finally, confirm the machine-learning URL still points at the GPU box. If you used its Tailscale IP as recommended above, it already does.

### Gotchas

- **Thumbnail generation cannot be offloaded.** It runs on the server, not the ML container. For a large first import it — not the AI — is the bottleneck, which is the main argument for doing that import on your fastest machine and [handing off afterwards](#moving-immich-to-another-machine).
- **Writes to network storage are slow.** If `STORAGE_ROOT` is an SMB/NFS mount, every thumbnail and transcode crosses it. Correct, but expect the initial import to take considerably longer than local disk would.
- **Deleting an asset in the UI deletes the file.** Immich owns this library; there is no read-only safety net. Assets go to trash first and are purged after 30 days.
- **Budget for derived files.** Thumbnails and previews run to a few hundred KB per photo on top of the originals, plus transcodes for videos.
- Back up **both** `./immich/postgres` (via `pg_dump`) and `$STORAGE_ROOT/immich`. The database alone is useless, and vice versa. See the [Immich backup docs](https://docs.immich.app/administration/backup-and-restore).

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
│   ├── includes/                # proxy_services.conf, immich.conf
│   ├── html/                    # landing-page dashboard served at /
│   └── certs/                   # TLS cert + key (git-ignored)
├── immich/
│   ├── remote-ml.yml            # ML container for the GPU box (not the NAS)
│   ├── start-immich-ml.sh       # GPU box: start remote ML
│   ├── stop-immich-ml.sh        # GPU box: stop remote ML
│   └── postgres/                # Immich database (git-ignored)
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

Released under the [MIT License](LICENSE.md).

Built on the excellent work of [Jellyfin](https://jellyfin.org), the [Servarr](https://wiki.servarr.com/) project (Sonarr / Radarr / Lidarr / Prowlarr), [qBittorrent](https://www.qbittorrent.org/), [slskd](https://github.com/slskd/slskd), [soularr](https://github.com/mrusse/soularr), [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr), and [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome).
