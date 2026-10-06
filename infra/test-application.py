"""Verify the combined frontend and API through one application origin."""

from __future__ import annotations

import argparse
import json
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class ApplicationSmokeTests(unittest.TestCase):
    application_url: str

    def request(self, path, *, method="GET", data=None, role=None):
        headers = {}
        if role:
            headers["x-demo-role"] = role
            headers["x-demo-user"] = "maya.chen" if role == "requester" else "jordan.lee"
        body = None
        if data is not None:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
        request = Request(
            f"{self.application_url}{path}",
            data=body,
            headers=headers,
            method=method,
        )
        try:
            response = urlopen(request, timeout=15)
        except HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()

    def test_health(self):
        status, _, body = self.request("/api/health")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"status": "healthy"})

    def test_frontend_and_security_headers(self):
        for path in ("/", "/tickets/example"):
            status, headers, body = self.request(path)
            self.assertEqual(status, 200)
            self.assertIn(b"Support Desk Simulator", body)
            self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
            self.assertEqual(headers["X-Frame-Options"], "DENY")
            self.assertEqual(headers["Referrer-Policy"], "no-referrer")
            self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        status, headers, _ = self.request("/assets/missing.js")
        self.assertEqual(status, 404)
        self.assertEqual(headers["Cache-Control"], "no-store")

    def test_api_errors_remain_structured(self):
        status, _, body = self.request("/api/tickets")
        self.assertEqual(status, 401)
        self.assertEqual(json.loads(body)["error"]["code"], "demo_identity_required")
        status, _, body = self.request("/api/not-a-route")
        self.assertEqual(status, 404)
        self.assertEqual(json.loads(body)["error"]["code"], "route_not_found")

    def test_same_origin_ticket_workflow(self):
        status, _, body = self.request(
            "/api/tickets",
            method="POST",
            role="requester",
            data={
                "subject": "App Service integration smoke test",
                "description": "Synthetic ticket created to verify the combined deployment.",
                "priority": "low",
                "product": "Analytics",
            },
        )
        self.assertEqual(status, 201)
        ticket_id = json.loads(body)["ticket"]["id"]
        status, _, body = self.request(
            f"/api/tickets/{ticket_id}/assign",
            method="POST",
            role="agent",
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["ticket"]["assignee"], "Jordan Lee")
        status, _, body = self.request(
            f"/api/tickets/{ticket_id}/status",
            method="PATCH",
            role="agent",
            data={"status": "resolved"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["ticket"]["status"], "resolved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application-url", default="http://127.0.0.1:5050")
    args = parser.parse_args()
    ApplicationSmokeTests.application_url = args.application_url.rstrip("/")
    unittest.main(argv=["test-application"], verbosity=2)
