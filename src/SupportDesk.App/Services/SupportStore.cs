using SupportDesk.App.Domain;

namespace SupportDesk.App.Services;

/// <summary>Provides a thread-safe, process-local synthetic support desk store.</summary>
public sealed class SupportStore : ISupportStore
{
    private readonly Lock syncRoot = new();
    private readonly Dictionary<string, Ticket> tickets;
    private readonly Dictionary<string, List<TicketHistory>> history;
    private readonly Dictionary<string, Article> articles;
    private int nextTicket = 1004;
    private int nextEvent = 8;

    /// <summary>Initializes a new seeded support store.</summary>
    public SupportStore()
    {
        Identities =
        [
            new("maya.chen", "Maya Chen", UserRole.Requester, "MC"),
            new("jordan.lee", "Jordan Lee", UserRole.Agent, "JL")
        ];
        Products = ["Analytics", "Workspace", "Billing"];

        tickets = SeedTickets();
        history = SeedHistory();
        articles = SeedArticles();
    }

    /// <inheritdoc />
    public IReadOnlyList<DemoIdentity> Identities { get; }

    /// <inheritdoc />
    public IReadOnlyList<string> Products { get; }

    /// <inheritdoc />
    public IReadOnlyList<Ticket> ListTickets(TicketFilters filters)
    {
        ArgumentNullException.ThrowIfNull(filters);

        lock (syncRoot)
        {
            IEnumerable<Ticket> query = tickets.Values;
            if (filters.Status is not null)
            {
                query = query.Where(ticket => ticket.Status == filters.Status);
            }

            if (filters.Priority is not null)
            {
                query = query.Where(ticket => ticket.Priority == filters.Priority);
            }

            if (!string.IsNullOrWhiteSpace(filters.Product))
            {
                query = query.Where(ticket => string.Equals(ticket.Product, filters.Product.Trim(), StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(filters.Search))
            {
                var search = filters.Search.Trim();
                query = query.Where(ticket =>
                    ticket.Id.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    ticket.Subject.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    ticket.Description.Contains(search, StringComparison.OrdinalIgnoreCase));
            }

            return query
                .OrderByDescending(ticket => ticket.UpdatedAt)
                .Select(Clone)
                .ToArray();
        }
    }

    /// <inheritdoc />
    public Ticket? GetTicket(string ticketId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ticketId);
        lock (syncRoot)
        {
            return tickets.TryGetValue(ticketId, out var ticket) ? Clone(ticket) : null;
        }
    }

    /// <inheritdoc />
    public Ticket CreateTicket(CreateTicketRequest request, DemoIdentity requester)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(requester);
        if (requester.Role != UserRole.Requester)
        {
            throw new InvalidOperationException("Only a requester can create tickets.");
        }

        lock (syncRoot)
        {
            var ticketId = $"TKT-{nextTicket++}";
            var now = DateTimeOffset.UtcNow;
            var ticket = new Ticket
            {
                Id = ticketId,
                Subject = request.Subject.Trim(),
                Description = request.Description.Trim(),
                Status = TicketStatus.Open,
                Priority = request.Priority!.Value,
                Product = request.Product.Trim(),
                Requester = requester.DisplayName,
                CreatedAt = now,
                UpdatedAt = now
            };
            tickets.Add(ticketId, ticket);
            history.Add(ticketId, [NewEvent(ticketId, "created", "Ticket created", requester.DisplayName, now)]);
            return Clone(ticket);
        }
    }

