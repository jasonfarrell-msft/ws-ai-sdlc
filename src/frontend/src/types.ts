export type UserRole = "requester" | "agent";
export type TicketStatus = "open" | "pending" | "resolved" | "closed";
export type TicketPriority = "low" | "medium" | "high" | "urgent";

export interface DemoIdentity {
  user: "maya.chen" | "jordan.lee";
  name: string;
  role: UserRole;
  initials: string;
}

export interface Ticket {
  id: string;
  subject: string;
  description: string;
  status: TicketStatus;
  priority: TicketPriority;
  product: string;
  requester: string;
  assignee: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TicketHistory {
  id: string;
  ticketId: string;
  type: "created" | "assigned" | "status";
  message: string;
  actor: string;
  createdAt: string;
}

export interface Article {
  id: string;
  title: string;
  summary: string;
  content: string;
  category: string;
  version: number;
  updatedAt: string;
}

export interface ApiError {
  error: { code: string; message: string; details?: unknown };
}
