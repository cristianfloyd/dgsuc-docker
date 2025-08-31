FROM alpine:3.18

# Install openssh-client and autossh
RUN apk add --no-cache \
    openssh-client \
    autossh \
    bash \
    curl

# Create directory for SSH keys
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Copy the tunnel startup script
COPY docker/ssh-tunnels/tunnel-manager.sh /usr/local/bin/tunnel-manager.sh
RUN chmod +x /usr/local/bin/tunnel-manager.sh

# Health check script
COPY docker/ssh-tunnels/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# SSH client configuration
RUN echo "Host *" >> /etc/ssh/ssh_config && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
    echo "    ServerAliveInterval 30" >> /etc/ssh/ssh_config && \
    echo "    ServerAliveCountMax 3" >> /etc/ssh/ssh_config

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/tunnel-manager.sh"]