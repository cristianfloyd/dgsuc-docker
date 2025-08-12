#!/bin/bash
# Script para generar instrucciones de instalación manual de claves SSH
# Autor: AI Assistant

set -e

echo "=== Instalación Manual de Clave SSH ==="
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -d "ssh-keys" ]; then
    echo "Error: No se encontró el directorio ssh-keys. Ejecuta este script desde la raíz del proyecto."
    exit 1
fi

# Mostrar claves disponibles
echo "Claves SSH disponibles:"
ls -la ssh-keys/*.pub 2>/dev/null || echo "No se encontraron claves públicas"
echo ""

# Seleccionar clave
echo "Selecciona la clave a instalar:"
echo "1) mapuche_ed25519 (ED25519 - recomendada)"
echo "2) mapuchedbprod (RSA - para túneles)"
read -p "Ingresa tu elección (1-2): " choice

case $choice in
    1)
        KEY_NAME="mapuche_ed25519"
        ;;
    2)
        KEY_NAME="mapuchedbprod"
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

PRIVATE_KEY="ssh-keys/$KEY_NAME"
PUBLIC_KEY="ssh-keys/$KEY_NAME.pub"

if [ ! -f "$PRIVATE_KEY" ] || [ ! -f "$PUBLIC_KEY" ]; then
    echo "Error: No se encontraron las claves SSH: $PRIVATE_KEY y $PUBLIC_KEY"
    exit 1
fi

echo ""
echo "Usando clave: $KEY_NAME"
echo ""

# Leer contenido de la clave pública
PUBLIC_KEY_CONTENT=$(cat "$PUBLIC_KEY")

echo "=== INSTRUCCIONES DE INSTALACIÓN MANUAL ==="
echo ""
echo "El servidor 172.17.128.1 está configurado para solo aceptar autenticación por clave pública."
echo "Para instalar la clave SSH, necesitas acceso directo al servidor o ayuda del administrador."
echo ""
echo "OPCIÓN 1: Si tienes acceso directo al servidor (recomendado)"
echo "----------------------------------------"
echo "1. Conéctate directamente al servidor 172.17.128.1"
echo "2. Ejecuta estos comandos como usuario 'arca':"
echo ""
echo "   mkdir -p ~/.ssh"
echo "   chmod 700 ~/.ssh"
echo "   echo '$PUBLIC_KEY_CONTENT' >> ~/.ssh/authorized_keys"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "OPCIÓN 2: Solicitar ayuda al administrador"
echo "----------------------------------------"
echo "Si no tienes acceso directo, contacta al administrador del servidor y proporciona:"
echo ""
echo "Usuario: arca"
echo "Clave pública:"
echo "$PUBLIC_KEY_CONTENT"
echo ""
echo "OPCIÓN 3: Usar otra clave existente"
echo "----------------------------------------"
echo "Si ya tienes otra clave SSH configurada en el servidor, puedes:"
echo "1. Usar esa clave para conectarte"
echo "2. Luego instalar esta nueva clave"
echo ""
echo "OPCIÓN 4: Verificar configuración actual"
echo "----------------------------------------"
echo "Para verificar qué claves están actualmente configuradas en el servidor:"
echo "ssh -i [clave_existente] arca@172.17.128.1 'cat ~/.ssh/authorized_keys'"
echo ""

# Generar script de instalación
INSTALL_SCRIPT="install-$KEY_NAME.sh"
cat > "$INSTALL_SCRIPT" << EOF
#!/bin/bash
# Script para instalar clave SSH $KEY_NAME en el servidor
# Ejecutar en el servidor remoto como usuario arca

echo "Instalando clave SSH $KEY_NAME..."

# Crear directorio .ssh si no existe
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Agregar clave pública
echo '$PUBLIC_KEY_CONTENT' >> ~/.ssh/authorized_keys

# Configurar permisos correctos
chmod 600 ~/.ssh/authorized_keys

echo "Clave SSH instalada exitosamente!"
echo "Ahora puedes conectarte usando:"
echo "ssh -i ssh-keys/$KEY_NAME arca@172.17.128.1"
EOF

chmod +x "$INSTALL_SCRIPT"

echo "=== ARCHIVOS GENERADOS ==="
echo "Se ha generado el script de instalación: $INSTALL_SCRIPT"
echo "Copia este archivo al servidor y ejecútalo como usuario arca"
echo ""

# Mostrar información de verificación
echo "=== VERIFICACIÓN ==="
echo "Después de instalar la clave, prueba la conexión con:"
echo "ssh -i $PRIVATE_KEY arca@172.17.128.1 'echo SSH connection successful'"
echo ""

# Mostrar información de configuración del proyecto
echo "=== CONFIGURACIÓN DEL PROYECTO ==="
echo "Para usar esta clave en el proyecto Docker:"
echo "1. Verifica que SSH_PRIVATE_KEY_PATH en docker-compose.yml apunte a: /etc/ssh-keys/$KEY_NAME"
echo "2. Verifica que el volumen SSH_KEYS_PATH incluya el directorio ssh-keys"
echo "3. Asegúrate de que los permisos de la clave privada sean 600"
echo ""

echo "=== NOTAS IMPORTANTES ==="
echo "- Nunca compartas la clave privada"
echo "- Mantén copias de seguridad de las claves"
echo "- Si el problema persiste, verifica los logs SSH en el servidor"
echo ""

echo "Script completado."
