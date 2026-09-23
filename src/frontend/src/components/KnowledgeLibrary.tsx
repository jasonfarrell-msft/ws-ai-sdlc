import type { Article } from "../types";
import { StatusMessage } from "./StatusMessage";

interface Props {
  articles: Article[];
  selected: Article | null;
  search: string;
  loading: boolean;
  error: string;
  onSearch: (value: string) => void;
  onSelect: (id: string) => void;
  onRetry: () => void;
}

export function KnowledgeLibrary({ articles, selected, search, loading, error, onSearch, onSelect, onRetry }: Props) {
  return (
    <section className="knowledge" aria-labelledby="knowledge-title">
      <div className="section-heading knowledge-heading"><div><p className="eyebrow">Read-only library</p><h1 id="knowledge-title">Knowledge base</h1><p>Versioned guidance for common support questions.</p></div>
        <label className="search-field"><span className="sr-only">Search knowledge articles</span><span aria-hidden="true">⌕</span><input value={search} maxLength={100} onChange={(event) => onSearch(event.target.value)} placeholder="Search articles" /></label>
      </div>
      <div className="knowledge-grid">
        <div className="article-list">
          {loading ? <StatusMessage kind="loading">Loading articles…</StatusMessage> : error ? <StatusMessage kind="error" retry={onRetry}>{error}</StatusMessage> : articles.length === 0 ? <StatusMessage>No articles match your search.</StatusMessage> :
            articles.map((article) => <button type="button" key={article.id} className={selected?.id === article.id ? "selected" : ""} onClick={() => onSelect(article.id)}><span className="article-category">{article.category}</span><strong>{article.title}</strong><span>{article.summary}</span><small>{article.id} · Version {article.version}</small></button>)}
        </div>
        <article className="article-detail">
          {selected ? <><div className="detail-top"><span>{selected.category}</span><span>Version {selected.version}</span></div><h2>{selected.title}</h2><p className="article-summary">{selected.summary}</p><div className="article-body">{selected.content}</div><footer>Last updated {new Intl.DateTimeFormat("en", { dateStyle: "long" }).format(new Date(selected.updatedAt))} · Read-only</footer></> :
            <StatusMessage>Select an article to read it.</StatusMessage>}
        </article>
      </div>
    </section>
  );
}
