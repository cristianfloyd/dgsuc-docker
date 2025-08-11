#!/bin/bash

# Check if health file exists and is recent
HEALTH_FILE="/tmp/tunnel_health"

if [ -f "$HEALTH_FILE" ]; then
    # Check if file was modified in the last 60 seconds
    if [ $(find "$HEALTH_FILE" -mmin -1 | wc -l) -gt 0 ]; then
        exit 0
    fi
fi

# If no recent health file, check tunnels directly
if pgrep -f autossh > /dev/null; then
    # Check if at least one tunnel port is listening
    if netstat -tln | grep -q ":543[3-9]"; then
        echo "healthy" > $HEALTH_FILE
        exit 0
    fi
fi

exit 1