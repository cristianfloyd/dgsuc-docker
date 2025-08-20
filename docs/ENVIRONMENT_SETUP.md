# 🔧 Configuración de Entorno - DGSUC Docker

## 🎯 Objetivo

Esta guía explica cómo configurar correctamente las variables de entorno para el desarrollo local de Laravel con Docker.

## ⚠️ Problema Importante: APP_KEY en Repositorios

### 🚨 **NUNCA** commitees archivos `.env` con claves reales

```bash
# ❌ MAL - Nunca hagas esto
git add .env
git commit -m "Added environment config"

# ✅ BIEN - Solo commitea templates
git add .env.example
git commit -m "Updated environment template"
```

## 🚀 Configuración Inicial (Nueva Máquina)

### 1. Clonar y configurar automáticamente

```bash
git clone <repository>
cd dgsuc-docker
make setup  # Configura todo automáticamente
```

### 2. Configuración manual (si prefieres)

```bash
# Crear archivo .env desde template
cp .env.example .env

# Generar APP_KEY única
make app-key

# Verificar configuración
make check-env

# Iniciar contenedores
make dev
```

## 📋 Variables de Entorno Críticas

### 🔑 APP_KEY
- **Propósito**: Cifrado/descifrado de datos en Laravel
- **Formato**: `base64:...`
- **Generación**: `make app-key` o `openssl rand -base64 32`

### 🗄️ Base de Datos
```env
DB_DATABASE=dgsuc_app
DB_USERNAME=dgsuc_user
DB_PASSWORD=tu_password_segura  # ⚠️ Cambiar siempre
```

### 🚀 Aplicación
```env
APP_ENV=local          # local, staging, production
APP_DEBUG=true         # true para desarrollo
APP_URL=http://localhost:8080
```

## 🔍 Comandos de Diagnóstico

```bash
# Verificar configuración local
make check-env

# Ver estado en contenedor
make env-status

# Ver logs si hay problemas
make logs
```

## 🛠️ Solución de Problemas Comunes

### 1. "No application encryption key has been specified"
```bash
# Solución
make app-key
make restart
```

### 2. Variables vacías en contenedor
```bash
# Verificar que .env existe
ls -la .env

# Verificar contenido
make check-env

# Reiniciar contenedores
make restart
```

### 3. Permisos de archivos
```bash
# Corregir permisos
make fix-permissions
```

## 🌍 Configuración por Entorno

### 🖥️ Desarrollo Local
```env
APP_ENV=local
APP_DEBUG=true
DB_PASSWORD=desarrollo_local_123
```

### 🧪 Staging
```env
APP_ENV=staging
APP_DEBUG=false
DB_PASSWORD=staging_secure_password
```

### 🚀 Producción
```env
APP_ENV=production
APP_DEBUG=false
DB_PASSWORD=super_secure_production_password
```

## 📦 Workflow para Equipos

### 👨‍💻 Desarrollador Nuevo

1. **Clona repositorio**
   ```bash
   git clone <repo>
   cd dgsuc-docker
   ```

2. **Configuración automática**
   ```bash
   make setup
   ```

3. **Verificar funcionamiento**
   ```bash
   curl http://localhost:8080
   ```

### 🔄 Actualizaciones de Template

1. **Actualizar .env.example** (cuando se agreguen nuevas variables)
2. **Documentar cambios** en este archivo
3. **Notificar al equipo** sobre nuevas variables requeridas

## 🔒 Seguridad

### ✅ Buenas Prácticas
- Cada desarrollador genera su propia APP_KEY
- Passwords únicos por entorno
- .env en .gitignore
- Templates documentados en .env.example

### ❌ Evitar
- Compartir APP_KEY entre desarrolladores
- Passwords por defecto en producción
- Commitear archivos .env
- Usar mismas credenciales en todos los entornos

## 🆘 Soporte

Si tienes problemas:

1. **Revisa logs**: `make logs`
2. **Verifica configuración**: `make check-env`
3. **Reinicia limpio**: `make clean && make setup`
4. **Consulta documentación**: Este archivo y README.md

---

**💡 Tip**: Guarda este workflow como favorito. La configuración correcta de entorno es crucial para el desarrollo eficiente con Laravel y Docker.
