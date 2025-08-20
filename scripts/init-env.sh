#!/bin/bash

echo "=== INICIALIZACIÓN DE ENTORNO DOCKER PARA LARAVEL ==="
echo

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para generar APP_KEY
generate_app_key() {
    echo -e "${YELLOW}Generando nueva APP_KEY...${NC}"
    
    # Generar APP_KEY usando openssl
    local app_key="base64:$(openssl rand -base64 32)"
    echo "$app_key"
}

# 1. Verificar si existe .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}📁 Archivo .env no encontrado. Creando desde .env.example...${NC}"
    
    if [ ! -f ".env.example" ]; then
        echo -e "${RED}❌ Error: .env.example no encontrado${NC}"
        exit 1
    fi
    
    cp .env.example .env
    echo -e "${GREEN}✅ Archivo .env creado${NC}"
else
    echo -e "${GREEN}✅ Archivo .env ya existe${NC}"
fi

# 2. Verificar APP_KEY
current_key=$(grep "^APP_KEY=" .env | cut -d'=' -f2)
if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
    echo -e "${YELLOW}🔑 APP_KEY vacía. Generando nueva clave...${NC}"
    
    new_key=$(generate_app_key)
    
    # Actualizar APP_KEY en .env
    if grep -q "^APP_KEY=" .env; then
        sed -i "s|^APP_KEY=.*|APP_KEY=$new_key|" .env
    else
        echo "APP_KEY=$new_key" >> .env
    fi
    
    echo -e "${GREEN}✅ Nueva APP_KEY generada: ${new_key:0:20}...${NC}"
else
    echo -e "${GREEN}✅ APP_KEY ya configurada: ${current_key:0:20}...${NC}"
fi

# 3. Verificar DB_PASSWORD
current_db_pass=$(grep "^DB_PASSWORD=" .env | cut -d'=' -f2)
if [ "$current_db_pass" = "change_me_please" ] || [ -z "$current_db_pass" ]; then
    echo -e "${YELLOW}🔐 DB_PASSWORD por defecto detectada. Generando contraseña segura...${NC}"
    
    new_db_pass="dgsuc_$(openssl rand -hex 8)_$(date +%Y)"
    
    if grep -q "^DB_PASSWORD=" .env; then
        sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$new_db_pass|" .env
    else
        echo "DB_PASSWORD=$new_db_pass" >> .env
    fi
    
    echo -e "${GREEN}✅ Nueva DB_PASSWORD generada${NC}"
else
    echo -e "${GREEN}✅ DB_PASSWORD ya configurada${NC}"
fi

# 4. Verificar APP_ENV para desarrollo local
current_env=$(grep "^APP_ENV=" .env | cut -d'=' -f2)
if [ "$current_env" != "local" ]; then
    echo -e "${YELLOW}🔧 Configurando APP_ENV=local para desarrollo...${NC}"
    sed -i "s|^APP_ENV=.*|APP_ENV=local|" .env
    echo -e "${GREEN}✅ APP_ENV configurado como local${NC}"
fi

# 5. Configurar bases de datos externas (si no existen)
echo -e "${YELLOW}🗄️  Configurando bases de datos externas...${NC}"

# DB2 (externa)
if ! grep -q "^DB2_HOST=" .env; then
    echo "
# --- DATABASES EXTERNAS ---
# DB2 - Externa (otra aplicación)
DB2_CONNECTION=pgsql
DB2_HOST=postgres
DB2_PORT=5432
DB2_DATABASE=liqui
DB2_USERNAME=dgsuc_user
DB2_PASSWORD=dgsuc_password_2024" >> .env
    echo -e "${GREEN}✅ Variables DB2 añadidas${NC}"
fi

# DB3 (externa)  
if ! grep -q "^DB3_HOST=" .env; then
    echo "
# DB3 - Externa (otra aplicación)
DB3_CONNECTION=pgsql
DB3_HOST=postgres
DB3_PORT=5432
DB3_DATABASE=liqui
DB3_USERNAME=dgsuc_user
DB3_PASSWORD=dgsuc_password_2024" >> .env
    echo -e "${GREEN}✅ Variables DB3 añadidas${NC}"
fi

# DB_PROD (para conexión pgsql-prod)
if ! grep -q "^DB_PROD_HOST=" .env; then
    echo "
# DB_PROD - Para conexión pgsql-prod
DB_PROD_HOST=postgres
DB_PROD_PORT=5432
DB_PROD_DATABASE=mapuche
DB_PROD_USERNAME=dgsuc_user
DB_PROD_PASSWORD=dgsuc_password_2024" >> .env
    echo -e "${GREEN}✅ Variables DB_PROD añadidas${NC}"
fi

# DB_TEST (para conexiones de test)
if ! grep -q "^DB_TEST_HOST=" .env; then
    echo "
# DB_TEST - Para conexiones de test
DB_TEST_HOST=postgres
DB_TEST_PORT=5432
DB_TEST_DATABASE=sicoss_test
DB_TEST_USERNAME=dgsuc_user
DB_TEST_PASSWORD=dgsuc_password_2024" >> .env
    echo -e "${GREEN}✅ Variables DB_TEST añadidas${NC}"
fi

echo
echo -e "${GREEN}🎉 Inicialización completada. Tu entorno está listo para usar.${NC}"
echo
echo "Próximos pasos:"
echo "1. docker-compose up -d"
echo "2. make composer install"
echo "3. Acceder a http://localhost:8080"
echo
echo -e "${YELLOW}📊 CONFIGURACIÓN DE BASES DE DATOS:${NC}"
echo "• DB (principal): Contenedor interno PostgreSQL"
echo "• DB2: Externa en host.docker.internal:5432"
echo "• DB3: Externa en host.docker.internal:5433"
echo
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "• No commitees el archivo .env al repositorio"
echo "• Ajusta las credenciales de DB2 y DB3 según tus bases externas"
