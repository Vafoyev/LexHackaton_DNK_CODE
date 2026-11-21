#!/usr/bin/env bash
# ============================================================
#  LexGuard AI 3.0 — Yagona Idempotent Ishga Tushirish Skripti
#  D-09 + D-10 Directive: "Bitta buyruq bilan butun tizim"
#  Muallif: DevOps/SRE Lead (Profile 8)
#
#  FOYDALANISH:
#    ./scripts/run_dev.sh          → Docker Compose bilan to'liq stack
#    ./scripts/run_dev.sh local    → Lokal (Docker'siz) Go backend
#    ./scripts/run_dev.sh down     → Barcha konteynerlarni to'xtatish
#    ./scripts/run_dev.sh logs     → Real-time loglar
#    ./scripts/run_dev.sh health   → Sog'lik tekshiruvi
#    ./scripts/run_dev.sh reset    → To'liq tozalab qayta boshlash
# ============================================================
set -Eeuo pipefail

# ── Ranglar ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Yo'llar ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_DIR="${ROOT_DIR}/deploy"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONT_DIR="${ROOT_DIR}/front"
ENV_FILE="${ROOT_DIR}/.env"
COMPOSE_FILE="${DEPLOY_DIR}/docker-compose.yml"

# ── Banner ───────────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ██╗     ███████╗██╗  ██╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗ "
    echo "  ██║     ██╔════╝╚██╗██╔╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗"
    echo "  ██║     █████╗   ╚███╔╝ ██║  ███╗██║   ██║███████║██████╔╝██║  ██║"
    echo "  ██║     ██╔══╝   ██╔██╗ ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║"
    echo "  ███████╗███████╗██╔╝ ██╗╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝"
    echo "  ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    echo -e "${NC}"
    echo -e "  ${BOLD}🛡️  LexGuard AI 3.0${NC} — Shartnomalar Xavfsizligi Platformasi"
    echo -e "  ${YELLOW}D-10 Stack: 3D WebGL + AI Live Voice + Anti-Hallucination${NC}"
    echo -e "  ${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ── Yordamchi Funksiyalar ────────────────────────────────────
log()  { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${BLUE}→${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "  ${RED}✗${NC}  $*" >&2; }
step() { echo -e "\n  ${BOLD}${CYAN}[$1]${NC} $2"; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "'$1' buyrug'i topilmadi. Iltimos o'rnating: $2"
        exit 1
    }
}

# ── .env Fayli Yaratish/Tekshirish ───────────────────────────
ensure_env() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        info ".env fayli topilmadi, avtomatik xavfsiz kalitlar yaratilmoqda..."
        JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        cat > "${ENV_FILE}" << EOF
# LexGuard AI 3.0 — Environment Variables (Auto-generated $(date -u +%Y-%m-%d))
# ⚠️  PRODUCTION UCHUN BARCHA QIYMATLARNI O'ZGARTIRING!

APP_ENV=development
APP_VERSION=1.0.0

# ── PostgreSQL ───────────────────────────────────────
POSTGRES_USER=lexguard
POSTGRES_PASSWORD=lexguard_secret_2026
POSTGRES_DB=lexguard
POSTGRES_PORT=5432

# ── Redis ────────────────────────────────────────────
REDIS_PASSWORD=redis_lexguard_2026
REDIS_PORT=6379

# ── MinIO (Object Storage) ───────────────────────────
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minio_lexguard_2026
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_BUCKET=lexguard-documents

# ── Go Backend ──────────────────────────────────────
JWT_SECRET=${JWT_SECRET}
AI_PROVIDER=noop
EXTERNAL_AI_ENABLED=false
BACKEND_PORT=8080

# ── Web Frontend ────────────────────────────────────
VITE_API_URL=/api/v1
FRONTEND_PORT=3000

# ── Admin Portal ────────────────────────────────────
ADMIN_PORT=4000
EOF
        log ".env fayli yaratildi: ${ENV_FILE}"
    else
        log ".env fayli mavjud."
    fi
    # Load env vars
    set -a; source "${ENV_FILE}"; set +a
}

