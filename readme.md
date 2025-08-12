# 🐳 DGSUC Docker Infrastructure

Infraestructura Docker containerizada para el Sistema de Informes y Controles DGSUC.

> **Nota**: Este repositorio contiene únicamente la infraestructura Docker. El código de la aplicación se clona desde un repositorio separado.

## 🏗️ Arquitectura

```
dgsuc-docker/                 # Este repositorio
├── docker/                   # Configuraciones Docker
│   ├── app/                 # PHP-FPM
│   ├── nginx/               # Servidor web
│   ├── workers/             # Queue workers
│   ├── postgres/            # Base de datos
│   ├── redis/               # Cache y sesiones
│   └── monitoring/          # Prometheus + Grafana
├── scripts/                  # Scripts de gestión
├── app/                      # ← Aplicación Laravel (clonada aquí)
└── docker-compose.yml        # Orquestación
```

## 🚀 Quick Start

### 1️⃣ Clonar este repositorio

```bash
git clone https://github.com/cristianfloyd/dgsuc-docker.git
cd dgsuc-docker
```

### 2️⃣ Inicialización automática

```bash
make init
```

Este comando realizará:
- ✅ Verificación de prerequisitos
- ✅ Clonado de la aplicación Laravel
- ✅ Configuración de variables de entorno
- ✅ Build de imágenes Docker
- ✅ Inicialización de base de datos

### 3️⃣ Iniciar servicios

```bash
# Desarrollo
make dev

# Producción
make prod
```

## 📋 Requisitos Previos

### Software
- Docker >= 20.10
- Docker Compose >= 2.0
- Git >= 2.30
- Make (opcional pero recomendado)

### Hardware Mínimo
- CPU: 4 cores
- RAM: 8 GB
- Disco: 100 GB SSD

## 🔧 Instalación Manual Detallada

### Paso 1: Preparar el entorno

```bash
# Clonar infraestructura
git clone https://github.com/cristianfloyd/dgsuc-docker.git
cd dgsuc-docker

# Clonar aplicación
./scripts/clone-app.sh [URL_REPOSITORIO] [BRANCH]
# O usar valores por defecto:
./scripts/clone-app.sh
```

### Paso 2: Configurar variables de entorno

```bash
# Copiar plantillas
cp .env.example .env.dev
cp .env.example .env.prod

# Editar según necesidad
nano .env.prod
```

Variables críticas a configurar:

```env
# Base de datos principal
DB_DATABASE=informes_app
DB_USERNAME=informes_user
DB_PASSWORD=contraseña_segura

# Redis Cache
REDIS_PASSWORD=redis_contraseña_segura

# Azure AD (SSO)
MICROSOFT_CLIENT_ID=xxx
MICROSOFT_CLIENT_SECRET=xxx
MICROSOFT_REDIRECT_URI=https://dgsuc.uba.ar/auth/microsoft/callback

# SSL Certificates
CERTBOT_EMAIL=admin@uba.ar
CERTBOT_DOMAIN=dgsuc.uba.ar

# Monitoring
GRAFANA_PASSWORD=grafana_admin_password
```

### Paso 3: Configurar aplicación Laravel

```bash
# Clonar y configurar aplicación
make clone

# Configurar permisos
chmod -R 775 ./app/storage
chmod -R 775 ./app/bootstrap/cache
```

### Paso 4: SSL/TLS

```bash
# Opción 1: Let's Encrypt (producción)
./scripts/ssl-setup.sh letsencrypt dgsuc.uba.ar admin@uba.ar

# Opción 2: Certificado existente
./scripts/ssl-setup.sh import /path/to/cert.pem /path/to/key.pem

# Opción 3: Auto-firmado (desarrollo)
./scripts/ssl-setup.sh self-signed
```

### Paso 5: Build y deploy

```bash
# Build de imágenes
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Iniciar servicios
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verificar estado
docker-compose ps
```

## 📦 Servicios Incluidos

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| **app** | 9000 | PHP-FPM 8.3 con Laravel |
| **nginx** | 80/443 | Servidor web con SSL |
| **postgres** | 5432 | PostgreSQL 17 |
| **redis** | 6379 | Cache y sesiones |
| **workers** | - | Queue workers (Supervisor) |
| **scheduler** | - | Laravel scheduler (cron) |
| **certbot** | - | Certificados SSL automáticos |
| **prometheus** | 9090 | Métricas (producción) |
| **grafana** | 3000 | Dashboards (producción) |

### Servicios de Desarrollo

