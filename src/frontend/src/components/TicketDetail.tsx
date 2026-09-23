import type { DemoIdentity, Ticket, TicketHistory, TicketStatus } from "../types";
import { StatusMessage } from "./StatusMessage";

interface Props {
  ticket: Ticket | null;
  history: TicketHistory[];
  identity: DemoIdentity;
  loading: boolean;
  error: string;
  actionBusy: boolean;
  onAssign: () => void;
  onStatus: (status: TicketStatus) => void;
}

const fullDate = (value: string) => new Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));

export function TicketDetail({ ticket, history, identity, loading, error, actionBusy, onAssign, onStatus }: Props) {
  if (loading) return <aside className="detail-panel"><StatusMessage kind="loading">Loading ticket details…</StatusMessage></aside>;
  if (error) return <aside className="detail-panel"><StatusMessage kind="error">{error}</StatusMessage></aside>;
  if (!ticket) return <aside className="detail-panel detail-placeholder"><span aria-hidden="true">↖</span><h2>Select a ticket</h2><p>Choose a queue item to see its details and activity.</p></aside>;
  return (
    <aside className="detail-panel" aria-labelledby="detail-title">
      <div className="detail-top"><span className={`badge status-${ticket.status}`}>{ticket.status}</span><span>{ticket.id}</span></div>
      <h2 id="detail-title">{ticket.subject}</h2>
      <div className="detail-facts">
        <div><span>Priority</span><strong className={`priority-text ${ticket.priority}`}>{ticket.priority}</strong></div>
        <div><span>Product</span><strong>{ticket.product}</strong></div>
        <div><span>Requester</span><strong>{ticket.requester}</strong></div>
        <div><span>Assignee</span><strong>{ticket.assignee ?? "Unassigned"}</strong></div>
      </div>
      <section className="description"><h3>Description</h3><p>{ticket.description}</p></section>
      {identity.role === "agent" && (
        <section className="agent-actions" aria-label="Agent actions">
          <h3>Agent actions</h3>
          <button className="primary-button" type="button" disabled={actionBusy || ticket.assignee === identity.name} onClick={onAssign}>
            {ticket.assignee === identity.name ? "Assigned to you" : "Assign to me"}
          </button>
          <label><span>Change status</span><select disabled={actionBusy} value={ticket.status} onChange={(event) => onStatus(event.target.value as TicketStatus)}>{["open", "pending", "resolved", "closed"].map((status) => <option key={status}>{status}</option>)}</select></label>
        </section>
      )}
      <section className="timeline"><h3>Activity</h3>
        {history.map((event) => <div className="timeline-item" key={event.id}><span className="timeline-mark" /><div><strong>{event.message}</strong><p>{event.actor} · {fullDate(event.createdAt)}</p></div></div>)}
      </section>
    </aside>
  );
}
