# 🏠 Self-Hosted Streaming Stack

<div align="center">

![Stream Stack](https://img.shields.io/badge/Streaming-Stack-blue?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

[![GitHub Repo stars](https://img.shields.io/github/stars/meas/homestreaming?style=social)](https://github.com/meas/homestreaming)
[![GitHub forks](https://img.shields.io/github/forks/meas/homestreaming?style=social)](https://github.com/meas/homestreaming)

**A complete self-hosted entertainment ecosystem powered by Docker**

[Features](#features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Configuration](#configuration) • [Services](#services) • [Accessing Services](#accessing-services)

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
┌────────────────────────────────────────────────────────────────────────┐
│                             Nginx                                       │
│   /jf → Jellyfin    /sonarr → Sonarr    /radarr → Radarr    /lidarr →  │
│   /prowlarr → Prowlarr  /qbt → Qbittorrent  /ag → AdGuard  /seerr →   │
│   /slskd → slskd                                            (All SSL) │
└────────────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
    ┌───▼────┐         ┌───▼───┐           ┌──▼──────┐
    │Jellyfin│         │Sonarr │           │ Radarr  │
    └────────┘         └───────┘           └─────────┘
        │                 │                   │
        └─────────────────┼───────────────────┘
                          │
                    ┌─────▼─────┐
                    │ Qbittorrent│
                    └─────┬─────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    ┌───▼────┐         ┌──▼───┐         ┌──▼──────┐
    │Sonarr  │         │Radarr│         │Lidarr   │
    │Lidarr  │         │Sonarr│         │Prowlarr │
    └────────┘         └──────┘         └─────────┘
                          │
                  ┌───────▼───────┐
                  │    slskd      │
                  │    soularr    │
                  └───────────────┘
```

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

**Docs:** https://gh.crunchyroll.com/docs/api/seerr/

### 🔎 Prowlarr
Indexer aggregation service that manages API keys for multiple torrent and usenet indexers.

**Docs:** https://wiki.prowlarr.com/

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

**Docs:** https://lidarr.video/

### 👾 slskd
Modern Soulseek client with remote configuration support.

**Docs:** https://slskd.org/

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
Proxy server to bypass cloudflare protection for scraping.

**Docs:** https://docs.flaresolverr.org/

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
- [Sonarr Setup Guide](https://sonarr.tv/)
- [Radarr Setup Guide](https://radarr.video/)
- [Lidarr Setup Guide](https://lidarr.video/)
- [Prowlarr Documentation](https://wiki.prowlarr.com/)

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

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

- [Jellyfin](https://jellyfin.org) - The media server foundation
- [Sonarr/Radarr/Lidarr](https://sonarr.tv, https://radarr.video, https://lidarr.video) - The download automation tools
- [Prowlarr](https://wiki.prowlarr.com) - Indexer aggregation
- [Soulseek](https://www.slsknet.org) - Community file sharing
- All open-source contributors and Docker maintainers

---

## 📧 Support

- 🐛 [Report an Issue](https://github.com/meas/homestreaming/issues)
- 💬 [Discussions](https://github.com/meas/homestreaming/discussions)
- 📧 [Contact](mailto:your.email@example.com)

<div align="center">

**Made with ❤️ and Docker**

[⬆ Back to Top](#-self-hosted-streaming-stack)

</div>