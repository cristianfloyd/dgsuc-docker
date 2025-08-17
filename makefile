# DGSUC Docker Management
.PHONY: help dev prod build up down restart logs shell test backup restore clean dev-windows-optimized

# Default environment
ENV ?= development
COMPOSE_DEV = docker-compose -f docker-compose.yml -f docker-compose.dev.yml
COMPOSE_PROD = docker-compose -f docker-compose.yml -f docker-compose.prod.yml

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo '📚 Documentation:'
	@echo '  📖 README.md                    - Documentación principal'
	@echo '  🎨 docs/ASSETS_MANAGEMENT.md    - Gestión de assets'
	@echo '  🚀 app/PRODUCTION_DEPLOYMENT_GUIDE.md - Guía de producción'
	@echo ''
	@echo '🔧 Permission Commands:'
	@echo '  check-permissions            - Check Laravel file permissions'
	@echo '  fix-permissions              - Fix Laravel file permissions (dgsuc_user:www-data)'
	@echo '  fix-permissions-script       - Use built-in permission fix script'
	@echo '  check-writable               - Test writable directories'
	@echo '  prod-check-permissions       - Check permissions (production)'
	@echo '  prod-fix-permissions         - Fix permissions (production)'
	@echo '  host-fix-permissions         - Fix permissions from host'

# Development Commands
dev: ## Start development environment
	@echo "Starting development environment..."
	BUILD_TARGET=development $(COMPOSE_DEV) up -d
	@echo "Development environment is running at http://localhost:8080"

dev-wsl: ## Start development environment for WSL
	@echo "Starting WSL development environment..."
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d
	@echo "WSL development environment is running at http://localhost:8080"

dev-build: ## Build development images
	BUILD_TARGET=development $(COMPOSE_DEV) build

dev-logs: ## Show development logs
	$(COMPOSE_DEV) logs -f

dev-shell: ## Enter development app container
	$(COMPOSE_DEV) exec app bash

dev-stop: ## Stop development environment
	$(COMPOSE_DEV) down

dev-clean: ## Clean development environment (removes volumes)
	$(COMPOSE_DEV) down -v
	docker system prune -f
	docker volume prune -f

dev-deploy: ## Full development deployment with assets
	@echo "Starting development deployment..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "Windows detected, using Docker commands directly..."; \
		BUILD_TARGET=development $(COMPOSE_DEV) down; \
		git pull origin main; \
		docker run --rm -v "$(PWD)/app:/var/www/html" -w /var/www/html node:18-alpine sh -c "npm install && npm run build"; \
		BUILD_TARGET=development $(COMPOSE_DEV) build --no-cache; \
		BUILD_TARGET=development $(COMPOSE_DEV) up -d; \
		sleep 10; \
		$(COMPOSE_DEV) exec app php artisan migrate --force; \
		$(COMPOSE_DEV) exec app php artisan cache:clear; \
		$(COMPOSE_DEV) exec app php artisan config:clear; \
		$(COMPOSE_DEV) exec app php artisan view:clear; \
		$(COMPOSE_DEV) run --rm app php artisan test; \
		echo "Development deployment complete!"; \
	else \
		BUILD_TARGET=development ./scripts/deploy.sh development; \
		echo "Development deployment complete!"; \
	fi

dev-build-assets: ## Build assets for development
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "Building assets for development (Windows)..."; \
		docker run --rm -v "$(PWD)/app:/var/www/html" -w /var/www/html node:18-alpine sh -c "npm install && npm run build"; \
	else \
		$(COMPOSE_DEV) exec node npm run build; \
	fi