| Servicio | Puerto | URL |
|----------|--------|-----|
| **app** | 8080 | http://localhost:8080 |
| **mailhog** | 8025 | http://localhost:8025 |
| **phpmyadmin** | 8090 | http://localhost:8090 |
| **xdebug** | 9003 | - |
| **node** | - | Compilación de assets |

## 🎮 Comandos Principales

### Gestión de Servicios

```bash
make dev              # Iniciar desarrollo
make prod             # Iniciar producción
make stop             # Detener servicios
make restart          # Reiniciar servicios
make ps               # Ver estado
make logs             # Ver logs
```

### Aplicación

```bash
make clone            # Clonar aplicación
make update           # Actualizar código
make shell            # Entrar al contenedor
make artisan cmd="..." # Ejecutar comando Artisan
make composer cmd="..." # Ejecutar Composer
make npm cmd="..."    # Ejecutar NPM
```

### Base de Datos

```bash
make db-migrate       # Ejecutar migraciones
make db-seed          # Ejecutar seeders
make db-fresh         # Fresh con seeds
make db-backup        # Crear backup
make db-restore       # Restaurar backup
```

### Cache y Optimización

```bash
make cache-clear      # Limpiar todos los caches
make cache-build      # Construir caches (producción)
```

### Queue Workers

```bash
make queue-work       # Iniciar worker manual
make queue-restart    # Reiniciar workers
make queue-failed     # Ver jobs fallidos
make queue-retry      # Reintentar jobs fallidos
```

### SSL/TLS

```bash
make ssl-generate     # Generar con Let's Encrypt
make ssl-renew        # Renovar certificados
make ssl-staging      # Generar certificados de prueba
```

## 🔄 Workflow de Desarrollo

### 1. Primera vez

```bash
# Clonar infraestructura
git clone https://github.com/cristianfloyd/dgsuc-docker.git
cd dgsuc-docker

# Inicializar
make init

# Seleccionar "Development" cuando se pregunte
# Configurar .env.dev si es necesario

# Iniciar servicios
make dev

# Aplicación disponible en http://localhost:8080
```

### 2. Desarrollo diario

```bash
# Iniciar ambiente
make dev

# Ver logs
make logs

# Ejecutar migraciones
make db-migrate

# Entrar al contenedor
make shell

# Detener al finalizar
make stop
```

### 3. Actualizar aplicación

```bash
# Pull últimos cambios
make update

# Reinstalar dependencias si es necesario
make composer cmd="install"

# Ejecutar migraciones
make db-migrate

# Reiniciar servicios
make restart
```

## 🚀 Deployment a Producción

### 1. Preparación

```bash
# Configurar variables de producción
cp .env.example .env.prod
nano .env.prod

# Configurar SSL
./scripts/ssl-setup.sh letsencrypt dgsuc.uba.ar admin@uba.ar

# Configurar variables de entorno de producción
cp .env.example .env.prod
# Editar variables sensibles como REDIS_PASSWORD, MICROSOFT_CLIENT_SECRET, etc.
```

### 2. Deploy

```bash
# Build de producción
BUILD_TARGET=production make prod-build

# Deploy
make prod

# Verificar
make health
```

### 3. Post-deployment

```bash
# Verificar servicios
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

# Verificar logs
make prod-logs

# Test de conectividad
curl -k https://localhost/health
```

## 📊 Configuración de Redis y Cache

Redis se utiliza para cache, sesiones y colas de trabajo:

### Configuración básica

```env
# .env.prod
REDIS_PASSWORD=password_segura
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

### Configuración avanzada

```env
# Configuración de memoria
REDIS_MAXMEMORY=2gb
REDIS_MAXMEMORY_POLICY=allkeys-lru

# Persistencia
REDIS_SAVE=900 1 300 10 60 10000
REDIS_APPENDONLY=yes
```

### Monitoreo de Redis

```bash
# Verificar estado de Redis
docker-compose exec redis redis-cli ping

# Ver logs
docker-compose logs redis

# Monitorear conexiones
docker-compose exec redis redis-cli monitor
```

## 🐛 Troubleshooting

### Problema: "Application not found"

```bash
# Clonar aplicación
make clone

# O manualmente
./scripts/clone-app.sh https://github.com/cristianfloyd/informes-app.git
```

### Problema: "Connection refused" a Redis

```bash
# Verificar estado de Redis
docker-compose ps redis

# Reiniciar Redis
docker-compose restart redis

# Verificar conectividad
docker-compose exec app php artisan cache:clear
```

### Problema: "Memory exhausted" en SICOSS

```bash
# Editar docker-compose.prod.yml
# Aumentar límites de memoria para workers:
deploy:
  resources:
    limits:
      memory: 8G
