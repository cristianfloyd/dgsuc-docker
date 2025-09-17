# Configuración Simplificada DGSUC

Esta es una versión reducida con Laravel + Nginx en un contenedor y PostgreSQL en otro contenedor separado, preparada para Portainer/Swarm.

## Archivos creados

- `docker-compose.simple.yml` - Configuración simplificada para Swarm
- `docker/simple-app/` - Archivos de configuración del contenedor Laravel+Nginx

## Uso

### Para desarrollo local
```bash
docker-compose -f docker-compose.simple.yml up -d --build
```

### Para Portainer/Swarm
```bash
docker stack deploy -c docker-compose.simple.yml dgsuc-simple
```

### Ver logs
```bash
docker service logs dgsuc-simple_app -f
docker service logs dgsuc-simple_postgres -f
```

## Servicios incluidos

- **Laravel PHP 8.4 + Nginx**: Aplicación web con servidor integrado
- **PostgreSQL 17**: Base de datos separada

## Características Portainer

- **Traefik**: Labels configurados para proxy automático
- **NFS**: Volúmenes persistentes en almacenamiento compartido
- **Swarm**: Configuración para modo replicado
- **Registry**: Usa registry privado `registry.rec.uba.ar`
- **SSL**: Certificados automáticos via Let's Encrypt
- **Dominio**: `dgsuc-simple.rec.uba.ar`

## Variables de entorno

```bash
# Aplicación
APP_NAME="Sistema DGSUC"
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:...
APP_URL=https://dgsuc-simple.rec.uba.ar

# Base de datos
DB_DATABASE=suc_app
DB_USERNAME=postgres
DB_PASSWORD=secreto_seguro

# Traefik (opcional)
NGINX_HOST=dgsuc-simple.rec.uba.ar
```

## Volúmenes NFS

- `postgres_data` - Datos de PostgreSQL
- `php_sessions` - Sesiones de Laravel
- `php_cache` - Cache de Laravel
- `nginx_logs` - Logs de Nginx
- `app_logs` - Logs de aplicación

## Limitaciones

- No incluye Redis (usa cache de archivos)
- No incluye workers de cola (usa sync)
- Optimizado para despliegues simples y medianos