dev-rebuild: ## Rebuild development environment completely (Windows optimized)
	@echo "🔧 Rebuilding development environment..."
	@echo ""
	@# Detect environment and choose appropriate strategy
	@if [ "$(OS)" = "Windows_NT" ] || command -v wsl.exe >/dev/null 2>&1; then \
		echo "🪟 Windows environment detected - using optimized rebuild"; \
		echo ""; \
		echo "🛑 Stopping current containers..."; \
		BUILD_TARGET=development $(COMPOSE_DEV) down; \
		echo "🧹 Cleaning Docker system..."; \
		docker system prune -f; \
		echo "🏗️  Building containers with --no-cache..."; \
		BUILD_TARGET=development $(COMPOSE_DEV) build --no-cache; \
		echo "🔄 Synchronizing code to Docker volume..."; \
		make sync-to-volume; \
		echo "🚀 Starting containers..."; \
		BUILD_TARGET=development $(COMPOSE_DEV) up -d; \
		echo "⏳ Waiting for containers to be ready..."; \
		sleep 10; \
		echo "📦 Installing Composer dependencies..."; \
		$(COMPOSE_DEV) exec app composer install; \
		echo "🔧 Fixing permissions and Git configuration..."; \
		$(COMPOSE_DEV) exec app sh -c "chown -R 1000:1000 /var/www/html && chmod -R 755 /var/www/html && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache && git config --global --add safe.directory /var/www/html"; \
		echo ""; \
		echo "✅ Development environment rebuilt with Windows optimizations!"; \
		echo "📍 Application URL: http://localhost:8080"; \
		echo "💡 For future code changes, use: make sync-to-volume"; \
	else \
		echo "🐧 Linux/Unix environment detected - using standard rebuild"; \
		BUILD_TARGET=development $(COMPOSE_DEV) down; \
		docker system prune -f; \
		BUILD_TARGET=development $(COMPOSE_DEV) build --no-cache; \
		BUILD_TARGET=development $(COMPOSE_DEV) up -d; \
		echo "Installing Composer dependencies..."; \
		$(COMPOSE_DEV) exec app composer install; \
		echo "Development environment rebuilt!"; \
	fi

# Production Commands
prod: ## Start production environment
	@echo "Starting production environment..."
	./scripts/deploy.sh production

prod-build: ## Build production images
	BUILD_TARGET=production $(COMPOSE_PROD) build

prod-build-assets: ## Build assets for production
	docker run --rm \
		-v "$(PWD)/app:/var/www/html" \
		-w /var/www/html \
		node:18-alpine \
		sh -c "npm install --production && npm run build"

prod-deploy: ## Full production deployment with assets
	@echo "Starting production deployment..."
	./scripts/deploy.sh production
	@echo "Production deployment complete!"

prod-logs: ## Show production logs
	$(COMPOSE_PROD) logs -f

prod-shell: ## Enter production app container
	$(COMPOSE_PROD) exec app sh

prod-stop: ## Stop production environment
	$(COMPOSE_PROD) down

prod-restart: ## Restart production services
	$(COMPOSE_PROD) restart

# Database Commands
db-migrate: ## Run database migrations
	$(COMPOSE_DEV) exec app php artisan migrate

db-seed: ## Seed the database
	$(COMPOSE_DEV) exec app php artisan db:seed

db-fresh: ## Fresh database with seeds
	$(COMPOSE_DEV) exec app php artisan migrate:fresh --seed

db-test: ## Test database connection
	@echo "Testing database connection..."
	$(COMPOSE_DEV) exec app php artisan db:show

db-backup: ## Backup database
	./scripts/backup.sh database

db-restore: ## Restore database from backup
	@read -p "Enter backup file name: " backup; \
	./scripts/restore.sh $$backup

# Laravel Commands
artisan: ## Run artisan command (usage: make artisan cmd="route:list")
	$(COMPOSE_DEV) exec app php artisan $(cmd)

composer: ## Run composer command (usage: make composer cmd="require package")
	$(COMPOSE_DEV) exec app composer $(cmd)

composer-install: ## Install Composer dependencies
	@echo "Installing Composer dependencies..."
	$(COMPOSE_DEV) exec app composer install

# Permission Management
check-permissions: ## Check Laravel file permissions in container
	@echo "Checking Laravel file permissions..."
	$(COMPOSE_DEV) exec app sh -c "echo '=== Storage permissions ==='; ls -la /var/www/html/storage"
	$(COMPOSE_DEV) exec app sh -c "echo '=== Bootstrap cache permissions ==='; ls -la /var/www/html/bootstrap/cache"
	$(COMPOSE_DEV) exec app sh -c "echo '=== .env file permissions ==='; ls -la /var/www/html/.env"
	$(COMPOSE_DEV) exec app sh -c "echo '=== Current user/group ==='; id"
	$(COMPOSE_DEV) exec app sh -c "echo '=== Web server user ==='; ps aux | grep nginx || ps aux | grep apache"