```

### Problema: Permisos en storage

```bash
# Desde el host
sudo chown -R 1000:1000 ./app/storage
chmod -R 775 ./app/storage

# O desde el contenedor
make shell
chown -R informes:informes storage
chmod -R 775 storage
```

## 📊 Monitoreo

### Prometheus + Grafana (Producción)

```bash
# Iniciar monitoreo
make monitor-start

# Acceder a Grafana
# http://localhost:3000
# Usuario: admin
# Password: (configurada en .env.prod)
```

### Métricas disponibles

- CPU y memoria por contenedor
- Requests por segundo (Nginx)
- Queries lentas (PostgreSQL)
- Cache hit rate (Redis)
- Queue jobs procesados
- Certificados SSL y expiración

## 🔒 Seguridad

### Checklist de Producción

- [ ] Cambiar todas las contraseñas por defecto
- [ ] Configurar SSL/TLS válido
- [ ] Limitar acceso a puertos (firewall)
- [ ] Configurar backup automático
- [ ] Habilitar logs de auditoría
- [ ] Configurar monitoreo
- [ ] Revisar permisos de archivos
- [ ] Actualizar imágenes regularmente

### Hardening

```bash
# Escanear vulnerabilidades
docker scan dgsuc_app:latest

# Limitar recursos
docker update --memory="4g" --cpus="2" dgsuc_app

# Auditoría con Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image dgsuc_app:latest
```

## 📁 Estructura de Directorios

```
dgsuc-docker/
├── docker/                    # Configuraciones Docker
│   ├── app/                  # PHP-FPM
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── php.ini
│   │   ├── php-dev.ini
│   │   └── entrypoint.sh
│   ├── nginx/                # Nginx
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── sites/
│   │   └── certs/
│   ├── workers/              # Queue workers
│   │   ├── Dockerfile
│   │   ├── supervisord.conf
│   │   └── entrypoint.sh
│   ├── postgres/             # PostgreSQL
│   │   ├── init.sql
│   │   └── postgresql.conf
│   ├── redis/                # Redis
│   │   └── redis.conf
│   └── monitoring/           # Prometheus + Grafana
│       ├── prometheus/
│       └── grafana/
├── scripts/                   # Scripts de gestión
│   ├── init.sh              # Inicialización
│   ├── clone-app.sh         # Clonar aplicación
│   ├── deploy.sh            # Deployment
│   ├── backup.sh            # Backups
│   └── ssl-setup.sh         # Configurar SSL
├── app/                      # Aplicación (ignorado en git)
├── docker-compose.yml        # Configuración base
├── docker-compose.dev.yml    # Override desarrollo
├── docker-compose.prod.yml   # Override producción
├── .env.example             # Plantilla de variables
├── .gitignore
├── Makefile                 # Comandos simplificados
└── README.md                # Este archivo
```

## 🔄 Actualización de la Infraestructura

```bash
# Pull últimos cambios de infraestructura
git pull origin main

# Rebuild imágenes
make prod-build

# Restart servicios
make prod-restart
```

## 📝 Variables de Entorno Importantes

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `APP_ENV` | Entorno de aplicación | production |
| `APP_URL` | URL de la aplicación | https://dgsuc.uba.ar |
| `DB_PASSWORD` | Contraseña PostgreSQL | SecurePass123! |
| `REDIS_PASSWORD` | Contraseña Redis | RedisPass456! |
| `MICROSOFT_CLIENT_ID` | Azure AD Client ID | xxx-xxx-xxx |
| `CERTBOT_EMAIL` | Email para certificados SSL | admin@uba.ar |
| `CERTBOT_DOMAIN` | Dominio principal | dgsuc.uba.ar |
| `WORKER_MEMORY` | Memoria para workers | 4096 |
| `GRAFANA_PASSWORD` | Contraseña Grafana | GrafanaPass789! |

## 🤝 Contribuir

1. Fork del repositorio
2. Crear rama feature (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## 📚 Documentación Adicional

- [Guía de Deployment Detallada](./docs/deployment.md)
- [Configuración Avanzada](./docs/advanced.md)
- [Troubleshooting Completo](./docs/troubleshooting.md)
- [Arquitectura del Sistema](./docs/architecture.md)

## 📞 Soporte

- **Email**: carenas@uba.ar
- **Issues**: https://github.com/cristianfloyd/dgsuc-docker/issues
- **Wiki**: https://github.com/cristianfloyd/dgsuc-docker/wiki

## 📄 Licencia

Propiedad de la Universidad de Buenos Aires - Todos los derechos reservados.

---

**Versión**: 2.0.0  
**Última actualización**: Diciembre 2024  
**Mantenido por**: Equipo DGSUC - UBA