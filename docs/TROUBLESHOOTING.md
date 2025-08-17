# DGSUC Docker - Guía de Solución de Problemas

Esta guía te ayudará a diagnosticar y resolver problemas comunes durante la inicialización y configuración del entorno DGSUC Docker.

## 🚨 Problemas Comunes y Soluciones

### 1. Error: `cp: can't stat '/source/.': No such file or directory`

**Descripción:** Error durante la sincronización de código al volumen Docker.

**Causas posibles:**
- El directorio `./app` no existe
- Problemas de permisos en Windows
- El volumen Docker no se montó correctamente

**Soluciones:**

```bash
# Opción 1: Usar el comando de diagnóstico
make diagnose

# Opción 2: Solucionar automáticamente
make fix-init

# Opción 3: Verificar manualmente
ls -la ./app
docker volume ls | grep dgsuc-docker_app_code
```

### 2. Error: `sh: git: not found`

**Descripción:** Git no está disponible en el contenedor temporal.

**Causas posibles:**
- El contenedor Alpine no tiene Git instalado
- Problemas de red durante la instalación de paquetes

**Soluciones:**

```bash
# El script fix-init ya incluye la instalación de Git
make fix-init

# Verificar manualmente
docker run --rm alpine:latest sh -c "apk add --no-cache git && git --version"
```

### 3. Error: `app_code` volume missing

**Descripción:** El volumen Docker para el código no existe.

**Soluciones:**

```bash
# Crear el volumen manualmente
docker volume create dgsuc-docker_app_code

# O usar el comando de solución automática
make fix-init
```

### 4. Error: `Permission denied` en archivos de Laravel

**Descripción:** Problemas de permisos en directorios de Laravel.

**Soluciones:**

```bash
# Corregir permisos automáticamente
make fix-permissions

# O manualmente
docker-compose exec app chown -R dgsuc_user:www-data /var/www/html/storage
docker-compose exec app chmod -R 775 /var/www/html/storage
docker-compose exec app chown -R dgsuc_user:www-data /var/www/html/bootstrap/cache
docker-compose exec app chmod -R 775 /var/www/html/bootstrap/cache
```

### 5. Error: `Connection refused` en base de datos

**Descripción:** La aplicación no puede conectarse a PostgreSQL.

**Causas posibles:**
- PostgreSQL no está ejecutándose
- Configuración incorrecta de puertos
- Credenciales incorrectas

**Soluciones:**

```bash
# Verificar estado de contenedores
make ps

# Ver logs de PostgreSQL
docker-compose logs postgres

# Verificar configuración de base de datos
docker-compose exec app php artisan config:show database

# Reiniciar servicios
make restart
```

### 6. Error: `HTTP/1.1 500 Internal Server Error`

**Descripción:** Error interno del servidor al acceder a la aplicación.

**Soluciones:**

```bash
# Ver logs de la aplicación
make logs app

# Verificar permisos
make fix-permissions

# Instalar dependencias
make composer-install

# Limpiar cachés
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
docker-compose exec app php artisan view:clear
```

## 🔧 Comandos de Diagnóstico y Solución

### Diagnóstico Completo

```bash
# Ejecutar diagnóstico completo
make diagnose
```

Este comando verifica:
- ✅ Docker y Docker Compose
- ✅ Git
- ✅ Estructura del proyecto
- ✅ Archivos de configuración
- ✅ Volúmenes Docker
- ✅ Contenedores e imágenes
- ✅ Permisos
- ✅ Espacio en disco
- ✅ Configuración de red
- ✅ Puertos
- ✅ Logs recientes

### Solución Automática de Errores

```bash
# Solución automática (detecta Windows/Linux)
make fix-init
```

Este comando:
- ✅ Verifica y clona la aplicación si es necesario
- ✅ Crea el volumen Docker si no existe
- ✅ Sincroniza código al volumen
- ✅ Construye contenedores
- ✅ Inicia servicios
- ✅ Instala dependencias de Composer
- ✅ Configura Git
- ✅ Corrige permisos
- ✅ Verifica conectividad

### Configuración del Entorno

```bash
# Configurar archivos .env básicos
make setup-env
```

Este comando:
- ✅ Crea archivos `.env.dev` y `.env.prod`
- ✅ Aplica secretos desde `.env.secrets`
- ✅ Genera claves de aplicación
- ✅ Configura el entorno principal

## 🛠️ Flujo de Solución de Problemas

### Paso 1: Diagnóstico
```bash
make diagnose
```

### Paso 2: Configurar Entorno (si es necesario)
```bash
make setup-env
```

### Paso 3: Solución Automática
```bash
make fix-init
```

### Paso 4: Verificar Estado
```bash
make ps
curl http://localhost:8080
```

### Paso 5: Si persisten problemas
```bash
# Ver logs específicos
make logs app
make logs postgres
make logs nginx

# Verificar permisos
make fix-permissions

# Instalar dependencias
make composer-install
```

## 🚀 Comandos de Emergencia

### Limpieza Completa
```bash
# Detener y eliminar todo
docker-compose down -v
docker system prune -af
docker volume prune -f

# Reinicializar desde cero
make init
```

### Reinicio Forzado
```bash
# Reiniciar todos los servicios
make restart

# O individualmente
docker-compose restart app
docker-compose restart postgres
docker-compose restart nginx
```

### Verificación de Conectividad
```bash
# Verificar que la aplicación responde
curl -I http://localhost:8080

# Verificar base de datos
docker-compose exec postgres psql -U dgsuc_user -d dgsuc_app -c "SELECT 1;"

# Verificar Redis
docker-compose exec redis redis-cli ping
```

## 📋 Checklist de Verificación

Antes de reportar un problema, verifica:

- [ ] Docker está ejecutándose
- [ ] Docker Compose está instalado
- [ ] Git está instalado
- [ ] El directorio `./app` existe
- [ ] Los archivos `.env` están configurados
- [ ] Los puertos 8080 y 5432 están disponibles
- [ ] Hay suficiente espacio en disco
- [ ] Los permisos son correctos

## 🆘 Obtener Ayuda

Si los problemas persisten:

1. **Ejecuta el diagnóstico completo:**
   ```bash
   make diagnose
   ```

2. **Revisa los logs:**
   ```bash
   make logs
   ```

3. **Verifica la configuración:**
   ```bash
   cat .env
   cat app/.env
   ```

4. **Comprueba el estado de los contenedores:**
   ```bash
   make ps
   ```

5. **Si todo falla, reinicia desde cero:**
   ```bash
   make clean
   make init
   ```

## 💡 Tips de Rendimiento

### Para Windows:
- Usa volúmenes Docker en lugar de bind mounts
- Considera usar WSL para mejor rendimiento
- Ejecuta `make sync-to-volume` para sincronizar cambios

### Para Linux/macOS:
- Los bind mounts funcionan bien
- Usa `make dev` para desarrollo estándar

### Para WSL:
- Usa `make dev-wsl` para configuración optimizada
- El rendimiento es significativamente mejor que Windows nativo

## 🔄 Comandos de Mantenimiento

```bash
# Actualizar dependencias
make composer-install

# Limpiar cachés
docker-compose exec app php artisan cache:clear

# Ejecutar migraciones
make db-migrate

# Verificar estado general
make ps
make logs
```

---

**Nota:** Esta guía se actualiza regularmente. Si encuentras un problema no documentado, ejecuta `make diagnose` y revisa los logs para obtener información específica del error.
