import time

import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.accounts import router as accounts_router
from app.api.auth import router as auth_router
from app.api.books import router as books_router
from app.api.budgets import router as budgets_router
from app.api.categories import router as categories_router
from app.api.debts import router as debts_router
from app.api.recurring import router as recurring_router
from app.api.tags import router as tags_router
from app.api.transactions import router as transactions_router
from app.api.users import router as users_router
from app.database import async_session
import app.models  # noqa: F401 — register all ORM models

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.dev.ConsoleRenderer() if __import__("sys").stdout.isatty() else structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(20),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

app = FastAPI(title="Family Finance API", version="0.1.0")

app.include_router(accounts_router)
app.include_router(auth_router)
app.include_router(books_router)
app.include_router(budgets_router)
app.include_router(categories_router)
app.include_router(debts_router)
app.include_router(recurring_router)
app.include_router(tags_router)
app.include_router(transactions_router)
app.include_router(users_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    start = time.monotonic()
    response = await call_next(request)
    duration_ms = (time.monotonic() - start) * 1000

    logger.info(
        "request",
        method=request.method,
        path=request.url.path,
        status=response.status_code,
        duration_ms=round(duration_ms, 1),
    )

    if duration_ms > 1000:
        logger.warning("slow_request", path=request.url.path, duration_ms=round(duration_ms, 1))

    return response


@app.get("/health")
async def health_check():
    checks = {}
    try:
        async with async_session() as session:
            await session.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception:
        checks["database"] = "error"

    all_ok = all(v == "ok" for v in checks.values())
    return JSONResponse(
        content={"status": "healthy" if all_ok else "degraded", "checks": checks},
        status_code=200 if all_ok else 503,
    )
