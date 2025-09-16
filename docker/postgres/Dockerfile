FROM postgres:17-alpine

# Instalar herramientas adicionales para troubleshooting
RUN apk add --no-cache \
    curl \
    nano \
    htop \
    procps

# Copiar configuraciones personalizadas
COPY postgresql-prod.conf /etc/postgresql/postgresql.conf
COPY init-db.sh /docker-entrypoint-initdb.d/init-db.sh

# Hacer el script de inicialización ejecutable
RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

# Crear directorios para logs
RUN mkdir -p /var/log/postgresql && \
    chown postgres:postgres /var/log/postgresql && \
    chmod 755 /var/log/postgresql

# Configurar PostgreSQL para usar nuestras configuraciones
# y habilitar logging a stdout para Portainer
RUN echo "# PostgreSQL Portainer Logging Configuration" >> /etc/postgresql/postgresql.conf && \
    echo "log_destination = 'stderr'" >> /etc/postgresql/postgresql.conf && \
    echo "logging_collector = off" >> /etc/postgresql/postgresql.conf && \
    echo "log_min_messages = info" >> /etc/postgresql/postgresql.conf && \
    echo "log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '" >> /etc/postgresql/postgresql.conf

# Exponer puerto estándar
EXPOSE 5432

# Variables de entorno por defecto
ENV POSTGRES_DB=dgsuc_app
ENV POSTGRES_USER=dgsuc_user
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Usar configuración personalizada
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]