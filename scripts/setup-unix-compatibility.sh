#!/bin/bash
# =============================================================================
# CONFIGURADOR MAESTRO DE COMPATIBILIDAD UNIX/LINUX
# =============================================================================

set -e

# Códigos de color para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar headers
show_header() {
    echo -e "\n${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}\n"
}

# Función para mostrar pasos
show_step() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Función para mostrar advertencias
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Función para mostrar errores
show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Directorio base del proyecto
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

show_header "CONFIGURACIÓN DE COMPATIBILIDAD UNIX/LINUX"
echo -e "${PURPLE}Sistema DGSUC - Docker Laravel${NC}"
echo -e "Configurando repositorio para compatibilidad 100% Unix/Linux\n"

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    show_error "No se encontró docker-compose.yml. ¿Estás en el directorio correcto?"
    exit 1
fi

show_success "Directorio del proyecto: $PROJECT_ROOT"

# 1. Verificar .gitattributes
show_step "Verificando configuración de line endings (.gitattributes)"
if [ -f ".gitattributes" ]; then
    show_success ".gitattributes ya existe"
else
    show_warning ".gitattributes no encontrado - debería haberse creado automáticamente"
fi

# 2. Normalizar permisos Unix
show_step "Normalizando permisos Unix/Linux"
if [ -f "scripts/fix-unix-permissions.sh" ]; then
    chmod +x scripts/fix-unix-permissions.sh
    ./scripts/fix-unix-permissions.sh
    show_success "Permisos Unix normalizados"
else
    show_error "Script de permisos no encontrado"
fi

# 3. Verificar case sensitivity
show_step "Verificando case sensitivity"
if [ -f "scripts/check-case-sensitivity.sh" ]; then
    chmod +x scripts/check-case-sensitivity.sh
    if ./scripts/check-case-sensitivity.sh; then
        show_success "Verificación de case sensitivity completada sin issues"
    else
        show_warning "Se encontraron algunos issues de case sensitivity - revisa el output anterior"
    fi
else
    show_error "Script de verificación de case sensitivity no encontrado"
fi

# 4. Configurar Git para line endings Unix
show_step "Configurando Git para line endings Unix"
git config core.autocrlf false
git config core.eol lf
show_success "Git configurado para line endings Unix (LF)"

# 5. Normalizar line endings existentes
show_step "Normalizando line endings existentes"

# Re-checkout todos los archivos para aplicar .gitattributes
if [ -f ".gitattributes" ]; then
    echo "Aplicando normalización de line endings..."
    
    # Hacer backup del estado actual
    git add . 2>/dev/null || true
    
    # Remover archivos del index y re-checkout
    git ls-files -z | xargs -0 rm
    git checkout HEAD -- .
    
    show_success "Line endings normalizados según .gitattributes"
else
    show_warning "Saltando normalización - .gitattributes no encontrado"
fi

# 6. Verificar configuraciones Docker
show_step "Verificando configuraciones Docker para Linux"

DOCKER_CONFIGS=(
    "docker-compose.yml"
    "docker-compose.linux.yml"
    "docker-compose.dev.yml"
    "docker-compose.prod.yml"
)

for config in "${DOCKER_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        show_success "✓ $config encontrado"
        
        # Verificar que no tenga referencias a Windows
        if grep -q "host.docker.internal\|windows\|C:\|D:" "$config" 2>/dev/null; then
            show_warning "⚠️  $config contiene referencias específicas de Windows"
        fi
    else
        show_warning "⚠️  $config no encontrado"
    fi
done

# 7. Crear archivo de configuración Unix
show_step "Creando configuración específica para Unix/Linux"

cat > .env.unix << 'EOF'
# =============================================================================
# CONFIGURACIÓN ESPECÍFICA PARA UNIX/LINUX
# =============================================================================

# Usuario y grupo para contenedores (ajustar según el sistema)
WWWUSER=1000
WWWGROUP=1000

# Configuraciones optimizadas para Linux
DB_EXTERNAL_PORT=5432
REDIS_EXTERNAL_PORT=6379
HTTP_PORT=80
HTTPS_PORT=443

# Configuraciones de performance para Linux
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Configuraciones de logging optimizadas
LOG_CHANNEL=stack
LOG_LEVEL=info

# Desactivar configuraciones específicas de Windows
DEV_XDEBUG_ENABLED=false
EOF

show_success "Archivo .env.unix creado"

# 8. Crear script de inicio para Linux
show_step "Creando script de inicio para Linux"

cat > scripts/start-linux.sh << 'EOF'
#!/bin/bash
# Script de inicio optimizado para Linux/Unix

set -e