fix-permissions: ## Fix Laravel file permissions in container
	@echo "Fixing Laravel file permissions..."
	$(COMPOSE_DEV) exec app sh -c "chown -R dgsuc_user:www-data /var/www/html/storage"
	$(COMPOSE_DEV) exec app sh -c "chown -R dgsuc_user:www-data /var/www/html/bootstrap/cache"
	$(COMPOSE_DEV) exec app sh -c "chmod -R 775 /var/www/html/storage"
	$(COMPOSE_DEV) exec app sh -c "chmod -R 775 /var/www/html/bootstrap/cache"
	$(COMPOSE_DEV) exec app sh -c "chmod 644 /var/www/html/.env"
	@echo "Permissions fixed!"

check-writable: ## Test if Laravel directories are writable
	@echo "Testing writable directories..."
	$(COMPOSE_DEV) exec app sh -c "touch /var/www/html/storage/test_write.tmp && rm /var/www/html/storage/test_write.tmp && echo '✓ storage/ is writable' || echo '✗ storage/ is NOT writable'"
	$(COMPOSE_DEV) exec app sh -c "touch /var/www/html/bootstrap/cache/test_write.tmp && rm /var/www/html/bootstrap/cache/test_write.tmp && echo '✓ bootstrap/cache/ is writable' || echo '✗ bootstrap/cache/ is NOT writable'"

fix-permissions-script: ## Use built-in permission fix script (development)
	@echo "Running built-in permission fix script..."
	$(COMPOSE_DEV) exec app /usr/local/bin/fix-permissions.sh
	@echo "Built-in script executed!"

# Production Permission Commands
prod-check-permissions: ## Check Laravel file permissions in production container
	@echo "Checking Laravel file permissions (production)..."
	$(COMPOSE_PROD) exec app sh -c "echo '=== Storage permissions ==='; ls -la /var/www/html/storage"
	$(COMPOSE_PROD) exec app sh -c "echo '=== Bootstrap cache permissions ==='; ls -la /var/www/html/bootstrap/cache"
	$(COMPOSE_PROD) exec app sh -c "echo '=== .env file permissions ==='; ls -la /var/www/html/.env"
	$(COMPOSE_PROD) exec app sh -c "echo '=== Current user/group ==='; id"

prod-fix-permissions: ## Fix Laravel file permissions in production container
	@echo "Fixing Laravel file permissions (production)..."
	$(COMPOSE_PROD) exec app sh -c "chown -R dgsuc_user:www-data /var/www/html/storage"
	$(COMPOSE_PROD) exec app sh -c "chown -R dgsuc_user:www-data /var/www/html/bootstrap/cache"
	$(COMPOSE_PROD) exec app sh -c "chmod -R 775 /var/www/html/storage"
	$(COMPOSE_PROD) exec app sh -c "chmod -R 775 /var/www/html/bootstrap/cache"
	$(COMPOSE_PROD) exec app sh -c "chmod 600 /var/www/html/.env"  # Más restrictivo en producción
	@echo "Production permissions fixed!"

# Host Permission Commands (for when containers can't fix it)
host-fix-permissions: ## Fix permissions from host (when container commands fail)
	@echo "Fixing permissions from host..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "Windows detected - permissions managed by Docker"; \
	else \
		sudo chown -R 1000:1000 ./app/storage ./app/bootstrap/cache; \
		chmod -R 775 ./app/storage ./app/bootstrap/cache; \
		chmod 644 ./app/.env; \
		echo "Host permissions fixed!"; \
	fi

deps-install: ## Install all dependencies (Composer + npm)
	@echo "Installing all dependencies..."
	@echo "Installing Composer dependencies..."
	$(COMPOSE_DEV) exec app composer install
	@echo "Installing npm dependencies..."
	$(COMPOSE_DEV) exec node npm install
	@echo "All dependencies installed!"

npm: ## Run npm command (usage: make npm cmd="run build")
	$(COMPOSE_DEV) exec node npm $(cmd)

test: ## Run tests
	$(COMPOSE_DEV) exec app php artisan test

