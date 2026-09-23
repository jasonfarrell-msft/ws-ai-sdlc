from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from threading import RLock
from typing import Any

from .models import CreateTicket


def _event(event_id: str, ticket_id: str, kind: str, message: str, actor: str, at: str) -> dict[str, Any]:
    return {
        "id": event_id,
        "ticketId": ticket_id,
        "type": kind,
        "message": message,
        "actor": actor,
        "createdAt": at,
    }


class SupportStore:
    """Process-local demo store. Every operation is protected and returns copies."""

    def __init__(self) -> None:
        self._lock = RLock()
        self.reset()

    def reset(self) -> None:
        with self._lock:
            self._next_ticket = 1004
            self._next_event = 8
            self._tickets: dict[str, dict[str, Any]] = {
                "TKT-1001": {
                    "id": "TKT-1001", "subject": "Unable to export quarterly report",
                    "description": "The CSV export finishes but the downloaded file is empty.",
                    "status": "open", "priority": "high", "product": "Analytics",
                    "requester": "Maya Chen", "assignee": None,
                    "createdAt": "2026-09-18T14:25:00Z", "updatedAt": "2026-09-18T14:25:00Z",
                },
                "TKT-1002": {
                    "id": "TKT-1002", "subject": "New teammate cannot join workspace",
                    "description": "An invitation was accepted, but the workspace remains unavailable.",
                    "status": "pending", "priority": "medium", "product": "Workspace",
                    "requester": "Maya Chen", "assignee": "Jordan Lee",
                    "createdAt": "2026-09-17T09:10:00Z", "updatedAt": "2026-09-19T16:40:00Z",
                },
                "TKT-1003": {
                    "id": "TKT-1003", "subject": "Duplicate billing notification",
                    "description": "Two renewal notices arrived for the same synthetic subscription.",
                    "status": "resolved", "priority": "low", "product": "Billing",
                    "requester": "Maya Chen", "assignee": "Jordan Lee",
                    "createdAt": "2026-09-15T11:05:00Z", "updatedAt": "2026-09-16T13:20:00Z",
                },
            }
            self._history = {
                "TKT-1001": [_event("EVT-1", "TKT-1001", "created", "Ticket created", "Maya Chen", "2026-09-18T14:25:00Z")],
                "TKT-1002": [
                    _event("EVT-2", "TKT-1002", "created", "Ticket created", "Maya Chen", "2026-09-17T09:10:00Z"),
                    _event("EVT-3", "TKT-1002", "assigned", "Assigned to Jordan Lee", "Jordan Lee", "2026-09-17T10:00:00Z"),
                    _event("EVT-4", "TKT-1002", "status", "Status changed from open to pending", "Jordan Lee", "2026-09-19T16:40:00Z"),
                ],
                "TKT-1003": [
                    _event("EVT-5", "TKT-1003", "created", "Ticket created", "Maya Chen", "2026-09-15T11:05:00Z"),
                    _event("EVT-6", "TKT-1003", "assigned", "Assigned to Jordan Lee", "Jordan Lee", "2026-09-15T11:30:00Z"),
                    _event("EVT-7", "TKT-1003", "status", "Status changed from open to resolved", "Jordan Lee", "2026-09-16T13:20:00Z"),
                ],
            }
            self._articles = {
                "KB-101": {
                    "id": "KB-101", "title": "Troubleshoot report exports", "summary": "Checks for empty or incomplete report downloads.",
                    "content": "Confirm the report has data for the selected date range. Then clear active filters, retry the export, and verify that pop-up and download permissions are enabled. If the file remains empty, record the report name and approximate time for support.",
                    "category": "Analytics", "version": 3, "updatedAt": "2026-08-12T10:00:00Z",
                },
                "KB-102": {
                    "id": "KB-102", "title": "Manage workspace invitations", "summary": "Resolve common invitation and membership issues.",
                    "content": "Verify that the invitation email matches the account email. Ask a workspace administrator to revoke any expired invitation and send a new one. Membership changes can take a few minutes to appear after acceptance.",
                    "category": "Workspace", "version": 2, "updatedAt": "2026-07-28T15:30:00Z",
                },
                "KB-103": {
                    "id": "KB-103", "title": "Understand renewal notifications", "summary": "How synthetic subscription reminders are generated.",
                    "content": "Renewal reminders are informational and do not initiate a charge. Duplicate notices can be ignored in this simulator. In a real service, confirm the subscription identifier before contacting billing support.",
                    "category": "Billing", "version": 1, "updatedAt": "2026-06-04T08:45:00Z",
                },
            }

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def list_tickets(self, status: str | None, priority: str | None, product: str | None, search: str | None) -> list[dict[str, Any]]:
        with self._lock:
            tickets = list(self._tickets.values())
            if status:
                tickets = [item for item in tickets if item["status"] == status]
            if priority:
                tickets = [item for item in tickets if item["priority"] == priority]
            if product:
                tickets = [item for item in tickets if item["product"].casefold() == product.casefold()]
            if search:
                needle = search.casefold()
                tickets = [item for item in tickets if needle in f'{item["id"]} {item["subject"]} {item["description"]}'.casefold()]
            return deepcopy(sorted(tickets, key=lambda item: item["updatedAt"], reverse=True))

    def get_ticket(self, ticket_id: str) -> dict[str, Any] | None:
        with self._lock:
            ticket = self._tickets.get(ticket_id)
            return deepcopy(ticket) if ticket else None

    def create_ticket(self, data: CreateTicket, requester: str) -> dict[str, Any]:
        with self._lock:
            ticket_id = f"TKT-{self._next_ticket}"
            self._next_ticket += 1
            now = self._now()
            ticket = {
                "id": ticket_id, **data.model_dump(), "status": "open",
                "requester": requester, "assignee": None, "createdAt": now, "updatedAt": now,
            }
            self._tickets[ticket_id] = ticket
            self._history[ticket_id] = [self._new_event(ticket_id, "created", "Ticket created", requester, now)]
            return deepcopy(ticket)

    def _new_event(self, ticket_id: str, kind: str, message: str, actor: str, at: str) -> dict[str, Any]:
        event = _event(f"EVT-{self._next_event}", ticket_id, kind, message, actor, at)
        self._next_event += 1
        return event

    def assign(self, ticket_id: str, agent: str) -> dict[str, Any] | None:
        with self._lock:
            ticket = self._tickets.get(ticket_id)
            if not ticket:
                return None
            now = self._now()
            ticket["assignee"] = agent
            ticket["updatedAt"] = now
            self._history[ticket_id].append(self._new_event(ticket_id, "assigned", f"Assigned to {agent}", agent, now))
            return deepcopy(ticket)

    def change_status(self, ticket_id: str, status: str, agent: str) -> dict[str, Any] | None:
        with self._lock:
            ticket = self._tickets.get(ticket_id)
            if not ticket:
                return None
            previous = ticket["status"]
            now = self._now()
            ticket["status"] = status
            ticket["updatedAt"] = now
            self._history[ticket_id].append(self._new_event(ticket_id, "status", f"Status changed from {previous} to {status}", agent, now))
            return deepcopy(ticket)

    def history(self, ticket_id: str) -> list[dict[str, Any]] | None:
        with self._lock:
            events = self._history.get(ticket_id)
            return deepcopy(events) if events is not None else None

    def list_articles(self, search: str | None) -> list[dict[str, Any]]:
        with self._lock:
            articles = list(self._articles.values())
            if search:
                needle = search.casefold()
                articles = [item for item in articles if needle in f'{item["title"]} {item["summary"]} {item["content"]} {item["category"]}'.casefold()]
            return deepcopy(sorted(articles, key=lambda item: item["title"]))

    def get_article(self, article_id: str) -> dict[str, Any] | None:
        with self._lock:
            article = self._articles.get(article_id)
            return deepcopy(article) if article else None
