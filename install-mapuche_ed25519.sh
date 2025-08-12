#!/bin/bash
# Script para instalar clave SSH mapuche_ed25519 en el servidor
# Ejecutar en el servidor remoto como usuario arca

echo "Instalando clave SSH mapuche_ed25519..."

# Crear directorio .ssh si no existe
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Agregar clave pública
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIE6cWyFf4T03wFiFmpd+qZM/FLVx1QTAizFDeX9IiOP dgsuc-tunnel-ed25519' >> ~/.ssh/authorized_keys

# Configurar permisos correctos
chmod 600 ~/.ssh/authorized_keys

echo "Clave SSH instalada exitosamente!"
echo "Ahora puedes conectarte usando:"
echo "ssh -i ssh-keys/mapuche_ed25519 arca@172.17.128.1"
