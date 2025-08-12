# 🐳 Sistema DGSUC - Docker Deployment

Sistema de Informes y Controles de la Universidad de Buenos Aires - Containerización Production-Ready

## 📋 Resumen

Esta solución Docker proporciona un ambiente completo y escalable para el Sistema DGSUC, diseñado para manejar el procesamiento de alto volumen de datos (1.2M+ registros SICOSS) con múltiples conexiones a bases de datos externas a través de túneles SSH.

### Características Principales

- **🚀 Production-Ready**: Configuración optimizada para ambientes de producción
- **🔄 Multi-ambiente**: Soporte para desarrollo, staging y producción
- **🔐 Seguridad**: SSL/TLS, headers de seguridad, aislamiento de redes
- **📊 Alto Rendimiento**: Optimizado para procesamiento SICOSS masivo
- **🔗 Multi-DB**: Gestión de múltiples conexiones PostgreSQL vía SSH tunnels
- **📈 Monitoreo**: Prometheus + Grafana integrados
- **♻️ Alta Disponibilidad**: Auto-reconexión, health checks, supervisión

### Stack Tecnológico

| Componente | Versión | Descripción |
|------------|---------|-------------|
| PHP-FPM | 8.3 | Aplicación Laravel |
| PostgreSQL | 17 | Base de datos principal |
| Redis | 7 | Cache y sesiones |
| Nginx | Latest | Servidor web con SSL |
| Supervisor | Latest | Gestión de workers |
| SSH Tunnel | AutoSSH | Conexiones externas |
| Prometheus | Latest | Métricas |
| Grafana | Latest | Visualización |

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└─────────────────┬───────────────────────────────────────────┘
                  │ HTTPS (443)
        ┌─────────▼──────────┐
        │     Nginx (SSL)     │
        └─────────┬──────────┘
                  │
        ┌─────────▼──────────┐
        │    PHP-FPM (App)   │
        └────┬────────────┬──┘
             │            │
    ┌────────▼───┐  ┌─────▼──────┐
    │   Redis    │  │ PostgreSQL │
    │  (Cache)   │  │   (Main)   │
    └────────────┘  └────────────┘
             │
    ┌────────▼────────────┐
    │   Queue Workers     │
    │  - Default (x2)     │
    │  - SICOSS (x2)      │
    │  - Reports (x2)     │
    │  - Emails (x1)      │
    └─────────────────────┘
             │
    ┌────────▼────────────┐
    │   SSH Tunnels       │
    │  - Mapuche Prod     │
    │  - Monthly Backups  │
    └─────────────────────┘
```

## 📦 Requisitos Previos

### Software Requerido

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0
- **Git**: >= 2.30
- **Make**: (opcional, para comandos simplificados)

### Hardware Mínimo

- **CPU**: 4 cores @ 2.4 GHz
- **RAM**: 8 GB
- **Almacenamiento**: 100 GB SSD
- **Red**: 100 Mbps

### Hardware Recomendado (Producción)

- **CPU**: 8 cores @ 3.0 GHz
- **RAM**: 16 GB
- **Almacenamiento**: 500 GB NVMe SSD
- **Red**: 1 Gbps

## 🚀 Instalación Rápida

### 1. Clonar el Repositorio

```bash
git clone https://github.com/cristianfloyd/informes-app.git
cd informes-app
```

### 2. Configuración Inicial

```bash
# Copiar archivos de configuración
cp .env.docker.example .env.prod
cp .env.docker.example .env.dev

# Editar configuraciones según ambiente
nano .env.prod  # o vim, code, etc.
```

### 2.1. 📁 Gestión Automática de Permisos

**En desarrollo**, el sistema corrige automáticamente los permisos de Laravel:

```bash
# Los permisos se corrigen automáticamente al iniciar el contenedor
# No requiere intervención manual gracias al script fix-permissions.sh
```

**Directorios gestionados automáticamente:**
- `storage/logs` - Logs de Laravel (775)
- `storage/framework` - Cache de Laravel (775)  
- `bootstrap/cache` - Cache de rutas y configuración (775)

**Si necesitas corregir manualmente:**
```bash
# Corregir permisos en contenedor ejecutándose
docker exec dgsuc_app bash -c "chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache"

# O reconstruir el contenedor
make dev-rebuild
```

**⚠️ Nota importante**: Los permisos deben usar `www-data` como propietario porque PHP-FPM se ejecuta con este usuario, no como `root`.

### 3. Configurar SSH Keys (para túneles)

```bash
# Copiar SSH keys para conexiones externas
cp ~/.ssh/id_rsa_mapuche ~/.ssh/
chmod 600 ~/.ssh/id_rsa_mapuche
```

### 4. Deploy Rápido

```bash
# Usando Make (recomendado)
make install

