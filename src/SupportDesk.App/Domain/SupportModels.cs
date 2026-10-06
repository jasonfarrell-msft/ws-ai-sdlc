using System.ComponentModel.DataAnnotations;

namespace SupportDesk.App.Domain;

/// <summary>Identifies the simulated role used by the workshop.</summary>
public enum UserRole
{
    /// <summary>A user who requests support.</summary>
    Requester,

    /// <summary>A user who handles support requests.</summary>
    Agent
}

/// <summary>Identifies the current lifecycle state of a ticket.</summary>
public enum TicketStatus
{
    /// <summary>The ticket is awaiting work.</summary>
    Open,

    /// <summary>The ticket is waiting for more information or an external action.</summary>
    Pending,

    /// <summary>The reported problem has been resolved.</summary>
    Resolved,

    /// <summary>The ticket is complete and closed.</summary>
    Closed
}

/// <summary>Identifies the urgency assigned to a ticket.</summary>
public enum TicketPriority
{
    /// <summary>Low urgency.</summary>
    Low,

    /// <summary>Normal urgency.</summary>
    Medium,

    /// <summary>High urgency.</summary>
    High,

    /// <summary>Immediate attention is requested.</summary>
    Urgent
}

/// <summary>Represents one simulated workshop identity.</summary>
/// <param name="UserName">The stable identity name.</param>
/// <param name="DisplayName">The display name shown in the UI.</param>
/// <param name="Role">The simulated role.</param>
/// <param name="Initials">The initials shown in the avatar.</param>
public sealed record DemoIdentity(string UserName, string DisplayName, UserRole Role, string Initials);

/// <summary>Represents a support ticket.</summary>
public sealed record Ticket
{
    /// <summary>Gets the ticket identifier.</summary>
    public required string Id { get; init; }

    /// <summary>Gets the ticket subject.</summary>
    public required string Subject { get; init; }

    /// <summary>Gets the detailed problem description.</summary>
    public required string Description { get; init; }

    /// <summary>Gets the current status.</summary>
    public required TicketStatus Status { get; set; }

    /// <summary>Gets the priority.</summary>
    public required TicketPriority Priority { get; init; }

    /// <summary>Gets the affected product.</summary>
    public required string Product { get; init; }

    /// <summary>Gets the requester display name.</summary>
    public required string Requester { get; init; }

    /// <summary>Gets or sets the assigned agent display name.</summary>
    public string? Assignee { get; set; }

    /// <summary>Gets the creation timestamp.</summary>
    public required DateTimeOffset CreatedAt { get; init; }

    /// <summary>Gets or sets the most recent update timestamp.</summary>
    public required DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>Represents an immutable ticket history event.</summary>
/// <param name="Id">The event identifier.</param>
/// <param name="TicketId">The related ticket identifier.</param>
/// <param name="Type">The event type.</param>
/// <param name="Message">The human-readable event description.</param>
/// <param name="Actor">The actor display name.</param>
/// <param name="CreatedAt">The event timestamp.</param>
public sealed record TicketHistory(
    string Id,
    string TicketId,
    string Type,
    string Message,
    string Actor,
    DateTimeOffset CreatedAt);

/// <summary>Represents a versioned knowledge article.</summary>
/// <param name="Id">The article identifier.</param>
/// <param name="Title">The article title.</param>
/// <param name="Summary">The article summary.</param>
/// <param name="Content">The article content.</param>
/// <param name="Category">The product category.</param>
/// <param name="Version">The article version.</param>
/// <param name="UpdatedAt">The latest update timestamp.</param>
public sealed record Article(
    string Id,
    string Title,
    string Summary,
    string Content,
    string Category,
    int Version,
    DateTimeOffset UpdatedAt);

/// <summary>Contains the values required to create a ticket.</summary>
public sealed class CreateTicketRequest : IValidatableObject
{
    /// <summary>Gets or sets the concise ticket subject.</summary>
    [Required, StringLength(120, MinimumLength = 4)]
    public string Subject { get; set; } = string.Empty;

    /// <summary>Gets or sets the detailed problem description.</summary>
    [Required, StringLength(4000, MinimumLength = 10)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Gets or sets the priority.</summary>
    [Required]
    public TicketPriority? Priority { get; set; }

    /// <summary>Gets or sets the affected product.</summary>
    [Required, StringLength(60, MinimumLength = 2)]
    public string Product { get; set; } = string.Empty;

    /// <summary>Validates normalized string values.</summary>
    /// <param name="validationContext">The validation context.</param>
    /// <returns>Validation failures for normalized values.</returns>
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Subject.Trim().Length is < 4 or > 120)
        {
            yield return new("The subject must contain 4 to 120 non-whitespace characters.", [nameof(Subject)]);
        }

        if (Description.Trim().Length is < 10 or > 4000)
        {
            yield return new("The description must contain 10 to 4000 non-whitespace characters.", [nameof(Description)]);
        }

        if (Product.Trim().Length is < 2 or > 60)
        {
            yield return new("The product must contain 2 to 60 non-whitespace characters.", [nameof(Product)]);
        }
    }
}

/// <summary>Contains the value required to change a ticket status.</summary>
public sealed class ChangeStatusRequest
{
    /// <summary>Gets or sets the new status.</summary>
    [Required]
    public TicketStatus? Status { get; set; }
}

/// <summary>Contains optional ticket list filters.</summary>
/// <param name="Status">The status filter.</param>
/// <param name="Priority">The priority filter.</param>
/// <param name="Product">The product filter.</param>
/// <param name="Search">The free-text search filter.</param>
public sealed record TicketFilters(
    TicketStatus? Status = null,
    TicketPriority? Priority = null,
    string? Product = null,
    string? Search = null);

/// <summary>Contains JSON values used to create a ticket through the API.</summary>
public sealed class CreateTicketApiRequest
{
    /// <summary>Gets or sets the ticket subject.</summary>
    public string Subject { get; set; } = string.Empty;

    /// <summary>Gets or sets the problem description.</summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>Gets or sets the priority name.</summary>
    public string Priority { get; set; } = string.Empty;

    /// <summary>Gets or sets the product name.</summary>
    public string Product { get; set; } = string.Empty;
}

/// <summary>Contains the JSON value used to change status through the API.</summary>
public sealed class ChangeStatusApiRequest
{
    /// <summary>Gets or sets the status name.</summary>
    public string Status { get; set; } = string.Empty;
}
