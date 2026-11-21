# ============================================================
#  LexGuard AI 3.0 — Makefile
#  Convenient commands for Docker & Local development
# ============================================================

.PHONY: help up down restart build logs ps dev local clean

help:
	@echo "LexGuard AI 3.0 — Commands:"
	@echo "  make up        - Start full Docker stack (Postgres, Redis, MinIO, Backend, Front, Admin)"
	@echo "  make down      - Stop all Docker containers"
	@echo "  make restart   - Restart all Docker containers"
	@echo "  make build     - Build all Docker images"
	@echo "  make logs      - Tail all Docker container logs"
	@echo "  make ps        - Check running containers"
	@echo "  make dev       - Run with ./scripts/run_dev.sh"
	@echo "  make local     - Run native local mode without Docker"

up:
	docker compose -f deploy/docker-compose.yml up -d

down:
	docker compose -f deploy/docker-compose.yml down

restart:
	docker compose -f deploy/docker-compose.yml restart

build:
	docker compose -f deploy/docker-compose.yml build

logs:
	docker compose -f deploy/docker-compose.yml logs -f

ps:
	docker compose -f deploy/docker-compose.yml ps

dev:
	./scripts/run_dev.sh

local:
	./scripts/run_dev.sh local

clean:
	docker compose -f deploy/docker-compose.yml down -v --remove-orphans
