import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.store import SupportStore

REQUESTER = {"x-demo-user": "maya.chen", "x-demo-role": "requester"}
AGENT = {"x-demo-user": "jordan.lee", "x-demo-role": "agent"}


@pytest.fixture()
def client():
    app.state.store = SupportStore()
    with TestClient(app) as test_client:
        yield test_client


def test_health_is_public_and_secure(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
    assert response.headers["x-content-type-options"] == "nosniff"


def test_list_filter_search_and_get_ticket(client):
    response = client.get("/api/tickets?status=open&priority=high&product=Analytics&search=export", headers=AGENT)
    assert response.status_code == 200
    assert [item["id"] for item in response.json()["tickets"]] == ["TKT-1001"]
    detail = client.get("/api/tickets/TKT-1001", headers=REQUESTER)
    assert detail.json()["ticket"]["subject"] == "Unable to export quarterly report"


def test_requester_creates_ticket_and_history(client):
    payload = {"subject": "Dashboard will not refresh", "description": "The dashboard has shown old sample data since this morning.", "priority": "medium", "product": "Analytics"}
    response = client.post("/api/tickets", headers=REQUESTER, json=payload)
    assert response.status_code == 201
    ticket = response.json()["ticket"]
    assert ticket["id"] == "TKT-1004"
    assert ticket["requester"] == "Maya Chen"
    history = client.get(f'/api/tickets/{ticket["id"]}/history', headers=REQUESTER)
    assert [event["type"] for event in history.json()["history"]] == ["created"]


def test_agent_assigns_and_changes_status_with_audit_history(client):
    assert client.post("/api/tickets/TKT-1001/assign", headers=AGENT).json()["ticket"]["assignee"] == "Jordan Lee"
    response = client.patch("/api/tickets/TKT-1001/status", headers=AGENT, json={"status": "resolved"})
    assert response.status_code == 200
    assert response.json()["ticket"]["status"] == "resolved"
    history = client.get("/api/tickets/TKT-1001/history", headers=AGENT).json()["history"]
    assert [event["type"] for event in history][-2:] == ["assigned", "status"]


def test_role_authorization_and_identity_validation(client):
    assert client.post("/api/tickets/TKT-1001/assign", headers=REQUESTER).status_code == 403
    assert client.post("/api/tickets", headers=AGENT, json={}).status_code == 403
    response = client.get("/api/tickets")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "demo_identity_required"
    assert client.get("/api/tickets", headers={"x-demo-user": "maya.chen", "x-demo-role": "agent"}).status_code == 401


def test_validation_and_body_limits_are_structured(client):
    response = client.post("/api/tickets", headers=REQUESTER, json={"subject": "x", "description": "short", "priority": "extreme", "product": ""})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    oversized = {"subject": "Valid subject", "description": "x" * 17000, "priority": "low", "product": "Billing"}
    response = client.post("/api/tickets", headers=REQUESTER, json=oversized)
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "request_too_large"


def test_articles_are_searchable_versioned_and_read_only(client):
    response = client.get("/api/articles?search=invitation", headers=REQUESTER)
    assert response.status_code == 200
    article = response.json()["articles"][0]
    assert article["id"] == "KB-102"
    assert article["version"] == 2
    assert client.get("/api/articles/KB-102", headers=AGENT).json()["article"]["content"]
    assert client.post("/api/articles", headers=AGENT, json={}).status_code == 405


def test_not_found_and_invalid_query(client):
    assert client.get("/api/tickets/TKT-9999", headers=AGENT).json()["error"]["code"] == "ticket_not_found"
    assert client.get("/api/articles/KB-999", headers=AGENT).status_code == 404
    response = client.get("/api/tickets?search=" + ("a" * 101), headers=AGENT)
    assert response.status_code == 422
