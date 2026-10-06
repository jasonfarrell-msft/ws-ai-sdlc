using SupportDesk.App.Domain;

namespace SupportDesk.App.Services;

/// <summary>Defines process-local support desk operations.</summary>
public interface ISupportStore
{
    /// <summary>Gets the supported demo identities.</summary>
    IReadOnlyList<DemoIdentity> Identities { get; }

    /// <summary>Gets the supported product names.</summary>
    IReadOnlyList<string> Products { get; }

    /// <summary>Returns tickets that match the supplied filters.</summary>
    /// <param name="filters">The ticket filters.</param>
    /// <returns>A snapshot of matching tickets.</returns>
    IReadOnlyList<Ticket> ListTickets(TicketFilters filters);

    /// <summary>Gets a ticket by identifier.</summary>
    /// <param name="ticketId">The ticket identifier.</param>
    /// <returns>The ticket snapshot, or <see langword="null"/> when not found.</returns>
    Ticket? GetTicket(string ticketId);

    /// <summary>Creates a ticket.</summary>
    /// <param name="request">The validated ticket values.</param>
    /// <param name="requester">The requester identity.</param>
    /// <returns>The created ticket.</returns>
    Ticket CreateTicket(CreateTicketRequest request, DemoIdentity requester);

    /// <summary>Assigns a ticket to an agent.</summary>
    /// <param name="ticketId">The ticket identifier.</param>
    /// <param name="agent">The agent identity.</param>
    /// <returns>The updated ticket, or <see langword="null"/> when not found.</returns>
    Ticket? AssignTicket(string ticketId, DemoIdentity agent);

    /// <summary>Changes a ticket status.</summary>
    /// <param name="ticketId">The ticket identifier.</param>
    /// <param name="status">The new status.</param>
    /// <param name="agent">The agent identity.</param>
    /// <returns>The updated ticket, or <see langword="null"/> when not found.</returns>
    Ticket? ChangeStatus(string ticketId, TicketStatus status, DemoIdentity agent);

    /// <summary>Gets the history for a ticket.</summary>
    /// <param name="ticketId">The ticket identifier.</param>
    /// <returns>The history snapshot, or <see langword="null"/> when not found.</returns>
    IReadOnlyList<TicketHistory>? GetHistory(string ticketId);

    /// <summary>Returns knowledge articles that match a search term.</summary>
    /// <param name="search">The optional free-text search term.</param>
    /// <returns>A snapshot of matching articles.</returns>
    IReadOnlyList<Article> ListArticles(string? search);

    /// <summary>Gets a knowledge article by identifier.</summary>
    /// <param name="articleId">The article identifier.</param>
    /// <returns>The article, or <see langword="null"/> when not found.</returns>
    Article? GetArticle(string articleId);
}