# O manualmente
./scripts/deploy.sh development
```

## 📝 Guía de Deployment Completa

### 🔧 Paso 1: Preparación del Entorno

#### 1.1 Verificar Prerequisitos

```bash
# Verificar Docker
docker --version
docker-compose --version

# Verificar recursos disponibles
docker system info
df -h
free -h
```

#### 1.2 Configurar Variables de Entorno

Editar el archivo `.env.prod` con las configuraciones específicas:

```env
# Configuración Principal
APP_NAME="Sistema DGSUC"
APP_URL=https://dgsuc.uba.ar
APP_KEY=base64:generar_con_php_artisan_key:generate

# Base de Datos Principal
DB_HOST=postgres
DB_DATABASE=informes_app
DB_USERNAME=informes_user
DB_PASSWORD=contraseña_segura_aqui
DB_SCHEMA=suc_app

# Conexión Mapuche (vía SSH Tunnel)
DB2_HOST=127.0.0.1
DB2_PORT=5433
DB2_DATABASE=mapuche_prod
DB2_USERNAME=informes_readonly
DB2_PASSWORD=contraseña_readonly

# SSH Tunnel Configuration
MAPUCHE_SSH_HOST=mapuche.uba.ar
MAPUCHE_SSH_USER=tunnel_user
SSH_TUNNEL_PORTS=5433:localhost:5432,5434:backup1:5432

# Microsoft Azure AD (SSO)
MICROSOFT_CLIENT_ID=azure_client_id
MICROSOFT_CLIENT_SECRET=azure_secret
```

### 🐳 Paso 2: Build de Imágenes

#### 2.1 Desarrollo

```bash
# Build para desarrollo
make dev-build

# O manualmente
BUILD_TARGET=development docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  build
```

#### 2.2 Producción

```bash
# Build para producción
make prod-build

# O manualmente
BUILD_TARGET=production docker-compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  build --no-cache
```

### 🗄️ Paso 3: Inicialización de Base de Datos

```bash
# Iniciar solo la base de datos
docker-compose up -d postgres

# Esperar que esté lista
sleep 10

# Crear esquemas
docker-compose exec postgres psql -U informes_user -d informes_app -c "
CREATE SCHEMA IF NOT EXISTS suc_app;
CREATE SCHEMA IF NOT EXISTS informes_app;
ALTER DATABASE informes_app SET search_path = 'suc_app,informes_app,public';
"

# Ejecutar migraciones
docker-compose run --rm app php artisan migrate --force

# Cargar datos iniciales (si aplica)
docker-compose run --rm app php artisan db:seed
```

### 🔐 Paso 4: Configuración SSL

#### 4.1 Generar Certificados con Let's Encrypt

```bash
# Para producción
make ssl-generate

# O manualmente
docker run -it --rm \
  -v "$(pwd)/docker/nginx/certs:/etc/letsencrypt" \
  -v "$(pwd)/public:/var/www/html" \
  certbot/certbot certonly \
  --webroot \
  --webroot-path=/var/www/html \
  --email admin@uba.ar \
  --agree-tos \
  --no-eff-email \
  -d dgsuc.uba.ar
```

#### 4.2 Para Desarrollo (certificado autofirmado)

```bash
# Generar certificado autofirmado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/certs/privkey.pem \
  -out docker/nginx/certs/fullchain.pem \
  -subj "/C=AR/ST=Buenos Aires/L=CABA/O=UBA/CN=localhost"
```

### 🚀 Paso 5: Deployment

#### 5.1 Desarrollo

```bash
# Iniciar todos los servicios
make dev

# Verificar estado
make ps

# Ver logs
make dev-logs
```

**Accesos Desarrollo:**
- Aplicación: http://localhost:8080
- Mailhog: http://localhost:8025
- PHPMyAdmin: http://localhost:8090

#### 5.2 Producción

```bash
# Deploy completo
make prod

# O usar script
./scripts/deploy.sh production
```

**El script de deployment realizará:**
1. ✅ Backup pre-deployment
2. ✅ Pull últimos cambios
3. ✅ Build de imágenes
4. ✅ Migración de base de datos
5. ✅ Optimización de Laravel
6. ✅ Inicio de servicios
7. ✅ Health checks
8. ✅ Verificación SSL

### 📊 Paso 6: Monitoreo

```bash
# Iniciar stack de monitoreo
make monitor-start

