#!/bin/bash

echo "=== FIX APP_KEY ISSUE ==="
echo

# 1. Verificar archivo .env
echo "1. Verificando archivo .env..."
if [ ! -f "./app/.env" ]; then
    echo "   ❌ Archivo .env no existe. Creando desde .env.example..."
    if [ -f "./app/.env.example" ]; then
        cp ./app/.env.example ./app/.env
        echo "   ✅ Archivo .env creado"
    else
        echo "   ❌ Tampoco existe .env.example"
        exit 1
    fi
else
    echo "   ✅ Archivo .env existe"
fi

# 2. Verificar APP_KEY en .env
echo "2. Verificando APP_KEY..."
APP_KEY=$(grep "^APP_KEY=" ./app/.env | cut -d'=' -f2)
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "" ]; then
    echo "   ❌ APP_KEY vacía o no existe"
    echo "   🔧 Generando nueva APP_KEY..."
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php artisan key:generate
    echo "   ✅ APP_KEY generada"
else
    echo "   ✅ APP_KEY existe: ${APP_KEY:0:20}..."
fi

# 3. Limpiar caché de configuración
echo "3. Limpiando caché de configuración..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php artisan config:clear
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php artisan cache:clear
echo "   ✅ Caché limpiado"

# 4. Verificar extensiones PHP críticas
echo "4. Verificando extensiones PHP en contenedor..."
echo "   📋 Extensiones disponibles:"
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php -m | grep -E "(openssl|ctype|mbstring|json|Core)" | sort

MISSING_EXTENSIONS=""
for ext in openssl ctype mbstring; do
    if ! docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php -m | grep -q "^$ext$"; then
        MISSING_EXTENSIONS="$MISSING_EXTENSIONS $ext"
    fi
done

# Verificar json (puede estar en Core)
if ! docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php -m | grep -qE "^(json|Core)$"; then
    MISSING_EXTENSIONS="$MISSING_EXTENSIONS json"
fi

if [ -n "$MISSING_EXTENSIONS" ]; then
    echo "   ❌ Extensiones faltantes:$MISSING_EXTENSIONS"
    echo "   🔧 Nota: openssl, ctype y json deberían estar incluidas en PHP 8.4 por defecto"
    echo "   Verifica la construcción del contenedor: docker-compose build app"
else
    echo "   ✅ Todas las extensiones críticas están disponibles"
fi

# 5. Verificar que Laravel puede leer APP_KEY
echo "5. Probando lectura de APP_KEY en Laravel..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app php -r "
    try {
        \$key = env('APP_KEY');
        if (empty(\$key)) {
            echo '   ❌ APP_KEY no se puede leer desde env()' . PHP_EOL;
            exit(1);
        }
        
        // Verificar si es base64
        if (strpos(\$key, 'base64:') === 0) {
            \$decoded = base64_decode(substr(\$key, 7));
            if (\$decoded === false) {
                echo '   ❌ APP_KEY base64 inválida' . PHP_EOL;
                exit(1);
            }
            echo '   ✅ APP_KEY base64 válida (' . strlen(\$decoded) . ' bytes)' . PHP_EOL;
        } else {
            echo '   ⚠️  APP_KEY no está en formato base64' . PHP_EOL;
        }
        
        // Verificar que Laravel puede usar la clave
        if (function_exists('config')) {
            \$appKey = config('app.key');
            if (empty(\$appKey)) {
                echo '   ❌ Laravel no puede acceder a app.key' . PHP_EOL;
                exit(1);
            }
            echo '   ✅ Laravel puede acceder a la configuración' . PHP_EOL;
        }
        
    } catch (Exception \$e) {
        echo '   ❌ Error: ' . \$e->getMessage() . PHP_EOL;
        exit(1);
    }
"

# 6. Verificar diferencias de encoding
echo "6. Verificando encoding del archivo .env..."
file_encoding=$(file -b --mime-encoding ./app/.env)
echo "   📄 Encoding del archivo: $file_encoding"

if [ "$file_encoding" != "us-ascii" ] && [ "$file_encoding" != "utf-8" ]; then
    echo "   ⚠️  Encoding puede causar problemas. Recomendado: UTF-8"
    echo "   🔧 Convirtiendo a UTF-8..."
    iconv -f "$file_encoding" -t UTF-8 ./app/.env > ./app/.env.tmp && mv ./app/.env.tmp ./app/.env
    echo "   ✅ Archivo convertido a UTF-8"
fi

echo
echo "=== RESUMEN ==="
echo "Si aún tienes problemas:"
echo "1. Reconstruye el contenedor: docker-compose build app"
echo "2. Reinicia los servicios: docker-compose down && docker-compose up -d"
echo "3. Verifica los logs: docker-compose logs app"
echo
