# Guía de Optimización de Performance en Windows con WSL2

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Problemas de Performance en Windows](#problemas-de-performance-en-windows)
3. [Migración Automática a WSL2](#migración-automática-a-wsl2)
4. [Configuración Manual](#configuración-manual)
5. [Mejores Prácticas](#mejores-prácticas)
6. [Troubleshooting](#troubleshooting)
7. [Comparativa de Performance](#comparativa-de-performance)

## Introducción

Docker en Windows puede sufrir problemas significativos de performance, especialmente durante el desarrollo. Esta guía te ayudará a optimizar tu entorno de desarrollo DGSUC utilizando WSL2 para obtener el máximo rendimiento.

### ⚡ Mejoras Esperadas

- **50-80%** más rápido en operaciones de archivos
- **3-5x** más rápido en inicio de contenedores
- **Hot reload** más eficiente
- Menor uso de CPU y memoria del host

## Problemas de Performance en Windows

### 🐌 Causas Principales

1. **Bind Mounts Lentos**: Windows tiene overhead significativo para bind mounts
2. **File System Cross-Platform**: NTFS → ext4 conversiones costosas
3. **File Watching Ineficiente**: Polling vs eventos nativos
4. **Memory Overhead**: Docker Desktop en Windows consume más recursos

### 📊 Síntomas Comunes

- ✗ Contenedores tardan >30 segundos en iniciar
- ✗ Cambios en código tardan >5 segundos en reflejarse
- ✗ Composer/NPM extremadamente lentos
- ✗ Alto uso de CPU durante desarrollo
- ✗ Xdebug timeouts frecuentes

## Migración Automática a WSL2

### 🚀 Opción Recomendada: Script Automático

```bash
# 1. Desde PowerShell como Administrador
wsl

# 2. Navegar al proyecto
cd /mnt/d/dgsuc-docker

# 3. Ejecutar migración automática
chmod +x scripts/migrate-to-wsl.sh
./scripts/migrate-to-wsl.sh
```

### 📋 Opciones de Migración

El script ofrece tres opciones:

#### 1. **Copia Completa** (Recomendado)
- Copia todo el proyecto a WSL filesystem nativo
- Máximo rendimiento
- Independiente del filesystem Windows

#### 2. **Optimización In-Situ**
- Mantiene proyecto en Windows
- Optimiza configuración Docker
- Mejora moderada de performance

#### 3. **Symlink Híbrido**
- Crea symlink desde WSL a Windows
- Balance entre conveniencia y performance
- Fácil acceso desde ambos sistemas

### 🛠️ Post-Migración

Después de ejecutar el script:

```bash
# Iniciar entorno optimizado
./wsl-dev.sh start

# Ver estado
./wsl-dev.sh status

# Optimizar caches
./wsl-dev.sh optimize
```

## Configuración Manual

### Prerrequisitos

1. **WSL2 Instalado**:
   ```powershell
   # PowerShell como Administrador
   wsl --install
   ```

2. **Docker Desktop con WSL2 Backend**:
   - Settings → General → "Use WSL 2 based engine"
   - Settings → Resources → WSL Integration → Habilitar tu distribución

### Configuración de Docker Compose

El archivo `docker-compose.wsl.yml` incluye optimizaciones específicas:

```yaml
services:
  app:
    volumes:
      # Cache modes optimizados
      - ./app:/var/www/html:cached
      - ./app/storage:/var/www/html/storage:delegated
      # Volúmenes nombrados para performance
      - php_sessions:/var/www/html/storage/framework/sessions
      - composer_cache:/home/dgsuc_user/.composer
    environment:
      # Optimizaciones de memoria
      - COMPOSER_MEMORY_LIMIT=-1
      - PHP_MEMORY_LIMIT=512M
      # OPcache optimizado
      - OPcache.enable=1
      - OPcache.memory_consumption=256
```

### Uso Manual

```bash
# Desde WSL
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d
```

## Mejores Prácticas

### 🏗️ Desarrollo en WSL2

1. **Usa VS Code con Remote-WSL**:
   ```bash
   # Instalar extensión Remote-WSL
   code --install-extension ms-vscode-remote.remote-wsl
   
   # Abrir proyecto desde WSL
   code .
   ```

2. **Configura Git en WSL**:
   ```bash
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu@email.com"
   ```

3. **Instala herramientas en WSL**:
   ```bash
   # Herramientas esenciales
   sudo apt update
   sudo apt install -y make curl git rsync
   ```

### 📁 Gestión de Archivos

1. **Trabaja Dentro de WSL**:
   - ✅ `/home/usuario/proyectos/dgsuc-docker`
   - ✗ `/mnt/c/Users/usuario/proyectos/dgsuc-docker`

2. **Backup Estratégico**:
   ```bash
   # Crear backup automático
   rsync -av /home/usuario/dgsuc-docker/ /mnt/d/backup/dgsuc-docker/
   ```

### 🔧 Optimizaciones Docker

1. **Limpieza Periódica**:
   ```bash
   # Script incluido
   ./wsl-dev.sh clean
   
   # Manual
   docker system prune -f
   docker volume prune -f
   ```

2. **Monitoreo de Recursos**:
   ```bash
   # Ver uso de recursos
   docker stats
   
   # Ver volúmenes
   docker volume ls
   ```

### 🖥️ Configuración de Host

1. **WSL2 Memory Limit**:
   ```ini
   # C:\Users\%USERNAME%\.wslconfig
   [wsl2]
   memory=8GB
   processors=4
   swap=2GB
   ```

2. **Docker Desktop Resources**:
   - Memory: 4GB mínimo, 8GB recomendado
   - CPUs: Al menos 2, preferible 4+
   - Disk: 50GB+ disponible

## Troubleshooting

### ❌ Problemas Comunes

#### 1. **"Docker daemon not running in WSL"**
```bash
# Verificar Docker Desktop WSL integration
# Settings → Resources → WSL Integration

# Restart Docker service
sudo service docker start

# Add user to docker group
sudo usermod -aG docker $USER
```

#### 2. **"Permission denied" en volúmenes**
```bash
# Fix permissions
sudo chown -R $USER:$USER ./app
chmod -R 755 ./app/storage
```

#### 3. **"Network timeouts" desde contenedores**
```bash
# Verificar DNS
docker run --rm alpine nslookup google.com

# Reset network
docker network prune
```

#### 4. **Performance aún lenta**
```bash
# Verificar que estás en WSL filesystem
pwd  # Debe mostrar /home/... no /mnt/...

# Verificar cache modes
docker-compose config | grep -A5 volumes
```

### 🔍 Diagnóstico

```bash
# Script de diagnóstico incluido
scripts/validate-config.sh

# Verificar WSL performance
time ls -la app/  # Debe ser <100ms

# Verificar Docker performance
time docker-compose ps  # Debe ser <5s
```

### 📞 Soporte Adicional

Si persisten problemas:

1. **Logs detallados**:
   ```bash
   ./wsl-dev.sh logs > debug.log
   ```

2. **Info del sistema**:
   ```bash
   # WSL info
   wsl --list --verbose
   
   # Docker info
   docker version
   docker info | grep -A5 "Server Version"
   ```

3. **Reset completo**:
   ```bash
   # Último recurso
   ./wsl-dev.sh clean
   docker system prune -a
   ```

## Comparativa de Performance

### 📈 Benchmarks Típicos

| Operación | Windows Nativo | WSL2 Optimizado | Mejora |
|-----------|----------------|-----------------|--------|
| `docker-compose up` | 45s | 12s | **73%** |
| Hot reload (Laravel) | 8s | 1.5s | **81%** |
| `composer install` | 180s | 65s | **64%** |
| `npm install` | 120s | 35s | **71%** |
| File sync (1000 files) | 25s | 4s | **84%** |

### 📊 Uso de Recursos

| Métrica | Windows Nativo | WSL2 Optimizado |
|---------|----------------|-----------------|
| RAM Docker Desktop | 4-6GB | 2-3GB |
| CPU idle | 15-25% | 5-10% |
| Disk I/O | Alto constante | Bajo, picos |
| Boot time completo | 2-3 min | 30-45s |

### 🎯 Casos de Uso

#### ✅ Perfecto para WSL2:
- Desarrollo diario
- Testing automatizado
- CI/CD local
- Debugging intensivo

#### ⚠️ Considerar híbrido:
- Diseño gráfico intensivo
- Herramientas Windows-específicas
- Sharepoint/Office integration

#### ❌ Mantener Windows:
- Aplicaciones legacy críticas
- Hardware específico
- Políticas corporativas restrictivas

## Comandos de Referencia Rápida

```bash
# Migración completa
./scripts/migrate-to-wsl.sh

# Desarrollo diario
./wsl-dev.sh start    # Iniciar
./wsl-dev.sh logs     # Ver logs
./wsl-dev.sh shell    # Entrar a contenedor
./wsl-dev.sh stop     # Detener

# Mantenimiento
./wsl-dev.sh optimize # Optimizar caches
./wsl-dev.sh clean    # Limpiar todo
./wsl-dev.sh status   # Ver estado

# Docker compose manual
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d

# Diagnóstico
scripts/validate-config.sh
```

---

> 💡 **Tip**: Después de migrar a WSL2, considera configurar VS Code con Remote-WSL para una experiencia de desarrollo completamente integrada.

> ⚠️ **Nota**: Los archivos del proyecto original en Windows permanecen intactos. Puedes volver a usarlos en cualquier momento si es necesario.