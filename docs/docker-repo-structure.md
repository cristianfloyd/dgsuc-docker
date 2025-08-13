dgsuc-docker/
├── .gitignore
├── README.md
├── Makefile
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.prod.yml
├── .env.example
├── app/                    # Carpeta donde se clonará la aplicación (ignorada en git)
├── docker/
│   ├── app/
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── php.ini
│   │   ├── php-dev.ini
│   │   └── entrypoint.sh
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── sites/
│   │   │   ├── default.conf
│   │   │   └── default-ssl.conf
│   │   └── certs/
│   │       └── .gitkeep
│   ├── workers/
│   │   ├── Dockerfile
│   │   ├── supervisord.conf
│   │   └── entrypoint.sh
│   ├── ssh-tunnel/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   ├── healthcheck.sh
│   │   └── config/
│   │       └── tunnels.conf
│   ├── postgres/
│   │   ├── init.sql
│   │   ├── init-dev.sql
│   │   ├── postgresql.conf
│   │   └── postgresql-prod.conf
│   ├── redis/
│   │   ├── redis.conf
│   │   └── redis-prod.conf
│   └── monitoring/
│       ├── prometheus/
│       │   └── prometheus.yml
│       └── grafana/
│           ├── dashboards/
│           │   └── dgsuc-dashboard.json
│           └── datasources/
│               └── prometheus.yml
└── scripts/
    ├── init.sh
    ├── clone-app.sh
    ├── deploy.sh
    ├── backup.sh
    ├── restore.sh
    └── ssl-setup.sh