using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace SupportDesk.App.Tests;

/// <summary>Verifies the hosted Blazor application and HTTP API.</summary>
[TestClass]
public sealed class ApiTests
{
    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    /// <summary>Starts the application test host.</summary>
    [TestInitialize]
    public void Initialize()
    {
        factory = new WebApplicationFactory<Program>();
        client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
    }

    /// <summary>Stops the application test host.</summary>
    [TestCleanup]
    public void Cleanup()
    {
        client.Dispose();
        factory.Dispose();
    }

    /// <summary>Verifies the public health endpoint and security headers.</summary>
    [TestMethod]
    public async Task Health_ReturnsHealthyResponseAndSecurityHeaders()
    {
        using var response = await client.GetAsync("/api/health");
        using var body = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.OK, response.StatusCode);
        Assert.AreEqual("healthy", body.RootElement.GetProperty("status").GetString());
        Assert.AreEqual("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.AreEqual("DENY", response.Headers.GetValues("X-Frame-Options").Single());
    }

    /// <summary>Verifies the application root renders the Blazor support desk.</summary>
    [TestMethod]
    public async Task Root_RendersSupportDeskApplication()
    {
        using var response = await client.GetAsync("/");
        var body = await response.Content.ReadAsStringAsync();

        Assert.AreEqual(HttpStatusCode.OK, response.StatusCode);
        StringAssert.Contains(body, "Support Desk");
        StringAssert.Contains(body, "Ticket queue");
    }

    /// <summary>Verifies API routes require a valid matching demo identity.</summary>
    [TestMethod]
    public async Task Tickets_RequireMatchingDemoIdentity()
    {
        using var response = await client.GetAsync("/api/tickets");
        using var body = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.AreEqual(
            "demo_identity_required",
            body.RootElement.GetProperty("error").GetProperty("code").GetString());
    }

    /// <summary>Verifies the requester and agent API workflow.</summary>
    [TestMethod]
    public async Task TicketWorkflow_CreatesAssignsAndResolvesTicket()
    {
        using var createRequest = new HttpRequestMessage(HttpMethod.Post, "/api/tickets")
        {
            Content = JsonContent.Create(new
            {
                subject = "Blazor integration test",
                description = "Synthetic ticket created by the .NET integration test.",
                priority = "low",
                product = "Analytics"
            })
        };
        AddIdentity(createRequest, "maya.chen", "requester");
        using var createResponse = await client.SendAsync(createRequest);
        using var createBody = await JsonDocument.ParseAsync(await createResponse.Content.ReadAsStreamAsync());
        var ticketId = createBody.RootElement.GetProperty("ticket").GetProperty("id").GetString();

        Assert.AreEqual(HttpStatusCode.Created, createResponse.StatusCode);
        Assert.IsNotNull(ticketId);
        Assert.AreEqual($"/api/tickets/{ticketId}", createResponse.Headers.Location?.OriginalString);

        using var assignRequest = new HttpRequestMessage(HttpMethod.Post, $"/api/tickets/{ticketId}/assign");
        AddIdentity(assignRequest, "jordan.lee", "agent");
        using var assignResponse = await client.SendAsync(assignRequest);

        using var statusRequest = new HttpRequestMessage(HttpMethod.Patch, $"/api/tickets/{ticketId}/status")
        {
            Content = JsonContent.Create(new { status = "resolved" })
        };
        AddIdentity(statusRequest, "jordan.lee", "agent");
        using var statusResponse = await client.SendAsync(statusRequest);
        using var statusBody = await JsonDocument.ParseAsync(await statusResponse.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.OK, assignResponse.StatusCode);
        Assert.AreEqual(HttpStatusCode.OK, statusResponse.StatusCode);
        Assert.AreEqual(
            "resolved",
            statusBody.RootElement.GetProperty("ticket").GetProperty("status").GetString());
    }

