# SSH Tunnels Service

Este servicio maneja 4 túneles SSH para conectar a bases de datos externas con 2 niveles de acceso diferentes.

## 🔑 Autenticación SSH

**Método**: Autenticación por clave pública via **Docker Secrets**
- **2 usuarios SSH diferentes**: `dgsuc_app_ro` (solo lectura), `dgsuc_app_rw` (lectura/escritura)
- **2 claves SSH separadas** para mayor seguridad
- **NO usa passwords**
- **Claves SSH almacenadas como Docker Secrets encriptadas**

## 🔐 Docker Secrets requeridos

```bash
# Crear en Portainer: https://portainer.uba.ar/#!/1/docker/secrets
ssh_private_key_ro      # Clave privada para dgsuc_app_ro (REQUERIDO)
ssh_public_key_ro       # Clave pública para dgsuc_app_ro (opcional)
ssh_private_key_rw      # Clave privada para dgsuc_app_rw (REQUERIDO) 
ssh_public_key_rw       # Clave pública para dgsuc_app_rw (opcional)
```

## 🌉 Túneles configurados

| Túnel | Servidor | Puerto Local | Usuario SSH | Conexiones Laravel | Clave SSH |
|-------|----------|--------------|-------------|-------------------|-----------|
| **1** | `dbprod.uba.ar` | `5434` | `dgsuc_app_ro` | `pgsql-prod-old` | `id_rsa_ro` |
| **2** | `dbprodr2.uba.ar` | `5436` | `dgsuc_app_rw` | `pgsql-prod` | `id_rsa_rw` |
| **3** | `dbtest.uba.ar` | `5433` | `dgsuc_app_ro` | `pgsql-2503` a `pgsql-2506` | `id_rsa_ro` |
| **4** | `dbtestr2.uba.ar` | `5435` | `dgsuc_app_rw` | `pgsql-2507` a `pgsql-2512` | `id_rsa_rw` |

## 🔧 Variables de entorno

```bash
# Túnel 1: DB Producción (RO)
SSH_HOST_DBPROD=dbprod.uba.ar
SSH_USER_DBPROD=dgsuc_app_ro
SSH_PORT_DBPROD=22

# Túnel 2: DB Producción R2 (RW)
SSH_HOST_DBPRODR2=dbprodr2.uba.ar
SSH_USER_DBPRODR2=dgsuc_app_rw
SSH_PORT_DBPRODR2=22

# Túnel 3: DB Test (RO)
SSH_HOST_DBTEST=dbtest.uba.ar
SSH_USER_DBTEST=dgsuc_app_ro
SSH_PORT_DBTEST=22

# Túnel 4: DB Test R2 (RW)
SSH_HOST_DBTESTR2=dbtestr2.uba.ar
SSH_USER_DBTESTR2=dgsuc_app_rw
SSH_PORT_DBTESTR2=22
```

## ✅ Health Check

El contenedor verifica automáticamente:
- ✅ Procesos `autossh` activos
- ✅ Puertos locales `5433`, `5434`, `5435`, `5436` escuchando
- ✅ Estado de cada uno de los 4 túneles individualmente
- ✅ Validación de claves SSH RO y RW por separado

## 📋 Pasos de configuración

### 1. Generar 2 pares de claves SSH
```bash
# Clave para usuario READ-ONLY
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_ro -N "" -C "dgsuc_app_ro@dgsuc.uba.ar"

# Clave para usuario READ-WRITE
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_rw -N "" -C "dgsuc_app_rw@dgsuc.uba.ar"
```

### 2. Crear 4 Docker Secrets en Portainer
```bash
# Ir a https://portainer.uba.ar/#!/1/docker/secrets y crear:

# 1. ssh_private_key_ro:
#    - Nombre: ssh_private_key_ro
#    - Contenido: [contenido de ~/.ssh/id_rsa_ro]

# 2. ssh_public_key_ro:
#    - Nombre: ssh_public_key_ro  
#    - Contenido: [contenido de ~/.ssh/id_rsa_ro.pub]

# 3. ssh_private_key_rw:
#    - Nombre: ssh_private_key_rw
#    - Contenido: [contenido de ~/.ssh/id_rsa_rw]

# 4. ssh_public_key_rw:
#    - Nombre: ssh_public_key_rw
#    - Contenido: [contenido de ~/.ssh/id_rsa_rw.pub]
```

### 3. Autorizar claves públicas en servidores destino
```bash
# Autorizar clave RO en servidores de solo lectura
ssh-copy-id -i ~/.ssh/id_rsa_ro.pub dgsuc_app_ro@dbprod.uba.ar
ssh-copy-id -i ~/.ssh/id_rsa_ro.pub dgsuc_app_ro@dbtest.uba.ar

# Autorizar clave RW en servidores de lectura/escritura  
ssh-copy-id -i ~/.ssh/id_rsa_rw.pub dgsuc_app_rw@dbprodr2.uba.ar
ssh-copy-id -i ~/.ssh/id_rsa_rw.pub dgsuc_app_rw@dbtestr2.uba.ar
```

### 4. Verificar conectividad SSH
```bash
# Test conexiones READ-ONLY
ssh -i ~/.ssh/id_rsa_ro dgsuc_app_ro@dbprod.uba.ar "echo 'DB Prod RO OK'"
ssh -i ~/.ssh/id_rsa_ro dgsuc_app_ro@dbtest.uba.ar "echo 'DB Test RO OK'"

# Test conexiones READ-WRITE
ssh -i ~/.ssh/id_rsa_rw dgsuc_app_rw@dbprodr2.uba.ar "echo 'DB Prod RW OK'"
ssh -i ~/.ssh/id_rsa_rw dgsuc_app_rw@dbtestr2.uba.ar "echo 'DB Test RW OK'"
```

### 5. Variables ya configuradas en .env.portainer
```bash
# Las variables están preconfiguradas para los 4 túneles
# Solo asegúrate de que los hosts sean correctos
```

## 🐛 Troubleshooting

### Ver logs del contenedor
```bash
docker logs <container_id>
```

### Verificar túneles activos
```bash
# Ejecutar dentro del contenedor
ps aux | grep autossh
netstat -tlpn | grep -E ":(5433|5434|5435|5436)"
```

### Test manual de túnel
```bash
# Test túnel DB Test RO (puerto 5433) - pgsql-2503 a pgsql-2506
telnet localhost 5433

# Test túnel DB Prod RO (puerto 5434) - pgsql-prod-old  
telnet localhost 5434

# Test túnel DB Test RW (puerto 5435) - pgsql-2507 a pgsql-2512
telnet localhost 5435

# Test túnel DB Prod RW (puerto 5436) - pgsql-prod
telnet localhost 5436
```