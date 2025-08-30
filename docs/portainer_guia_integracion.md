# 🐳 Guía de Integración: DGSUC con Portainer

Esta guía te permitirá desplegar y gestionar el Sistema DGSUC utilizando Portainer.

## 🐳 Paso 1: Preparar los Archivos de Configuración

### 1.1 Utilizar docker-compose.portainer.yml

Utilizar el archivo principal para Portainer:

```yaml
Archivo docker-compose: docker-compose.portainer.yml
```

### 1.2 Utilizar archivo .env para Portainer

```bash
Archivo: .env.portainer
```

## 🎯 Paso 2: Preparar Directorios y Permisos

### 2.1 Crear Estructura de Directorios

```bash
# Crear directorios necesarios para la aplicación
sudo mkdir -p /opt/dgsuc/{data,logs,config}
sudo mkdir -p /opt/dgsuc/data/{postgres,redis}
sudo mkdir -p /opt/dgsuc/logs/{nginx,app,postgres,redis,workers}
```

## Paso 3: Despliegue en Portainer

### 3.1 Preparar el Repositorio

```bash
cd /opt/dgsuc

# Clonar o subir archivos del proyecto
git clone https://github.com/tu-usuario/dgsuc-app.git .
# O copiar archivos manualmente

# Asegurar permisos correctos
sudo chown -R 1000:1000 /opt/dgsuc/app
sudo chmod -R 755 /opt/dgsuc
```

### 3.2 Crear Stack en Portainer

1. **Acceder a Portainer**
   - URL: `https://tu-servidor:9443`
   - Ir a **Stacks** → **Add Stack**

2. **Configurar el Stack**
   - **Name**: `dgsuc-production`
   - **Build method**: Seleccionar **Web editor**

3. **Pegar el docker-compose.portainer.yml**
   - Copiar todo el contenido del archivo creado anteriormente

4. **Configurar Variables de Entorno**
   - Scroll hacia abajo hasta **Environment variables**
   - **Load variables from .env file**: Activar
   - Subir el archivo `.env` creado anteriormente

5. **Configuraciones Avanzadas**
   ```yaml
   # En la sección de configuraciones avanzadas
   Enable access control: true
   ```

### 3.3 Configurar Volúmenes Persistentes

Antes de desplegar, asegurar que los volúmenes estén correctamente mapeados:

```bash
# Crear directorios de datos persistentes
sudo mkdir -p /opt/dgsuc/data/{postgres,redis}
sudo mkdir -p /opt/dgsuc/logs/{nginx,app,postgres,redis,workers}

# Establecer permisos
sudo chown -R 1000:1000 /opt/dgsuc/data
sudo chown -R 1000:1000 /opt/dgsuc/logs
sudo chmod -R 755 /opt/dgsuc/data
sudo chmod -R 755 /opt/dgsuc/logs
```

### 3.4 Desplegar el Stack

1. **Click en "Deploy the stack"**
2. **Esperar la descarga y build de imágenes** (puede tomar 10-15 minutos)
3. **Verificar el estado en Portainer**

## ** Paso 4: Verificación Post-Despliegue

### 4.1 Verificar Estado de Contenedores

En Portainer:
1. Ir a **Stacks** → **dgsuc-production**
2. Verificar que todos los contenedores estén **Running**
3. Revisar **Logs** de cada servicio

### 4.2 Health Checks Manual

```bash
# Acceder al servidor donde está Portainer
ssh usuario@tu-servidor

# Verificar servicios principales
curl -k https://localhost/health

# Verificar base de datos
docker exec dgsuc_postgres pg_isready -U dgsuc_user -d dgsuc_app

# Verificar Redis
docker exec dgsuc_redis redis-cli ping

# Verificar workers
docker exec dgsuc_workers supervisorctl status
```

### 4.3 Configuración SSL

La aplicación utilizará el certificado SSL global de UBA. Asegúrate de que el certificado esté disponible en el path configurado en las variables de entorno.

## Paso 5: Configuración Avanzada en Portainer

### 5.1 Configurar Backups Automáticos

Se recomienda configurar backups automáticos para proteger los datos:

### 5.2 Configurar Backups Automáticos