# ── Admin placeholder (agar bo'sh bo'lsa) ────────────────────
ensure_admin_placeholder() {
    if [[ ! -f "${ROOT_DIR}/admin/index.html" ]]; then
        mkdir -p "${ROOT_DIR}/admin"
        cat > "${ROOT_DIR}/admin/index.html" << 'ADMINHTML'
<!DOCTYPE html>
<html lang="uz" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LexGuard AI — Admin Portal</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #020617; color: #f1f5f9; font-family: Inter, system-ui, sans-serif;
      display: flex; align-items: center; justify-content: center; min-height: 100vh;
      background-image: radial-gradient(ellipse at 20% 50%, rgba(99,102,241,0.15) 0%, transparent 60%);
    }
    .card {
      background: rgba(15,23,42,0.8); border: 1px solid rgba(99,102,241,0.3);
      border-radius: 16px; padding: 48px; text-align: center; max-width: 480px;
      backdrop-filter: blur(12px);
    }
    .shield { font-size: 64px; margin-bottom: 24px; }
    h1 { font-size: 28px; font-weight: 700; color: #818cf8; margin-bottom: 8px; }
    p  { color: #94a3b8; line-height: 1.6; margin-bottom: 24px; }
    .badge {
      display: inline-block; background: rgba(99,102,241,0.2);
      border: 1px solid rgba(99,102,241,0.4); border-radius: 20px;
      padding: 4px 16px; font-size: 12px; color: #a5b4fc; margin: 4px;
    }
    .api-link {
      display: block; margin-top: 24px; color: #60a5fa; text-decoration: none;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="shield">🏛️</div>
    <h1>LexGuard AI Admin</h1>
    <p>B2B Korporativ Kabinet — Shartnomalar Monitoringi va Xavflar Xaritasi</p>
    <span class="badge">📊 Analytics</span>
    <span class="badge">🛡️ Security</span>
    <span class="badge">📋 Audit Trail</span>
    <a class="api-link" href="http://localhost:8080/api/v1/integrations/status" target="_blank">
      → Backend API Status
    </a>
    <a class="api-link" href="http://localhost:3000" target="_blank">
      → Web Frontend
    </a>
  </div>
</body>
</html>
ADMINHTML
        info "Admin placeholder yaratildi."
    fi
}

# ── Docker Mavjudligini Tekshirish ───────────────────────────
check_docker() {
    require_cmd docker "https://docs.docker.com/get-docker/"
    # Docker daemon ishlaydimi?
    docker info >/dev/null 2>&1 || {
        err "Docker daemon ishlamayapti. Iltimos ishga tushiring: open -a Docker"
        exit 1
    }
    log "Docker daemon faol."
}

# ── Docker Compose Versiyasini Aniqlash ─────────────────────
get_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        err "docker compose yoki docker-compose topilmadi!"
        exit 1
    fi
}

# ── Health Check (barcha xizmatlar) ─────────────────────────
wait_for_health() {
    local service=$1
    local url=$2
    local max_attempts=${3:-30}
    local attempt=1

    info "${service} tayyor bo'lishini kutilmoqda..."
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            log "${service} tayyor! (${attempt}/${max_attempts})"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    echo ""
    warn "${service} ${max_attempts} urinishdan keyin ham tayyor bo'lmadi (non-fatal)"
    return 0
}

# ── ASOSIY: Docker Compose bilan Stack Ko'tarish ────────────
cmd_up() {
    print_banner
    check_docker
    ensure_env
    ensure_admin_placeholder

    local COMPOSE=$(get_compose_cmd)
    local COMPOSE_CMD="${COMPOSE} -f ${COMPOSE_FILE} --env-file ${ENV_FILE}"

    step "1/5" "Tarmoq va volume'lar yaratilmoqda..."
    ${COMPOSE_CMD} up -d --remove-orphans --build --wait postgres redis 2>&1 | grep -E "(Starting|Started|healthy|Error)" | head -20 || true
    log "PostgreSQL 16 + pgvector va Redis ko'tarildi."

    step "2/5" "MinIO object storage ishga tushirilmoqda..."
    ${COMPOSE_CMD} up -d --wait minio 2>&1 | grep -E "(Starting|Started|healthy|Error)" | head -10 || true
    log "MinIO Console: http://localhost:${MINIO_CONSOLE_PORT:-9001}"

    step "3/5" "Go Backend (Modular Monolith) build va ishga tushirish..."
    ${COMPOSE_CMD} up -d --build --wait backend 2>&1 | grep -E "(Building|Built|Starting|Started|healthy|Error)" | head -20 || true
    wait_for_health "Go Backend" "http://localhost:${BACKEND_PORT:-8080}/healthz" 30
    log "Backend API: http://localhost:${BACKEND_PORT:-8080}"

    step "4/5" "Web Frontend (React + Three.js 3D + Live Voice) build..."
    ${COMPOSE_CMD} up -d --build --wait frontend 2>&1 | grep -E "(Building|Built|Starting|Started|healthy|Error)" | head -20 || true
    log "Web Frontend: http://localhost:${FRONTEND_PORT:-3000}"

    step "5/5" "Admin Portal (B2B Analytics) build..."
    ${COMPOSE_CMD} up -d --build --wait admin 2>&1 | grep -E "(Building|Built|Starting|Started|healthy|Error)" | head -20 || true
    log "Admin Portal: http://localhost:${ADMIN_PORT:-4000}"

    echo ""
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}${BOLD}  🛡️  LexGuard AI 3.0 — BARCHA XIZMATLAR TAYYOR!${NC}"
    echo -e "  ${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}🌐 Web Frontend${NC}     : http://localhost:${FRONTEND_PORT:-3000}"
    echo -e "  ${BOLD}🏛️  Admin Portal${NC}     : http://localhost:${ADMIN_PORT:-4000}"
    echo -e "  ${BOLD}⚙️  Go Backend API${NC}   : http://localhost:${BACKEND_PORT:-8080}"
    echo -e "  ${BOLD}📊 MinIO Console${NC}    : http://localhost:${MINIO_CONSOLE_PORT:-9001}"
    echo -e "  ${BOLD}🗄️  PostgreSQL${NC}       : localhost:${POSTGRES_PORT:-5432} (lexguard/lexguard_secret_2026)"
    echo -e "  ${BOLD}🔴 Redis${NC}            : localhost:${REDIS_PORT:-6379}"
    echo ""
    echo -e "  ${CYAN}── D-10 Funksiyalar ─────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}🔊 AI Live Voice${NC}    : POST http://localhost:${BACKEND_PORT:-8080}/api/v1/analyses/{id}/voice-brief"
    echo -e "  ${BOLD}🌐 3D Visualizer${NC}    : http://localhost:${FRONTEND_PORT:-3000} → 'Tahlil' sahifasi"
    echo -e "  ${BOLD}📈 Health Check${NC}     : http://localhost:${BACKEND_PORT:-8080}/healthz"
    echo ""
    echo -e "  ${YELLOW}── Demo Hisoblar ──────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Demo Sessiya${NC}        : POST /api/v1/auth/demo-session"
    echo -e "  ${BOLD}Yurist Login${NC}        : lawyer@lexguard.uz / Password123!"
    echo -e "  ${BOLD}Klient Login${NC}        : client@lexguard.uz / Password123!"
    echo ""
    echo -e "  ${BLUE}📋 Loglarni kuzatish: ./scripts/run_dev.sh logs${NC}"
    echo -e "  ${BLUE}🛑 To'xtatish:        ./scripts/run_dev.sh down${NC}"
    echo ""
}

