"""Verify the public API and the frontend's same-origin proxy."""

from __future__ import annotations

import argparse
import json
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class ContainerSmokeTests(unittest.TestCase):
    frontend_url: str
    backend_url: str

    def request(self, url, *, method="GET", data=None, role=None):
        headers = {}
        if role:
            headers["x-demo-role"] = role
            headers["x-demo-user"] = "maya.chen" if role == "requester" else "jordan.lee"
        body = None
        if data is not None:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
        request = Request(url, data=body, headers=headers, method=method)
        try:
            response = urlopen(request, timeout=15)
        except HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()

    def test_direct_and_proxied_health(self):
        for origin in (self.backend_url, self.frontend_url):
            with self.subTest(origin=origin):
                status, _, body = self.request(f"{origin}/api/health")
                self.assertEqual(status, 200)
                self.assertEqual(json.loads(body), {"status": "healthy"})

    def test_frontend_and_security_headers(self):
        for path in ("/", "/tickets/example"):
            status, headers, body = self.request(f"{self.frontend_url}{path}")
            self.assertEqual(status, 200)
            self.assertIn(b"Support Desk Simulator", body)
            self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
            self.assertEqual(headers["X-Frame-Options"], "DENY")
            self.assertEqual(headers["Referrer-Policy"], "no-referrer")
            self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        status, _, _ = self.request(f"{self.frontend_url}/assets/missing.js")
        self.assertEqual(status, 404)

    def test_proxy_preserves_api_errors(self):
        status, _, body = self.request(f"{self.frontend_url}/api/tickets")
        self.assertEqual(status, 401)
        self.assertEqual(json.loads(body)["error"]["code"], "demo_identity_required")
        status, _, body = self.request(f"{self.frontend_url}/api/not-a-route")
        self.assertEqual(status, 404)
        self.assertIn("error", json.loads(body))

    def test_same_origin_ticket_workflow(self):
        status, _, body = self.request(
            f"{self.frontend_url}/api/tickets",
            method="POST",
            role="requester",
            data={
                "subject": "Container integration smoke test",
                "description": "Synthetic ticket created to verify the same-origin proxy.",
                "priority": "low",
                "product": "Analytics",
            },
        )
        self.assertEqual(status, 201)
        ticket_id = json.loads(body)["ticket"]["id"]
        status, _, body = self.request(
            f"{self.frontend_url}/api/tickets/{ticket_id}/assign",
            method="POST",
            role="agent",
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["ticket"]["assignee"], "Jordan Lee")
        status, _, body = self.request(
            f"{self.frontend_url}/api/tickets/{ticket_id}/status",
            method="PATCH",
            role="agent",
            data={"status": "resolved"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["ticket"]["status"], "resolved")
        status, _, body = self.request(
            f"{self.backend_url}/api/tickets/{ticket_id}", role="agent"
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["ticket"]["assignee"], "Jordan Lee")
        self.assertEqual(json.loads(body)["ticket"]["status"], "resolved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frontend-url", default="http://127.0.0.1:8080")
    parser.add_argument("--backend-url", default="http://127.0.0.1:5050")
    args = parser.parse_args()
    ContainerSmokeTests.frontend_url = args.frontend_url.rstrip("/")
    ContainerSmokeTests.backend_url = args.backend_url.rstrip("/")
    unittest.main(argv=["test-containers"], verbosity=2)