```yaml
# Agregar al stack principal o crear stack separado
  backup:
    image: postgres:17-alpine
    container_name: dgsuc_backup
    restart: "no"
    environment:
      - PGPASSWORD=${DB_PASSWORD}
    volumes:
      - /opt/dgsuc/backups:/backups
      - postgres_data:/var/lib/postgresql/data:ro
    command: >
      sh -c "
        while true; do
          pg_dump -h postgres -U ${DB_USERNAME} -d ${DB_DATABASE} > /backups/backup-$(date +%Y%m%d-%H%M%S).sql
          find /backups -name '*.sql' -mtime +7 -delete
          sleep 24h
        done
      "
    networks:
      - dgsuc_network
    depends_on:
      - postgres
```

## Paso 6: Configurar Logs y Monitoreo

### 6.1 Configuración de Logs

Los logs de la aplicación se almacenan en `/opt/dgsuc/logs/` y se pueden revisar desde Portainer:

1. **Acceder a Portainer**: `https://tu-servidor:9443`
2. **Ir a Containers** → Seleccionar contenedor
3. **Logs** → Revisar logs en tiempo real

### 6.2 Monitoreo Básico

Para monitoreo avanzado, la UBA cuenta con sistemas globales de Grafana y Prometheus. Contacta al equipo de infraestructura para integración.

## Paso 7: Configurar Notificaciones

### 7.1 Configurar Notificaciones de Aplicación

La aplicación puede enviar notificaciones a través de email y webhooks configurados en las variables de entorno. Revisar la documentación de la aplicación para más detalles.

## Paso 8: Operaciones de Mantenimiento

### 8.1 Actualizar la Aplicación

1. **En Portainer**:
   - Ir a **Stacks** → **dgsuc-production**
   - Click en **Editor**
   - Modificar la versión de la imagen
   - Click en **Update the stack**

2. **Rollback si es necesario**:
   - **Stacks** → **dgsuc-production**
   - **Editor** → revertir cambios
   - **Update the stack**

### 8.2 Escalar Servicios

En Portainer:
1. **Containers** → Seleccionar contenedor
2. **Duplicate/Edit** → cambiar réplicas
3. **Deploy**

### 8.3 Comandos Útiles desde Portainer Console

```bash
# Acceder a console de cualquier contenedor en Portainer
# Container → Console

# Comandos Laravel
php artisan migrate
php artisan cache:clear
php artisan config:cache
php artisan queue:status

# Verificar workers
supervisorctl status

# Ver logs
tail -f /var/log/supervisor/worker-sicoss.log
```

## Troubleshooting Común

### Problema: Contenedor no inicia

**Solución**:
1. En Portainer: **Containers** → Click en contenedor
2. **Logs** → revisar errores
3. **Duplicate/Edit** → ajustar configuración
4. **Replace**

### Problema: Base de datos no conecta

**Solución**:
```bash
# Desde Portainer Console del contenedor app
php artisan tinker
>>> DB::connection()->getPdo();
```

### Problema: Workers no procesan jobs

**Solución**:
```bash
# Console del contenedor workers
supervisorctl restart all
supervisorctl status
```

## 📋 Checklist Final

- [ ] Todos los contenedores están **Running**
- [ ] Health checks pasan correctamente
- [ ] SSL funciona (certificado global UBA configurado)
- [ ] Base de datos conecta correctamente
- [ ] Redis funciona
- [ ] Workers procesan jobs
- [ ] SSH tunnels conectan
- [ ] Logs funcionan correctamente
- [ ] Logs se escriben correctamente
- [ ] Backups funcionan
- [ ] Performance es aceptable

## 🎯 Accesos Importantes

- **Aplicación**: https://dgsuc.uba.ar
- **Portainer**: https://tu-servidor:9443

### 9.2 Configurar Registry Privado (Opcional)

Si quieres usar un registry privado para tus imágenes:

```yaml
# Stack adicional: dgsuc-registry
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: dgsuc_registry
    restart: always
    ports:
      - "5000:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
      - /opt/dgsuc/registry/data:/data
      - /opt/dgsuc/registry/auth:/auth
    networks:
      - dgsuc_network

networks:
  dgsuc_network:
    external: true
```

```bash
# Crear usuario para registry
mkdir -p /opt/dgsuc/registry/{data,auth}
docker run --entrypoint htpasswd registry:2 \
  -Bbn admin tu_password_registry > /opt/dgsuc/registry/auth/htpasswd

# Configurar en Portainer
# Registries → Add registry
# URL: https://tu-servidor:5000
# Authentication: Enabled
```

