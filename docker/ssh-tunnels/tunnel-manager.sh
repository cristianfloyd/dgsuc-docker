#!/bin/bash
set -e

echo "=== SSH Tunnels Manager ==="
echo "Authentication: SSH Public Key (Docker Secrets)"
echo "Starting multiple SSH tunnels..."

# Setup SSH directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Copy SSH keys from Docker Secrets to SSH directory
# READ-ONLY keys (for dgsuc_app_ro user)
if [[ -f "/run/secrets/ssh_private_key_ro" ]]; then
    echo "✅ Docker Secret found: ssh_private_key_ro"
    cp /run/secrets/ssh_private_key_ro /root/.ssh/id_rsa_ro
    chmod 600 /root/.ssh/id_rsa_ro
    echo "✅ SSH private key RO copied to /root/.ssh/id_rsa_ro"
else
    echo "❌ Docker Secret NOT found: ssh_private_key_ro"
    echo "   Create secret in Portainer: https://portainer.uba.ar/#!/1/docker/secrets"
    exit 1
fi

if [[ -f "/run/secrets/ssh_public_key_ro" ]]; then
    echo "✅ Docker Secret found: ssh_public_key_ro"
    cp /run/secrets/ssh_public_key_ro /root/.ssh/id_rsa_ro.pub
    chmod 644 /root/.ssh/id_rsa_ro.pub
    echo "✅ SSH public key RO copied to /root/.ssh/id_rsa_ro.pub"
else
    echo "⚠️  Docker Secret not found: ssh_public_key_ro (optional)"
fi

# READ-WRITE keys (for dgsuc_app_rw user)
if [[ -f "/run/secrets/ssh_private_key_rw" ]]; then
    echo "✅ Docker Secret found: ssh_private_key_rw"
    cp /run/secrets/ssh_private_key_rw /root/.ssh/id_rsa_rw
    chmod 600 /root/.ssh/id_rsa_rw
    echo "✅ SSH private key RW copied to /root/.ssh/id_rsa_rw"
else
    echo "❌ Docker Secret NOT found: ssh_private_key_rw"
    echo "   Create secret in Portainer: https://portainer.uba.ar/#!/1/docker/secrets"
    exit 1
fi

if [[ -f "/run/secrets/ssh_public_key_rw" ]]; then
    echo "✅ Docker Secret found: ssh_public_key_rw"
    cp /run/secrets/ssh_public_key_rw /root/.ssh/id_rsa_rw.pub
    chmod 644 /root/.ssh/id_rsa_rw.pub
    echo "✅ SSH public key RW copied to /root/.ssh/id_rsa_rw.pub"
else
    echo "⚠️  Docker Secret not found: ssh_public_key_rw (optional)"
fi

# Function to start a tunnel
start_tunnel() {
    local ssh_host=$1
    local ssh_user=$2  
    local ssh_port=$3
    local local_port=$4
    local remote_port=$5
    local tunnel_name=$6
    local ssh_key_type=$7  # 'ro' or 'rw'
    
    if [[ -z "$ssh_host" || -z "$ssh_user" ]]; then
        echo "❌ $tunnel_name: Missing SSH_HOST or SSH_USER - skipping"
        return 0
    fi
    
    # Determine which SSH key to use
    local identity_file="/root/.ssh/id_rsa_${ssh_key_type}"
    if [[ ! -f "$identity_file" ]]; then
        echo "❌ $tunnel_name: SSH key not found: $identity_file"
        return 1
    fi
    
    echo "🔧 Starting $tunnel_name tunnel..."
    echo "   $ssh_user@$ssh_host:$ssh_port -> localhost:$local_port -> remote:$remote_port"
    echo "   Using SSH key: $identity_file"
    
    # Start autossh in background with specific key
    autossh -f -N \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o PasswordAuthentication=no \
        -o PubkeyAuthentication=yes \
        -o IdentityFile="$identity_file" \
        -p $ssh_port \
        -L $local_port:localhost:$remote_port \
        $ssh_user@$ssh_host
        
    if [[ $? -eq 0 ]]; then
        echo "✅ $tunnel_name tunnel started successfully"
    else
        echo "❌ $tunnel_name tunnel failed to start"
    fi
}