test-coverage: ## Run tests with coverage
	$(COMPOSE_DEV) exec app php artisan test --coverage

# Cache Commands
cache-clear: ## Clear all caches
	$(COMPOSE_DEV) exec app php artisan cache:clear
	$(COMPOSE_DEV) exec app php artisan config:clear
	$(COMPOSE_DEV) exec app php artisan route:clear
	$(COMPOSE_DEV) exec app php artisan view:clear

cache-build: ## Build all caches (production)
	$(COMPOSE_DEV) exec app php artisan config:cache
	$(COMPOSE_DEV) exec app php artisan route:cache
	$(COMPOSE_DEV) exec app php artisan view:cache
	$(COMPOSE_DEV) exec app php artisan event:cache

# Queue Commands
queue-work: ## Start queue worker
	$(COMPOSE_DEV) exec app php artisan queue:work

queue-restart: ## Restart queue workers
	$(COMPOSE_DEV) exec app php artisan queue:restart

queue-failed: ## List failed jobs
	$(COMPOSE_DEV) exec app php artisan queue:failed

queue-retry: ## Retry failed jobs
	$(COMPOSE_DEV) exec app php artisan queue:retry all

# Node.js Commands
node-shell: ## Enter node container shell (development)
	$(COMPOSE_DEV) exec node sh

node-install: ## Install npm dependencies (development)
	$(COMPOSE_DEV) exec node npm install

node-dev: ## Run npm dev command (development)
	$(COMPOSE_DEV) exec node npm run dev

node-build: ## Run npm build command (development)
	$(COMPOSE_DEV) exec node npm run build

# Asset Commands (Both environments)
assets-build: ## Build assets for current environment
	@echo "Building assets for development environment..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		docker run --rm -v "$(shell pwd)/app:/var/www/html" -w /var/www/html node:18-alpine sh -c "npm install && npm run build"; \
	else \
		$(COMPOSE_DEV) exec node npm run build; \
	fi

assets-install: ## Install npm dependencies for current environment
	@echo "Installing npm dependencies for development environment..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		docker run --rm -v "$(PWD)/app:/var/www/html" -w /var/www/html node:18-alpine sh -c "npm install"; \
	else \
		$(COMPOSE_DEV) exec node npm install; \
	fi

assets-watch: ## Watch and build assets in development
	@echo "Starting asset watcher for development..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		echo "Windows detected. For hot reload, use: make dev and then make node-dev in another terminal"; \
		make node-dev; \
	else \
		$(COMPOSE_DEV) exec node npm run dev; \
	fi

assets-check: ## Check if assets are built
	@echo "Checking built assets..."
	@if [ -d "app/public/build" ]; then \
		echo "✓ Assets directory exists"; \
		if [ "$(OS)" = "Windows_NT" ]; then \
			dir app\\public\\build; \
		else \
			ls -la app/public/build/; \
		fi; \
	else \
		echo "✗ Assets directory not found. Run 'make assets-build' first"; \
	fi

assets-clean: ## Clean built assets
	@echo "Cleaning built assets..."
	rm -rf app/public/build
	@echo "✓ Assets cleaned"

# SSH Tunnel Commands
tunnel-status: ## Check SSH tunnel status
	$(COMPOSE_DEV) exec ssh-tunnel ps aux | grep ssh

tunnel-restart: ## Restart SSH tunnels
	$(COMPOSE_DEV) restart ssh-tunnel

tunnel-logs: ## Show SSH tunnel logs
	$(COMPOSE_DEV) logs -f ssh-tunnel

# Monitoring Commands
monitor-start: ## Start monitoring stack
	$(COMPOSE_PROD) up -d prometheus grafana

monitor-stop: ## Stop monitoring stack
	$(COMPOSE_PROD) stop prometheus grafana

grafana: ## Open Grafana dashboard
	@echo "Opening Grafana at http://localhost:3000"
	@command -v xdg-open > /dev/null && xdg-open http://localhost:3000 || open http://localhost:3000

