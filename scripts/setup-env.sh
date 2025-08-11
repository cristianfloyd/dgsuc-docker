#!/bin/bash
# scripts/setup-env.sh

set -e

echo "🔧 Configurando variables de entorno para DGSUC..."

# Verificar si existe .env
if [ ! -f .env ]; then
    echo "📝 Creando archivo .env desde .env.example..."
    cp .env.example .env
    
    # Generar APP_KEY
    echo "🔑 Generando APP_KEY..."
    php artisan key:generate --force
    
    echo "✅ Archivo .env creado exitosamente"
else
    echo "ℹ️  El archivo .env ya existe"
fi

# Verificar variables críticas
echo "🔍 Verificando variables críticas..."

CRITICAL_VARS=(
    "APP_KEY"
    "DB_PASSWORD"
    "MAPUCHE_SSH_HOST"
    "MAPUCHE_SSH_USER"
)

for var in "${CRITICAL_VARS[@]}"; do
    if grep -q "^${var}=$" .env || grep -q "^${var}=YOUR_" .env; then
        echo "⚠️  Variable crítica no configurada: $var"
    fi
done

echo "🎉 Configuración completada!"
echo "📋 Recuerda configurar las variables sensibles en .env.secrets"
