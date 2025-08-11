# Production Dockerfile for PHP-FPM
FROM php:8.3-fpm-alpine AS base

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
        sockets

# Install Redis extension
RUN pecl install redis && \
    docker-php-ext-enable redis

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create application user
RUN addgroup -g 1000 -S informes && \
    adduser -u 1000 -S informes -G informes

# Production build stage
FROM base AS production

# Copy PHP configuration
COPY docker/app/php.ini /usr/local/etc/php/conf.d/app.ini

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY --chown=informes:informes . .

# Install dependencies (production only)
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader && \
    composer clear-cache

# Optimize Laravel
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan event:cache

# Set correct permissions
RUN chown -R informes:informes /var/www/html && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/www/html/storage && \
    chmod -R 775 /var/www/html/bootstrap/cache

# Copy entrypoint
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER informes

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

# Development build stage
FROM base AS development

# Copy PHP development configuration
COPY docker/app/php-dev.ini /usr/local/etc/php/conf.d/app.ini

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

# Keep container running in dev
CMD ["php-fpm"]