# Plex Stack — Setup & Post-Deploy Guide

## Pre-flight

### 1. Create all appdata directories

App configs live in `appdata/plex-stack/` — a sibling to `appdata/docker/`, NOT inside it.
`appdata/docker/` is owned by root (it's the Docker daemon data-root) and must not be touched.

```bash
# *arr app configs — separate from Docker's data-root
mkdir -p /home/argus/Drives/1TBa/appdata/plex-stack/{overseerr,sonarr,radarr,lidarr,prowlarr,qbittorrent}/config

# Plex (already exists per your spec, but verify)
mkdir -p /home/argus/Drives/1TBa/plex/{config,transcode}

# Downloads staging
mkdir -p /home/argus/Drives/2TBa/downloads/{complete,incomplete}

# Verify ownership — all should show argus:argus
ls -la /home/argus/Drives/1TBa/appdata/plex-stack/

# Verify NFS mounts are online before starting
ls /mnt/nas/vol1/movies && ls /mnt/nas/vol2/tv && ls /mnt/nas/vol2/other
```

### 2. Verify NFS mounts survive reboot

Check `/etc/fstab` has entries like:
```
nas-host:/vol1  /mnt/nas/vol1  nfs  defaults,_netdev,x-systemd.automount  0  0
nas-host:/vol2  /mnt/nas/vol2  nfs  defaults,_netdev,x-systemd.automount  0  0
```
The `x-systemd.automount` flag prevents Docker from starting before NFS is ready.

### 3. Set up .env file

```bash
cp .env.template .env
# Edit .env with your NordVPN token and Plex claim token
nano .env
```

### 4. Add .env to .gitignore

```bash
echo ".env" >> /home/argus/Repos/personal-self/plex/.gitignore
```

---

## First Boot

```bash
cd /home/argus/Repos/personal-self/plex

# Start NordVPN first and verify it connects
docker compose up nordvpn -d
docker compose logs -f nordvpn   # Wait for "Connected" message

# Verify VPN is working — IP should NOT be 192.168.2.27
docker exec nordvpn curl -s https://ipinfo.io/ip

# Start everything else
docker compose up -d

# Watch logs for errors
docker compose logs -f
```

---

## Post-Deploy Configuration

### Plex (port 32400)
Access: `http://192.168.2.27:32400/web`

1. Sign in with your Plex account
2. Add libraries:
   - Movies → `/data/movies`
   - TV Shows → `/data/tv`
   - Music → `/data/music`
   - Other → `/data/other`
3. Settings → Transcoder → Temporary directory → `/transcode`
4. Settings → Remote Access → Verify external access if desired

### qBittorrent (port 8080) — accessed through NordVPN
Access: `http://192.168.2.27:8080`

Default credentials: `admin` / `adminadmin` (change immediately)

1. Tools → Options → Downloads:
   - Default save path: `/downloads/complete`
   - Incomplete downloads path: `/downloads/incomplete`
2. Tools → Options → Connection: Verify port 6881 is open
3. Tools → Options → Web UI: Change password

**Generate an API key** — you'll need it for Sonarr/Radarr/Lidarr.

### Prowlarr (port 9696)
Access: `http://192.168.2.27:9696`

1. Settings → Indexers → Add your indexers (public and/or private trackers)
2. Settings → Apps → Add each *arr app:
   - Sonarr: `http://sonarr:8989` + API key from Sonarr Settings → General
   - Radarr: `http://radarr:7878` + API key
   - Lidarr: `http://lidarr:8686` + API key
3. Sync all indexers once apps are configured

### Sonarr (port 8989)
Access: `http://192.168.2.27:8989`

1. Settings → Media Management:
   - Enable hardlinks (same filesystem = fast, no copy)
   - Root folder: `/tv`
2. Settings → Download Clients → Add qBittorrent:
   - Host: `nordvpn` (container name, not IP — they share a network)
   - Port: `8080`
   - Category: `sonarr`
3. Settings → General → copy your API key for Prowlarr + Overseerr

### Radarr (port 7878)
Access: `http://192.168.2.27:7878`

Same pattern as Sonarr:
1. Root folder: `/movies`
2. qBittorrent host: `nordvpn`, port `8080`, category: `radarr`
3. Copy API key for Prowlarr + Overseerr

### Lidarr (port 8686)
Access: `http://192.168.2.27:8686`

1. Root folder: `/music`
2. qBittorrent host: `nordvpn`, port `8080`, category: `lidarr`

### Overseerr (port 5055)
Access: `http://192.168.2.27:5055`

1. Sign in with Plex — Overseerr auto-discovers your Plex server
2. Add Radarr: `http://radarr:7878` + API key → set default quality profile + root folder
3. Add Sonarr: `http://sonarr:8989` + API key → set default quality profile + root folder
4. Settings → Users → Configure request limits if desired

---

## Hardlinks — Critical for Efficient Storage

For hardlinks to work (avoid copying files on import), the download path and library path **must be on the same filesystem**. Your current layout has downloads on `2TBa` and media on NAS, so Sonarr/Radarr will **copy** then delete rather than hardlink. This is expected given your layout and works fine.

If you ever want hardlinks for Radarr/Sonarr, you'd need to move downloads staging onto the NAS as a subfolder.

---

## VPN Kill Switch Verification

```bash
# Confirm qBittorrent traffic exits through VPN
docker exec nordvpn curl -s https://ipinfo.io/json

# Simulate VPN drop — qBittorrent should lose internet but LAN stays up
docker exec nordvpn ip link set nordlynx down
docker exec qbittorrent curl --max-time 5 https://example.com  # Should fail
docker exec nordvpn ip link set nordlynx up
```

---

## Useful Commands

```bash
# Tail all logs
docker compose logs -f

# Restart a single service
docker compose restart sonarr

# Force Watchtower to check for updates now
docker exec watchtower /watchtower --run-once

# Check VPN IP
docker exec nordvpn curl -s https://ipinfo.io/ip

# Update all images manually
docker compose pull && docker compose up -d
```

---

## Port Summary

| Service      | Port  | URL                              |
|-------------|-------|----------------------------------|
| Plex        | 32400 | http://192.168.2.27:32400/web   |
| Overseerr   | 5055  | http://192.168.2.27:5055        |
| Sonarr      | 8989  | http://192.168.2.27:8989        |
| Radarr      | 7878  | http://192.168.2.27:7878        |
| Lidarr      | 8686  | http://192.168.2.27:8686        |
| Prowlarr    | 9696  | http://192.168.2.27:9696        |
| qBittorrent | 8080  | http://192.168.2.27:8080        |