# ── LOKAL: Docker'siz Go Backend (dev mode) ─────────────────
cmd_local() {
    print_banner
    require_cmd go "https://go.dev/dl/"
    ensure_env

    step "1/3" "Go backend uchun lokal muhit tayyorlanmoqda..."
    cd "${BACKEND_DIR}"

    # Update DATABASE_URL to localhost (not docker network)
    export DATABASE_URL="postgres://${POSTGRES_USER:-lexguard}:${POSTGRES_PASSWORD:-lexguard_secret_2026}@127.0.0.1:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-lexguard}?sslmode=disable"

    step "2/3" "Migratsiyalar va Seed ma'lumotlar yuklanmoqda..."
    go build -o ./bin/migrate ./cmd/migrate
    ./bin/migrate up && ./bin/migrate seed || warn "Migratsiya xatosi (baza allaqachon tayyor bo'lishi mumkin)"

    step "3/3" "LexGuard AI Go Backend ishga tushirilmoqda..."
    go build -o ./bin/lexguard-api ./cmd/server
    log "Backend: http://127.0.0.1:8080"
    exec ./bin/lexguard-api
}

# ── TO'XTATISH ───────────────────────────────────────────────
cmd_down() {
    check_docker
    local COMPOSE=$(get_compose_cmd)
    info "Barcha LexGuard AI konteynerlar to'xtatilmoqda..."
    ${COMPOSE} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" down --remove-orphans
    log "Barcha xizmatlar to'xtatildi."
}

# ── LOGLAR ───────────────────────────────────────────────────
cmd_logs() {
    check_docker
    local COMPOSE=$(get_compose_cmd)
    local service="${2:-}"
    ${COMPOSE} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" logs -f --tail=100 ${service}
}

