# 🏠 Self-Hosted Media Server Stack

<div align="center">

![Media Stack](https://img.shields.io/badge/Media-Server-blue?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

[![GitHub Repo stars](https://img.shields.io/github/stars/user/media-stack?style=social)](https://github.com/yourusername/media-stack)
[![GitHub forks](https://img.shields.io/github/forks/user/media-stack?style=social)](https://github.com/yourusername/media-stack)

**A complete self-hosted entertainment ecosystem powered by Docker**

[Features](#features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Configuration](#configuration) • [Services](#services) • [Contributing](#contributing)

</div>

---

## 📖 Overview

This project provides a fully-featured, self-hosted media server stack that brings the convenience of streaming services to your own hardware. Automate the download and organization of your media library with a powerful combination of applications working together seamlessly.

### ✨ Why Self-Host?

- **Complete Control** - Own your data and content forever
- **Privacy First** - No third-party services tracking your viewing habits
- **Cost Effective** - No recurring subscription fees
- **Customization** - Tailor every aspect to your needs
- **Offline Access** - Stream content anywhere with internet access

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        NGINX                                 │
│              (Reverse Proxy + SSL Termination)               │
└─────────────────────────────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    ┌─────▼─────┐      ┌────▼─────┐      ┌────▼─────┐
    │ Jellyfin  │      │  Seerr   │      │ AdGuard  │
    │ (Streaming)│    │ (Discovery)│    │ (DNS/AdBlock)│
    └───────────┘      └───────────┘      └───────────┘
          │                                            │
          │                ┌───────────────────────────┘
          │                │
          │    ┌───────────▼─────────────┐    ┌──────────▼─────────────┐
          └────►│  Prowlarr (Indexers)  │────►│   Qbittorrent (DL)     │
                 └───────────────────────┘    └───────────────────────┘
                                                │      │
                                    ┌───────────┼───────────┐
                                    │           │           │
                              ┌─────▼─────┐ ┌─▼─────┐ ┌──▼──────┐
                              │  Sonarr   │ │ Radarr│ │  Lidarr │
                              │(TV Series)│ │(Movies)│ │(Music)  │
                              └───────────┘ └───────┘ └─────────┘
                                                │
                                  ┌─────────────▼──────────────┐
                                  │        Soulseek            │
                                  │  (slskd + soularr)         │
                                  │    (Community Downloads)   │
                                  └────────────────────────────┘
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
| 🔐 **Secure Access** | Nginx reverse proxy with optional SSL |
| 🌐 **Bypass Protection** | FlareSolverr handles cloudflare-protected sites |
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
git clone https://github.com/yourusername/media-stack.git
cd media-stack
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
NGINX_HTTPS_PORT=443
TZ=Europe/Your_City
```

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Access your services

- **Jellyfin**: http://localhost:8080
- **Sonarr**: http://localhost:8989
- **Radarr**: http://localhost:7878
- **Lidarr**: http://localhost:8686
- **Qbittorrent**: http://localhost:8081
- **AdGuard**: http://localhost:3000

### 5. Setup services

1. **Jellyfin** - Add your media files to the configured path
2. **Sonarr/Radarr/Lidarr** - Add your indexer API keys and configure search preferences
3. **Prowlarr** - Add your preferred indexer accounts
4. **Seerr** - Configure to connect with your Jellyfin instance

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JELLYFIN_MEDIA_PATH` | Path to your media library | - |
| `QBITTORRENT_DOWNLOADS_PATH` | Path for downloaded torrents | - |
| `NGINX_HOST_PORT` | HTTP port for Nginx | 80 |
| `NGINX_HTTPS_PORT` | HTTPS port for Nginx | 443 |
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

**Services Provided By:** jellyfin/jellyfin

### 📺 Seerr
Automated content discovery service that recommends movies and TV shows based on your Jellyfin library.

**Services Provided By:** seerr/seerr

### 🔎 Prowlarr
Indexer aggregation service that manages API keys for multiple torrent and usenet indexers.

**Services Provided By:** ghcr.io/hotio/prowlarr

### ⬇️ Qbittorrent
Full-featured, open-source BitTorrent client.

**Services Provided By:** lscr.io/linuxserver/qbittorrent

### 📺 Sonarr
Automated TV series download and management tool.

**Services Provided By:** ghcr.io/hotio/sonarr

### 🎥 Radarr
Automated movie download and management tool.

**Services Provided By:** ghcr.io/hotio/radarr

### 🎵 Lidarr
Automated music download and management tool.

**Services Provided By:** ghcr.io/hotio/lidarr

### 👾 slskd
Modern Soulseek client with remote configuration support.

**Services Provided By:** slskd/slskd

### 🤖 soularr
Automated downloader for Soulseek using Lidarr data for metadata matching.

**Services Provided By:** ghcr.io/mrusse/soularr

### 🛡️ AdGuard Home
Network-wide ad blocking DNS server with web interface.

**Services Provided By:** adguard/adguardhome

### 🔄 Nginx
High-performance web server and reverse proxy.

**Services Provided By:** nginx:mainline-alpine

### 🧩 FlareSolverr
Proxy server to bypass cloudflare protection for scraping.

**Services Provided By:** ghcr.io/flaresolverr/flaresolverr

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
```

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

### SSL Certificates

Generate self-signed certificates or use Let's Encrypt with Certbot for production use.

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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 🙏 Acknowledgments

- [Jellyfin](https://jellyfin.org) - The media server foundation
- [Sonarr/Radarr/Lidarr](https://sonarr.tv, https://radarr.video, https://lidarr.video) - The download automation tools
- [Prowlarr](https://wiki.prowlarr.com) - Indexer aggregation
- [Soulseek](https://www.slsknet.org) - Community file sharing
- All open-source contributors and Docker maintainers

---

## 📧 Support

- 🐛 [Report an Issue](https://github.com/yourusername/media-stack/issues)
- 💬 [Discussions](https://github.com/yourusername/media-stack/discussions)
- 📧 [Contact](mailto:your.email@example.com)

<div align="center">

**Made with ❤️ and Docker**

[⬆ Back to Top](#-self-hosted-media-server-stack)

</div>