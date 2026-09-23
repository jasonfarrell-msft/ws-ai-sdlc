import type { Ticket, TicketPriority, TicketStatus } from "../types";
import { StatusMessage } from "./StatusMessage";

export interface Filters {
  search: string;
  status: "" | TicketStatus;
  priority: "" | TicketPriority;
  product: string;
}

interface Props {
  tickets: Ticket[];
  selectedId?: string;
  filters: Filters;
  loading: boolean;
  error: string;
  onFilters: (filters: Filters) => void;
  onSelect: (id: string) => void;
  onRetry: () => void;
}

const label = (value: string) => value.charAt(0).toUpperCase() + value.slice(1);
const date = (value: string) => new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(new Date(value));

export function TicketQueue({ tickets, selectedId, filters, loading, error, onFilters, onSelect, onRetry }: Props) {
  const update = (key: keyof Filters, value: string) => onFilters({ ...filters, [key]: value });
  return (
    <section className="queue-panel" aria-labelledby="queue-title">
      <div className="section-heading">
        <div><p className="eyebrow">Live workspace</p><h1 id="queue-title">Support queue</h1></div>
        <span className="count">{tickets.length} {tickets.length === 1 ? "ticket" : "tickets"}</span>
      </div>
      <form className="filters" role="search" onSubmit={(event) => event.preventDefault()}>
        <label className="search-field">
          <span className="sr-only">Search tickets</span>
          <span aria-hidden="true">⌕</span>
          <input value={filters.search} maxLength={100} onChange={(event) => update("search", event.target.value)} placeholder="Search tickets" />
        </label>
        <label><span className="sr-only">Filter status</span><select value={filters.status} onChange={(event) => update("status", event.target.value)}><option value="">All statuses</option>{["open", "pending", "resolved", "closed"].map((item) => <option key={item}>{item}</option>)}</select></label>
        <label><span className="sr-only">Filter priority</span><select value={filters.priority} onChange={(event) => update("priority", event.target.value)}><option value="">All priorities</option>{["urgent", "high", "medium", "low"].map((item) => <option key={item}>{item}</option>)}</select></label>
        <label><span className="sr-only">Filter product</span><select value={filters.product} onChange={(event) => update("product", event.target.value)}><option value="">All products</option>{["Analytics", "Workspace", "Billing"].map((item) => <option key={item}>{item}</option>)}</select></label>
      </form>
      {loading ? <StatusMessage kind="loading">Loading the queue…</StatusMessage> :
        error ? <StatusMessage kind="error" retry={onRetry}>{error}</StatusMessage> :
        tickets.length === 0 ? <StatusMessage>No tickets match these filters.</StatusMessage> :
        <div className="ticket-list">
          {tickets.map((ticket) => (
            <button key={ticket.id} className={`ticket-row ${selectedId === ticket.id ? "selected" : ""}`} onClick={() => onSelect(ticket.id)} type="button" aria-pressed={selectedId === ticket.id}>
              <span className={`priority-dot ${ticket.priority}`} aria-label={`${ticket.priority} priority`} />
              <span className="ticket-main"><span className="ticket-subject">{ticket.subject}</span><span className="ticket-meta">{ticket.id} · {ticket.product} · Updated {date(ticket.updatedAt)}</span></span>
              <span className={`badge status-${ticket.status}`}>{label(ticket.status)}</span>
              <span className="chevron" aria-hidden="true">›</span>
            </button>
          ))}
        </div>}
    </section>
  );
}
