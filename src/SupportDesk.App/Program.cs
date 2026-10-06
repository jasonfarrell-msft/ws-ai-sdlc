using System.Text.Json;
using System.Text.Json.Serialization;
using SupportDesk.App.Api;
using SupportDesk.App.Components;
using SupportDesk.App.Services;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options => options.Limits.MaxRequestBodySize = 16_384);
builder.Services
    .AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase, allowIntegerValues: false));
});
builder.Services.Configure<RouteHandlerOptions>(options => options.ThrowOnBadRequest = true);
builder.Services.AddSingleton<ISupportStore, SupportStore>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["X-Frame-Options"] = "DENY";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        context.Response.Headers.ContentSecurityPolicy =
            "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; " +
            "img-src 'self' data:; connect-src 'self' ws: wss:; font-src 'self'; object-src 'none'; " +
            "base-uri 'self'; form-action 'self'; frame-ancestors 'none'";
        return Task.CompletedTask;
    });
    if (context.Request.Path.StartsWithSegments("/api") &&
        context.Request.ContentLength is > 16_384)
    {
        await WriteApiErrorAsync(
            context,
            StatusCodes.Status413PayloadTooLarge,
            "request_too_large",
            "Request body exceeds 16 KB.");
        return;
    }

    try
    {
        await next(context);
    }
    catch (BadHttpRequestException exception) when (context.Request.Path.StartsWithSegments("/api"))
    {
        var status = exception.StatusCode;
        await WriteApiErrorAsync(
            context,
            status,
            status == StatusCodes.Status413PayloadTooLarge ? "request_too_large" : "invalid_request",
            status == StatusCodes.Status413PayloadTooLarge
                ? "Request body exceeds 16 KB."
                : "The request could not be parsed.");
        return;
    }

    if (context.Request.Path.StartsWithSegments("/api") &&
        context.Response.StatusCode == StatusCodes.Status404NotFound &&
        !context.Response.HasStarted)
    {
        await WriteApiErrorAsync(
            context,
            StatusCodes.Status404NotFound,
            "route_not_found",
            "API route was not found.");
    }
});

app.UseWhen(
    context => !context.Request.Path.StartsWithSegments("/api"),
    branch => branch.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true));
app.UseHttpsRedirection();
app.UseAntiforgery();

app.MapStaticAssets();
app.MapSupportApi();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();

static Task WriteApiErrorAsync(HttpContext context, int status, string code, string message)
{
    context.Response.StatusCode = status;
    return context.Response.WriteAsJsonAsync(new { error = new { code, message } });
}

/// <summary>Provides the entry point type used by application integration tests.</summary>
public partial class Program;