### 9.3 Network Security

```yaml
# Agregar al docker-compose.portainer.yml
# Configuración de red más segura
networks:
  dgsuc_frontend:
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.20.1.0/24
  
  dgsuc_backend:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.20.2.0/24

services:
  nginx:
    networks:
      - dgsuc_frontend
      - dgsuc_backend
  
  app:
    networks:
      - dgsuc_backend
  
  postgres:
    networks:
      - dgsuc_backend
  
  redis:
    networks:
      - dgsuc_backend
```

## 🔄 Paso 10: Automatización y CI/CD con Portainer

### 10.1 Webhook para Auto-Deploy

1. **Configurar Webhook en Portainer**:
   ```bash
   # En Portainer UI:
   Stacks → dgsuc-production → Webhooks
   - Create webhook
   - Copy webhook URL
   ```

2. **Usar con GitHub Actions**:
   ```yaml
   # .github/workflows/deploy.yml
   name: Deploy to Production
   
   on:
     push:
       branches: [ main ]
   
   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - name: Trigger Portainer Webhook
           run: |
             curl -X POST ${{ secrets.PORTAINER_WEBHOOK_URL }}
   ```

### 10.2 Script de Deployment Automático

```bash
#!/bin/bash
# /opt/dgsuc/scripts/auto-deploy.sh

set -e

STACK_NAME="dgsuc-production"
PORTAINER_URL="https://localhost:9443"
PORTAINER_USERNAME="admin"
PORTAINER_PASSWORD="tu_password"

echo "🚀 Iniciando auto-deployment..."

# Login to Portainer API
AUTH_TOKEN=$(curl -s -X POST \
  "${PORTAINER_URL}/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"Username\":\"${PORTAINER_USERNAME}\",\"Password\":\"${PORTAINER_PASSWORD}\"}" \
  | jq -r '.jwt')

echo "✅ Autenticado en Portainer"

# Get endpoint ID
ENDPOINT_ID=$(curl -s -X GET \
  "${PORTAINER_URL}/api/endpoints" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  | jq -r '.[0].Id')

# Update stack
curl -s -X PUT \
  "${PORTAINER_URL}/api/stacks/${STACK_NAME}?endpointId=${ENDPOINT_ID}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "pullImage": true,
    "prune": true
  }'

echo "✅ Stack actualizado correctamente"

# Verificar servicios
sleep 30
echo "🔍 Verificando servicios..."

# Health check
if curl -f -s https://localhost/health > /dev/null; then
  echo "✅ Aplicación funcionando correctamente"
else
  echo "❌ Error: Aplicación no responde"
  exit 1
fi

echo "🎉 Deployment completado exitosamente"
```


## Paso 11: Maintenance y Troubleshooting

### 11.1 Scripts de Mantenimiento Automatizado

```bash
#!/bin/bash
# /opt/dgsuc/scripts/maintenance.sh

LOG_FILE="/var/log/dgsuc-maintenance.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

# Función de backup
backup_database() {
    log "Iniciando backup de base de datos..."
    
    docker exec dgsuc_postgres pg_dump \
        -U dgsuc_user \
        -d dgsuc_app \
        --verbose \
        --format=custom \
        --file="/backups/dgsuc-$(date +%Y%m%d-%H%M).backup"
    
    if [ $? -eq 0 ]; then
        log "✅ Backup completado exitosamente"
    else
        log "❌ Error en backup"
        return 1
    fi
}

# Limpiar logs antiguos
cleanup_logs() {
    log "Limpiando logs antiguos..."
    
    find /opt/dgsuc/logs -name "*.log" -mtime +30 -delete
    find /opt/dgsuc/backups -name "*.backup" -mtime +7 -delete
    
    log "✅ Limpieza completada"
}

# Optimizar base de datos
optimize_database() {
    log "Optimizando base de datos..."
    
    docker exec dgsuc_postgres psql \
        -U dgsuc_user \
        -d dgsuc_app \
        -c "VACUUM ANALYZE;"
    
    log "✅ Optimización completada"
}

# Verificar health de servicios
health_check() {
    log "Verificando salud de servicios..."
    
    services=("dgsuc_app" "dgsuc_postgres" "dgsuc_redis" "dgsuc_nginx" "dgsuc_workers")
    
    for service in "${services[@]}"; do
        if docker exec "$service" echo "OK" > /dev/null 2>&1; then
            log "✅ $service: Healthy"
        else
            log "❌ $service: Unhealthy"
        fi
    done
}

# Ejecutar mantenimiento
main() {
    log "🔧 Iniciando rutina de mantenimiento"
    
    backup_database
    cleanup_logs
    optimize_database
    health_check
    
    log "🎉 Mantenimiento completado"
}

main "$@"
```

