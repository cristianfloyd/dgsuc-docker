#!/bin/bash
set -e

# Configuration
SSH_HOST=${SSH_HOST:-localhost}
SSH_PORT=${SSH_PORT:-22}
SSH_USER=${SSH_USER:-root}
SSH_KEY=${SSH_KEY:-/root/.ssh/id_rsa}

# Parse tunnel configuration
# Format: LOCAL_PORT:REMOTE_HOST:REMOTE_PORT,LOCAL_PORT2:REMOTE_HOST2:REMOTE_PORT2
IFS=',' read -ra TUNNELS <<< "$LOCAL_FORWARD_PORTS"

echo "Starting SSH Tunnel Manager..."
echo "Connecting to: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"

# Create tunnel command
TUNNEL_CMD="autossh -M 0 -N -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"
TUNNEL_CMD="${TUNNEL_CMD} -p ${SSH_PORT} -i ${SSH_KEY} ${SSH_USER}@${SSH_HOST}"

# Add each tunnel
for tunnel in "${TUNNELS[@]}"; do
    echo "Adding tunnel: $tunnel"
    TUNNEL_CMD="${TUNNEL_CMD} -L $tunnel"
done

# Function to handle Mapuche connections
setup_mapuche_tunnels() {
    # Production Mapuche
    if [ ! -z "$MAPUCHE_PROD_HOST" ]; then
        TUNNEL_CMD="${TUNNEL_CMD} -L 5433:${MAPUCHE_PROD_HOST}:5432"
        echo "Added Mapuche Production tunnel on port 5433"
    fi
    
    # Monthly backups - dynamic configuration
    if [ ! -z "$MAPUCHE_BACKUP_PATTERN" ]; then
        local port=5434
        for month in $(seq 1 12); do
            backup_var="MAPUCHE_BACKUP_${month}_HOST"
            if [ ! -z "${!backup_var}" ]; then
                TUNNEL_CMD="${TUNNEL_CMD} -L ${port}:${!backup_var}:5432"
                echo "Added Mapuche Backup Month ${month} tunnel on port ${port}"
                ((port++))
            fi
        done
    fi
}

# Setup Mapuche-specific tunnels
setup_mapuche_tunnels

# Health check file
HEALTH_FILE="/tmp/tunnel_health"

# Function to check tunnel health
check_tunnel() {
    for tunnel in "${TUNNELS[@]}"; do
        local_port=$(echo $tunnel | cut -d':' -f1)
        if ! nc -z localhost $local_port 2>/dev/null; then
            echo "Tunnel on port $local_port is down"
            return 1
        fi
    done
    echo "healthy" > $HEALTH_FILE
    return 0
}

# Monitor tunnels in background
monitor_tunnels() {
    while true; do
        sleep 30
        if check_tunnel; then
            echo "All tunnels are healthy"
        else
            echo "Some tunnels are down, restarting..."
            pkill -f autossh
            exec "$0"
        fi
    done
}

# Start monitoring in background
monitor_tunnels &

# Execute tunnel command
echo "Executing: ${TUNNEL_CMD}"
exec ${TUNNEL_CMD}