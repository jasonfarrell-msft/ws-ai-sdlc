import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "./api";
import { CreateTicket } from "./components/CreateTicket";
import { KnowledgeLibrary } from "./components/KnowledgeLibrary";
import { TicketDetail } from "./components/TicketDetail";
import { TicketQueue, type Filters } from "./components/TicketQueue";
import type { Article, DemoIdentity, Ticket, TicketHistory, TicketStatus } from "./types";

const identities: DemoIdentity[] = [
  { user: "maya.chen", name: "Maya Chen", role: "requester", initials: "MC" },
  { user: "jordan.lee", name: "Jordan Lee", role: "agent", initials: "JL" }
];
const emptyFilters: Filters = { search: "", status: "", priority: "", product: "" };

export default function App() {
  const [identity, setIdentity] = useState(identities[1]);
  const [view, setView] = useState<"tickets" | "knowledge">("tickets");
  const [creating, setCreating] = useState(false);
  const [filters, setFilters] = useState(emptyFilters);
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selected, setSelected] = useState<Ticket | null>(null);
  const [history, setHistory] = useState<TicketHistory[]>([]);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState("");
  const [detailError, setDetailError] = useState("");
  const [actionBusy, setActionBusy] = useState(false);
  const [createError, setCreateError] = useState("");
  const [notice, setNotice] = useState("");
  const [articles, setArticles] = useState<Article[]>([]);
  const [article, setArticle] = useState<Article | null>(null);
  const [articleSearch, setArticleSearch] = useState("");
  const [articleLoading, setArticleLoading] = useState(false);
  const [articleError, setArticleError] = useState("");

  const ticketQuery = useMemo(() => {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => value.trim() && params.set(key, value.trim()));
    const query = params.toString();
    return query ? `?${query}` : "";
  }, [filters]);

  const loadTickets = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const response = await api.tickets(identity, ticketQuery);
      setTickets(response.tickets);
      if (selected && !response.tickets.some((item) => item.id === selected.id)) {
        setSelected(null); setHistory([]);
      }
    } catch (caught) { setError(caught instanceof Error ? caught.message : "Could not load tickets."); }
    finally { setLoading(false); }
  }, [identity, ticketQuery, selected]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadTickets(), filters.search ? 250 : 0);
    return () => window.clearTimeout(timer);
  }, [loadTickets, filters.search]);

  const selectTicket = async (id: string) => {
    setDetailLoading(true); setDetailError("");
    try {
      const [ticketResponse, historyResponse] = await Promise.all([api.ticket(identity, id), api.history(identity, id)]);
      setSelected(ticketResponse.ticket); setHistory(historyResponse.history);
    } catch (caught) { setDetailError(caught instanceof Error ? caught.message : "Could not load this ticket."); setSelected(null); }
    finally { setDetailLoading(false); }
  };

  const refreshSelected = async (ticket: Ticket) => {
    setSelected(ticket);
    setTickets((current) => current.map((item) => item.id === ticket.id ? ticket : item));
    const response = await api.history(identity, ticket.id);
    setHistory(response.history);
  };

  const runAction = async (action: () => Promise<{ ticket: Ticket }>, message: string) => {
    setActionBusy(true); setDetailError("");
    try { const response = await action(); await refreshSelected(response.ticket); setNotice(message); }
    catch (caught) { setDetailError(caught instanceof Error ? caught.message : "The action failed."); }
    finally { setActionBusy(false); }
  };

  const loadArticles = useCallback(async () => {
    setArticleLoading(true); setArticleError("");
    try {
      const response = await api.articles(identity, articleSearch.trim());
      setArticles(response.articles);
      if (article && !response.articles.some((item) => item.id === article.id)) setArticle(null);
    } catch (caught) { setArticleError(caught instanceof Error ? caught.message : "Could not load articles."); }
    finally { setArticleLoading(false); }
  }, [identity, articleSearch, article]);

  useEffect(() => {
    if (view !== "knowledge") return;
    const timer = window.setTimeout(() => void loadArticles(), articleSearch ? 250 : 0);
    return () => window.clearTimeout(timer);
  }, [view, loadArticles, articleSearch]);

  const changeIdentity = (next: DemoIdentity) => {
    setIdentity(next); setSelected(null); setHistory([]); setArticle(null); setCreating(false); setNotice("");
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <button className="brand" onClick={() => { setView("tickets"); setCreating(false); }}><span className="brand-mark">S</span><span><strong>Support Desk</strong><small>Simulator</small></span></button>
        <nav aria-label="Primary navigation"><button className={view === "tickets" ? "active" : ""} onClick={() => setView("tickets")}>Tickets</button><button className={view === "knowledge" ? "active" : ""} onClick={() => setView("knowledge")}>Knowledge</button></nav>
        <div className="identity">
          <label><span className="sr-only">Demo identity</span><select value={identity.user} onChange={(event) => changeIdentity(identities.find((item) => item.user === event.target.value) ?? identities[0])}>{identities.map((item) => <option key={item.user} value={item.user}>{item.name} · {item.role}</option>)}</select></label>
          <span className="avatar" aria-hidden="true">{identity.initials}</span>
        </div>
      </header>
      <div className="demo-banner" role="note"><strong>Demo environment</strong><span>Synthetic data only. Identities are simulated and provide no real authentication.</span></div>
      {notice && <div className="toast" role="status">{notice}<button aria-label="Dismiss message" onClick={() => setNotice("")}>×</button></div>}
      <main>
        {view === "knowledge" ? <KnowledgeLibrary articles={articles} selected={article} search={articleSearch} loading={articleLoading} error={articleError} onSearch={setArticleSearch} onRetry={() => void loadArticles()} onSelect={async (id) => { try { setArticle((await api.article(identity, id)).article); } catch (caught) { setArticleError(caught instanceof Error ? caught.message : "Could not load article."); } }} /> :
          creating ? <CreateTicket busy={actionBusy} error={createError} onCancel={() => setCreating(false)} onCreate={async (input) => {
            setActionBusy(true); setCreateError("");
            try { const response = await api.createTicket(identity, input); setCreating(false); setNotice(`${response.ticket.id} created.`); setFilters(emptyFilters); await loadTickets(); await selectTicket(response.ticket.id); }
            catch (caught) { setCreateError(caught instanceof Error ? caught.message : "Could not create ticket."); }
            finally { setActionBusy(false); }
          }} /> :
          <>
            <div className="workspace-actions">{identity.role === "requester" && <button className="primary-button" onClick={() => setCreating(true)}>＋ Create ticket</button>}</div>
            <div className="ticket-workspace">
              <TicketQueue tickets={tickets} selectedId={selected?.id} filters={filters} loading={loading} error={error} onFilters={setFilters} onSelect={(id) => void selectTicket(id)} onRetry={() => void loadTickets()} />
              <TicketDetail ticket={selected} history={history} identity={identity} loading={detailLoading} error={detailError} actionBusy={actionBusy}
                onAssign={() => selected && void runAction(() => api.assign(identity, selected.id), "Ticket assigned to you.")}
                onStatus={(status: TicketStatus) => selected && void runAction(() => api.changeStatus(identity, selected.id, status), `Status changed to ${status}.`)} />
            </div>
          </>}
      </main>
      <footer className="site-footer"><span>Support Desk Simulator</span><span>Process-local data resets when the API restarts · No AI capabilities</span></footer>
    </div>
  );
}
