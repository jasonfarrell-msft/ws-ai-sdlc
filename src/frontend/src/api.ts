import type { ApiError, Article, DemoIdentity, Ticket, TicketHistory } from "./types";

const baseUrl = (import.meta.env.VITE_API_BASE_URL ?? "").replace(/\/$/, "");

async function request<T>(path: string, identity: DemoIdentity, init?: RequestInit): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        "x-demo-user": identity.user,
        "x-demo-role": identity.role,
        ...init?.headers
      }
    });
  } catch {
    throw new Error("The support service is unavailable. Check that the API is running and try again.");
  }

  const body = (await response.json().catch(() => null)) as T | ApiError | null;
  if (!response.ok) {
    const isApiError = typeof body === "object" && body !== null && "error" in body;
    throw new Error(isApiError ? (body as ApiError).error.message : `Request failed (${response.status}).`);
  }
  if (!body) throw new Error("The support service returned an empty response.");
  return body as T;
}

export const api = {
  tickets: (identity: DemoIdentity, query = "") =>
    request<{ tickets: Ticket[] }>(`/api/tickets${query}`, identity),
  ticket: (identity: DemoIdentity, id: string) =>
    request<{ ticket: Ticket }>(`/api/tickets/${encodeURIComponent(id)}`, identity),
  history: (identity: DemoIdentity, id: string) =>
    request<{ history: TicketHistory[] }>(`/api/tickets/${encodeURIComponent(id)}/history`, identity),
  createTicket: (identity: DemoIdentity, input: Pick<Ticket, "subject" | "description" | "priority" | "product">) =>
    request<{ ticket: Ticket }>("/api/tickets", identity, { method: "POST", body: JSON.stringify(input) }),
  assign: (identity: DemoIdentity, id: string) =>
    request<{ ticket: Ticket }>(`/api/tickets/${encodeURIComponent(id)}/assign`, identity, { method: "POST" }),
  changeStatus: (identity: DemoIdentity, id: string, status: Ticket["status"]) =>
    request<{ ticket: Ticket }>(`/api/tickets/${encodeURIComponent(id)}/status`, identity, {
      method: "PATCH",
      body: JSON.stringify({ status })
    }),
  articles: (identity: DemoIdentity, search = "") =>
    request<{ articles: Article[] }>(`/api/articles${search ? `?search=${encodeURIComponent(search)}` : ""}`, identity),
  article: (identity: DemoIdentity, id: string) =>
    request<{ article: Article }>(`/api/articles/${encodeURIComponent(id)}`, identity)
};
