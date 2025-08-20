#!/bin/bash
set -e

# Configurar autenticación md5 para mejor compatibilidad con Laravel
echo "Configurando autenticación PostgreSQL para Laravel..."

# Reemplazar la configuración de autenticación
sed -i 's/host all all all scram-sha-256/host all all all md5/' /var/lib/postgresql/data/pg_hba.conf

echo "Configuración PostgreSQL completada."
