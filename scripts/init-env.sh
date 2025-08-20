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

echo
echo -e "${GREEN}🎉 Inicialización completada. Tu entorno está listo para usar.${NC}"
echo
echo "Próximos pasos:"
echo "1. docker-compose up -d"
echo "2. make composer install"
echo "3. Acceder a http://localhost:8080"
echo
echo -e "${YELLOW}⚠️  IMPORTANTE: No commitees el archivo .env al repositorio${NC}"
