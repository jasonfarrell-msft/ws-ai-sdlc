using System.ComponentModel.DataAnnotations;
using SupportDesk.App.Domain;
using SupportDesk.App.Services;

namespace SupportDesk.App.Api;

/// <summary>Maps the support desk HTTP API.</summary>
public static class SupportApi
{
    private const int MaximumSearchLength = 100;

    /// <summary>Maps all support desk API endpoints.</summary>
    /// <param name="endpoints">The endpoint route builder.</param>
    /// <returns>The supplied endpoint route builder.</returns>
    public static IEndpointRouteBuilder MapSupportApi(this IEndpointRouteBuilder endpoints)
    {
        ArgumentNullException.ThrowIfNull(endpoints);

        var api = endpoints.MapGroup("/api");
        api.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

        api.MapGet("/tickets", (
            HttpRequest request,
            ISupportStore store,
            string? status,
            string? priority,
            string? product,
            string? search) =>
        {
            if (!TryGetIdentity(request, store, out _, out var identityError))
            {
                return identityError;
            }

            if (!TryParseOptionalEnum(status, "status", out TicketStatus? parsedStatus, out var statusError))
            {
                return statusError;
            }

            if (!TryParseOptionalEnum(priority, "priority", out TicketPriority? parsedPriority, out var priorityError))
            {
                return priorityError;
            }

            var filterError = ValidateOptionalFilter(product, 60, "product")
                ?? ValidateOptionalFilter(search, MaximumSearchLength, "search");
            return filterError ?? Results.Ok(new
            {
                tickets = store.ListTickets(new(parsedStatus, parsedPriority, product, search))
            });
        });

        api.MapGet("/tickets/{ticketId}", (string ticketId, HttpRequest request, ISupportStore store) =>
        {
            if (!TryGetIdentity(request, store, out _, out var identityError))
            {
                return identityError;
            }

            return store.GetTicket(ticketId) is { } ticket
                ? Results.Ok(new { ticket })
                : ApiError(StatusCodes.Status404NotFound, "ticket_not_found", "Ticket was not found.");
        });

        api.MapPost("/tickets", (CreateTicketApiRequest input, HttpRequest request, ISupportStore store) =>
        {
            if (!TryGetIdentity(request, store, out var identity, out var identityError))
            {
                return identityError;
            }

            if (identity!.Role != UserRole.Requester)
            {
                return ApiError(StatusCodes.Status403Forbidden, "forbidden", "This action requires the requester demo role.");
            }

            if (!TryParseEnum(input.Priority, "priority", out TicketPriority priority, out var priorityError))
            {
                return priorityError;
            }

            var ticketRequest = new CreateTicketRequest
            {
                Subject = input.Subject,
                Description = input.Description,
                Priority = priority,
                Product = input.Product
            };
            if (Validate(ticketRequest) is { } validationError)
            {
                return validationError;
            }

            var ticket = store.CreateTicket(ticketRequest, identity);
            return Results.Created($"/api/tickets/{ticket.Id}", new { ticket });
        });

        api.MapPost("/tickets/{ticketId}/assign", (string ticketId, HttpRequest request, ISupportStore store) =>
        {
            if (!TryGetAgent(request, store, out var agent, out var agentError))
            {
                return agentError;
            }

            return store.AssignTicket(ticketId, agent!) is { } ticket
                ? Results.Ok(new { ticket })
                : ApiError(StatusCodes.Status404NotFound, "ticket_not_found", "Ticket was not found.");
        });

        api.MapPatch("/tickets/{ticketId}/status", (
            string ticketId,
            ChangeStatusApiRequest input,
            HttpRequest request,
            ISupportStore store) =>
        {
            if (!TryGetAgent(request, store, out var agent, out var agentError))
            {
                return agentError;
            }

            if (!TryParseEnum(input.Status, "status", out TicketStatus status, out var statusError))
            {
                return statusError;
            }

            return store.ChangeStatus(ticketId, status, agent!) is { } ticket
                ? Results.Ok(new { ticket })
                : ApiError(StatusCodes.Status404NotFound, "ticket_not_found", "Ticket was not found.");
        });

        api.MapGet("/tickets/{ticketId}/history", (string ticketId, HttpRequest request, ISupportStore store) =>
        {
            if (!TryGetIdentity(request, store, out _, out var identityError))
            {
                return identityError;
            }

            return store.GetHistory(ticketId) is { } history
                ? Results.Ok(new { history })
                : ApiError(StatusCodes.Status404NotFound, "ticket_not_found", "Ticket was not found.");
        });

        api.MapGet("/articles", (HttpRequest request, ISupportStore store, string? search) =>
        {
            if (!TryGetIdentity(request, store, out _, out var identityError))
            {
                return identityError;
            }

            return ValidateOptionalFilter(search, MaximumSearchLength, "search")
                ?? Results.Ok(new { articles = store.ListArticles(search) });
        });

        api.MapGet("/articles/{articleId}", (string articleId, HttpRequest request, ISupportStore store) =>
        {
            if (!TryGetIdentity(request, store, out _, out var identityError))
            {
                return identityError;
            }

            return store.GetArticle(articleId) is { } article
                ? Results.Ok(new { article })
                : ApiError(StatusCodes.Status404NotFound, "article_not_found", "Article was not found.");
        });

        return endpoints;
    }

