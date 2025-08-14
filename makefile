# DGSUC Docker Management
.PHONY: help dev prod build up down restart logs shell test backup restore clean

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

dev-rebuild: ## Rebuild development environment completely
	@echo "Rebuilding development environment..."
	BUILD_TARGET=development $(COMPOSE_DEV) down
	docker system prune -f
	BUILD_TARGET=development $(COMPOSE_DEV) build --no-cache
	BUILD_TARGET=development $(COMPOSE_DEV) up -d
	@echo "Installing Composer dependencies..."
	$(COMPOSE_DEV) exec app composer install
	@echo "Development environment rebuilt!"

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

init: ## Initialize the environment
	./scripts/init.sh

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

backup-all: ## Complete system backup
	./scripts/backup.sh full

logs: ## Show all logs
	docker-compose logs -f

health: ## Health check all services
	@echo "Checking service health..."
	@docker-compose ps | grep -E "Up|healthy" || echo "Some services are down!"

validate: ## Validate Docker Compose configuration
	@echo "Validating configuration..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1; \
	else \
		./scripts/validate-config.sh; \
	fi

# Installation
install: ## Initial installation
	@echo "Installing DGSUC Docker Environment..."
	@cp .env.docker.example .env
	@echo "Please configure .env file before continuing"
	@read -p "Press enter when .env is configured..." 
	@make dev-build
	@make dev
	@make db-migrate
	@echo "Installation complete!"

# Windows-specific commands
dev-windows: ## Start development environment (Windows optimized)
	@echo "Starting development environment for Windows..."
	@if [ "$(OS)" = "Windows_NT" ]; then \
		BUILD_TARGET=development $(COMPOSE_DEV) up -d; \
		echo "Development environment started!"; \
		echo "For hot reload, run 'make node-dev' in another terminal"; \
		echo "Application available at: http://localhost:8080"; \
	else \
		echo "This command is for Windows only. Use 'make dev' instead."; \
	fi

dev-simple: ## Simple development start (cross-platform)
	@echo "Starting development environment..."
	BUILD_TARGET=development $(COMPOSE_DEV) up -d
	@echo "Development environment started!"
	@echo "Application available at: http://localhost:8080"

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

change-domain: ## Change domain configuration
	@echo "Changing domain configuration..."
	@read -p "Enter old domain (e.g., dgsuc.uba.ar): " old_domain; \
	read -p "Enter new domain (e.g., dgsuc.midominio.com): " new_domain; \
	read -p "Enter new email: " new_email; \
	./scripts/change-domain.sh "$$old_domain" "$$new_domain" "admin@uba.ar" "$$new_email"

ssl-generate-new: ## Generate SSL certificate for new domain
	@read -p "Enter domain: " domain; \
	read -p "Enter email: " email; \
	./scripts/ssl-setup.sh letsencrypt "$$domain" "$$email"

ssl-test-domain: ## Test SSL for specific domain
	@read -p "Enter domain to test: " domain; \
	curl -s -o /dev/null -w "SSL Test for $$domain: %{http_code}\n" https://$$domain