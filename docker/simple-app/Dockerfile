# Dockerfile simplificado solo con Laravel y Nginx (sin PostgreSQL)
FROM php:8.4-fpm-alpine AS base

# Instalar dependencias del sistema
RUN apk add --no-cache \
    postgresql-dev \
    nginx \
    supervisor \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    curl-dev \
    linux-headers \
    $PHPIZE_DEPS \
    git \
    unzip \
    bash \
    curl

# Configurar extensiones PHP
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_pgsql \
        pgsql \
        zip \
        gd \
        intl \
        mbstring \
        xml \
        curl \
        bcmath \
        opcache \
        pcntl \
        sockets \
        exif

# Instalar Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Crear usuarios
RUN deluser www-data 2>/dev/null || true && \
    addgroup -g 1000 www-data && \
    adduser -u 1000 -D -s /bin/bash -G www-data www-data

# Configurar Nginx
RUN mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/sites-enabled

# Copiar configuraciones
COPY ./docker/simple-app/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/simple-app/default.conf /etc/nginx/sites-enabled/default
COPY ./docker/simple-app/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./docker/simple-app/php.ini /usr/local/etc/php/conf.d/app.ini
COPY ./docker/simple-app/entrypoint.sh /usr/local/bin/entrypoint.sh

# Hacer ejecutable el entrypoint
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configurar directorio de trabajo
WORKDIR /var/www/html

# Copiar aplicación Laravel
COPY --chown=1000:1000 ./app/ .

# Instalar dependencias de PHP
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader && \
    composer clear-cache

# Configurar permisos
RUN chown -R 1000:1000 /var/www/html && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/www/html/storage && \
    chmod -R 775 /var/www/html/bootstrap/cache

# Exponer solo puerto 80 (Nginx)
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]