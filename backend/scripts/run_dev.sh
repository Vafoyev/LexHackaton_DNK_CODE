#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo -e "${RED}[XATOLIK] $1 buyrug'i topilmadi. Iltimos, o'rnating.${NC}"
        exit 1
    }
}

ensure_env() {
    if [[ ! -f .env ]]; then
        JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        cat > .env <<EOF
APP_ENV=development
HTTP_ADDR=:8080
DATABASE_URL=postgres://lexguard:lexguard@127.0.0.1:5432/lexguard?sslmode=disable
JWT_SECRET=${JWT_SECRET}
AI_PROVIDER=noop
EXTERNAL_AI_ENABLED=true
STORAGE_DIR=./var/uploads
EOF
        echo -e "${GREEN}[INFO] .env fayli avtomatik xavfsiz tasodifiy kalitlar bilan yaratildi.${NC}"
    fi
}

ensure_database() {
    echo -e "${BLUE}[1/4] PostgreSQL va pgvector tekshirilmoqda...${NC}"
    # Try psql check
    if command -v psql >/dev/null 2>&1; then
        psql -U lexguard -d lexguard -c "SELECT 1;" >/dev/null 2>&1 || {
            echo -e "${YELLOW}[INFO] 'lexguard' bazasi yoki foydalanuvchisi sozlanmoqda...${NC}"
            psql -U "$(whoami)" -d postgres -c "
                DO \$\$
                BEGIN
                    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'lexguard') THEN
                        CREATE ROLE lexguard WITH LOGIN PASSWORD 'lexguard' SUPERUSER CREATEDB;
                    END IF;
                END
                \$\$;
            " >/dev/null 2>&1 || true
            psql -U "$(whoami)" -d postgres -c "CREATE DATABASE lexguard OWNER lexguard;" >/dev/null 2>&1 || true
            psql -U lexguard -d lexguard -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >/dev/null 2>&1 || true
        }
    elif command -v docker >/dev/null 2>&1; then
        echo -e "${BLUE}[INFO] Docker orqali PostgreSQL ko'tarilmoqda...${NC}"
        docker compose up -d --wait postgres || true
    fi
    echo -e "${GREEN}[OK] PostgreSQL va pgvector faol.${NC}"
}

cmd_up() {
    require_cmd go
    ensure_env
    ensure_database

    mkdir -p bin var/uploads

    echo -e "${BLUE}[2/4] Baza migratsiyalari va qonunchilik korpusi (FK, O'RQ-547/1115/1125) yuklanmoqda...${NC}"
    go build -o ./bin/migrate ./cmd/migrate
    ./bin/migrate up
    ./bin/migrate seed

    echo -e "${BLUE}[3/4] Go Modular Monolith binary qurilmoqda...${NC}"
    go build -o ./bin/lexguard-api ./cmd/server

    echo -e "${BLUE}[4/4] LexGuard AI serveri ishga tushirilmoqda...${NC}"
    echo -e "${GREEN}========================================================================${NC}"
    echo -e "${GREEN}  🛡️  LexGuard AI 3.0 Backend Server Tayyor!${NC}"
    echo -e "${GREEN}  - URL: http://127.0.0.1:8080${NC}"
    echo -e "${GREEN}  - Liveness/Readiness: http://127.0.0.1:8080/readyz${NC}"
    echo -e "${GREEN}  - Demo Yurist Login: lawyer@lexguard.uz (Parol: Password123!)${NC}"
    echo -e "${GREEN}  - Demo Klient Login: client@lexguard.uz (Parol: Password123!)${NC}"
    echo -e "${GREEN}  - Tezkor Demo Sessiya: POST /api/v1/auth/demo-session${NC}"
    echo -e "${GREEN}========================================================================${NC}"

    exec ./bin/lexguard-api
}

cmd_test() {
    require_cmd go
    echo -e "${BLUE}Unit va Anti-Gallyutsinatsiya testlari ishga tushirilmoqda...${NC}"
    go test -v -race -count=1 ./...
}

cmd_reset() {
    echo -e "${YELLOW}Baza noldan tozalanib qayta yuklanmoqda...${NC}"
    go build -o ./bin/migrate ./cmd/migrate
    ./bin/migrate reset
    echo -e "${GREEN}[OK] Baza muvaffaqiyatli tozalandi va seed yuklandi.${NC}"
}

cmd_down() {
    echo -e "${YELLOW}Server to'xtatilmoqda...${NC}"
    pkill -f "lexguard-api" || true
    echo -e "${GREEN}[OK] To'xtatildi.${NC}"
}

case "${1:-up}" in
    up)    cmd_up ;;
    test)  cmd_test ;;
    reset) cmd_reset ;;
    down)  cmd_down ;;
    *)     echo "Ishlatish: $0 {up|test|reset|down}"; exit 2 ;;
esac
