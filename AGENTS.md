# AGENTS.md

## Project Overview

Family finance app (家庭记账系统) — transaction tracking, budgets, reporting, family collaboration. Three clients (Vue web, Flutter mobile, Flutter web) share one FastAPI backend + PostgreSQL.

## Stack

| Layer | Tech |
|-------|------|
| Backend | Python 3.12, FastAPI, SQLAlchemy 2.0 (async), asyncpg |
| Frontend | Vue 3, TypeScript, Vite, Element Plus, ECharts |
| Mobile | Flutter, Riverpod, go_router, fl_chart, Dio |
| DB | PostgreSQL 15 (Alpine) |
| Deploy | Docker Compose — 5 services: db, api, web, flutter-web, nginx |

## Commands

### Backend

```bash
# Run API server (dev)
docker compose up api

# Run full API test suite (164 cases)
python3 scripts/test_backend_api.py

# Run tests inside container (requires DB running)
docker compose exec api pytest tests/ -v
```

### Frontend (inside Docker)

```bash
# Dev server with hot-reload
docker compose up web

# Type-check + build
docker compose exec web npm run build

# Type-check only
docker compose exec web npx vue-tsc -b --noEmit
```

### Flutter Mobile

```bash
# Analyze (check for errors)
cd mobile && flutter analyze

# Build web release
cd mobile && flutter build web --release

# Deploy web to container
docker cp mobile/build/web/. ff-flutter-web:/usr/share/nginx/html/

# Build APK release
cd mobile && flutter build apk --release

# Install APK on connected device
adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk

# Run tests
cd mobile && flutter test
```

### Full Stack

```bash
docker compose up -d            # Start everything
docker compose ps               # Check status
curl http://localhost/health    # Health check (proxied through nginx)
```

### UDP Discovery (LAN server discovery for Android app)

```bash
# Run on host machine (not in Docker) — broadcasts server IP on port 9876
python3 scripts/udp_discovery.py
```

## Architecture

- **Backend entrypoint**: `backend/app/main.py` — FastAPI app with lifespan (scheduler + UDP discovery)
- **DB init**: `db/init/01-*.sql` through `06-*.sql` — loaded in order by `docker-entrypoint-initdb.d` on first container start
- **Nginx routing** (port 8080): `/api/` → api:8000, `/` → web:5173 (dev)
- **Nginx mobile web** (port 8090): Flutter web build served via ff-flutter-web container
- **API routers**: 38+ routers in `backend/app/api/`, all registered in `main.py`
- **ORM models**: registered via `import app.models` in main.py (side-effect import)
- **Mobile models**: hand-written in `mobile/lib/data/models/models.dart` (fromJson/toJson, no codegen)
- **API service**: `mobile/lib/data/services/api_service.dart` — singleton Dio client with all CRUD methods

## Key Gotchas

- **Async everywhere**: Backend uses `asyncpg` + `AsyncSession`. All DB calls are `await session.execute(...)`. Don't use synchronous SQLAlchemy patterns.
- **CORS origins hardcoded** in `main.py`: `localhost:5173` and `127.0.0.1:5173`. If changing frontend port, update here.
- **DB init runs only on first start**: Volume `pgdata` persists data. To re-init, `docker compose down -v` (destroys data).
- **Flutter web Dockerfile**: just copies pre-built `build/web/` into nginx. Build must happen locally first with `flutter build web --release`, then `docker cp`.
- **Android needs cleartext HTTP**: `android/app/src/main/res/xml/network_security_config.xml` must allow cleartext for local dev server.
- **Android INTERNET permission**: Must be in `AndroidManifest.xml` or network calls fail silently with `Operation not permitted`.
- **Docker code not volume-mounted**: Backend code is baked into the image. To deploy changes: `docker cp` + `docker restart`.
- **API returns List not Map**: Most list endpoints (`/transactions`, `/budgets`, `/categories`, `/stats/*`) return arrays directly, not `{items: [...]}` wrappers.
- **Model null safety**: Many API fields return `null` for optional data (e.g., `month` for yearly budgets, `entry_side` for transactions). fromJson methods must use `??` defaults.

## Testing

- **Backend API tests**: `scripts/test_backend_api.py` — 164 test cases covering all modules (auth, transactions, accounts, budgets, categories, tags, stats, sync, credit bills, debts, savings, recurring, reimbursements, imports, AI, family)
- **Flutter tests**: `mobile/test/` — `flutter test`
- **Frontend**: no test framework configured
- **Android**: Build APK + `adb install` for on-device testing

## Environment

- `.env` required (copy from `.env.example`). Key vars: `DB_PASSWORD`, `SECRET_KEY`, `POSTGRES_DB`, `POSTGRES_USER`
- Secrets must not be committed — `.env` is in `.gitignore`

## Code Style

- Backend: Python 3.12, pydantic v2 + SQLAlchemy 2.0
- Frontend: strict TypeScript (`noUnusedLocals`, `noUnusedParameters` enabled in tsconfig)
- Mobile: flutter_lints, hand-written models with fromJson/toJson
- API routes use dependency injection (`Depends(get_db)`) pattern consistently
- Git commit format: Chinese verb (2 chars) + space + description (e.g., "修复 xxx", "新增 xxx")
