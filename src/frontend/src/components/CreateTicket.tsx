import { useState } from "react";
import type { Ticket, TicketPriority } from "../types";

interface Props {
  busy: boolean;
  error: string;
  onCancel: () => void;
  onCreate: (input: Pick<Ticket, "subject" | "description" | "priority" | "product">) => Promise<void>;
}

export function CreateTicket({ busy, error, onCancel, onCreate }: Props) {
  const [subject, setSubject] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<TicketPriority>("medium");
  const [product, setProduct] = useState("Analytics");
  return (
    <section className="create-card" aria-labelledby="create-title">
      <div className="section-heading"><div><p className="eyebrow">Requester workspace</p><h1 id="create-title">Create a ticket</h1></div><button className="icon-button" onClick={onCancel} aria-label="Close ticket form">×</button></div>
      <p>Tell the support team what happened. Do not enter real customer or confidential data.</p>
      {error && <div className="inline-error" role="alert">{error}</div>}
      <form onSubmit={(event) => { event.preventDefault(); void onCreate({ subject, description, priority, product }); }}>
        <label><span>Subject</span><input required minLength={4} maxLength={120} value={subject} onChange={(event) => setSubject(event.target.value)} placeholder="A concise summary" /></label>
        <label><span>Description</span><textarea required minLength={10} maxLength={4000} rows={7} value={description} onChange={(event) => setDescription(event.target.value)} placeholder="What did you expect, and what happened instead?" /><small>{description.length}/4000</small></label>
        <div className="form-row">
          <label><span>Product</span><select value={product} onChange={(event) => setProduct(event.target.value)}><option>Analytics</option><option>Workspace</option><option>Billing</option></select></label>
          <label><span>Priority</span><select value={priority} onChange={(event) => setPriority(event.target.value as TicketPriority)}><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option><option value="urgent">Urgent</option></select></label>
        </div>
        <div className="form-actions"><button type="button" className="secondary-button" onClick={onCancel}>Cancel</button><button className="primary-button" disabled={busy}>{busy ? "Creating…" : "Create ticket"}</button></div>
      </form>
    </section>
  );
}
