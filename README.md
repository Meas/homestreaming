# 🏠 Self-Hosted Streaming Stack

<div align="center">

![Stream Stack](https://img.shields.io/badge/Streaming-Stack-blue?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**A complete self-hosted entertainment ecosystem powered by Docker**

[Features](#features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Configuration](#configuration) • [Services](#services) • [Accessing Services](#accessing-services) • [Initial Setup Guide](#-initial-setup-guide) • [Volume Paths](#-volume-paths--requirements) • [Port Requirements](#-port-requirements) • [Maintenance](#-maintenance) • [Troubleshooting](#-troubleshooting) • [Legal Disclaimer](#-legal-disclaimer) • [Initial Setup Guide](#-initial-setup-guide) • [Volume Paths](#-volume-paths--requirements) • [Port Requirements](#-port-requirements) • [Maintenance](#-maintenance)

</div>

---

## 📖 Overview

This project provides a fully-featured, self-hosted media server stack that brings the convenience of streaming services to your own hardware. All services are proxied through a central Nginx instance with consistent paths, making it work seamlessly with **Tailscale** and other VPN solutions that don't support native subdomain routing.

### ✨ Why Self-Host?

- **Complete Control** - Own your data and content forever
- **Privacy First** - No third-party services tracking your viewing habits
- **Cost Effective** - No recurring subscription fees
- **Customization** - Tailor every aspect to your needs
- **Offline Access** - Stream content anywhere with internet access

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Nginx Reverse Proxy                               │
│              Path-Based Routing (All Services via /service/)               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌────────────────┼────────────────┐
                    │                │                │
            ┌───────▼────────┐ ┌────▼───────┐  ┌────▼─────┐
            │    Jellyfin    │ │  AdGuard   │  │  Seerr   │
            │    /jf/        │ │   /ag/     │  │ /seerr/  │
            └────────┬───────┘ └────────────┘  └──────────┘
                     │                         │
                     │                         │
                     ▼                         ▼
            ┌─────────────────────────────────────────────┐
            │               Media Storage                  │
            │  ┌─────────────┬─────────────┬─────────────┐  │
            │  │    Movies   │  TV Shows   │    Music    │  │
            │  └─────────────┴───────────┴─────────────┘  │
            └─────────────────────────────────────────────┘
                     │
         ┌────────────┼────────────┐
         │            │            │
    ┌────▼─────┐ ┌────▼────┐ ┌────▼──────┐
    │  Sonarr  │ │  Radarr │ │   Lidarr  │
    │ /sonarr/ │ │ /radarr/│ │  /lidarr/ │
    └────┬─────┘ └────┬────┘ └────┬──────┘
         │            │            │
         └────────────┼────────────┘
                      │
            ┌─────────▼─────────┐
            │      Prowlarr     │
            │   /prowlarr/      │
            │  (Indexer Agg)    │
            └─────────┬─────────┘
                      │
            ┌─────────▼─────────┐
            │   Qbittorrent     │
            │     /qbt/         │
            │   (Torrent DL)    │
            └───────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  (soularr-tools profile only)                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────│
                    │               │
            ┌───────▼────────┐ ┌────▼───────┐
            │    slskd       │ │   soularr  │
            │    /slskd/     │ │            │
            │  (Soulseek)    │ │            │
            └────────────────┘ └────────────┘ 
```

**Data Flow:**
- **Indexers** → Prowlarr → Sonarr/Radarr/Lidarr → Qbittorrent (downloads)
- **Soulseek** → slskd → soularr (downloads via P2P network)
- All services → Jellyfin (displays media)
- Jellyfin → Seerr (suggests content)

---

## 🚀 Features

| Feature | Description |
|---------|-------------|
| 🎬 **Automated Media Management** | Sonarr, Radarr, and Lidarr automatically download and organize content |
| 🎵 **Community Downloads** | Soulseek-based downloading from community sources |
| 🔍 **Smart Discovery** | Seerr suggests content based on your Jellyfin library |
| 📡 **Indexer Aggregation** | Prowlarr manages multiple indexer APIs from one place |
| 🛡️ **Privacy Shield** | AdGuard Home blocks ads and trackers at DNS level |
| 🔐 **Secure Access** | Unified SSL/TLS encryption for all services |
| 🌐 **VPN Friendly** | Path-based routing works with Tailscale, ZeroTier, etc. |
| ⚡ **Containerized** | All services run in Docker for easy deployment |

---

## 📋 Prerequisites

- **Docker** & **Docker Compose** installed
- **Port 80, 443, and 53** available on your system
- **Sufficient storage** for your media collection
- **A reliable torrent client** (optional, for initial setup)

---

## ⚡ Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/meas/homestreaming.git
cd homestreaming
```

### 2. Configure environment variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your preferences:

```bash
# Example configuration
JELLYFIN_MEDIA_PATH=/path/to/your/media
NGINX_CONFIG_NAME=https # or http-only
TZ=Europe/Your_City
```

### 3. Start the stack

```bash
docker compose up -d
```

---

## 🔒 HTTPS Configuration

The stack supports both HTTP and HTTPS modes. Choose your configuration:

### HTTP Mode (Default)

Use this for development or when you don't need encryption:

```bash
NGINX_CONFIG_NAME=http-only
docker compose up -d
```

Access services via `http://your-hostname/service-name`

### HTTPS Mode

Use this for production with SSL encryption:

```bash
NGINX_CONFIG_NAME=https
docker compose up -d
```

You need to provide SSL certificates:

**Self-signed certificates (for testing):**
```bash
mkdir -p nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/default.key \
  -out nginx/certs/default.crt
```

**Let's Encrypt (for production):**
```bash
# Generate certificate and configure nginx
docker compose up -d
# Then use certbot to obtain SSL certificates
```

**Note:** SSL certificates are mapped from `./nginx/certs/` to `/etc/ssl/certs/` in the nginx container.

---

## 🔗 Accessing Services

All services are accessible via path-based routing through Nginx. This setup ensures compatibility with Tailscale, ZeroTier, and other VPN solutions that don't support native subdomain resolution.

| Service | Path | Description |
|---------|------|-------------|
| Jellyfin | `/jf/` | Media streaming server |
| Sonarr | `/sonarr/` | TV series automation |
| Radarr | `/radarr/` | Movie automation |
| Lidarr | `/lidarr/` | Music automation |
| Prowlarr | `/prowlarr/` | Indexer aggregation |
| Qbittorrent | `/qbt/` | Torrent client |
| AdGuard | `/ag/` | DNS and ad-blocking |
| Seerr | `/seerr/` | Content discovery |
| slskd | `/slskd/` | Soulseek client |

**Examples:**
- Jellyfin: `http://localhost/jf/` or `http://your-tailscale-ip/jf/`
- Sonarr: `http://localhost/sonarr/`
- Seerr: `http://localhost/seerr/`

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JELLYFIN_MEDIA_PATH` | Path to your media library | - |
| `QBITTORRENT_DOWNLOADS_PATH` | Path for downloaded torrents | - |
| `NGINX_CONFIG_NAME` | Nginx configuration mode | `http-only` |
| `TZ` | Timezone | Etc/CET |

### Volume Mappings

| Service | Configuration Volume | Data Volume |
|---------|---------------------|-------------|
| Jellyfin | `./jellyfin/config` | `./jellyfin/media` |
| qBittorrent | `./qbittorrent/config` | `./qbittorrent/downloads` |
| Sonarr | `./sonarr/config` | Downloads + Series Library |
| Radarr | `./radarr/config` | Downloads + Movies Library |
| Lidarr | `./lidarr/config` | Downloads + Music Library |
| slskd | `./slskd/config` | All Media + Incomplete/Downloads |
| soularr | `./soularr/config` | Downloads Path |

---

## 🧩 Services

### 🎬 Jellyfin
Open-source media server for streaming your personal media collection.

**Docs:** https://jellyfin.org/docs/

### 📺 Seerr
Automated content discovery service that recommends movies and TV shows based on your Jellyfin library.

**Docs:** https://seerr.dev/

### 🔎 Prowlarr
Indexer aggregation service that manages API keys for multiple torrent and usenet indexers.

**Docs:** https://prowlarr.com/

### ⬇️ Qbittorrent
Full-featured, open-source BitTorrent client.

**Docs:** https://www.qbittorrent.org/

### 📺 Sonarr
Automated TV series download and management tool.

**Docs:** https://sonarr.tv/

### 🎥 Radarr
Automated movie download and management tool.

**Docs:** https://radarr.video/

### 🎵 Lidarr
Automated music download and management tool.

**Docs:** https://lidarr.audio/

### 👾 slskd
Modern Soulseek client with remote configuration support.

**Docs:** https://github.com/slskd/slskd

### 🤖 soularr
Automated downloader for Soulseek using Lidarr data for metadata matching.

**Docs:** https://github.com/mrusse/soularr

### 🛡️ AdGuard Home
Network-wide ad blocking DNS server with web interface.

**Docs:** https://github.com/AdguardTeam/AdGuardHome

### 🔄 Nginx
High-performance web server and reverse proxy.

**Docs:** https://nginx.org/en/docs/

### 🧩 FlareSolverr
Proxy server to bypass Cloudflare protection for content scraping. Used by Prowlarr when configured with Cloudflare-protected indexers.

**Docs:** https://github.com/FlareSolverr/FlareSolverr

**Note:** Configure Cloudflare bypass in your Prowlarr indexer settings as needed.

---

## 🎮 Soularr Setup

Soularr is a tool that automatically downloads content from Soulseek based on your Lidarr data:

```bash
# Start soularr tools profile
docker compose --profile soularr-tools up -d

# View logs
docker compose --profile soularr-tools logs -f soularr

# Stop soularr tools
docker compose --profile soularr-tools down
```

**Configuration:** Place your `slskd.config.yml` in `./slskd/config/`

---

## 📚 Getting Started Guides

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Sonarr Setup Guide](https://trash-guides.info/Sonarr/)
- [Radarr Setup Guide](https://trash-guides.info/Radarr/)
- [Lidarr Setup Guide](https://trash-guides.info/Lidarr/)
- [Prowlarr Documentation](https://trash-guides.info/Prowlarr/)

---

## 📚 Arr Service Documentation

Additional resources for Sonarr, Radarr, and Lidarr:

- **[Servarr Wiki](https://wiki.servarr.com/)** - Official documentation for all Arr services
- **[Trash Guides](https://trash-guides.info/)** - Community guides and best practices

---

## 🧭 Initial Setup Guide

### Step 1: Jellyfin
1. Access `http://your-hostname/jf/` and complete the initial setup wizard
2. Add your media libraries (Movies, Shows, Music)
3. Create user accounts for family members
4. Configure thumbnail, poster, and fanart settings

### Step 2: Prowlarr
1. Access `http://your-hostname/prowlarr/` and create an account
2. Add indexers you have accounts for (ThePirateBay, etc.)
3. Set indexer authentication in Prowlarr settings if required
4. Verify indexer connection in "System > Indexers"

### Step 3: Sonarr / Radarr / Lidarr
1. Access each service and create an account
2. Add indexers from Prowlarr (Settings > Connect > Indexers)
3. Add your media server connection (Jellyfin)
4. Set up quality profiles and download locations
5. Search for content to verify automation works

### Step 4: Qbittorrent
1. Access `http://your-hostname/qbt/` and create an account
2. Configure download directory and watched folders
3. Set bandwidth limits as needed

### Step 5: Seerr
1. Access `http://your-hostname/seerr/` and create an account
2. Connect your Jellyfin server
3. Select which libraries to monitor (Movies, Shows)
4. Allow Seerr to scan your library

### Step 6: AdGuard Home (Optional)
1. Access `http://your-hostname/ag/setup/` and complete setup
2. Configure your DNS settings in your router or DHCP server
3. Set up filters and blocklists

---

## 📂 Volume Paths & Requirements

**Important:** All volume paths in `.env` must be absolute paths or properly formatted relative paths.

| Variable | Description | Example |
|----------|-------------|---------|
| `JELLYFIN_MEDIA_PATH` | Root directory for all media (movies, shows, music) | `/mnt/media` |
| `JELLYFIN_CONFIG_PATH` | Jellyfin configuration storage | `./jellyfin/config` |
| `JELLYFIN_CACHE_PATH` | Jellyfin cache storage | `./jellyfin/cache` |
| `QBITTORRENT_DOWNLOADS_PATH` | Torrent downloads directory | `/mnt/downloads` |
| `QBITTORRENT_CONFIG_PATH` | Qbittorrent configuration | `./qbittorrent/config` |
| `NGINX_SHARE_FILES` | Shared files accessible via `/file/` | `./nginx/files` (optional) |

**Media Organization:**
- Movies: Place in `{JELLYFIN_MEDIA_PATH}/videos/movies/`
- TV Shows: Place in `{JELLYFIN_MEDIA_PATH}/videos/shows/`
- Music: Place in `{JELLYFIN_MEDIA_PATH}/music/`

---

## 🔌 Port Requirements

The following ports must be available on your system:

| Port | Service | Protocol | Notes |
|------|---------|----------|-------|
| 80 | Nginx | TCP | HTTP default |
| 443 | Nginx | TCP | HTTPS default |
| 53 | AdGuard Home | TCP/UDP | DNS server |
| 8080 | Qbittorrent WebUI | TCP | Configure via `QBITTORRENT_WEBUI_PORT` |
| 12854 | Qbittorrent | TCP | Configure via `QBITTORRENT_TORRENTING_PORT` |

**If ports are occupied:**
- Modify port mappings in `docker-compose.yaml`
- Use port forwarding on your router
- Stop conflicting services

---

## 🛠️ Usage

### Common Commands

```bash
# Start all services
docker compose up -d

# Start with soularr tools
docker compose --profile soularr-tools up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Restart specific service
docker compose restart sonarr

# Access service console
docker compose exec sonarr bash
````

### Volume Management

```bash
# Backup media files
tar -czf media-backup.tar.gz ./jellyfin/media

# Backup configuration
tar -czf config-backup.tar.gz ./sonarr ./radarr ./lidarr ./prowlarr
```

### SSL Certificate Renewal

If using Let's Encrypt certificates, renew them periodically:

```bash
# Using certbot (example)
certbot renew --nginx -d your-domain.com
```

### Updating Services

```bash
# Update all services to latest tags
docker compose pull
docker compose up -d

# Update specific service
docker compose pull sonarr
docker compose up -d sonarr
```

### Jellyfin WebSocket Fix

For WebSocket connections to work properly with Nginx, the `/jf/socket` location is configured with proper upgrade headers in `./nginx/includes/proxy_services.conf`.

---

## 📝 Customization

### Nginx Configuration

Edit `./nginx/conf.d/http-only.conf` or `./nginx/conf.d/https.conf` to customize reverse proxy rules.

Edit `./nginx/includes/proxy_services.conf` to modify service routing paths.

---

## 🔧 Troubleshooting

### Port Already in Use

If ports are already occupied, modify the port mappings in `docker-compose.yaml` or use a port-forwarding solution.

### Container Won't Start

```bash
# Check logs
docker compose logs service_name

# Rebuild without cache
docker compose up -d --build

# Remove containers and volumes
docker compose down -v
```

### Media Not Appearing in Jellyfin

1. Ensure files are in the correct path
2. Refresh Jellyfin library
3. Check file permissions

### Prowlarr Indexer Connection Issues

1. Verify your indexer account credentials are correct
2. Check if the indexer requires Cloudflare bypass (configure FlareSolverr)
3. Verify indexer status in "System > Indexers"

### Seerr Not Discovering Content

1. Ensure Seerr can connect to your Jellyfin server
2. Check Seerr logs: `docker compose logs seerr`
3. Verify your Jellyfin API key is correct

### Nginx 502 Bad Gateway

1. Check if all required containers are running: `docker compose ps`
2. Verify service URLs in docker-compose.yaml
3. Check nginx logs: `docker compose logs nginx`

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

- [Jellyfin](https://jellyfin.org) - The media server foundation
- [Sonarr/Radarr/Lidarr](https://sonarr.tv, https://radarr.video, https://lidarr.audio) - The download automation tools
- [Prowlarr](https://prowlarr.com) - Indexer aggregation
- [Soulseek](https://github.com/mrusse/soularr) - Community file sharing
- All open-source contributors and Docker maintainers

---

## 📧 Support

- 🐛 [Report an Issue](https://github.com/meas/homestreaming/issues)
- 💬 [Discussions](https://github.com/meas/homestreaming/discussions)
- 📧 [Contact](mailto:your.email@example.com)

---

## ⚖️ Legal Disclaimer

This project uses automation tools (Sonarr, Radarr, Lidarr, Prowlarr) to download content you own or have legally obtained rights to. Indexers may provide access to copyrighted material. Users are responsible for ensuring they have the legal right to download and store such content.

- Respect copyright laws in your country/region
- Only use content you own or have permission to use
- Prowlarr indexers should be configured with accounts you own
- The authors of this project are not responsible for any misuse

---

<div align="center">

**Made with ❤️ and Docker**

[⬆ Back to Top](#-self-hosted-streaming-stack)

</div>