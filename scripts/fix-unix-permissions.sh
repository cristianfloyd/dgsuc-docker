#!/bin/bash
# =============================================================================
# SCRIPT PARA NORMALIZAR PERMISOS UNIX/LINUX
# =============================================================================

set -e

echo "🔧 Normalizando permisos para compatibilidad Unix/Linux..."

# Directorio base del proyecto
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 Estableciendo permisos básicos de directorios y archivos..."

# Permisos estándar para directorios (755)
find . -type d -not -path "./.*" -not -path "./app/vendor/*" -not -path "./app/node_modules/*" -exec chmod 755 {} \;

# Permisos estándar para archivos (644)
find . -type f -not -path "./.*" -not -path "./app/vendor/*" -not -path "./app/node_modules/*" -not -name "*.sh" -exec chmod 644 {} \;

echo "🔨 Estableciendo permisos ejecutables para scripts..."

# Scripts ejecutables (755)
find . -name "*.sh" -not -path "./app/vendor/*" -exec chmod 755 {} \;

# Artisan ejecutable
if [ -f "app/artisan" ]; then
    chmod 755 app/artisan
    echo "✅ app/artisan ahora es ejecutable"
fi

echo "🗂️ Configurando permisos especiales para Laravel..."

# Directorios de Laravel que necesitan escritura
LARAVEL_WRITABLE_DIRS=(
    "app/storage"
    "app/storage/app"
    "app/storage/framework"
    "app/storage/framework/cache"
    "app/storage/framework/sessions"
    "app/storage/framework/views"
    "app/storage/logs"
    "app/bootstrap/cache"
)

for dir in "${LARAVEL_WRITABLE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        chmod -R 775 "$dir"
        echo "✅ $dir configurado con permisos 775"
    fi
done

echo "🐳 Configurando permisos para archivos Docker..."

# Archivos Docker ejecutables
DOCKER_FILES=(
    "docker/app/entrypoint.sh"
    "docker/workers/entrypoint.sh"
    "docker/app/fix-permissions.sh"
)

for file in "${DOCKER_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 755 "$file"
        echo "✅ $file ahora es ejecutable"
    fi
done

echo "📄 Verificando archivos de configuración..."

# Archivos de configuración sensibles (solo lectura para otros)
CONFIG_FILES=(
    ".env"
    ".env.example"
    "app/.env"
    "app/.env.example"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 640 "$file"
        echo "✅ $file configurado con permisos 640 (seguro)"
    fi
done

echo "🔍 Resumen de permisos establecidos:"
echo "  📁 Directorios: 755 (rwxr-xr-x)"
echo "  📄 Archivos: 644 (rw-r--r--)"
echo "  🔨 Scripts (.sh): 755 (rwxr-xr-x)"
echo "  🗂️ Storage/cache: 775 (rwxrwxr-x)"
echo "  🔒 Config files: 640 (rw-r-----)"

echo ""
echo "✅ Permisos Unix/Linux normalizados correctamente!"
echo "🚀 El repositorio ahora es compatible con sistemas Unix/Linux"