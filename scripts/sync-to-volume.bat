@echo off
REM Script para Windows para sincronizar código al volumen interno de Docker

echo 🔄 Sincronizando código al volumen interno de Docker...

REM Verificar que Docker está ejecutándose
docker version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker no está ejecutándose. Por favor inicia Docker Desktop.
    pause
    exit /b 1
)

REM Verificar que el volumen existe
docker volume inspect dgsuc-docker_app_code >nul 2>&1
if errorlevel 1 (
    echo ⚠️  El volumen app_code no existe. Creándolo...
    docker volume create dgsuc-docker_app_code
)

REM Verificar que la carpeta app existe
if not exist "%cd%\app" (
    echo ❌ La carpeta .\app no existe. No hay nada que sincronizar.
    echo 💡 Primero clona la aplicación con: make clone
    pause
    exit /b 1
)

REM Generar nombre único para el contenedor usando timestamp simple
set container_name=sync_temp_%RANDOM%

REM Crear contenedor temporal para sincronización
echo 📦 Creando contenedor temporal para sincronización...
docker run -d --name %container_name% -v dgsuc-docker_app_code:/var/www/html -v "%cd%/app:/source:ro" alpine:latest sleep 300 > temp_container_id.txt
set /p container_id=<temp_container_id.txt
del temp_container_id.txt

echo 📦 Contenedor creado: %container_id%

REM Esperar un momento para que el contenedor esté listo
ping 127.0.0.1 -n 3 > nul

REM Sincronizar archivos
echo 📁 Copiando archivos al volumen...
docker exec %container_name% sh -c "find /var/www/html -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'storage' ! -name 'bootstrap' -exec rm -rf {} + || true && cp -r /source/. /var/www/html/ || true && chown -R 33:33 /var/www/html || true && find /var/www/html -type f -exec chmod 644 {} \; || true && find /var/www/html -type d -exec chmod 755 {} \; || true && if [ -d '/var/www/html/storage' ]; then chmod -R 775 /var/www/html/storage || true; fi && if [ -d '/var/www/html/bootstrap/cache' ]; then chmod -R 775 /var/www/html/bootstrap/cache || true; fi && echo 'Sincronización de archivos completada'"

REM Limpiar contenedor temporal
echo 🧹 Limpiando contenedor temporal...
docker stop %container_name% >nul 2>&1
docker rm %container_name% >nul 2>&1

echo ✅ Sincronización completada. El código está ahora en el volumen interno de Docker.
echo 💡 Para volver a sincronizar cambios, ejecuta este script nuevamente.