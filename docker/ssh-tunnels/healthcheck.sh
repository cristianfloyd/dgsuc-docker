#!/bin/bash

echo "=== SSH Tunnels Health Check ==="

# Check if autossh processes are running
AUTOSSH_COUNT=$(ps aux | grep autossh | grep -v grep | wc -l)
echo "Active autossh processes: $AUTOSSH_COUNT"

if [[ $AUTOSSH_COUNT -eq 0 ]]; then
    echo "❌ No autossh processes running"
    exit 1
fi

# Check if expected ports are listening  
EXPECTED_TUNNELS=0
ACTIVE_TUNNELS=0

# Tunnel 1: DB Producción (puerto 5434) - pgsql-prod-old
if [[ -n "$SSH_HOST_DBPROD" && -n "$SSH_USER_DBPROD" ]]; then
    EXPECTED_TUNNELS=$((EXPECTED_TUNNELS + 1))
    if netstat -tln 2>/dev/null | grep ":${LOCAL_PORT_DBPROD:-5434}" >/dev/null; then
        echo "✅ DB Prod (port ${LOCAL_PORT_DBPROD:-5434}) - pgsql-prod-old - OK"
        ACTIVE_TUNNELS=$((ACTIVE_TUNNELS + 1))
    else
        echo "❌ DB Prod (port ${LOCAL_PORT_DBPROD:-5434}) - pgsql-prod-old - NOT LISTENING"
    fi
fi

# Tunnel 2: DB Producción R2 (puerto 5436) - pgsql-prod
if [[ -n "$SSH_HOST_DBPRODR2" && -n "$SSH_USER_DBPRODR2" ]]; then
    EXPECTED_TUNNELS=$((EXPECTED_TUNNELS + 1))
    if netstat -tln 2>/dev/null | grep ":${LOCAL_PORT_DBPRODR2:-5436}" >/dev/null; then
        echo "✅ DB Prod R2 (port ${LOCAL_PORT_DBPRODR2:-5436}) - pgsql-prod - OK"
        ACTIVE_TUNNELS=$((ACTIVE_TUNNELS + 1))
    else
        echo "❌ DB Prod R2 (port ${LOCAL_PORT_DBPRODR2:-5436}) - pgsql-prod - NOT LISTENING"
    fi
fi

# Tunnel 3: DB Test (puerto 5433) - pgsql-2503 a pgsql-2506
if [[ -n "$SSH_HOST_DBTEST" && -n "$SSH_USER_DBTEST" ]]; then
    EXPECTED_TUNNELS=$((EXPECTED_TUNNELS + 1))
    if netstat -tln 2>/dev/null | grep ":${LOCAL_PORT_DBTEST:-5433}" >/dev/null; then
        echo "✅ DB Test (port ${LOCAL_PORT_DBTEST:-5433}) - pgsql-2503 a 2506 - OK"
        ACTIVE_TUNNELS=$((ACTIVE_TUNNELS + 1))
    else
        echo "❌ DB Test (port ${LOCAL_PORT_DBTEST:-5433}) - pgsql-2503 a 2506 - NOT LISTENING"
    fi
fi

# Tunnel 4: DB Test R2 (puerto 5435) - pgsql-2507 a pgsql-2512
if [[ -n "$SSH_HOST_DBTESTR2" && -n "$SSH_USER_DBTESTR2" ]]; then
    EXPECTED_TUNNELS=$((EXPECTED_TUNNELS + 1))
    if netstat -tln 2>/dev/null | grep ":${LOCAL_PORT_DBTESTR2:-5435}" >/dev/null; then
        echo "✅ DB Test R2 (port ${LOCAL_PORT_DBTESTR2:-5435}) - pgsql-2507 a 2512 - OK"
        ACTIVE_TUNNELS=$((ACTIVE_TUNNELS + 1))
    else
        echo "❌ DB Test R2 (port ${LOCAL_PORT_DBTESTR2:-5435}) - pgsql-2507 a 2512 - NOT LISTENING"
    fi
fi

echo "Expected tunnels: $EXPECTED_TUNNELS, Active tunnels: $ACTIVE_TUNNELS"

if [[ $EXPECTED_TUNNELS -eq 0 ]]; then
    echo "⚠️  No tunnels configured - marking as healthy"
    exit 0
fi

if [[ $ACTIVE_TUNNELS -eq $EXPECTED_TUNNELS ]]; then
    echo "✅ All tunnels healthy"
    exit 0
else
    echo "❌ Some tunnels are down ($ACTIVE_TUNNELS/$EXPECTED_TUNNELS active)"
    exit 1
fi