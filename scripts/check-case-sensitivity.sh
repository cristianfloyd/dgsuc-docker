#!/bin/bash
# =============================================================================
# VERIFICADOR DE CASE SENSITIVITY PARA COMPATIBILIDAD UNIX/LINUX
# =============================================================================

set -e

echo "🔍 Verificando case sensitivity para compatibilidad Unix/Linux..."

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ISSUES_FOUND=0

echo "📄 Buscando potenciales conflictos de case sensitivity..."

# Función para reportar issues
report_issue() {
    echo "⚠️  $1"
    ((ISSUES_FOUND++))
}

# Verificar archivos con nombres similares pero diferente case
echo "🔎 Verificando archivos con nombres similares..."

# Buscar archivos .php que podrían tener conflictos
find app -name "*.php" -type f | while read -r file; do
    filename=$(basename "$file")
    dirname=$(dirname "$file")
    
    # Buscar archivos similares en el mismo directorio
    find "$dirname" -maxdepth 1 -name "*.php" -type f | while read -r similar; do
        similar_name=$(basename "$similar")
        if [ "$filename" != "$similar_name" ] && [ "${filename,,}" = "${similar_name,,}" ]; then
            report_issue "Conflicto de case: $file vs $similar"
        fi
    done
done

# Verificar nombres de clases vs archivos
echo "🏗️  Verificando consistencia de nombres de clases..."

# Buscar clases PHP y verificar que coincidan con nombres de archivo
find app/app -name "*.php" -type f | while read -r file; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .php)
        
        # Extraer nombre de clase del archivo
        classname=$(grep -oP '(?<=class\s)[A-Za-z0-9_]+' "$file" | head -1 2>/dev/null || echo "")
        
        if [ -n "$classname" ] && [ "$filename" != "$classname" ]; then
            report_issue "Inconsistencia clase/archivo: $file (class $classname)"
        fi
    fi
done

# Verificar imports/namespaces que podrían ser case-sensitive
echo "📦 Verificando imports y namespaces..."

# Buscar use statements que podrían tener problemas
find app/app -name "*.php" -type f -exec grep -l "use.*[A-Z].*;" {} \; | while read -r file; do
    # Verificar que los archivos referenciados existan con el case correcto
    grep -oP '(?<=use\s)[^;]+' "$file" 2>/dev/null | while read -r namespace; do
        # Convertir namespace a path
        namespace_path=$(echo "$namespace" | sed 's/\\/\//g' | sed 's/App\///g')
        expected_file="app/app/${namespace_path}.php"
        
        if [ ! -f "$expected_file" ]; then
            # Buscar archivo con case incorrecto
            expected_dir=$(dirname "$expected_file")
            expected_name=$(basename "$expected_file")
            
            if [ -d "$expected_dir" ]; then
                find "$expected_dir" -maxdepth 1 -iname "$expected_name" -type f | while read -r found; do
                    if [ "$found" != "$expected_file" ]; then
                        report_issue "Case incorrecto en import: $file -> $namespace (encontrado: $found)"
                    fi
                done
            fi
        fi
    done
done

# Verificar configuraciones Laravel
echo "⚙️  Verificando configuraciones Laravel..."

# Verificar que los nombres de servicios en config/ coincidan con los archivos
if [ -d "app/config" ]; then
    find app/config -name "*.php" -type f | while read -r config; do
        filename=$(basename "$config" .php)
        
        # Verificar referencias en otros archivos de config
        find app/config -name "*.php" -type f -exec grep -l "$filename" {} \; | while read -r ref_file; do
            if [ "$ref_file" != "$config" ]; then
                # Verificar que las referencias usen el case correcto
                grep -n "$filename" "$ref_file" | while read -r line; do
                    case_variants=$(echo "$line" | grep -oE "['\"]$filename['\"]|$filename\s*=>" | head -1)
                    if [ -n "$case_variants" ]; then
                        echo "📋 Referencia encontrada: $ref_file -> $filename"
                    fi
                done
            fi
        done
    done
fi

echo ""
echo "📊 Resumen de verificación:"

if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ No se encontraron problemas de case sensitivity"
    echo "🎉 El repositorio es compatible con sistemas Unix/Linux case-sensitive"
else
    echo "⚠️  Se encontraron $ISSUES_FOUND posibles problemas"
    echo "🔧 Revisa y corrige estos issues para garantizar compatibilidad completa"
fi

echo ""
echo "💡 Recomendaciones adicionales:"
echo "  • Usar siempre PascalCase para nombres de clases"
echo "  • Usar snake_case para nombres de archivos de migración"
echo "  • Usar kebab-case para nombres de archivos de vistas"
echo "  • Verificar imports después de renombrar archivos"
echo "  • Probar en un sistema Linux real antes del despliegue"

exit $ISSUES_FOUND