# Start Tunnel 1: DB Producción (puerto 5434) - pgsql-prod-old
if [[ -n "$SSH_HOST_DBPROD" && -n "$SSH_USER_DBPROD" ]]; then
    start_tunnel "$SSH_HOST_DBPROD" "$SSH_USER_DBPROD" "$SSH_PORT_DBPROD" "$LOCAL_PORT_DBPROD" "$REMOTE_PORT_DBPROD" "DB PROD (5434→pgsql-prod-old)" "$SSH_KEY_DBPROD"
else
    echo "⚠️  DB Prod tunnel disabled - missing SSH_HOST_DBPROD or SSH_USER_DBPROD"
fi

# Start Tunnel 2: DB Producción R2 (puerto 5436) - pgsql-prod
if [[ -n "$SSH_HOST_DBPRODR2" && -n "$SSH_USER_DBPRODR2" ]]; then
    start_tunnel "$SSH_HOST_DBPRODR2" "$SSH_USER_DBPRODR2" "$SSH_PORT_DBPRODR2" "$LOCAL_PORT_DBPRODR2" "$REMOTE_PORT_DBPRODR2" "DB PROD R2 (5436→pgsql-prod)" "$SSH_KEY_DBPRODR2"
else
    echo "⚠️  DB Prod R2 tunnel disabled - missing SSH_HOST_DBPRODR2 or SSH_USER_DBPRODR2"
fi

# Start Tunnel 3: DB Test (puerto 5433) - pgsql-2503 a pgsql-2506
if [[ -n "$SSH_HOST_DBTEST" && -n "$SSH_USER_DBTEST" ]]; then
    start_tunnel "$SSH_HOST_DBTEST" "$SSH_USER_DBTEST" "$SSH_PORT_DBTEST" "$LOCAL_PORT_DBTEST" "$REMOTE_PORT_DBTEST" "DB TEST (5433→pgsql-2503-2506)" "$SSH_KEY_DBTEST"
else
    echo "⚠️  DB Test tunnel disabled - missing SSH_HOST_DBTEST or SSH_USER_DBTEST"
fi

# Start Tunnel 4: DB Test R2 (puerto 5435) - pgsql-2507 a pgsql-2512
if [[ -n "$SSH_HOST_DBTESTR2" && -n "$SSH_USER_DBTESTR2" ]]; then
    start_tunnel "$SSH_HOST_DBTESTR2" "$SSH_USER_DBTESTR2" "$SSH_PORT_DBTESTR2" "$LOCAL_PORT_DBTESTR2" "$REMOTE_PORT_DBTESTR2" "DB TEST R2 (5435→pgsql-2507-2512)" "$SSH_KEY_DBTESTR2"
else
    echo "⚠️  DB Test R2 tunnel disabled - missing SSH_HOST_DBTESTR2 or SSH_USER_DBTESTR2"
fi

echo "=== Tunnels Status ==="
ps aux | grep autossh | grep -v grep || echo "No active tunnels found"

echo "=== Listening Ports ==="
netstat -tlpn 2>/dev/null | grep -E ":(5433|5434|5435|5436)" || echo "No tunnels listening"

# Keep container running and monitor tunnels
echo "🔄 Monitoring tunnels... (Press Ctrl+C to stop)"

# Trap signals to gracefully shutdown
trap 'echo "🛑 Shutting down tunnels..."; killall autossh; exit 0' SIGTERM SIGINT

# Keep the script running
while true; do
    sleep 60
    
    # Check if tunnels are still alive
    if ! ps aux | grep -v grep | grep autossh >/dev/null 2>&1; then
        echo "❌ All tunnels died - exiting"
        exit 1
    fi
done