# SSL Certificate Commands
ssl-generate: ## Generate SSL certificate with Let's Encrypt
	docker run -it --rm \
		-v "$(PWD)/docker/nginx/certs:/etc/letsencrypt" \
		-v "$(PWD)/public:/var/www/html" \
		certbot/certbot certonly \
		--webroot \
		--webroot-path=/var/www/html \
		--email admin@uba.ar \
		--agree-tos \
		--no-eff-email \
		-d dgsuc.uba.ar \
		-d www.dgsuc.uba.ar

ssl-renew-docker: ## Renew SSL certificates using Docker
	docker run -it --rm \
		-v "$(PWD)/docker/nginx/certs:/etc/letsencrypt" \
		-v "$(PWD)/public:/var/www/html" \
		certbot/certbot renew

# Application Commands
clone: ## Clone the application repository
	./scripts/clone-app.sh

init: ## Initialize the environment (configure variables and setup)
	@echo "🚀 Initializing DGSUC Docker Environment..."
	@echo ""
	@./scripts/init.sh

update: ## Update application code
	cd app && git pull && cd ..
	@echo "Application updated. Run 'make dev' or 'make prod' to restart services."

# Environment switching
switch-to-dev: ## Switch to development environment
	@echo "Switching to development environment..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		copy .env.dev .env; \
		copy .env.dev app\\.env; \
	else \
		ln -sf .env.dev .env; \
		cp .env.dev ./app/.env; \
	fi
	@echo "Environment switched to development (.env.dev)"

switch-to-prod: ## Switch to production environment
	@echo "Switching to production environment..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		copy .env.prod .env; \
		copy .env.prod app\\.env; \
	else \
		ln -sf .env.prod .env; \
		cp .env.prod ./app/.env; \
	fi
	@echo "Environment switched to production (.env.prod)"

env-status: ## Show current environment configuration
	@echo "Current environment status:"
	@if [ -f ".env" ] && [ -L ".env" ]; then \
		echo "  .env -> $$(readlink .env)"; \
	elif [ -f ".env" ]; then \
		echo "  .env exists (regular file)"; \
	else \
		echo "  .env not found"; \
	fi
	@if [ -f "./app/.env" ]; then \
		echo "  app/.env exists"; \
		echo "  DB_USERNAME=$$(grep '^DB_USERNAME=' ./app/.env | cut -d'=' -f2 2>/dev/null || echo 'not set')"; \
		echo "  DB_DATABASE=$$(grep '^DB_DATABASE=' ./app/.env | cut -d'=' -f2 2>/dev/null || echo 'not set')"; \
	else \
		echo "  app/.env not found"; \
	fi

# Utility Commands
ps: ## Show running containers
	$(COMPOSE_DEV) ps

stats: ## Show container resource usage
	docker stats --no-stream

clean: ## Clean everything (containers, volumes, images)
	$(COMPOSE_DEV) down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

backup-all: ## Backup completo del sistema
	./scripts/backup.sh full

logs: ## Mostrar todos los logs
	docker-compose logs -f

health: ## Verificar estado de salud de todos los servicios
	@echo "Verificando estado de los servicios..."
	@docker-compose ps | grep -E "Up|healthy" || echo "Algunos servicios están caídos o no saludables."

validate: ## Validar configuración de Docker Compose
	@echo "Validando configuración de Docker Compose..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1; \
	else \
		./scripts/validate-config.sh; \
	fi

# Instalación
install: ## Instalación inicial
	@echo "Instalando entorno Docker de DGSUC..."
	@cp .env.docker.example .env
	@echo "Por favor, configure el archivo .env antes de continuar"
	@read -p "Presione enter cuando haya configurado el archivo .env..." 
	@make dev-build
	@make dev
	@make db-migrate
	@echo "¡Instalación completada!"

# Comandos específicos para Windows
sync-to-volume: ## Sincronizar código al volumen Docker (optimización de rendimiento en Windows)
	@echo "🔄 Sincronizando código al volumen interno de Docker..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		./scripts/sync-to-volume.bat; \
	else \
		./scripts/sync-to-volume.sh; \
	fi