    private static bool TryGetAgent(
        HttpRequest request,
        ISupportStore store,
        out DemoIdentity? identity,
        out IResult error)
    {
        if (!TryGetIdentity(request, store, out identity, out error))
        {
            return false;
        }

        if (identity!.Role != UserRole.Agent)
        {
            error = ApiError(StatusCodes.Status403Forbidden, "forbidden", "This action requires the agent demo role.");
            return false;
        }

        return true;
    }

    private static bool TryGetIdentity(
        HttpRequest request,
        ISupportStore store,
        out DemoIdentity? identity,
        out IResult error)
    {
        var userName = request.Headers["x-demo-user"].ToString();
        var role = request.Headers["x-demo-role"].ToString();
        identity = store.Identities.SingleOrDefault(candidate =>
            string.Equals(candidate.UserName, userName, StringComparison.Ordinal) &&
            string.Equals(candidate.Role.ToString(), role, StringComparison.OrdinalIgnoreCase));

        if (identity is null)
        {
            error = ApiError(
                StatusCodes.Status401Unauthorized,
                "demo_identity_required",
                "Use a valid demo identity and role.");
            return false;
        }

        error = Results.Empty;
        return true;
    }

    private static IResult? Validate(object value)
    {
        var results = new List<ValidationResult>();
        if (Validator.TryValidateObject(value, new ValidationContext(value), results, validateAllProperties: true))
        {
            return null;
        }

        var details = results.Select(result => new
        {
            field = result.MemberNames.FirstOrDefault() ?? string.Empty,
            message = result.ErrorMessage ?? "The value is invalid."
        });
        return ApiError(StatusCodes.Status422UnprocessableEntity, "validation_error", "The request was not valid.", details);
    }

    private static IResult? ValidateOptionalFilter(string? value, int maximumLength, string field)
    {
        if (value is null)
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(value) || value.Length > maximumLength)
        {
            return ApiError(
                StatusCodes.Status422UnprocessableEntity,
                "validation_error",
                "The request was not valid.",
                new[] { new { field, message = $"The value must contain 1 to {maximumLength} characters." } });
        }

        return null;
    }

    private static bool TryParseOptionalEnum<T>(
        string? value,
        string field,
        out T? parsed,
        out IResult error)
        where T : struct, Enum
    {
        if (value is null)
        {
            parsed = null;
            error = Results.Empty;
            return true;
        }

        if (TryParseEnum(value, field, out T required, out error))
        {
            parsed = required;
            return true;
        }

        parsed = null;
        return false;
    }

    private static bool TryParseEnum<T>(string value, string field, out T parsed, out IResult error)
        where T : struct, Enum
    {
        if (Enum.TryParse(value, ignoreCase: true, out parsed) && Enum.IsDefined(parsed))
        {
            error = Results.Empty;
            return true;
        }

        error = ApiError(
            StatusCodes.Status422UnprocessableEntity,
            "validation_error",
            "The request was not valid.",
            new[] { new { field, message = $"The value must be a valid {field}." } });
        return false;
    }

    private static IResult ApiError(int status, string code, string message, object? details = null) =>
        Results.Json(new { error = new { code, message, details } }, statusCode: status);
}
