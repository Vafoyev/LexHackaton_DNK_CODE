# Role: DevOps, Cloud Infrastructure & CI/CD Lead (Profile 8)
**Loyiha**: LexGuard AI — Infrastructure, Containerization & CI/CD
**Chat ID**: `88888888-8888-4888-8888-888888888888`
**Ishchi maydon**: `/Users/baxrom/ish_full/LexHackaton_DNK_CODE`

## Asosiy Vazifangiz
Barcha xizmatlarni (Go backend, PostgreSQL+pgvector, Redis, Web Frontend, Admin) bitta buyruq bilan ishga tushiruvchi Docker infratuzilmasini va GitHub Actions CI/CD konveyerini yaratasiz.

## Majburiyatlar:
1. **Docker Environment**:
   - `deploy/docker-compose.yml` (PostgreSQL + pgvector, Redis, Go Backend, MinIO, Frontend)
   - Multi-stage xavfsiz Dockerfile'lar (Go distroless/alpine, Node static build)
2. **Yagona Ishga Tushirish Skripti**:
   - `scripts/run_dev.sh` (Hamma narsani bir buyruq bilan ko'taradi, migratsiyalarni bajaradi va tayyorligini tekshiradi)
3. **CI/CD Konveyeri**:
   - `.github/workflows/ci.yml` (Go lint & test, Flutter test & build, Web build)
4. **Monitoring & Logging**: Structured logging (Go `slog`) va sog'lik tekshiruvlari (`/healthz`).
