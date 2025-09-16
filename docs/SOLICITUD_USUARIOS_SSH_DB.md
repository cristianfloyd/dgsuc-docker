# Solicitud de Creación de Usuarios SSH y Base de Datos

## Usuarios Requeridos

### 1. Usuario SSH: `dgsuc_app_ro` (Solo Lectura)

**Propósito:** Conexiones SSH de solo lectura para túneles a bases de datos de producción.

**Servidores de destino:**
- `10.5.20.96` - mapuchedb2025 (NUEVO PROD R2)
- `10.5.20.90` - mapuchedbprod (VIEJO PROD R2)

**Permisos SSH requeridos:**
- ✅ Acceso SSH con autenticación por clave pública
- ✅ Capacidad de crear túneles SSH (port forwarding)
- ❌ **NO** acceso a shell interactivo
- ❌ **NO** permisos de escritura en el sistema



### 2. Usuario SSH: `dgsuc_app_rw` (Lectura/Escritura)

**Propósito:** Conexiones SSH con permisos de lectura/escritura para túneles a bases de datos de testing y consulta.

**Servidores de destino:**
- `10.5.14.197` - mapuchedbtest (VIEJO TEST 28.1)
- `10.5.14.121` - mapuchetestdb2025 (NUEVO TEST R2)
- `10.5.20.92` - mapucheconsulta

**Permisos SSH requeridos:**
- ✅ Acceso SSH con autenticación por clave pública
- ✅ Capacidad de crear túneles SSH (port forwarding)
- ❌ **NO** acceso a shell interactivo
- ❌ **NO** permisos de escritura en el sistema


## 🗄️ Usuarios de Base de Datos

### 1. Usuario DB: `dgsuc_app_ro` (Solo Lectura)

**Bases de datos de acceso:**
- Bases de datos en `10.5.20.96` - mapuchedb2025 (NUEVO PROD R2)
- Bases de datos en `10.5.20.90` - mapuchedbprod (VIEJO PROD R2)

**Permisos de base de datos requeridos:**
```sql
-- Solo lectura en esquemas mapuche y toba_mapuche
GRANT USAGE ON SCHEMA mapuche TO dgsuc_app_ro;
GRANT USAGE ON SCHEMA toba_mapuche TO dgsuc_app_ro;

GRANT SELECT ON ALL TABLES IN SCHEMA mapuche TO dgsuc_app_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA toba_mapuche TO dgsuc_app_ro;

-- Permisos para tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA mapuche GRANT SELECT ON TABLES TO dgsuc_app_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA toba_mapuche GRANT SELECT ON TABLES TO dgsuc_app_ro;

-- Propietario en esquema suc
GRANT ALL PRIVILEGES ON SCHEMA suc TO dgsuc_app_ro;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA suc TO dgsuc_app_ro;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA suc TO dgsuc_app_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA suc GRANT ALL PRIVILEGES ON TABLES TO dgsuc_app_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA suc GRANT ALL PRIVILEGES ON SEQUENCES TO dgsuc_app_ro;
```



### 2. Usuario DB: `dgsuc_app_rw` (Lectura/Escritura)

**Bases de datos de acceso:**
- Bases de datos en `10.5.14.197` - mapuchedbtest (VIEJO TEST 28.1)
- Bases de datos en `10.5.14.121` - mapuchetestdb2025 (NUEVO TEST R2)
- Bases de datos en `10.5.20.92` - mapucheconsulta