# Acceder a Grafana
# URL: http://localhost:3000
# Usuario: admin
# Password: (configurada en .env)
```

### ✅ Paso 7: Verificación Post-Deployment

```bash
# 1. Verificar servicios
docker-compose ps

# 2. Health checks
curl -k https://localhost/health

# 3. Verificar logs
docker-compose logs --tail=50

# 4. Test de conexión a base de datos
docker-compose exec app php artisan tinker
>>> DB::connection()->getPdo();
>>> DB::connection('mapuche')->getPdo();

# 5. Verificar workers
docker-compose exec workers supervisorctl status

# 6. Verificar túneles SSH
make tunnel-status
```

## 🔧 Comandos Útiles

### Gestión de Servicios

```bash
# Estado de servicios
make ps

# Reiniciar servicios
make prod-restart

# Detener servicios
make prod-stop

# Logs en tiempo real
make logs
```

### Base de Datos

```bash
# Backup
make db-backup

# Restaurar
make db-restore

# Migraciones
make db-migrate

# Fresh con seeds
make db-fresh
```

### Cache y Optimización

```bash
# Limpiar todos los caches
make cache-clear

# Construir caches (producción)
make cache-build
```

### Mantenimiento

```bash
# Entrar al contenedor
make prod-shell

# Ejecutar comando Artisan
make artisan cmd="queue:status"

# Ejecutar Composer
make composer cmd="update"
```

### Troubleshooting

```bash
# Ver recursos utilizados
make stats

# Verificar health
make health

# Reiniciar túneles SSH
make tunnel-restart

# Ver logs de túneles
make tunnel-logs
```

## 🐛 Solución de Problemas Comunes

### Error: "Connection refused" a Base de Datos Externa

```bash
# Verificar túnel SSH
docker-compose logs ssh-tunnel

# Reiniciar túnel
docker-compose restart ssh-tunnel

# Verificar conectividad
docker-compose exec ssh-tunnel nc -zv localhost 5433
```

### Error: "Memory exhausted" en SICOSS

```bash
# Aumentar memoria en docker-compose.prod.yml
services:
  workers:
    deploy:
      resources:
        limits:
          memory: 8G  # Aumentar según necesidad
```

### Error: SSL Certificate

```bash
# Renovar certificado
make ssl-renew

# Verificar certificado
openssl x509 -in docker/nginx/certs/fullchain.pem -text -noout
```

### Contenedor no inicia

```bash
# Ver logs detallados
docker-compose logs -f [servicio]

# Reconstruir imagen
docker-compose build --no-cache [servicio]

# Limpiar y reiniciar
docker-compose down -v
docker-compose up -d
```

## 📈 Optimización de Performance

### Para Procesamiento SICOSS

1. **Ajustar memoria PHP**:
```ini
# docker/app/php.ini
memory_limit = 8192M
max_execution_time = 3600
```

2. **Configurar workers dedicados**:
```yaml
# docker-compose.prod.yml
workers:
  environment:
    WORKER_MEMORY: 8192
    WORKER_TIMEOUT: 7200
```

3. **Optimizar PostgreSQL**:
```sql
-- Índices específicos
CREATE INDEX CONCURRENTLY idx_sicoss_periodo 
ON afip_mapuche_sicoss(periodo_fiscal);
```

## 🔒 Seguridad

### Checklist de Seguridad

- [ ] Cambiar todas las contraseñas por defecto
- [ ] Configurar firewall del host
- [ ] Habilitar SSL/TLS
- [ ] Configurar backup automático
- [ ] Revisar permisos de archivos
- [ ] Actualizar regularmente las imágenes
- [ ] Monitorear logs de acceso
- [ ] Configurar fail2ban

### Hardening Adicional

```bash
# Limitar recursos
docker update --memory="4g" --cpus="2" container_name

# Scan de vulnerabilidades
docker scan dgsuc_app:latest

# Auditoría de seguridad
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image dgsuc_app:latest
```

## 📚 Documentación Adicional

- [Configuración Avanzada](./docs/advanced-config.md)
- [API Documentation](./docs/api.md)
- [Troubleshooting Guide](./docs/troubleshooting.md)
- [Security Best Practices](./docs/security.md)

## 🤝 Soporte

Para soporte y consultas:

- **Email**: carenas@uba.ar
- **Documentación**: https://docs.dgsuc.uba.ar
- **Issues**: https://github.com/cristianfloyd/informes-app/issues

## 📄 Licencia

Sistema interno de la Universidad de Buenos Aires - Todos los derechos reservados.

---

**Última actualización**: Agosto 2025  
**Versión**: 1.0.0  
**Mantenido por**: Equipo DGSUC - UBA