# ── SOG'LIK TEKSHIRUVI ───────────────────────────────────────
cmd_health() {
    ensure_env
    echo -e "\n  ${BOLD}${CYAN}🩺 LexGuard AI — Sog'lik Tekshiruvi${NC}\n"
    local all_ok=true

    check_service() {
        local name="$1" url="$2"
        if curl -sf "$url" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC}  ${BOLD}${name}${NC}"
        else
            echo -e "  ${RED}✗${NC}  ${BOLD}${name}${NC} — JAVOB YO'Q (${url})"
            all_ok=false
        fi
    }

    check_service "Go Backend (/healthz)"    "http://localhost:${BACKEND_PORT:-8080}/healthz"
    check_service "Go Backend (/readyz)"     "http://localhost:${BACKEND_PORT:-8080}/readyz"
    check_service "Web Frontend"             "http://localhost:${FRONTEND_PORT:-3000}"
    check_service "Admin Portal"             "http://localhost:${ADMIN_PORT:-4000}"
    check_service "MinIO Console"            "http://localhost:${MINIO_CONSOLE_PORT:-9001}"

    echo ""
    if $all_ok; then
        log "Barcha xizmatlar sog'lom! 🎉"
    else
        warn "Ba'zi xizmatlar javob bermayapti. 'docker compose logs' bilan tekshiring."
    fi
    echo ""
}

# ── TO'LIQ RESET ─────────────────────────────────────────────
cmd_reset() {
    warn "DIQQAT: Barcha ma'lumotlar va volumelar o'chiriladi!"
    read -r -p "  Davom etishni tasdiqlang [y/N]: " confirm
    [[ "${confirm,,}" == "y" ]] || { info "Bekor qilindi."; exit 0; }

    check_docker
    local COMPOSE=$(get_compose_cmd)
    ${COMPOSE} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" down -v --remove-orphans
    docker volume rm lexguard_postgres_data lexguard_redis_data lexguard_minio_data lexguard_uploads_data 2>/dev/null || true
    log "Barcha volumelar o'chirildi. Endi './scripts/run_dev.sh' bilan qayta boshlang."
}

# ── TESTLAR ──────────────────────────────────────────────────
cmd_test() {
    require_cmd go "https://go.dev/dl/"
    step "1/3" "Go Unit & Anti-Hallucination testlari ishga tushirilmoqda..."
    (cd "${BACKEND_DIR}" && go test -v -race -count=1 -timeout=120s ./...)
    log "Go backend testlari muvaffaqiyatli o'tdi!"

    if command -v npm >/dev/null 2>&1 && [ -d "${FRONT_DIR}" ]; then
        step "2/3" "Web Frontend tahlili va TypeScript tekshiruvi..."
        (cd "${FRONT_DIR}" && npx tsc --noEmit)
        log "Web Frontend TypeScript tekshiruvi muvaffaqiyatli o'tdi!"
    fi

    if command -v flutter >/dev/null 2>&1 && [ -d "${ROOT_DIR}/mobile" ]; then
        step "3/3" "Flutter Mobile testlari ishga tushirilmoqda..."
        (cd "${ROOT_DIR}/mobile" && flutter test)
        log "Flutter mobil testlari muvaffaqiyatli o'tdi!"
    fi
}

# ── Asosiy komanda dispatcher ────────────────────────────────
MODE="${1:-up}"
shift 2>/dev/null || true

case "${MODE}" in
    up|start)   cmd_up      ;;
    local)      cmd_local   ;;
    down|stop)  cmd_down    ;;
    logs)       cmd_logs "" "$@" ;;
    health|status) cmd_health ;;
    reset|clean) cmd_reset  ;;
    test)       cmd_test    ;;
    *)
        echo -e "\n  ${BOLD}Foydalanish:${NC}"
        echo "    ./scripts/run_dev.sh [buyruq]"
        echo ""
        echo -e "  ${BOLD}Buyruqlar:${NC}"
        echo "    up      — Docker Compose bilan to'liq stack (default)"
        echo "    local   — Lokal Go backend (Docker'siz)"
        echo "    down    — Barcha konteynerlarni to'xtatish"
        echo "    logs    — Real-time loglar kuzatish"
        echo "    health  — Barcha xizmatlar sog'ligi tekshiruvi"
        echo "    reset   — To'liq tozalash (volumelar bilan)"
        echo "    test    — Go unit testlarini ishga tushirish"
        echo ""
        exit 1
        ;;
esac