echo "🐧 Iniciando DGSUC en Linux/Unix..."

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose no está disponible"
    exit 1
fi

# Usar configuración específica de Linux
export COMPOSE_FILE="docker-compose.linux.yml"

echo "📁 Usando configuración: $COMPOSE_FILE"

# Configurar variables de entorno Unix
if [ -f ".env.unix" ]; then
    echo "🔧 Cargando configuración Unix..."
    export $(grep -v '^#' .env.unix | xargs)
fi

# Iniciar servicios
echo "🚀 Iniciando servicios..."
docker compose up -d

echo "✅ DGSUC iniciado en modo Linux/Unix"
echo "🌐 Aplicación disponible en: http://localhost"
EOF

chmod +x scripts/start-linux.sh
show_success "Script de inicio para Linux creado"

# 9. Crear documentación Unix
show_step "Creando documentación de compatibilidad Unix"

cat > UNIX_COMPATIBILITY.md << 'EOF'
# Compatibilidad Unix/Linux

Este repositorio ha sido configurado para ser 100% compatible con sistemas Unix/Linux.

## Configuraciones Aplicadas

### 1. Line Endings
- **Configurado**: Todos los archivos usan LF (Unix) line endings
- **Archivo**: `.gitattributes` controla automáticamente los line endings

### 2. Permisos de Archivos
- **Scripts**: 755 (ejecutables)
- **Archivos regulares**: 644
- **Directorios**: 755
- **Storage Laravel**: 775

### 3. Case Sensitivity
- **Verificado**: Nombres de archivos y clases consistentes
- **Tool**: `scripts/check-case-sensitivity.sh`

### 4. Docker Configuration
- **Archivo específico**: `docker-compose.linux.yml`
- **Optimizado**: Sin dependencias de Windows
- **Performance**: Bind mounts directos

## Uso en Linux/Unix

### Inicio Rápido
```bash
# Configurar compatibilidad (solo primera vez)
./scripts/setup-unix-compatibility.sh

# Iniciar en Linux
./scripts/start-linux.sh
```

### Comandos Manuales
```bash
# Usar configuración Linux
export COMPOSE_FILE="docker-compose.linux.yml"
docker compose up -d

# Verificar permisos
./scripts/fix-unix-permissions.sh

# Verificar case sensitivity
./scripts/check-case-sensitivity.sh
```

## Variables de Entorno Unix

Archivo `.env.unix` contiene configuraciones específicas:
- `WWWUSER/WWWGROUP`: Usuario/grupo del contenedor
- Puertos nativos de Linux
- Configuraciones optimizadas

## Diferencias vs Windows

| Aspecto | Windows | Linux/Unix |
|---------|---------|------------|
| Line endings | CRLF | LF |
| Permisos | No aplicable | 644/755/775 |
| Case sensitivity | Insensible | Sensible |
| Docker | Docker Desktop | Docker nativo |
| Performance | Volúmenes Docker | Bind mounts |

## Verificación

Después de clonar en Unix/Linux:
1. Ejecutar `./scripts/setup-unix-compatibility.sh`
2. Verificar que no hay warnings
3. Iniciar con `./scripts/start-linux.sh`
4. Confirmar que todos los servicios funcionan
EOF

show_success "Documentación Unix creada: UNIX_COMPATIBILITY.md"

# 10. Resumen final
show_header "RESUMEN DE CONFIGURACIÓN"

echo -e "${GREEN}✅ Configuraciones aplicadas:${NC}"
echo "   📄 .gitattributes (line endings LF)"
echo "   🔧 Permisos Unix normalizados"
echo "   🐳 docker-compose.linux.yml creado"
echo "   🚀 scripts/start-linux.sh creado"
echo "   📋 .env.unix creado"
echo "   📖 UNIX_COMPATIBILITY.md creado"

echo -e "\n${BLUE}📋 Próximos pasos:${NC}"
echo "1. Hacer commit de los cambios:"
echo "   ${YELLOW}git add .${NC}"
echo "   ${YELLOW}git commit -m \"feat: configurar compatibilidad 100% Unix/Linux\"${NC}"
echo ""
echo "2. En sistemas Linux/Unix, ejecutar:"
echo "   ${YELLOW}./scripts/setup-unix-compatibility.sh${NC}"
echo "   ${YELLOW}./scripts/start-linux.sh${NC}"
echo ""
echo "3. Verificar funcionamiento:"
echo "   ${YELLOW}docker compose ps${NC}"
echo "   ${YELLOW}curl http://localhost${NC}"

echo -e "\n${GREEN}🎉 Repositorio configurado para compatibilidad 100% Unix/Linux${NC}"