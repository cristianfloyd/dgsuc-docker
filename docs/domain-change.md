# 🔄 Guía de Cambio de Dominio - DGSUC Docker

Esta guía detalla el proceso completo para cambiar el dominio de la aplicación DGSUC de `dgsuc.uba.ar` a cualquier otro dominio (ej: `dgsuc.cristianarenas.com`).

## 📋 Tabla de Contenidos

- [Prerequisitos](#-prerequisitos)
- [Proceso Automatizado](#-proceso-automatizado)
- [Proceso Manual](#-proceso-manual)
- [Verificación](#-verificación)
- [Troubleshooting](#-troubleshooting)
- [Rollback](#-rollback)

## �� Prerequisitos

### 1. DNS Configurado
```bash
# Configurar estos registros DNS en tu proveedor:
# A record: dgsuc.cristianarenas.com -> IP_DEL_SERVIDOR
# A record: www.dgsuc.cristianarenas.com -> IP_DEL_SERVIDOR
# CNAME record: www -> dgsuc.cristianarenas.com (opcional)
```

### 2. Puertos Abiertos
```bash
# Verificar que estos puertos estén abiertos en el servidor:
# 80 (HTTP - para Let's Encrypt)
# 443 (HTTPS)
# 22 (SSH)
```

### 3. Backup Previo
```bash
# Crear backup completo antes del cambio
make backup-all

# Backup específico de configuración
tar -czf config-backup-$(date +%Y%m%d_%H%M%S).tar.gz .env docker/nginx/sites/ scripts/
```

## 🚀 Proceso Automatizado (Recomendado)

### Paso 1: Ejecutar Script de Cambio
```bash
# Opción 1: Comando interactivo
make change-domain

# Opción 2: Script directo
./scripts/change-domain.sh dgsuc.uba.ar dgsuc.cristianarenas.com admin@uba.ar admin@cristianarenas.com
```

### Paso 2: Verificar Cambios
```bash
# Verificar que todos los cambios se aplicaron correctamente
./scripts/verify-domain-change.sh dgsuc.cristianarenas.com admin@cristianarenas.com
```

### Paso 3: Reiniciar Servicios
```bash
# Reiniciar todos los contenedores
make restart

# O reiniciar específicamente nginx
docker-compose restart nginx
```

### Paso 4: Probar Nuevo Dominio
```bash
# Probar conectividad SSL
make ssl-test-domain
# Ingresa: dgsuc.cristianarenas.com

# O probar manualmente
curl -I https://dgsuc.cristianarenas.com
```

## 🔧 Proceso Manual (Paso a Paso)

### 1. Actualizar Variables de Entorno

```bash
# Editar .env
nano .env
```

Cambiar estas variables:
```env
# Cambiar de:
APP_URL=https://dgsuc.uba.ar
CERTBOT_EMAIL=admin@uba.ar
CERTBOT_DOMAIN=dgsuc.uba.ar
SESSION_DOMAIN=.uba.ar
MAIL_FROM_ADDRESS=dgsuc@uba.ar
MAIL_USERNAME=dgsuc@uba.ar

# A:
APP_URL=https://dgsuc.cristianarenas.com
CERTBOT_EMAIL=admin@cristianarenas.com
CERTBOT_DOMAIN=dgsuc.cristianarenas.com
SESSION_DOMAIN=.cristianarenas.com
MAIL_FROM_ADDRESS=dgsuc@cristianarenas.com
MAIL_USERNAME=dgsuc@cristianarenas.com

# Si tienes CORS configurado:
CORS_ALLOWED_ORIGINS=https://dgsuc.cristianarenas.com,https://www.dgsuc.cristianarenas.com
```

### 2. Actualizar Configuración Nginx

```bash
# Editar configuración SSL
nano docker/nginx/sites/default-ssl.conf
```

Cambiar las líneas de `server_name`:
```nginx
# Cambiar de:
server_name dgsuc.uba.ar www.dgsuc.uba.ar;

# A:
server_name dgsuc.cristianarenas.com www.dgsuc.cristianarenas.com;
```

### 3. Eliminar Certificados SSL Antiguos

```bash
# Eliminar certificados anteriores
rm -f docker/nginx/certs/fullchain.pem
rm -f docker/nginx/certs/privkey.pem
```

### 4. Generar Nuevo Certificado SSL

```bash
# Generar certificado Let's Encrypt para el nuevo dominio
./scripts/ssl-setup.sh letsencrypt dgsuc.cristianarenas.com admin@cristianarenas.com
```

### 5. Actualizar Configuración Laravel (si existe)

```bash
# Si tienes la aplicación Laravel clonada
if [ -d "app" ]; then
    # Actualizar config/app.php
    sed -i "s|'url' => env('APP_URL', 'https://dgsuc.uba.ar')|'url' => env('APP_URL', 'https://dgsuc.cristianarenas.com')|g" app/config/app.php
    
    # Actualizar config/session.php
    sed -i "s|'domain' => env('SESSION_DOMAIN', '.uba.ar')|'domain' => env('SESSION_DOMAIN', '.cristianarenas.com')|g" app/config/session.php
fi
```

### 6. Actualizar Crontab para Renovación SSL

```bash
# Actualizar job de renovación automática
(crontab -l 2>/dev/null | grep -v "ssl-auto-renew.sh"; echo "0 2 * * * $(pwd)/scripts/ssl-auto-renew.sh >> /var/log/ssl-renewal.log 2>&1") | crontab -
```

## ✅ Verificación

### 1. Verificar Configuración

```bash
# Verificar variables de entorno
grep -E "(APP_URL|CERTBOT_DOMAIN|CERTBOT_EMAIL|SESSION_DOMAIN)" .env

# Verificar configuración nginx
grep -n "server_name" docker/nginx/sites/default-ssl.conf

# Verificar certificado SSL
openssl x509 -in docker/nginx/certs/fullchain.pem -text -noout | grep -A1 "Subject:"
```

### 2. Verificar Resolución DNS

```bash
# Verificar que el dominio resuelve correctamente
nslookup dgsuc.cristianarenas.com

# Verificar desde el servidor
dig dgsuc.cristianarenas.com
```

### 3. Verificar Conectividad

```bash
# Probar conectividad HTTP
curl -I http://dgsuc.cristianarenas.com

# Probar conectividad HTTPS
curl -I https://dgsuc.cristianarenas.com

# Probar redirección HTTP a HTTPS
curl -I http://dgsuc.cristianarenas.com | grep Location
```

### 4. Verificar Servicios

```bash
# Verificar estado de contenedores
docker-compose ps

# Verificar logs de nginx
docker-compose logs nginx

# Verificar logs de SSL
docker-compose logs certbot
```

### 5. Verificar Aplicación

```bash
# Probar endpoint de salud
curl https://dgsuc.cristianarenas.com/health

# Probar acceso a la aplicación
curl https://dgsuc.cristianarenas.com
```

## 🐛 Troubleshooting

### Problema: "Certificate not found"

```bash
# Regenerar certificado
./scripts/ssl-setup.sh letsencrypt dgsuc.cristianarenas.com admin@cristianarenas.com

# Verificar permisos
chmod 644 docker/nginx/certs/fullchain.pem
chmod 600 docker/nginx/certs/privkey.pem
```

### Problema: "Domain does not resolve"

```bash
# Verificar configuración DNS
nslookup dgsuc.cristianarenas.com

# Verificar propagación DNS
dig +trace dgsuc.cristianarenas.com

# Esperar propagación (puede tomar hasta 24 horas)
```

### Problema: "SSL certificate error"

```bash
# Verificar certificado
openssl x509 -in docker/nginx/certs/fullchain.pem -text -noout

# Verificar cadena de certificados
openssl verify docker/nginx/certs/fullchain.pem

# Regenerar si es necesario
./scripts/ssl-setup.sh letsencrypt dgsuc.cristianarenas.com admin@cristianarenas.com
```

### Problema: "Nginx configuration error"

```bash
# Verificar sintaxis de nginx
docker-compose exec nginx nginx -t

# Verificar logs
docker-compose logs nginx

# Reiniciar nginx
docker-compose restart nginx
```

### Problema: "Application not accessible"

```bash
# Verificar que la aplicación esté corriendo
docker-compose ps

# Verificar logs de la aplicación
docker-compose logs app

# Verificar conectividad interna
docker-compose exec nginx curl -I http://app:9000
```

## �� Rollback

### Rollback Automático

```bash
# Si tienes backup configurado
./scripts/rollback-domain.sh 20241201_143022
```

### Rollback Manual

```bash
# 1. Restaurar backup de configuración
tar -xzf config-backup-20241201_143022.tar.gz

# 2. Restaurar certificados SSL (si los tienes)
cp backup-certs/fullchain.pem docker/nginx/certs/
cp backup-certs/privkey.pem docker/nginx/certs/

# 3. Reiniciar servicios
make restart

# 4. Verificar restauración
./scripts/verify-domain-change.sh dgsuc.uba.ar admin@uba.ar
```

## 📋 Checklist de Verificación

### Antes del Cambio
- [ ] DNS configurado y propagado
- [ ] Backup completo creado
- [ ] Puertos 80 y 443 abiertos
- [ ] Email válido para Let's Encrypt

### Durante el Cambio
- [ ] Variables de entorno actualizadas
- [ ] Configuración nginx actualizada
- [ ] Certificados SSL generados
- [ ] Crontab actualizado

### Después del Cambio
- [ ] DNS resuelve correctamente
- [ ] SSL funciona sin errores
- [ ] Aplicación accesible
- [ ] Redirección HTTP→HTTPS funciona
- [ ] Logs sin errores críticos
- [ ] Renovación automática configurada

## 🔧 Comandos Útiles

### Verificación Rápida
```bash
# Verificar todo en un comando
./scripts/verify-domain-change.sh dgsuc.cristianarenas.com admin@cristianarenas.com

# Verificar SSL específicamente
make ssl-test-domain

# Verificar estado de servicios
make health
```

### Logs y Debugging
```bash
# Ver logs en tiempo real
docker-compose logs -f nginx

# Ver logs de SSL
docker-compose logs -f certbot

# Ver logs de la aplicación
docker-compose logs -f app
```

### Mantenimiento
```bash
# Renovar certificados manualmente
make ssl-renew

# Verificar renovación automática
crontab -l | grep ssl

# Limpiar logs antiguos
docker-compose exec nginx logrotate /etc/logrotate.d/nginx
```

## 📞 Soporte

Si encuentras problemas durante el cambio de dominio:

1. **Revisar logs**: `docker-compose logs [servicio]`
2. **Verificar DNS**: `nslookup [dominio]`
3. **Probar conectividad**: `curl -I https://[dominio]`
4. **Consultar documentación**: Revisar esta guía
5. **Contactar soporte**: Crear issue en el repositorio

---

**Nota**: Este proceso cambia permanentemente el dominio de la aplicación. Asegúrate de tener un plan de rollback antes de proceder.

**Última actualización**: Diciembre 2024  
**Versión**: 1.0
