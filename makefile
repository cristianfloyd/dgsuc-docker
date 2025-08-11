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
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development Commands
dev: ## Start development environment
	@echo "Starting development environment..."
	$(COMPOSE_DEV) up -d
	@echo "Development environment is running at http://localhost:8080"

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

# Production Commands
prod: ## Start production environment
	@echo "Starting production environment..."
	./scripts/deploy.sh production

prod-build: ## Build production images
	BUILD_TARGET=production $(COMPOSE_PROD) build

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
	docker-compose exec app php artisan migrate

db-seed: ## Seed the database
	docker-compose exec app php artisan db:seed

db-fresh: ## Fresh database with seeds
	docker-compose exec app php artisan migrate:fresh --seed

db-backup: ## Backup database
	./scripts/backup.sh database

db-restore: ## Restore database from backup
	@read -p "Enter backup file name: " backup; \
	./scripts/restore.sh $$backup

# Laravel Commands
artisan: ## Run artisan command (usage: make artisan cmd="route:list")
	docker-compose exec app php artisan $(cmd)

composer: ## Run composer command (usage: make composer cmd="require package")
	docker-compose exec app composer $(cmd)

npm: ## Run npm command (usage: make npm cmd="run build")
	docker-compose exec node npm $(cmd)

test: ## Run tests
	docker-compose exec app php artisan test

test-coverage: ## Run tests with coverage
	docker-compose exec app php artisan test --coverage

# Cache Commands
cache-clear: ## Clear all caches
	docker-compose exec app php artisan cache:clear
	docker-compose exec app php artisan config:clear
	docker-compose exec app php artisan route:clear
	docker-compose exec app php artisan view:clear

cache-build: ## Build all caches (production)
	docker-compose exec app php artisan config:cache
	docker-compose exec app php artisan route:cache
	docker-compose exec app php artisan view:cache
	docker-compose exec app php artisan event:cache

# Queue Commands
queue-work: ## Start queue worker
	docker-compose exec app php artisan queue:work

queue-restart: ## Restart queue workers
	docker-compose exec app php artisan queue:restart

queue-failed: ## List failed jobs
	docker-compose exec app php artisan queue:failed

queue-retry: ## Retry failed jobs
	docker-compose exec app php artisan queue:retry all

# SSH Tunnel Commands
tunnel-status: ## Check SSH tunnel status
	docker-compose exec ssh-tunnel ps aux | grep ssh

tunnel-restart: ## Restart SSH tunnels
	docker-compose restart ssh-tunnel

tunnel-logs: ## Show SSH tunnel logs
	docker-compose logs -f ssh-tunnel

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

ssl-renew: ## Renew SSL certificates
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

# Utility Commands
ps: ## Show running containers
	docker-compose ps

stats: ## Show container resource usage
	docker stats --no-stream

clean: ## Clean everything (containers, volumes, images)
	@echo "Warning: This will remove all containers, volumes, and images!"
	@read -p "Are you sure? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ]; then \
		docker-compose down -v --rmi all; \
	fi

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