### 11.2 Configurar Cron para Mantenimiento

```bash
# Agregar al crontab del servidor
sudo crontab -e

# Backup diario a las 2 AM
0 2 * * * /opt/dgsuc/scripts/maintenance.sh

# Cleanup semanal los domingos a las 3 AM
0 3 * * 0 /opt/dgsuc/scripts/cleanup.sh

# Health check cada hora
0 * * * * /opt/dgsuc/scripts/health-check.sh
```

## Paso 12: Configurar Notificaciones

### 12.1 Notificaciones de la Aplicación

Para configurar notificaciones por email y webhooks, utilizar las variables de entorno correspondientes en el archivo `.env.portainer`. Consultar la documentación de la aplicación para los parámetros específicos.

## Paso 13: Testing y Validación

### 13.1 Script de Testing Automatizado

```bash
#!/bin/bash
# /opt/dgsuc/scripts/test-deployment.sh

set -e

BASE_URL="https://dgsuc.uba.ar"

echo "🧪 Iniciando tests de deployment..."

# Test 1: Health check básico
test_health() {
    echo "Test 1: Health check..."
    if curl -f -s "${BASE_URL}/health" > /dev/null; then
        echo "✅ Health check: PASS"
    else
        echo "❌ Health check: FAIL"
        return 1
    fi
}

# Test 2: Base de datos
test_database() {
    echo "Test 2: Database connectivity..."
    if docker exec dgsuc_app php artisan tinker --execute="DB::connection()->getPdo(); echo 'DB OK';" 2>/dev/null; then
        echo "✅ Database: PASS"
    else
        echo "❌ Database: FAIL"
        return 1
    fi
}

# Test 3: Redis
test_redis() {
    echo "Test 3: Redis connectivity..."
    if docker exec dgsuc_redis redis-cli ping | grep -q "PONG"; then
        echo "✅ Redis: PASS"
    else
        echo "❌ Redis: FAIL"
        return 1
    fi
}

# Test 4: Workers
test_workers() {
    echo "Test 4: Queue workers..."
    if docker exec dgsuc_workers supervisorctl status | grep -q "RUNNING"; then
        echo "✅ Workers: PASS"
    else
        echo "❌ Workers: FAIL"
        return 1
    fi
}

# Test 5: SSL Certificate
test_ssl() {
    echo "Test 5: SSL Certificate..."
    if echo | openssl s_client -servername dgsuc.uba.ar -connect dgsuc.uba.ar:443 2>/dev/null | openssl x509 -noout -dates; then
        echo "✅ SSL: PASS"
    else
        echo "❌ SSL: FAIL"
        return 1
    fi
}

# Test 6: Logs
test_logs() {
    echo "Test 6: Log files..."
    if [ -d "/opt/dgsuc/logs" ] && [ "$(ls -A /opt/dgsuc/logs)" ]; then
        echo "✅ Logs: PASS"
    else
        echo "❌ Logs: FAIL"
        return 1
    fi
}

# Test 7: Performance básico
test_performance() {
    echo "Test 7: Performance básico..."
    response_time=$(curl -o /dev/null -s -w '%{time_total}' "${BASE_URL}")
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        echo "✅ Performance: PASS (${response_time}s)"
    else
        echo "⚠️ Performance: SLOW (${response_time}s)"
    fi
}

# Ejecutar todos los tests
run_tests() {
    test_health
    test_database
    test_redis
    test_workers
    test_ssl
    test_logs
    test_performance
    
    echo "🎉 Tests completados"
}

run_tests "$@"
```

### 13.2 Load Testing con Artillery

