FROM php:8.3-cli-alpine

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

# Create application user (dgsuc_user) with www-data group
RUN addgroup -g 1000 -S dgsuc_user && \
    adduser -u 1000 -S dgsuc_user -G www-data

# Copy supervisor configuration
COPY docker/workers/worker.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/workers/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Create log directory
RUN mkdir -p /var/log/supervisor && \
    chown -R dgsuc_user:www-data /var/log/supervisor

USER dgsuc_user

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]