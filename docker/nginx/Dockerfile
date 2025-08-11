FROM nginx:alpine

# Install required packages
RUN apk add --no-cache \
    openssl \
    curl \
    bash

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites/ /etc/nginx/sites-available/

# Create symbolic link for enabled sites
RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# Create directories
RUN mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/certs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]