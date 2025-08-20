#!/bin/bash
set -e

echo "🔧 Ejecutando script de inicialización personalizado de PostgreSQL..."

# Cambiar método de autenticación a md5 para todos los hosts
# Esto es una solución temporal para problemas de compatibilidad con SCRAM-SHA-256 y algunos drivers PHP/Laravel
# Para producción, considerar usar SCRAM-SHA-256 con configuración de cliente apropiada o SSL.
echo "📝 Configurando autenticación md5..."
echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
echo "host all all ::/0 md5" >> "$PGDATA/pg_hba.conf"

# Crear usuario 'postgres' si no existe (para compatibilidad)
echo "👤 Creando usuario 'postgres' para compatibilidad..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
            CREATE ROLE postgres WITH SUPERUSER CREATEDB CREATEROLE LOGIN;
            ALTER ROLE postgres PASSWORD 'dgsuc_password_2024';
        END IF;
    END
    \$\$;
EOSQL

# Crear bases de datos adicionales si no existen
# Estas son para conexiones externas que Laravel necesita acceder
echo "🗄️ Creando bases de datos adicionales: mapuche, sicoss_test, liqui..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE mapuche' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mapuche')\gexec
    SELECT 'CREATE DATABASE sicoss_test' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sicoss_test')\gexec
    SELECT 'CREATE DATABASE liqui' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'liqui')\gexec
EOSQL

echo "✅ Script de inicialización personalizado de PostgreSQL finalizado."