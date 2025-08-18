#!/bin/bash

# Script para crear certificados SSL autofirmados para desarrollo
# Estos certificados son SOLO para desarrollo local

set -e

CERTS_DIR="docker/nginx/certs"
CERT_FILE="$CERTS_DIR/development.crt"
KEY_FILE="$CERTS_DIR/development.key"

echo "🔐 Creando certificados SSL para desarrollo..."

# Crear directorio si no existe
mkdir -p "$CERTS_DIR"

# Verificar si ya existen los certificados
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "ℹ️  Los certificados de desarrollo ya existen."
    echo "📁 Ubicación: $CERTS_DIR/"
    exit 0
fi

# Crear certificados autofirmados
echo "🔨 Generando certificados autofirmados..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=AR/ST=CABA/L=Buenos Aires/O=UBA/OU=DGSUC/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1"

# Verificar que se crearon correctamente
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "✅ Certificados SSL de desarrollo creados exitosamente:"
    echo "   📄 Certificado: $CERT_FILE"
    echo "   🔑 Clave privada: $KEY_FILE"
    echo ""
    echo "⚠️  NOTA: Estos certificados son SOLO para desarrollo local."
    echo "   El navegador mostrará una advertencia de seguridad que puedes ignorar."
else
    echo "❌ Error: No se pudieron crear los certificados SSL"
    exit 1
fi
