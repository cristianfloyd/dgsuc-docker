# DGSUC Docker Configuration Validator (PowerShell)
param(
    [switch]$Verbose
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Functions
function Write-Info { Write-Host "[OK] $args" -ForegroundColor $Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor $Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor $Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor $Blue }

# Header
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "           DGSUC Docker Configuration Validator            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$Errors = 0
$Warnings = 0

# Check Docker Compose syntax
Write-Step "Validating Docker Compose syntax..."

try {
    $null = docker-compose config 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Docker Compose syntax is valid"
    } else {
        Write-Error "Docker Compose syntax is invalid"
        docker-compose config
        $Errors++
    }
} catch {
    Write-Error "Docker Compose not found or not working"
    $Errors++
}

# Check required files
Write-Step "Checking required files..."

$RequiredFiles = @(
    "docker-compose.yml",
    "docker/app/Dockerfile",
    "docker/nginx/Dockerfile",
    "docker/nginx/nginx.conf",
    "docker/postgres/postgresql.conf",
    "docker/redis/redis.conf"
)

foreach ($file in $RequiredFiles) {
    if (Test-Path $file) {
        Write-Info "$file exists"
    } else {
        Write-Error "$file is missing"
        $Errors++
    }
}

# Check environment files
Write-Step "Checking environment configuration..."

if (Test-Path ".env.dev") {
    Write-Info ".env.dev exists"
} else {
    Write-Warn ".env.dev is missing (recommended for development)"
    $Warnings++
}

if (Test-Path ".env.prod") {
    Write-Info ".env.prod exists"
} else {
    Write-Warn ".env.prod is missing (recommended for production)"
    $Warnings++
}

# Check application directory
Write-Step "Checking application directory..."

if (Test-Path "app") {
    Write-Info "Application directory exists"
    
    # Check Laravel files
    if (Test-Path "app/.env") {
        Write-Info "Laravel .env exists"
    } else {
        Write-Warn "Laravel .env is missing"
        $Warnings++
    }
    
    if (Test-Path "app/composer.json") {
        Write-Info "Laravel composer.json exists"
    } else {
        Write-Error "Laravel composer.json is missing"
        $Errors++
    }
} else {
    Write-Warn "Application directory is missing (run ./scripts/clone-app.sh)"
    $Warnings++
}

# Check SSL certificates
Write-Step "Checking SSL configuration..."

if (Test-Path "docker/nginx/certs") {
    Write-Info "SSL certificates directory exists"
    
    if ((Test-Path "docker/nginx/certs/fullchain.pem") -and (Test-Path "docker/nginx/certs/privkey.pem")) {
        Write-Info "SSL certificates found"
    } else {
        Write-Warn "SSL certificates not found (run make ssl-setup)"
        $Warnings++
    }
} else {
    Write-Warn "SSL certificates directory is missing"
    $Warnings++
}

# Check SSH keys
Write-Step "Checking SSH configuration..."

if ((Test-Path "ssh-keys") -or (Test-Path "$env:USERPROFILE\.ssh")) {
    Write-Info "SSH keys directory exists"
} else {
    Write-Warn "SSH keys directory is missing (if using external databases)"
    $Warnings++
}

# Check Docker daemon
Write-Step "Checking Docker daemon..."

try {
    $null = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Docker daemon is running"
    } else {
        Write-Error "Docker daemon is not running"
        $Errors++
    }
} catch {
    Write-Error "Docker not found or not working"
    $Errors++
}

# Check available disk space
Write-Step "Checking disk space..."

try {
    $Drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$((Get-Location).Drive.Name):'"
    $FreeSpaceGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
    
    if ($FreeSpaceGB -gt 10) {
        Write-Info "Sufficient disk space available ($FreeSpaceGB GB)"
    } else {
        Write-Warn "Low disk space ($FreeSpaceGB GB) - recommend at least 10GB"
        $Warnings++
    }
} catch {
    Write-Warn "Cannot check disk space"
    $Warnings++
}

# Check memory
Write-Step "Checking system memory..."

try {
    $Memory = Get-WmiObject -Class Win32_ComputerSystem
    $MemoryGB = [math]::Round($Memory.TotalPhysicalMemory / 1GB, 2)
    
    if ($MemoryGB -gt 4) {
        Write-Info "Sufficient memory available ($MemoryGB GB)"
    } else {
        Write-Warn "Low memory ($MemoryGB GB) - recommend at least 4GB for production"
        $Warnings++
    }
} catch {
    Write-Warn "Cannot check memory"
    $Warnings++
}

# Summary
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                    Validation Summary                     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

if ($Errors -eq 0 -and $Warnings -eq 0) {
    Write-Info "Configuration is valid! Ready to deploy."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  • Development: make dev"
    Write-Host "  • Production: make prod"
    Write-Host "  • View logs: make logs"
    exit 0
} elseif ($Errors -eq 0) {
    Write-Warn "Configuration has $Warnings warnings but no errors."
    Write-Host ""
    Write-Host "Warnings should be addressed for optimal operation."
    exit 0
} else {
    Write-Error "Configuration has $Errors errors and $Warnings warnings."
    Write-Host ""
    Write-Host "Please fix the errors before proceeding."
    exit 1
}
