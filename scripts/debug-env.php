<?php

/**
 * Script para debuggear el archivo .env
 * Lee el archivo .env y muestra el valor de APP_KEY
 */

echo "🔍 Debug del archivo .env\n";
echo "========================\n\n";

// Ruta del archivo .env
$envPath = '/var/www/html/.env';

echo "📁 Ruta del archivo: $envPath\n";

// Verificar si el archivo existe
if (!file_exists($envPath)) {
    echo "❌ ERROR: El archivo .env no existe en $envPath\n";
    exit(1);
}

echo "✅ El archivo .env existe\n\n";

// Leer el contenido del archivo
$content = file_get_contents($envPath);

if ($content === false) {
    echo "❌ ERROR: No se pudo leer el archivo .env\n";
    exit(1);
}

echo "📄 Contenido del archivo .env:\n";
echo "-----------------------------\n";
echo $content;
echo "\n-----------------------------\n\n";

// Buscar la línea APP_KEY
$lines = explode("\n", $content);
$appKeyLine = null;
$appKeyLineNumber = null;

foreach ($lines as $index => $line) {
    $line = trim($line);
    if (strpos($line, 'APP_KEY=') === 0) {
        $appKeyLine = $line;
        $appKeyLineNumber = $index + 1;
        break;
    }
}

if ($appKeyLine === null) {
    echo "❌ ERROR: No se encontró la línea APP_KEY en el archivo .env\n";
    exit(1);
}

echo "🔑 Línea APP_KEY encontrada (línea $appKeyLineNumber):\n";
echo "   $appKeyLine\n\n";

// Extraer el valor de APP_KEY
$appKeyValue = substr($appKeyLine, 8); // Remover "APP_KEY="

echo "📋 Valor de APP_KEY:\n";
echo "   '$appKeyValue'\n\n";

// Verificar si está vacío
if (empty($appKeyValue)) {
    echo "⚠️  ADVERTENCIA: APP_KEY está vacío\n";
} else {
    echo "✅ APP_KEY tiene un valor\n";
}

// Verificar la longitud
echo "📏 Longitud del valor: " . strlen($appKeyValue) . " caracteres\n\n";

// Verificar si parece ser una clave válida de Laravel
if (strpos($appKeyValue, 'base64:') === 0) {
    echo "✅ El formato parece ser correcto (base64:...)\n";
} else {
    echo "⚠️  El formato no parece ser el estándar de Laravel (debería empezar con 'base64:')\n";
}

echo "\n🎯 Debug completado\n";
