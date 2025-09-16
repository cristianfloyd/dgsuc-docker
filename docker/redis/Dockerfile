FROM redis:7-alpine

# Instalar herramientas adicionales para troubleshooting
RUN apk add --no-cache \
    curl \
    nano \
    htop \
    procps

# Copiar configuraciones personalizadas
COPY redis-prod.conf /usr/local/etc/redis/redis.conf

# Crear directorios para logs
RUN mkdir -p /var/log/redis && \
    chown redis:redis /var/log/redis && \
    chmod 755 /var/log/redis

# Crear directorio para ACL
RUN mkdir -p /etc/redis && \
    chown redis:redis /etc/redis

# Crear archivo ACL básico
RUN echo "user default on nopass ~* &* -@dangerous +@all" > /etc/redis/users.acl && \
    chown redis:redis /etc/redis/users.acl && \
    chmod 640 /etc/redis/users.acl

# Configurar logging para Portainer
RUN sed -i 's|logfile /var/log/redis/redis-server.log|logfile ""# Logging to stdout for Portainer|g' /usr/local/etc/redis/redis.conf && \
    sed -i 's|syslog-enabled yes|syslog-enabled no|g' /usr/local/etc/redis/redis.conf

# Exponer puerto estándar
EXPOSE 6379

# Usar configuración personalizada
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]