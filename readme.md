# 🐳 DGSUC Docker Infrastructure

Infraestructura Docker containerizada para el Sistema de Informes y Controles de la Universidad de Buenos Aires.

> **Nota**: Este repositorio contiene únicamente la infraestructura Docker. El código de la aplicación se clona desde un repositorio separado.

## 🏗️ Arquitectura

```
dgsuc-docker/                 # Este repositorio
├── docker/                   # Configuraciones Docker
│   ├── app/                 # PHP-FPM
│   ├── nginx/               # Servidor web
│   ├── workers/             # Queue workers
│   ├── ssh-tunnel/          # Gestión de túneles SSH
│   ├── postgres/            # Base de datos
│   ├── redis/               # Cache
│   └── monitoring/          # Prometheus + Grafana
├── scripts/                  # Scripts de gestión
├── app/                      # ← Aplicación Laravel (clonada aquí)
└── docker-compose.yml        # Orquestación
```

## 🚀 Quick Start

### 1️⃣ Clonar este repositorio

```bash
git clone https://github.com/uba/dgsuc-docker.git
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
git clone https://github.com/uba/dgsuc-docker.git
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
DB_PASSWORD=contraseña_segura

# Conexiones externas (Mapuche)
DB2_HOST=127.0.0.1
DB2_PORT=5433
DB2_DATABASE=mapuche_prod
DB2_USERNAME=readonly_user
DB2_PASSWORD=readonly_pass

# SSH Tunnels
MAPUCHE_SSH_HOST=servidor.uba.ar
MAPUCHE_SSH_USER=usuario_ssh
SSH_TUNNEL_PORTS=5433:localhost:5432

# Azure AD (SSO)
MICROSOFT_CLIENT_ID=xxx
MICROSOFT_CLIENT_SECRET=xxx
```

### Paso 3: Configurar túneles SSH

```bash
# Copiar SSH key
cp ~/.ssh/id_rsa_tunnel ~/.ssh/
chmod 600 ~/.ssh/id_rsa_tunnel

# Configurar en .env
MAPUCHE_SSH_HOST=mapuche.uba.ar
MAPUCHE_SSH_USER=tunnel_user
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
| **ssh-tunnel** | - | Gestión de túneles SSH |
| **prometheus** | 9090 | Métricas (producción) |
| **grafana** | 3000 | Dashboards (producción) |

### Servicios de Desarrollo

| Servicio | Puerto | URL |
|----------|--------|-----|
| **mailhog** | 8025 | http://localhost:8025 |
| **phpmyadmin** | 8090 | http://localhost:8090 |
| **xdebug** | 9003 | - |

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

### Túneles SSH

```bash
make tunnel-status    # Ver estado de túneles
make tunnel-restart   # Reiniciar túneles
make tunnel-logs      # Ver logs de túneles
```

### SSL/TLS

```bash
make ssl-generate     # Generar con Let's Encrypt
make ssl-renew        # Renovar certificados
```

## 🔄 Workflow de Desarrollo

### 1. Primera vez

```bash
# Clonar infraestructura
git clone https://github.com/uba/dgsuc-docker.git
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

# Configurar SSH tunnels
cp /path/to/ssh/key ~/.ssh/tunnel_key
chmod 600 ~/.ssh/tunnel_key
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

## 🔌 Configuración de Túneles SSH

Los túneles SSH permiten conectar a bases de datos externas (Mapuche):

### Configuración básica

```env
# .env.prod
MAPUCHE_SSH_HOST=servidor.uba.ar
MAPUCHE_SSH_USER=usuario
MAPUCHE_SSH_PORT=22
SSH_TUNNEL_PORTS=5433:localhost:5432,5434:backup1:5432
```

### Múltiples conexiones

```env
# Producción Mapuche
DB2_HOST=127.0.0.1
DB2_PORT=5433

# Backup Enero
DB3_HOST=127.0.0.1
DB3_PORT=5434

# Backup Febrero
DB4_HOST=127.0.0.1
DB4_PORT=5435
```

### Monitoreo de túneles

```bash
# Ver estado
make tunnel-status

# Ver logs
docker-compose logs ssh-tunnel

# Reiniciar si hay problemas
make tunnel-restart
```

## 🐛 Troubleshooting

### Problema: "Application not found"

```bash
# Clonar aplicación
make clone

# O manualmente
./scripts/clone-app.sh https://github.com/uba/dgsuc-sistema.git
```

### Problema: "Connection refused" a DB externa

```bash
# Verificar túnel SSH
make tunnel-status

# Reiniciar túnel
make tunnel-restart

# Verificar conectividad
docker-compose exec ssh-tunnel nc -zv localhost 5433
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
- Estado de túneles SSH

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
│   ├── ssh-tunnel/           # SSH tunnels
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── healthcheck.sh
│   ├── postgres/             # PostgreSQL
│   │   ├── init.sql
│   │   └── postgresql.conf
│   └── redis/                # Redis
│       └── redis.conf
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
| `DB2_*` | Conexión Mapuche | Ver .env.example |
| `REDIS_PASSWORD` | Contraseña Redis | RedisPass456! |
| `MICROSOFT_CLIENT_ID` | Azure AD Client ID | xxx-xxx-xxx |
| `SSH_TUNNEL_PORTS` | Puertos túneles SSH | 5433:host:5432 |
| `WORKER_MEMORY` | Memoria para workers | 4096 |
| `SICOSS_MEMORY_LIMIT` | Límite memoria SICOSS | 8192 |

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

- **Email**: soporte-dgsuc@uba.ar
- **Issues**: https://github.com/uba/dgsuc-docker/issues
- **Wiki**: https://github.com/uba/dgsuc-docker/wiki

## 📄 Licencia

Propiedad de la Universidad de Buenos Aires - Todos los derechos reservados.

---

**Versión**: 1.0.0  
**Última actualización**: Agosto 2025  
**Mantenido por**: Equipo DGSUC - UBA