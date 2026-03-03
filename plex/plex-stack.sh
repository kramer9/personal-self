#!/usr/bin/env bash
# =============================================================================
# plex-stack.sh — Management wrapper for the Plex media server stack
# Host: Thelio @ 192.168.2.27 | Pop!_OS 22.04
# Compose: /home/argus/Repos/personal-self/plex/docker-compose.yml
# =============================================================================

set -euo pipefail

COMPOSE_DIR="/home/argus/Repos/personal-self/plex"
COMPOSE_CMD="docker-compose"

cd "$COMPOSE_DIR"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [service]

Commands:
  start              Bring up the full stack (docker-compose up -d)
  stop               Stop and remove all stack containers
  restart [service]  Restart the full stack, or a single service
  status             Show container health + NFS mount status
  logs [service]     Tail logs for all services, or a single service
  update             Pull latest images and recreate containers
  vpn-check          Verify qBittorrent exits through VPN (not ISP IP)
  kill-switch-test   Test the VPN kill switch

Services: nordvpn, qbittorrent, plex, sonarr, radarr, lidarr,
          prowlarr, flaresolverr, overseerr
EOF
}

check_wireguard() {
    if ! lsmod | grep -q "^wireguard"; then
        echo "WARNING: wireguard kernel module not loaded — loading now..."
        sudo modprobe wireguard
    fi
}

check_nfs() {
    local ok=true
    for mount in /mnt/nas/vol1 /mnt/nas/vol2 /mnt/usbdrive; do
        if mountpoint -q "$mount"; then
            printf "  %-20s MOUNTED\n" "$mount"
        else
            printf "  %-20s NOT MOUNTED ⚠\n" "$mount"
            ok=false
        fi
    done
    $ok || echo "  WARNING: Some NFS/storage mounts are missing — plex libraries may be incomplete."
}

cmd="${1:-help}"
service="${2:-}"

case "$cmd" in
    start)
        check_wireguard
        echo "Starting plex stack..."
        $COMPOSE_CMD up -d
        ;;

    stop)
        echo "Stopping plex stack..."
        $COMPOSE_CMD down
        ;;

    restart)
        if [[ -n "$service" ]]; then
            echo "Restarting $service..."
            $COMPOSE_CMD restart "$service"
        else
            check_wireguard
            echo "Restarting full stack..."
            $COMPOSE_CMD down
            $COMPOSE_CMD up -d
        fi
        ;;

    status)
        echo "=== Container Status ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
            | grep -E "NAME|plex|sonarr|radarr|lidarr|qbit|overseerr|nord|prowlarr|flare" || true
        echo ""
        echo "=== Stopped Stack Containers ==="
        docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}" \
            | grep -E "plex|sonarr|radarr|lidarr|qbit|overseerr|nord|prowlarr|flare" || echo "  None"
        echo ""
        echo "=== Storage Mounts ==="
        check_nfs
        ;;

    logs)
        if [[ -n "$service" ]]; then
            $COMPOSE_CMD logs -f --tail=100 "$service"
        else
            $COMPOSE_CMD logs -f --tail=50
        fi
        ;;

    update)
        echo "Pulling latest images..."
        $COMPOSE_CMD pull
        echo "Recreating containers with new images..."
        check_wireguard
        $COMPOSE_CMD up -d --remove-orphans
        echo "Pruning old images..."
        docker image prune -f
        ;;

    vpn-check)
        host_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unknown")
        vpn_ip=$(docker exec nordvpn curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "FAILED")
        qbit_ip=$(docker exec qbittorrent curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "FAILED")
        echo "Host IP (ISP):      $host_ip"
        echo "NordVPN exit IP:    $vpn_ip"
        echo "qBittorrent exit:   $qbit_ip"
        if [[ "$vpn_ip" == "$host_ip" ]]; then
            echo "WARNING: VPN IP matches host IP — VPN may not be active!"
        elif [[ "$qbit_ip" != "$vpn_ip" ]]; then
            echo "WARNING: qBittorrent IP differs from VPN — kill switch may be broken!"
        else
            echo "OK: qBittorrent is routing through VPN."
        fi
        ;;

    kill-switch-test)
        echo "Testing kill switch — bringing down WireGuard interface..."
        docker exec nordvpn ip link set nordlynx down 2>/dev/null \
            || docker exec nordvpn wg-quick down wg0 2>/dev/null \
            || echo "Could not bring down interface (check nordvpn logs)"
        echo "Testing qBittorrent connectivity (should FAIL)..."
        if docker exec qbittorrent curl --max-time 5 -s https://example.com > /dev/null 2>&1; then
            echo "FAIL: qBittorrent reached internet without VPN — kill switch broken!"
        else
            echo "OK: qBittorrent was blocked when VPN dropped."
        fi
        echo "Restoring VPN interface..."
        docker exec nordvpn ip link set nordlynx up 2>/dev/null \
            || docker exec nordvpn wg-quick up wg0 2>/dev/null \
            || echo "Could not restore — run: docker-compose restart nordvpn"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "Unknown command: $cmd"
        usage
        exit 1
        ;;
esac
