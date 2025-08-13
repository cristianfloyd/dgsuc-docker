# 🎨 Gestión de Assets - Sistema DGSUC

Esta documentación describe cómo gestionar los assets (CSS, JavaScript, imágenes) en el Sistema DGSUC usando Vite y Docker.

## 📋 Índice

- [Arquitectura](#arquitectura)
- [Configuración](#configuración)
- [Comandos Disponibles](#comandos-disponibles)
- [Workflow de Desarrollo](#workflow-de-desarrollo)
- [Workflow de Producción](#workflow-de-producción)
- [Troubleshooting](#troubleshooting)

## 🏗️ Arquitectura

### Stack Tecnológico

- **Vite 6.3.5** - Bundler y dev server
- **Laravel Vite Plugin** - Integración con Laravel
- **Tailwind CSS** - Framework CSS
- **Alpine.js** - Framework JavaScript ligero
- **DaisyUI** - Componentes para Tailwind

### Estructura de Archivos

```
app/
├── resources/
│   ├── css/
│   │   ├── app.css              # CSS principal
│   │   └── filament/
│   │       └── reportes/
│   │           └── theme.css    # Tema Filament
│   └── js/
│       └── app.js               # JavaScript principal
├── public/
│   └── build/                   # Assets compilados (gitignored)
├── vite.config.js               # Configuración de Vite
├── tailwind.config.js           # Configuración de Tailwind
├── postcss.config.js            # Configuración de PostCSS
└── package.json                 # Dependencias npm
```

### Configuración de Vite

```javascript
// app/vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
                "resources/css/filament/reportes/theme.css",
            ],
            refresh: true,
        }),
    ],
});
```

## ⚙️ Configuración

### Dependencias

```json
{
    "devDependencies": {
        "@tailwindcss/forms": "^0.5.10",
        "@tailwindcss/typography": "^0.5.16",
        "autoprefixer": "^10.4.21",
        "axios": "^1.10.0",
        "daisyui": "^5.0.43",
        "laravel-vite-plugin": "^1.3",
        "postcss": "^8.5.6",
        "postcss-nesting": "^13.0.2",
        "tailwindcss": "^3.4.17",
        "vite": "^6.3.5"
    },
    "dependencies": {
        "alpinejs": "^3.14.9"
    }
}
```

### Configuración de Tailwind

```javascript
// app/tailwind.config.js
module.exports = {
    content: [
        './resources/**/*.blade.php',
        './resources/**/*.js',
        './resources/**/*.vue',
        './app/Filament/**/*.php',
    ],
    theme: {
        extend: {},
    },
    plugins: [
        require('@tailwindcss/forms'),
        require('@tailwindcss/typography'),
        require('daisyui'),
    ],
    daisyui: {
        themes: ["light", "dark"],
    },
};
```

## 🚀 Comandos Disponibles

### Comandos de Desarrollo

```bash
# Iniciar modo desarrollo con hot reload
make assets-watch

# Compilar assets para desarrollo
make assets-build

# Instalar dependencias npm
make assets-install

# Verificar assets compilados
make assets-check

# Limpiar assets compilados
make assets-clean
```

### Comandos de Producción

```bash
# Compilar assets optimizados para producción
make prod-build-assets

# Deployment completo con assets
make prod-deploy
```

### Comandos Específicos de Node.js

```bash
# Entrar al contenedor node
make node-shell

# Ejecutar Vite en modo desarrollo
make node-dev

# Compilar con servicio node
make node-build

# Instalar dependencias
make node-install
```

## 🔄 Workflow de Desarrollo

### 1. Configuración Inicial

```bash
# Iniciar entorno de desarrollo
make dev

# Instalar dependencias
make assets-install

# Verificar configuración
make assets-check
```

### 2. Desarrollo Diario

```bash
# Opción A: Modo desarrollo con hot reload
make assets-watch

# Opción B: Compilar manualmente
make assets-build

# Verificar cambios
make assets-check
```

### 3. Actualización de Dependencias

```bash
# Actualizar dependencias npm
make assets-install

# Limpiar y recompilar
make assets-clean
make assets-build
```

### 4. Verificación

```bash
# Verificar que los assets se compilaron
make assets-check

# Ver contenido del directorio build
ls -la app/public/build/

# Verificar que la aplicación funciona
curl http://localhost:8080
```

## 🏭 Workflow de Producción

### 1. Compilación de Assets

```bash
# Compilar assets optimizados
make prod-build-assets

# Verificar compilación
make assets-check
```

### 2. Deployment Completo

```bash
# Deployment con assets incluidos
make prod-deploy
```

### 3. Verificación Post-Deployment

```bash
# Verificar assets en producción
ls -la app/public/build/

# Verificar manifest.json
cat app/public/build/manifest.json

# Test de conectividad
curl -k https://dgsuc.uba.ar
```

## 🔧 Troubleshooting

### Problema: "Assets no se cargan"

```bash
# 1. Verificar que los assets estén compilados
make assets-check

# 2. Si no existen, compilar
make assets-build

# 3. Verificar permisos
ls -la app/public/build/
```

### Problema: "Vite no encontrado"

```bash
# 1. Verificar que el servicio node esté corriendo
make ps

# 2. Reinstalar dependencias
make assets-install

# 3. Reiniciar servicios
make restart
```

### Problema: "Error de compilación"

```bash
# 1. Limpiar assets
make assets-clean

# 2. Reinstalar dependencias
make assets-install

# 3. Recompilar
make assets-build

# 4. Verificar logs
make logs
```

### Problema: "Assets no se actualizan en desarrollo"

```bash
# 1. Detener modo watch
Ctrl+C

# 2. Limpiar cache
make assets-clean

# 3. Reiniciar modo desarrollo
make assets-watch
```

### Problema: "Error en producción"

```bash
# 1. Verificar assets de producción
make assets-check

# 2. Recompilar para producción
make prod-build-assets

# 3. Verificar permisos
chmod -R 755 app/public/build/
```

## 📊 Monitoreo y Verificación

### Verificación de Assets

```bash
# Verificar estructura de archivos
tree app/public/build/

# Verificar tamaños de archivos
du -sh app/public/build/*

# Verificar manifest.json
cat app/public/build/manifest.json | jq .
```

### Logs de Vite

```bash
# Ver logs del servicio node
make logs node

# Ver logs en tiempo real
make logs -f node
```

### Métricas de Performance

```bash
# Verificar tamaño de assets
ls -lh app/public/build/assets/

# Verificar compresión
gzip -l app/public/build/assets/*.js
gzip -l app/public/build/assets/*.css
```

## 🔒 Seguridad

### Configuración de Nginx

```nginx
# Configuración para assets estáticos
location /build {
    alias /var/www/html/public/build;
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
}
```

### Headers de Seguridad

```nginx
# Headers adicionales para assets
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';";
```

## 📝 Notas Importantes

### Gitignore

El directorio `app/public/build/` está en `.gitignore` porque:
- Los assets se compilan durante el deployment
- Evita conflictos de merge
- Mantiene el repositorio limpio

### Optimizaciones

- **Desarrollo:** Hot reload y source maps
- **Producción:** Minificación y optimización
- **Cache:** Headers de cache para assets estáticos

### Dependencias

- **Desarrollo:** Todas las dependencias incluyendo devDependencies
- **Producción:** Solo dependencias de producción (`--production`)

---

**Última actualización:** $(date)
**Versión:** 1.0.0
