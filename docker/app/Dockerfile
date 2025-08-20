# Production Dockerfile for PHP-FPM
FROM php:8.4-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    postgresql-dev \
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
    supervisor \
    git \
    unzip \
    bash

# Install PHP extensions
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

# Install Redis extension
RUN pecl install redis && \
    docker-php-ext-enable redis

# Note: openssl, ctype, json, and mbstring are built-in since PHP 8.0+

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create or modify www-data user to UID 1000
RUN deluser www-data 2>/dev/null || true && \
    addgroup -g 1000 www-data && \
    adduser -u 1000 -D -s /bin/bash -G www-data www-data

# Production build stage
FROM base AS production

# Install Node.js and npm for asset building
RUN apk add --no-cache nodejs npm

# Copy PHP configuration
COPY ./docker/app/php.ini /usr/local/etc/php/conf.d/app.ini

# Set working directory
WORKDIR /var/www/html

# Copy application files with correct ownership
COPY --chown=1000:1000 ./app/ .

# Install PHP dependencies (production only)
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader && \
    composer clear-cache

# Install Node.js dependencies and build assets
RUN npm ci && \
    npm run build && \
    npm cache clean --force && \
    rm -rf node_modules

# Optimize Laravel
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan event:cache

# Set correct permissions for UID 1000
RUN chown -R 1000:1000 /var/www/html && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/www/html/storage && \
    chmod -R 775 /var/www/html/bootstrap/cache

# Copy entrypoint
COPY ./docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

# Development build stage
FROM base AS development

# Copy PHP development configuration
COPY ./docker/app/php-dev.ini /usr/local/etc/php/conf.d/app.ini

# Install development tools
RUN apk add --no-cache \
    nodejs \
    npm \
    vim \
    htop

# Install Xdebug
RUN pecl install xdebug && \
    docker-php-ext-enable xdebug

WORKDIR /var/www/html

# Fix storage permissions for Laravel (development)
RUN mkdir -p storage/logs storage/framework/{cache,sessions,views} bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache && \
    chown -R 1000:1000 storage bootstrap/cache

# Add permission fix script for development
COPY ./docker/app/fix-permissions.sh /usr/local/bin/fix-permissions.sh
# RUN chmod +x /usr/local/bin/fix-permissions.sh

# Keep container running in dev
CMD ["php-fpm"]