FROM alpine:3.18

RUN apk add --no-cache \
    openssh-client \
    autossh \
    bash \
    curl

# Create SSH directory
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

# SSH config
RUN echo "Host *" >> /etc/ssh/ssh_config && \
    echo "  StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "  UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
    echo "  ServerAliveInterval 60" >> /etc/ssh/ssh_config && \
    echo "  ServerAliveCountMax 3" >> /etc/ssh/ssh_config && \
    echo "  ExitOnForwardFailure yes" >> /etc/ssh/ssh_config

ENTRYPOINT ["/entrypoint.sh"]