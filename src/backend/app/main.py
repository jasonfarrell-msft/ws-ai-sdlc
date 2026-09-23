from __future__ import annotations

import os
import logging
from dataclasses import dataclass
from typing import Annotated, Literal, cast

from fastapi import Depends, FastAPI, Header, HTTPException, Path, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .models import ArticleFilters, ChangeStatus, CreateTicket, TicketFilters
from .store import SupportStore

MAX_BODY_BYTES = 16_384
logger = logging.getLogger("support_desk.api")
DEMO_IDENTITIES = {
    ("maya.chen", "requester"): "Maya Chen",
    ("jordan.lee", "agent"): "Jordan Lee",
}


def error_response(status: int, code: str, message: str, details: object | None = None) -> JSONResponse:
    error: dict[str, object] = {"code": code, "message": message}
    if details is not None:
        error["details"] = details
    return JSONResponse(status_code=status, content={"error": error})


@dataclass(frozen=True)
class Identity:
    user: str
    role: Literal["requester", "agent"]
    display_name: str


def require_identity(
    user: Annotated[str | None, Header(alias="x-demo-user")] = None,
    role: Annotated[str | None, Header(alias="x-demo-role")] = None,
) -> Identity:
    display_name = DEMO_IDENTITIES.get((user or "", role or ""))
    if not display_name:
        raise HTTPException(status_code=401, detail={"code": "demo_identity_required", "message": "Use a valid demo identity and role."})
    return Identity(
        user=user or "",
        role=cast(Literal["requester", "agent"], role),
        display_name=display_name,
    )


def require_role(expected: Literal["requester", "agent"]):
    def dependency(identity: Annotated[Identity, Depends(require_identity)]) -> Identity:
        if identity.role != expected:
            raise HTTPException(status_code=403, detail={"code": "forbidden", "message": f"This action requires the {expected} demo role."})
        return identity
    return dependency


app = FastAPI(title="Support Desk Simulator API", version="1.0.0", docs_url=None, redoc_url=None)
app.state.store = SupportStore()
frontend_origin = os.getenv("FRONTEND_ORIGIN", "http://localhost:5173")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[frontend_origin],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["Content-Type", "x-demo-user", "x-demo-role"],
)


@app.middleware("http")
async def security_and_size_headers(request: Request, call_next):
    response = None
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            if int(content_length) > MAX_BODY_BYTES:
                response = error_response(413, "request_too_large", "Request body exceeds 16 KB.")
        except ValueError:
            response = error_response(400, "invalid_content_length", "Content-Length must be a number.")
    if response is None and request.method in {"POST", "PUT", "PATCH"}:
        body = await request.body()
        if len(body) > MAX_BODY_BYTES:
            response = error_response(413, "request_too_large", "Request body exceeds 16 KB.")
    if response is None:
        response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError):
    details = [{"field": ".".join(str(part) for part in item["loc"][1:]), "message": item["msg"]} for item in exc.errors()]
    return error_response(422, "validation_error", "The request was not valid.", details)


@app.exception_handler(StarletteHTTPException)
async def http_error(_: Request, exc: StarletteHTTPException):
    detail = exc.detail
    if isinstance(detail, dict):
        return error_response(exc.status_code, str(detail.get("code", "request_error")), str(detail.get("message", "Request failed.")))
    return error_response(exc.status_code, "request_error", str(detail))


@app.exception_handler(Exception)
async def unhandled_error(_: Request, exc: Exception):
    logger.error("Unhandled API request failure: %s", type(exc).__name__, exc_info=exc)
    return error_response(500, "internal_error", "An unexpected error occurred.")


def store(request: Request) -> SupportStore:
    return request.app.state.store


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.get("/api/tickets")
def list_tickets(
    request: Request,
    _: Annotated[Identity, Depends(require_identity)],
    filters: Annotated[TicketFilters, Query()],
):
    return {"tickets": store(request).list_tickets(filters.status, filters.priority, filters.product, filters.search)}


@app.post("/api/tickets", status_code=201)
def create_ticket(request: Request, data: CreateTicket, identity: Annotated[Identity, Depends(require_role("requester"))]):
    return {"ticket": store(request).create_ticket(data, identity.display_name)}


@app.get("/api/tickets/{ticket_id}")
def get_ticket(request: Request, ticket_id: Annotated[str, Path(pattern=r"^TKT-[0-9]{4,}$", max_length=20)], _: Annotated[Identity, Depends(require_identity)]):
    ticket = store(request).get_ticket(ticket_id)
    if not ticket:
        return error_response(404, "ticket_not_found", "Ticket was not found.")
    return {"ticket": ticket}


@app.post("/api/tickets/{ticket_id}/assign")
def assign_ticket(request: Request, ticket_id: Annotated[str, Path(pattern=r"^TKT-[0-9]{4,}$", max_length=20)], identity: Annotated[Identity, Depends(require_role("agent"))]):
    ticket = store(request).assign(ticket_id, identity.display_name)
    if not ticket:
        return error_response(404, "ticket_not_found", "Ticket was not found.")
    return {"ticket": ticket}


@app.patch("/api/tickets/{ticket_id}/status")
def change_ticket_status(request: Request, ticket_id: Annotated[str, Path(pattern=r"^TKT-[0-9]{4,}$", max_length=20)], data: ChangeStatus, identity: Annotated[Identity, Depends(require_role("agent"))]):
    ticket = store(request).change_status(ticket_id, data.status, identity.display_name)
    if not ticket:
        return error_response(404, "ticket_not_found", "Ticket was not found.")
    return {"ticket": ticket}


@app.get("/api/tickets/{ticket_id}/history")
def ticket_history(request: Request, ticket_id: Annotated[str, Path(pattern=r"^TKT-[0-9]{4,}$", max_length=20)], _: Annotated[Identity, Depends(require_identity)]):
    history = store(request).history(ticket_id)
    if history is None:
        return error_response(404, "ticket_not_found", "Ticket was not found.")
    return {"history": history}


@app.get("/api/articles")
def list_articles(
    request: Request,
    _: Annotated[Identity, Depends(require_identity)],
    filters: Annotated[ArticleFilters, Query()],
):
    return {"articles": store(request).list_articles(filters.search)}


@app.get("/api/articles/{article_id}")
def get_article(request: Request, article_id: Annotated[str, Path(pattern=r"^KB-[0-9]{3,}$", max_length=20)], _: Annotated[Identity, Depends(require_identity)]):
    article = store(request).get_article(article_id)
    if not article:
        return error_response(404, "article_not_found", "Article was not found.")
    return {"article": article}