    /// <inheritdoc />
    public Ticket? AssignTicket(string ticketId, DemoIdentity agent)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ticketId);
        EnsureAgent(agent);

        lock (syncRoot)
        {
            if (!tickets.TryGetValue(ticketId, out var ticket))
            {
                return null;
            }

            var now = DateTimeOffset.UtcNow;
            ticket.Assignee = agent.DisplayName;
            ticket.UpdatedAt = now;
            history[ticketId].Add(NewEvent(ticketId, "assigned", $"Assigned to {agent.DisplayName}", agent.DisplayName, now));
            return Clone(ticket);
        }
    }

    /// <inheritdoc />
    public Ticket? ChangeStatus(string ticketId, TicketStatus status, DemoIdentity agent)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ticketId);
        EnsureAgent(agent);

        lock (syncRoot)
        {
            if (!tickets.TryGetValue(ticketId, out var ticket))
            {
                return null;
            }

            var previous = ticket.Status;
            var now = DateTimeOffset.UtcNow;
            ticket.Status = status;
            ticket.UpdatedAt = now;
            history[ticketId].Add(NewEvent(
                ticketId,
                "status",
                $"Status changed from {previous.ToString().ToLowerInvariant()} to {status.ToString().ToLowerInvariant()}",
                agent.DisplayName,
                now));
            return Clone(ticket);
        }
    }

    /// <inheritdoc />
    public IReadOnlyList<TicketHistory>? GetHistory(string ticketId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ticketId);
        lock (syncRoot)
        {
            return history.TryGetValue(ticketId, out var events) ? events.ToArray() : null;
        }
    }

    /// <inheritdoc />
    public IReadOnlyList<Article> ListArticles(string? search)
    {
        lock (syncRoot)
        {
            IEnumerable<Article> query = articles.Values;
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim();
                query = query.Where(article =>
                    article.Id.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                    article.Title.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                    article.Summary.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                    article.Content.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                    article.Category.Contains(term, StringComparison.OrdinalIgnoreCase));
            }

            return query.OrderBy(article => article.Title).ToArray();
        }
    }

    /// <inheritdoc />
    public Article? GetArticle(string articleId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(articleId);
        lock (syncRoot)
        {
            return articles.GetValueOrDefault(articleId);
        }
    }

    private static Ticket Clone(Ticket ticket) => ticket with { };

    private static void EnsureAgent(DemoIdentity agent)
    {
        ArgumentNullException.ThrowIfNull(agent);
        if (agent.Role != UserRole.Agent)
        {
            throw new InvalidOperationException("Only a support agent can perform this action.");
        }
    }

    private TicketHistory NewEvent(string ticketId, string type, string message, string actor, DateTimeOffset createdAt) =>
        new($"EVT-{nextEvent++}", ticketId, type, message, actor, createdAt);

    private static Dictionary<string, Ticket> SeedTickets() => new(
        new[]
        {
            new Ticket
            {
                Id = "TKT-1001", Subject = "Unable to export quarterly report",
                Description = "The CSV export finishes but the downloaded file is empty.",
                Status = TicketStatus.Open, Priority = TicketPriority.High, Product = "Analytics",
                Requester = "Maya Chen", CreatedAt = Parse("2026-09-18T14:25:00Z"), UpdatedAt = Parse("2026-09-18T14:25:00Z")
            },
            new Ticket
            {
                Id = "TKT-1002", Subject = "New teammate cannot join workspace",
                Description = "An invitation was accepted, but the workspace remains unavailable.",
                Status = TicketStatus.Pending, Priority = TicketPriority.Medium, Product = "Workspace",
                Requester = "Maya Chen", Assignee = "Jordan Lee",
                CreatedAt = Parse("2026-09-17T09:10:00Z"), UpdatedAt = Parse("2026-09-19T16:40:00Z")
            },
            new Ticket
            {
                Id = "TKT-1003", Subject = "Duplicate billing notification",
                Description = "Two renewal notices arrived for the same synthetic subscription.",
                Status = TicketStatus.Resolved, Priority = TicketPriority.Low, Product = "Billing",
                Requester = "Maya Chen", Assignee = "Jordan Lee",
                CreatedAt = Parse("2026-09-15T11:05:00Z"), UpdatedAt = Parse("2026-09-16T13:20:00Z")
            }
        }.ToDictionary(ticket => ticket.Id));

    private static Dictionary<string, List<TicketHistory>> SeedHistory() => new()
    {
        ["TKT-1001"] = [new("EVT-1", "TKT-1001", "created", "Ticket created", "Maya Chen", Parse("2026-09-18T14:25:00Z"))],
        ["TKT-1002"] =
        [
            new("EVT-2", "TKT-1002", "created", "Ticket created", "Maya Chen", Parse("2026-09-17T09:10:00Z")),
            new("EVT-3", "TKT-1002", "assigned", "Assigned to Jordan Lee", "Jordan Lee", Parse("2026-09-17T10:00:00Z")),
            new("EVT-4", "TKT-1002", "status", "Status changed from open to pending", "Jordan Lee", Parse("2026-09-19T16:40:00Z"))
        ],
        ["TKT-1003"] =
        [
            new("EVT-5", "TKT-1003", "created", "Ticket created", "Maya Chen", Parse("2026-09-15T11:05:00Z")),
            new("EVT-6", "TKT-1003", "assigned", "Assigned to Jordan Lee", "Jordan Lee", Parse("2026-09-15T11:30:00Z")),
            new("EVT-7", "TKT-1003", "status", "Status changed from open to resolved", "Jordan Lee", Parse("2026-09-16T13:20:00Z"))
        ]
    };

    private static Dictionary<string, Article> SeedArticles() => new(
        new[]
        {
            new Article("KB-101", "Troubleshoot report exports", "Checks for empty or incomplete report downloads.",
                "Confirm the report has data for the selected date range. Then clear active filters, retry the export, and verify that pop-up and download permissions are enabled. If the file remains empty, record the report name and approximate time for support.",
                "Analytics", 3, Parse("2026-08-12T10:00:00Z")),
            new Article("KB-102", "Manage workspace invitations", "Resolve common invitation and membership issues.",
                "Verify that the invitation email matches the account email. Ask a workspace administrator to revoke any expired invitation and send a new one. Membership changes can take a few minutes to appear after acceptance.",
                "Workspace", 2, Parse("2026-07-28T15:30:00Z")),
            new Article("KB-103", "Understand renewal notifications", "How synthetic subscription reminders are generated.",
                "Renewal reminders are informational and do not initiate a charge. Duplicate notices can be ignored in this simulator. In a real service, confirm the subscription identifier before contacting billing support.",
                "Billing", 1, Parse("2026-06-04T08:45:00Z"))
        }.ToDictionary(article => article.Id));

    private static DateTimeOffset Parse(string value) =>
        DateTimeOffset.Parse(value, System.Globalization.CultureInfo.InvariantCulture);
}