    /// <summary>Verifies unknown API routes preserve the structured error contract.</summary>
    [TestMethod]
    public async Task UnknownApiRoute_ReturnsStructuredNotFound()
    {
        using var response = await client.GetAsync("/api/not-a-route");
        using var body = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.NotFound, response.StatusCode);
        Assert.AreEqual(
            "route_not_found",
            body.RootElement.GetProperty("error").GetProperty("code").GetString());
    }

    /// <summary>Verifies invalid enum values cannot enter the domain.</summary>
    [TestMethod]
    public async Task InvalidEnumValues_ReturnStructuredValidationErrors()
    {
        using var unknownPriority = CreateRequesterPost(
            """{"subject":"Valid subject","description":"A valid synthetic description.","priority":"extreme","product":"Analytics"}""");
        using var unknownResponse = await client.SendAsync(unknownPriority);
        using var unknownBody = await JsonDocument.ParseAsync(await unknownResponse.Content.ReadAsStreamAsync());

        using var numericPriority = CreateRequesterPost(
            """{"subject":"Valid subject","description":"A valid synthetic description.","priority":999,"product":"Analytics"}""");
        using var numericResponse = await client.SendAsync(numericPriority);
        using var numericBody = await JsonDocument.ParseAsync(await numericResponse.Content.ReadAsStreamAsync());

        using var queryRequest = new HttpRequestMessage(HttpMethod.Get, "/api/tickets?status=999");
        AddIdentity(queryRequest, "jordan.lee", "agent");
        using var queryResponse = await client.SendAsync(queryRequest);
        using var queryBody = await JsonDocument.ParseAsync(await queryResponse.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.UnprocessableEntity, unknownResponse.StatusCode);
        Assert.AreEqual("validation_error", unknownBody.RootElement.GetProperty("error").GetProperty("code").GetString());
        Assert.AreEqual(HttpStatusCode.BadRequest, numericResponse.StatusCode);
        Assert.AreEqual("invalid_request", numericBody.RootElement.GetProperty("error").GetProperty("code").GetString());
        Assert.AreEqual(HttpStatusCode.UnprocessableEntity, queryResponse.StatusCode);
        Assert.AreEqual("validation_error", queryBody.RootElement.GetProperty("error").GetProperty("code").GetString());
    }

    /// <summary>Verifies normalized strings and oversized bodies preserve the API contract.</summary>
    [TestMethod]
    public async Task InvalidStringsAndOversizedBodies_ReturnStructuredErrors()
    {
        using var whitespaceRequest = CreateRequesterPost(
            """{"subject":"   x","description":"A valid synthetic description.","priority":"low","product":"Analytics"}""");
        using var whitespaceResponse = await client.SendAsync(whitespaceRequest);
        using var whitespaceBody = await JsonDocument.ParseAsync(await whitespaceResponse.Content.ReadAsStreamAsync());

        using var oversizedRequest = CreateRequesterPost(
            $$"""{"subject":"Valid subject","description":"{{new string('x', 17_000)}}","priority":"low","product":"Analytics"}""");
        using var oversizedResponse = await client.SendAsync(oversizedRequest);
        using var oversizedBody = await JsonDocument.ParseAsync(await oversizedResponse.Content.ReadAsStreamAsync());

        Assert.AreEqual(HttpStatusCode.UnprocessableEntity, whitespaceResponse.StatusCode);
        Assert.AreEqual("validation_error", whitespaceBody.RootElement.GetProperty("error").GetProperty("code").GetString());
        Assert.AreEqual(HttpStatusCode.RequestEntityTooLarge, oversizedResponse.StatusCode);
        Assert.AreEqual("request_too_large", oversizedBody.RootElement.GetProperty("error").GetProperty("code").GetString());
    }

    /// <summary>Verifies unsupported methods retain the HTTP method-not-allowed response.</summary>
    [TestMethod]
    public async Task KnownReadOnlyRoute_RejectsUnsupportedMethod()
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/articles");
        AddIdentity(request, "jordan.lee", "agent");
        using var response = await client.SendAsync(request);

        Assert.AreEqual(HttpStatusCode.MethodNotAllowed, response.StatusCode);
    }

    private static HttpRequestMessage CreateRequesterPost(string json)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/tickets")
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        };
        AddIdentity(request, "maya.chen", "requester");
        return request;
    }

    private static void AddIdentity(HttpRequestMessage request, string user, string role)
    {
        request.Headers.Add("x-demo-user", user);
        request.Headers.Add("x-demo-role", role);
    }
}