dev-windows-optimized: ## Iniciar entorno de desarrollo (Windows WSL optimizado con auto-clone y composer)
	@echo "🚀 Iniciando entorno de desarrollo optimizado para Windows..."
	@echo ""
	@# Verificar si estamos en WSL o si WSL está disponible
	@if [ -n "$$WSL_DISTRO_NAME" ]; then \
		echo "✅ WSL detectado: $$WSL_DISTRO_NAME"; \
		USE_WSL=true; \
	elif command -v wsl.exe >/dev/null 2>&1; then \
		echo "⚠️  WSL disponible pero no activo. Para mejor rendimiento, ejecute desde WSL:"; \
		echo "   wsl"; \
		echo "   cd $$(pwd | sed 's|^/mnt/\([a-z]\)|\1:|' | sed 's|/|\\\\|g')"; \
		echo "   make dev-windows-optimized"; \
		echo ""; \
		read -p "¿Continuar con la configuración estándar de Windows? (y/N): " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Configuración cancelada. Ejecute desde WSL para un rendimiento óptimo."; \
			exit 1; \
		fi; \
		USE_WSL=false; \
	else \
		echo "ℹ️  Configuración estándar de Windows"; \
		USE_WSL=false; \
	fi; \
	\
	echo ""; \
	echo "📦 Preparando entorno de desarrollo..."; \
	\
	if [ "$$USE_WSL" = "true" ]; then \
		echo "🔧 Usando configuración optimizada para WSL..."; \
		COMPOSE_CMD="docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml"; \
	else \
		echo "🔧 Usando configuración estándar de Windows..."; \
		COMPOSE_CMD="$(COMPOSE_DEV)"; \
	fi; \
	\
	echo "🏗️  Construyendo contenedores..."; \
	BUILD_TARGET=development $$COMPOSE_CMD build; \
	\
	echo "🚀 Iniciando contenedores..."; \
	BUILD_TARGET=development $$COMPOSE_CMD up -d; \
	\
	echo "⏳ Esperando que los contenedores estén listos..."; \
	sleep 10; \
	\
	echo "📂 Verificando directorio de la aplicación..."; \
	if ! $$COMPOSE_CMD exec -T app test -d /var/www/html/app 2>/dev/null; then \
		echo "📥 Clonando la aplicación dentro del contenedor..."; \
		$$COMPOSE_CMD exec -T app bash -c "\
			cd /var/www/html && \
			git clone https://github.com/cristianfloyd/dgsuc-app.git app && \
			echo '✅ Aplicación clonada correctamente'"; \
	else \
		echo "✅ El directorio de la aplicación ya existe"; \
	fi; \
	\
	echo "📋 Instalando dependencias de Composer..."; \
	$$COMPOSE_CMD exec -T app bash -c "\
		cd /var/www/html/app && \
		composer install --no-interaction --prefer-dist && \
		echo '✅ Dependencias de Composer instaladas'"; \
	\
	echo "🔑 Configurando entorno de Laravel..."; \
	if ! $$COMPOSE_CMD exec -T app test -f /var/www/html/app/.env 2>/dev/null; then \
		$$COMPOSE_CMD exec -T app bash -c "\
			cd /var/www/html/app && \
			cp .env.example .env && \
			php artisan key:generate && \
			echo '✅ Archivo .env de Laravel configurado'"; \
	else \
		echo "✅ El archivo .env de Laravel ya existe"; \
	fi; \
	\
	echo "🗃️  Ejecutando migraciones de base de datos..."; \
	$$COMPOSE_CMD exec -T app bash -c "\
		cd /var/www/html/app && \
		php artisan migrate --force && \
		echo '✅ Migraciones de base de datos completadas'"; \
	\
	echo "🧹 Limpiando cachés de Laravel..."; \
	$$COMPOSE_CMD exec -T app bash -c "\
		cd /var/www/html/app && \
		php artisan cache:clear && \
		php artisan config:clear && \
		php artisan view:clear && \
		echo '✅ Cachés limpiadas'"; \
	\
	echo ""; \
	echo "🎉 ¡Entorno de desarrollo listo!"; \
	echo ""; \
	echo "📍 URL de la aplicación: http://localhost:8080"; \
	echo ""; \
	if [ "$$USE_WSL" = "true" ]; then \
		echo "🛠️  Comandos de desarrollo en WSL:"; \
		echo "   ./wsl-dev.sh logs    - Ver logs"; \
		echo "   ./wsl-dev.sh shell   - Ingresar al contenedor"; \
		echo "   ./wsl-dev.sh stop    - Detener entorno"; \
	else \
		echo "🛠️  Comandos de desarrollo:"; \
		echo "   make logs           - Ver logs"; \
		echo "   make dev-shell      - Ingresar al contenedor"; \
		echo "   make dev-stop       - Detener entorno"; \
	fi; \
	echo ""

