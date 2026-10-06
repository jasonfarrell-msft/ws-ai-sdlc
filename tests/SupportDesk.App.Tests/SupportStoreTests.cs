using SupportDesk.App.Domain;
using SupportDesk.App.Services;

namespace SupportDesk.App.Tests;

/// <summary>Verifies the process-local support store behavior.</summary>
[TestClass]
public sealed class SupportStoreTests
{
    private SupportStore store = null!;
    private DemoIdentity requester = null!;
    private DemoIdentity agent = null!;

    /// <summary>Creates a fresh seeded store for each test.</summary>
    [TestInitialize]
    public void Initialize()
    {
        store = new SupportStore();
        requester = store.Identities.Single(identity => identity.Role == UserRole.Requester);
        agent = store.Identities.Single(identity => identity.Role == UserRole.Agent);
    }

    /// <summary>Verifies seeded tickets can be filtered and searched.</summary>
    [TestMethod]
    public void ListTickets_FiltersByStatusPriorityProductAndSearch()
    {
        var tickets = store.ListTickets(new(
            TicketStatus.Open,
            TicketPriority.High,
            "Analytics",
            "export"));

        Assert.HasCount(1, tickets);
        Assert.AreEqual("TKT-1001", tickets[0].Id);
    }

    /// <summary>Verifies requester creation adds a ticket and history event.</summary>
    [TestMethod]
    public void CreateTicket_AddsTicketAndHistory()
    {
        var request = new CreateTicketRequest
        {
            Subject = "Dashboard will not refresh",
            Description = "The dashboard has shown old synthetic data since this morning.",
            Priority = TicketPriority.Medium,
            Product = "Analytics"
        };

        var ticket = store.CreateTicket(request, requester);
        var history = store.GetHistory(ticket.Id);

        Assert.AreEqual("TKT-1004", ticket.Id);
        Assert.AreEqual("Maya Chen", ticket.Requester);
        Assert.IsNotNull(history);
        Assert.HasCount(1, history);
        Assert.AreEqual("created", history[0].Type);
    }

    /// <summary>Verifies agent operations update the ticket and append activity.</summary>
    [TestMethod]
    public void AgentActions_UpdateTicketAndAppendHistory()
    {
        var assigned = store.AssignTicket("TKT-1001", agent);
        var resolved = store.ChangeStatus("TKT-1001", TicketStatus.Resolved, agent);
        var history = store.GetHistory("TKT-1001");

        Assert.IsNotNull(assigned);
        Assert.AreEqual("Jordan Lee", assigned.Assignee);
        Assert.IsNotNull(resolved);
        Assert.AreEqual(TicketStatus.Resolved, resolved.Status);
        Assert.IsNotNull(history);
        CollectionAssert.AreEqual(
            new[] { "assigned", "status" },
            history.TakeLast(2).Select(item => item.Type).ToArray());
    }

    /// <summary>Verifies role restrictions are enforced by the domain service.</summary>
    [TestMethod]
    public void AgentActions_RejectRequester()
    {
        Assert.ThrowsExactly<InvalidOperationException>(() => store.AssignTicket("TKT-1001", requester));
        Assert.ThrowsExactly<InvalidOperationException>(() =>
            store.ChangeStatus("TKT-1001", TicketStatus.Closed, requester));
    }

    /// <summary>Verifies knowledge articles remain searchable and versioned.</summary>
    [TestMethod]
    public void ListArticles_SearchesVersionedKnowledge()
    {
        var articles = store.ListArticles("invitation");

        Assert.HasCount(1, articles);
        Assert.AreEqual("KB-102", articles[0].Id);
        Assert.AreEqual(2, articles[0].Version);
    }
}
