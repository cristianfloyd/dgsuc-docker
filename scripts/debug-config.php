<?php

/**
 * Script para debuggear la configuración de Laravel
 * Verifica por qué APP_KEY no se está leyendo correctamente
 */

echo "🔍 Debug de configuración de Laravel\n";
echo "==================================\n\n";

// Cargar el autoloader de Composer
require_once '/var/www/html/vendor/autoload.php';

// Crear una nueva instancia de Laravel
$app = require_once '/var/www/html/bootstrap/app.php';

echo "📋 Verificando configuración de Laravel...\n";
echo "----------------------------------------\n\n";

// Verificar si el archivo .env se está cargando
echo "1. Verificando archivo .env:\n";
$envPath = '/var/www/html/.env';
if (file_exists($envPath)) {
    echo "   ✅ Archivo .env existe en: $envPath\n";
    
    // Leer el contenido del archivo .env
    $envContent = file_get_contents($envPath);
    if (preg_match('/^APP_KEY=(.+)$/m', $envContent, $matches)) {
        echo "   ✅ APP_KEY encontrado en .env: " . substr($matches[1], 0, 20) . "...\n";
    } else {
        echo "   ❌ APP_KEY NO encontrado en .env\n";
    }
} else {
    echo "   ❌ Archivo .env NO existe\n";
}

echo "\n2. Verificando variables de entorno:\n";
echo "   APP_KEY (getenv): " . (getenv('APP_KEY') ?: 'NO DEFINIDA') . "\n";
echo "   APP_KEY (\$_ENV): " . (isset($_ENV['APP_KEY']) ? $_ENV['APP_KEY'] : 'NO DEFINIDA') . "\n";
echo "   APP_KEY (\$_SERVER): " . (isset($_SERVER['APP_KEY']) ? $_SERVER['APP_KEY'] : 'NO DEFINIDA') . "\n";

echo "\n3. Verificando configuración de Laravel:\n";
try {
    // Intentar obtener la configuración de Laravel
    $config = $app['config']->get('app');
    echo "   ✅ Configuración de Laravel cargada\n";
    echo "   APP_KEY en config: " . ($config['key'] ?: 'VACÍA') . "\n";
    echo "   APP_ENV en config: " . ($config['env'] ?: 'NO DEFINIDA') . "\n";
    echo "   APP_DEBUG en config: " . ($config['debug'] ? 'true' : 'false') . "\n";
} catch (Exception $e) {
    echo "   ❌ Error al cargar configuración: " . $e->getMessage() . "\n";
}

echo "\n4. Verificando archivo de configuración app.php:\n";
$configPath = '/var/www/html/config/app.php';
if (file_exists($configPath)) {
    echo "   ✅ Archivo config/app.php existe\n";
    $configContent = file_get_contents($configPath);
    if (strpos($configContent, "env('APP_KEY')") !== false) {
        echo "   ✅ config/app.php usa env('APP_KEY')\n";
    } else {
        echo "   ❌ config/app.php NO usa env('APP_KEY')\n";
    }
} else {
    echo "   ❌ Archivo config/app.php NO existe\n";
}

echo "\n5. Verificando bootstrap/app.php:\n";
$bootstrapPath = '/var/www/html/bootstrap/app.php';
if (file_exists($bootstrapPath)) {
    echo "   ✅ Archivo bootstrap/app.php existe\n";
} else {
    echo "   ❌ Archivo bootstrap/app.php NO existe\n";
}

echo "\n6. Verificando permisos:\n";
echo "   Permisos de .env: " . substr(sprintf('%o', fileperms($envPath)), -4) . "\n";
echo "   Usuario propietario: " . posix_getpwuid(fileowner($envPath))['name'] . "\n";
echo "   Grupo propietario: " . posix_getgrgid(filegroup($envPath))['name'] . "\n";

echo "\n🎯 Debug completado\n";
