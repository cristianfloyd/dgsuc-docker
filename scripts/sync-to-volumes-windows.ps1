# ============================================================================
# Script para sincronizar código desde Windows hacia volúmenes Docker
# ============================================================================

param(
    [string]$Action = "sync-all",
    [string]$Path = "",
    [switch]$Watch = $false
)

# Configuración
$PROJECT_NAME = "dgsuc-docker"
$APP_VOLUME = "${PROJECT_NAME}_app_code"
$NGINX_VOLUME = "${PROJECT_NAME}_nginx_config"
$COMPOSER_VOLUME = "${PROJECT_NAME}_composer_cache"

# Colores para output
$COLOR_GREEN = "Green"
$COLOR_YELLOW = "Yellow"
$COLOR_RED = "Red"
$COLOR_BLUE = "Blue"

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host "🔄 $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $COLOR_GREEN
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $COLOR_RED
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $COLOR_YELLOW
}

function Sync-AppCode {
    Write-Status "Sincronizando código de aplicación..."
    
    # Verificar que el directorio app existe
    if (-not (Test-Path "app")) {
        Write-Error "Directorio 'app' no encontrado"
        return $false
    }
    
    # Crear contenedor temporal para copiar archivos
    $tempContainer = "temp_sync_$(Get-Random)"
    
    try {
        # Crear contenedor temporal con el volumen montado
        docker run -d --name $tempContainer -v "${APP_VOLUME}:/sync" alpine:latest tail -f /dev/null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error al crear contenedor temporal"
            return $false
        }
        
        # Copiar archivos de la aplicación
        Write-Status "Copiando archivos de aplicación..."
        docker cp "app/." "${tempContainer}:/sync/"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Código de aplicación sincronizado"
            return $true
        } else {
            Write-Error "Error al copiar código de aplicación"
            return $false
        }
    }
    finally {
        # Limpiar contenedor temporal
        docker rm -f $tempContainer 2>$null
    }
}

function Sync-NginxConfig {
    Write-Status "Sincronizando configuración de Nginx..."
    
    # Verificar que el directorio de configuración existe
    if (-not (Test-Path "docker/nginx/sites")) {
        Write-Error "Directorio 'docker/nginx/sites' no encontrado"
        return $false
    }
    
    # Crear contenedor temporal para copiar archivos
    $tempContainer = "temp_nginx_sync_$(Get-Random)"
    
    try {
        # Crear contenedor temporal con el volumen montado
        docker run -d --name $tempContainer -v "${NGINX_VOLUME}:/sync" alpine:latest tail -f /dev/null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error al crear contenedor temporal para Nginx"
            return $false
        }
        
        # Copiar configuración de Nginx para desarrollo
        Write-Status "Copiando configuración de Nginx para desarrollo..."
        docker cp "docker/nginx/sites/development.conf" "${tempContainer}:/sync/default.conf"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Configuración de Nginx sincronizada"
            return $true
        } else {
            Write-Error "Error al copiar configuración de Nginx"
            return $false
        }
    }
    finally {
        # Limpiar contenedor temporal
        docker rm -f $tempContainer 2>$null
    }
}

function Sync-SpecificFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "Archivo no encontrado: $FilePath"
        return $false
    }
    
    Write-Status "Sincronizando archivo: $FilePath"
    
    # Determinar el volumen de destino basado en la ruta
    $targetVolume = $APP_VOLUME
    $targetPath = "/sync"
    
    if ($FilePath.StartsWith("docker/nginx/")) {
        $targetVolume = $NGINX_VOLUME
        $FilePath = $FilePath -replace "docker/nginx/sites/", ""
    } elseif ($FilePath.StartsWith("app/")) {
        $FilePath = $FilePath -replace "app/", ""
    }
    
    # Crear contenedor temporal
    $tempContainer = "temp_file_sync_$(Get-Random)"
    
    try {
        docker run -d --name $tempContainer -v "${targetVolume}:/sync" alpine:latest tail -f /dev/null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error al crear contenedor temporal"
            return $false
        }
        
        # Copiar archivo específico
        $parentDir = Split-Path -Parent $FilePath
        if ($parentDir) {
            docker exec $tempContainer mkdir -p "/sync/$parentDir"
        }
        
        docker cp $FilePath "${tempContainer}:/sync/$FilePath"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Archivo sincronizado: $FilePath"
            return $true
        } else {
            Write-Error "Error al sincronizar archivo: $FilePath"
            return $false
        }
    }
    finally {
        docker rm -f $tempContainer 2>$null
    }
}

function Show-Help {
    Write-Host @"
🔄 Script de Sincronización para Volúmenes Docker (Windows)

USO:
    .\sync-to-volumes-windows.ps1 [ACCIÓN] [OPCIONES]

ACCIONES:
    sync-all          Sincronizar todo el código y configuración
    sync-app          Sincronizar solo código de aplicación
    sync-nginx        Sincronizar solo configuración de Nginx
    sync-file         Sincronizar archivo específico (requiere -Path)
    help              Mostrar esta ayuda

OPCIONES:
    -Path <ruta>      Ruta del archivo específico a sincronizar
    -Watch            Monitorear cambios y sincronizar automáticamente (futuro)

EJEMPLOS:
    .\sync-to-volumes-windows.ps1 sync-all
    .\sync-to-volumes-windows.ps1 sync-app
    .\sync-to-volumes-windows.ps1 sync-file -Path "app/config/app.php"

VOLÚMENES:
    app_code:         $APP_VOLUME
    nginx_config:     $NGINX_VOLUME
    composer_cache:   $COMPOSER_VOLUME
"@ -ForegroundColor $COLOR_BLUE
}

# Función principal
function Main {
    Write-Host "🚀 Sincronización de Volúmenes Docker para Windows" -ForegroundColor $COLOR_BLUE
    Write-Host "=================================================" -ForegroundColor $COLOR_BLUE
    
    switch ($Action.ToLower()) {
        "sync-all" {
            Write-Status "Iniciando sincronización completa..."
            $appResult = Sync-AppCode
            $nginxResult = Sync-NginxConfig
            
            if ($appResult -and $nginxResult) {
                Write-Success "Sincronización completa exitosa"
            } else {
                Write-Error "Error en la sincronización"
                exit 1
            }
        }
        
        "sync-app" {
            if (Sync-AppCode) {
                Write-Success "Sincronización de aplicación exitosa"
            } else {
                Write-Error "Error en sincronización de aplicación"
                exit 1
            }
        }
        
        "sync-nginx" {
            if (Sync-NginxConfig) {
                Write-Success "Sincronización de Nginx exitosa"
            } else {
                Write-Error "Error en sincronización de Nginx"
                exit 1
            }
        }
        
        "sync-file" {
            if (-not $Path) {
                Write-Error "Debe especificar -Path para sincronizar archivo específico"
                exit 1
            }
            
            if (Sync-SpecificFile -FilePath $Path) {
                Write-Success "Sincronización de archivo exitosa"
            } else {
                Write-Error "Error en sincronización de archivo"
                exit 1
            }
        }
        
        "help" {
            Show-Help
        }
        
        default {
            Write-Error "Acción no válida: $Action"
            Show-Help
            exit 1
        }
    }
}

# Ejecutar función principal
Main