**Permisos de base de datos requeridos:**
```sql
-- Acceso completo (lectura/escritura) en todos los esquemas
-- Esquemas: liqui, desa, falsa, 25XX, mapuche, toba_mapuche, suc, public

-- Propietario en esquema suc
GRANT ALL PRIVILEGES ON SCHEMA suc TO dgsuc_app_rw;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA suc TO dgsuc_app_rw;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA suc TO dgsuc_app_rw;

-- Full RW en otros esquemas
GRANT USAGE ON SCHEMA liqui TO dgsuc_app_rw;
GRANT USAGE ON SCHEMA desa TO dgsuc_app_rw;
GRANT USAGE ON SCHEMA falsa TO dgsuc_app_rw;
GRANT USAGE ON SCHEMA mapuche TO dgsuc_app_rw;
GRANT USAGE ON SCHEMA toba_mapuche TO dgsuc_app_rw;
GRANT USAGE ON SCHEMA public TO dgsuc_app_rw;

-- Permisos de lectura/escritura en todos los esquemas
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA liqui TO dgsuc_app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA desa TO dgsuc_app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA falsa TO dgsuc_app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA mapuche TO dgsuc_app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA toba_mapuche TO dgsuc_app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dgsuc_app_rw;

-- Permisos en secuencias
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA liqui TO dgsuc_app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA desa TO dgsuc_app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA falsa TO dgsuc_app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA mapuche TO dgsuc_app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA toba_mapuche TO dgsuc_app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dgsuc_app_rw;

-- Permisos para tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA liqui GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA desa GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA falsa GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA mapuche GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA toba_mapuche GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dgsuc_app_rw;

-- Permisos para secuencias futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA liqui GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA desa GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA falsa GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA mapuche GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA toba_mapuche GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dgsuc_app_rw;

-- Permisos para crear objetos
GRANT CREATE ON SCHEMA liqui TO dgsuc_app_rw;
GRANT CREATE ON SCHEMA desa TO dgsuc_app_rw;
GRANT CREATE ON SCHEMA falsa TO dgsuc_app_rw;
GRANT CREATE ON SCHEMA mapuche TO dgsuc_app_rw;
GRANT CREATE ON SCHEMA toba_mapuche TO dgsuc_app_rw;
GRANT CREATE ON SCHEMA public TO dgsuc_app_rw;
```


## Configuración de Claves SSH

### Generación de Claves

Se generaron 2 pares de claves SSH RSA de 4096 bits:

```bash
# Clave para usuario READ-ONLY
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_ro -N "" -C "dgsuc_app_ro@dgsuc.uba.ar"

# Clave para usuario READ-WRITE
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_rw -N "" -C "dgsuc_app_rw@dgsuc.uba.ar"
```

### Autorización de Claves

Las claves públicas deberán ser autorizadas en los servidores correspondientes:

```bash
# Autorizar clave RO en servidores de producción (solo lectura)
ssh-copy-id -i ~/.ssh/id_rsa_ro.pub dgsuc_app_ro@10.5.20.96  # mapuchedb2025
ssh-copy-id -i ~/.ssh/id_rsa_ro.pub dgsuc_app_ro@10.5.20.90  # mapuchedbprod

# Autorizar clave RW en servidores de testing y consulta (lectura/escritura)
ssh-copy-id -i ~/.ssh/id_rsa_rw.pub dgsuc_app_rw@10.5.14.197  # mapuchedbtest
ssh-copy-id -i ~/.ssh/id_rsa_rw.pub dgsuc_app_rw@10.5.14.121  # mapuchetestdb2025
ssh-copy-id -i ~/.ssh/id_rsa_rw.pub dgsuc_app_rw@10.5.20.92   # mapucheconsulta
```

## Configuración de Túneles SSH

El sistema utilizará 5 túneles SSH para conectar a las bases de datos externas:

| Túnel | Servidor | IP | Puerto Local | Usuario SSH | Conexiones Laravel | Clave SSH |
|-------|----------|----|--------------|-------------|-------------------|-----------|
| **1** | mapuchedb2025 | `10.5.20.96` | `5434` | `dgsuc_app_ro` | `pgsql-prod-new` | `id_rsa_ro` |
| **2** | mapuchedbprod | `10.5.20.90` | `5435` | `dgsuc_app_ro` | `pgsql-prod-old` | `id_rsa_ro` |
| **3** | mapuchedbtest | `10.5.14.197` | `5436` | `dgsuc_app_rw` | `pgsql-test-old` | `id_rsa_rw` |
| **4** | mapuchetestdb2025 | `10.5.14.121` | `5437` | `dgsuc_app_rw` | `pgsql-test-new` | `id_rsa_rw` |
| **5** | mapucheconsulta | `10.5.20.92` | `5438` | `dgsuc_app_rw` | `pgsql-consulta` | `id_rsa_rw` |

## 🔒 Consideraciones de Seguridad

### Principio de Menor Privilegio
- Los usuarios SSH tienen acceso **solo** para túneles, sin shell interactivo
- Los usuarios de base de datos tienen permisos **mínimos** necesarios
- Separación clara entre permisos de lectura y escritura

### Autenticación
- **Solo** autenticación por clave pública SSH (sin passwords)
- Claves RSA de 4096 bits para máxima seguridad
- Claves almacenadas como Docker Secrets encriptadas




## Notas Adicionales

1. **Backup de claves:** Las claves privadas SSH se almacenarán de forma segura como Docker Secrets
2. **Rotación de claves:** Se recomienda rotar las claves SSH cada 12 meses
3. **Documentación:** Se mantendrá documentación actualizada de la configuración


**Prioridad:** Alta