dev-windows: ## Iniciar entorno de desarrollo (optimizado para Windows con volumen Docker)
	@echo "🚀 Iniciando entorno de desarrollo con volumen Docker (optimizado para Windows)..."
	@make sync-to-volume
	BUILD_TARGET=development $(COMPOSE_DEV) up -d
	@echo "⏳ Esperando que los contenedores estén listos..."
	@sleep 5
	@echo "🔧 Configurando Git y permisos..."
	@$(COMPOSE_DEV) exec app sh -c "git config --global --add safe.directory /var/www/html" || true
	@echo "✅ Entorno de desarrollo iniciado con volumen Docker."
	@echo "📍 URL de la aplicación: http://localhost:8080"
	@echo "💡 Para sincronizar cambios, ejecuta: make sync-to-volume"

dev-simple: ## Inicio simple del entorno de desarrollo (multiplataforma)
	@echo "Iniciando entorno de desarrollo..."
	BUILD_TARGET=development $(COMPOSE_DEV) up -d
	@echo "¡Entorno de desarrollo iniciado!"
	@echo "Aplicación disponible en: http://localhost:8080"

ssl-setup: ## Setup SSL certificates
	@echo "Setting up SSL certificates..."
	@./scripts/ssl-setup.sh letsencrypt $(CERTBOT_DOMAIN) $(CERTBOT_EMAIL)

ssl-renew: ## Renew SSL certificates
	@echo "Renewing SSL certificates..."
	@./scripts/ssl-auto-renew.sh

ssl-status: ## Check SSL certificate status
	@echo "Checking SSL certificate status..."
	@openssl x509 -in docker/nginx/certs/fullchain.pem -text -noout | grep -A2 "Validity"

ssl-test: ## Test SSL configuration
	@echo "Testing SSL configuration..."
	@curl -s -o /dev/null -w "SSL Test: %{http_code}\n" https://$(CERTBOT_DOMAIN)

ssl-auto-renew: ## Setup automatic SSL renewal
	@echo "Setting up automatic SSL renewal..."
	@(crontab -l 2>/dev/null; echo "0 2 * * * $(PWD)/scripts/ssl-auto-renew.sh >> /var/log/ssl-renewal.log 2>&1") | crontab -

change-domain: ## Cambiar configuración de dominio
	@echo "Modificando configuración de dominio..."
	@read -p "Ingrese el dominio anterior (ej: dgsuc.uba.ar): " old_domain; \
	read -p "Ingrese el nuevo dominio (ej: dgsuc.midominio.com): " new_domain; \
	read -p "Ingrese el nuevo correo electrónico: " new_email; \
	./scripts/change-domain.sh "$$old_domain" "$$new_domain" "admin@uba.ar" "$$new_email"

ssl-generate-new: ## Generate SSL certificate for new domain
	@read -p "Enter domain: " domain; \
	read -p "Enter email: " email; \
	./scripts/ssl-setup.sh letsencrypt "$$domain" "$$email"

ssl-test-domain: ## Test SSL for specific domain
	@read -p "Enter domain to test: " domain; \
	curl -s -o /dev/null -w "SSL Test for $$domain: %{http_code}\n" https://$$domain

# Troubleshooting Commands
setup-env: ## Configurar entorno básico (crear archivos .env)
	@echo "🔧 Configurando entorno básico..."
	@./scripts/setup-env.sh

diagnose: ## Diagnosticar problemas de inicialización
	@echo "🔍 Diagnosticando problemas de inicialización..."
	@./scripts/diagnose-init.sh

fix-init: ## Solucionar errores de inicialización
	@echo "🔧 Solucionando errores de inicialización..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		./scripts/fix-init-errors-windows.sh; \
	else \
		./scripts/fix-init-errors.sh; \
	fi