```yaml
# /opt/dgsuc/tests/load-test.yml
config:
  target: 'https://dgsuc.uba.ar'
  phases:
    - duration: 60
      arrivalRate: 5
      name: "Warm up"
    - duration: 120
      arrivalRate: 10
      name: "Ramp up load"
    - duration: 600
      arrivalRate: 20
      name: "Sustained load"
  processor: "./load-test-functions.js"

scenarios:
  - name: "Health check"
    weight: 30
    flow:
      - get:
          url: "/health"
          
  - name: "Home page"
    weight: 50
    flow:
      - get:
          url: "/"
          
  - name: "SICOSS endpoint"
    weight: 20
    flow:
      - post:
          url: "/api/sicoss/process"
          json:
            test: true
```

```bash
# Ejecutar load test
npm install -g artillery
artillery run /opt/dgsuc/tests/load-test.yml
```

## 📋 Paso 14: Checklist Final de Producción

### ✅ Pre-Deployment
- [ ] Todas las variables de entorno configuradas
- [ ] Certificados SSL válidos y configurados
- [ ] Backups funcionando correctamente
- [ ] Monitoreo configurado y funcionando
- [ ] Logs rotando correctamente
- [ ] SSH keys configuradas para túneles
- [ ] Recursos del servidor adecuados
- [ ] Firewall configurado correctamente

### ✅ Post-Deployment
- [ ] Todos los contenedores en estado Running
- [ ] Health checks pasando
- [ ] Base de datos conectando
- [ ] Redis funcionando
- [ ] Workers procesando jobs
- [ ] SSL certificate válido
- [ ] Logs accesibles desde Portainer
- [ ] Alertas configuradas y funcionando
- [ ] Performance acceptable (< 2s response time)
- [ ] Backups automáticos funcionando

### ✅ Operaciones Diarias
- [ ] Revisar logs de errores en Portainer
- [ ] Confirmar que backups se ejecutaron
- [ ] Revisar uso de recursos del servidor
- [ ] Verificar estado de workers
- [ ] Confirmar que túneles SSH están activos

## 🔄 Paso 15: Proceso de Actualización

### Actualización Zero-Downtime

```bash
#!/bin/bash
# /opt/dgsuc/scripts/zero-downtime-update.sh

echo "🔄 Iniciando actualización zero-downtime..."

# 1. Crear backup pre-update
docker exec dgsuc_postgres pg_dump -U dgsuc_user dgsuc_app > "/opt/dgsuc/backups/pre-update-$(date +%Y%m%d-%H%M).sql"

# 2. Pull nueva imagen
docker pull dgsuc/app:latest

# 3. Crear contenedor temporal con nueva versión
docker run -d \
  --name dgsuc_app_new \
  --network dgsuc_network \
  -e APP_ENV=production \
  dgsuc/app:latest

# 4. Health check del nuevo contenedor
sleep 30
if docker exec dgsuc_app_new php artisan tinker --execute="echo 'OK';" > /dev/null; then
    echo "✅ Nuevo contenedor healthy"
else
    echo "❌ Nuevo contenedor unhealthy - abortando"
    docker rm -f dgsuc_app_new
    exit 1
fi

# 5. Actualizar nginx para apuntar al nuevo contenedor
# (requerir script adicional para cambiar upstream)

# 6. Esperar que el tráfico se drene del contenedor viejo
sleep 60

# 7. Parar contenedor viejo
docker stop dgsuc_app

# 8. Renombrar contenedores
docker rename dgsuc_app dgsuc_app_old
docker rename dgsuc_app_new dgsuc_app

# 9. Cleanup
docker rm dgsuc_app_old

echo "🎉 Actualización completada sin downtime"
```

## 📞 Paso 16: Soporte y Documentación

### Contactos de Soporte
- **Email Técnico**: carenas@uba.ar
- **Teams**: SUC

### Documentación Adicional
- **Manual de Usuario**: https://docs.dgsuc.uba.ar/user-manual
- **API Documentation**: https://docs.dgsuc.uba.ar/api
- **Troubleshooting**: https://docs.dgsuc.uba.ar/troubleshooting
- **Security Guidelines**: https://docs.dgsuc.uba.ar/security

### Recursos Útiles
- **Portainer Documentation**: https://docs.portainer.io
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices
- **Laravel**: [https://laravel.com/docs/12.x](https://laravel.com/docs/12.x)

---



**Última actualización**: Agosto 2025  
**Versión**: 2.0.0  
**Maintainer**: Equipo DGSUC - UBA