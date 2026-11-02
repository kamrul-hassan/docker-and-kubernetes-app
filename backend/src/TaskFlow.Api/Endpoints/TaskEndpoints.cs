using Microsoft.EntityFrameworkCore;
using TaskFlow.Api.Data;

namespace TaskFlow.Api.Endpoints;

public record TaskDto(int Id, string Title, bool IsDone, DateTimeOffset CreatedAt);
public record CreateTaskRequest(string Title);
public record UpdateTaskRequest(string Title, bool IsDone);

public static class TaskEndpoints
{
    private const int MaxTitleLength = 200;

    public static IEndpointRouteBuilder MapTaskEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tasks").WithTags("Tasks");

        group.MapGet("/", async (AppDbContext db, CancellationToken ct) =>
            await db.Tasks
                .AsNoTracking()
                .OrderBy(t => t.IsDone).ThenByDescending(t => t.CreatedAt)
                .Select(t => new TaskDto(t.Id, t.Title, t.IsDone, t.CreatedAt))
                .ToListAsync(ct));

        group.MapGet("/{id:int}", async (int id, AppDbContext db, CancellationToken ct) =>
            await db.Tasks.FindAsync([id], ct) is { } t
                ? Results.Ok(ToDto(t))
                : Results.NotFound());

        group.MapPost("/", async (CreateTaskRequest req, AppDbContext db, CancellationToken ct) =>
        {
            if (Validate(req.Title) is { } problem) return problem;

            var task = new TaskItem
            {
                Title = req.Title.Trim(),
                CreatedAt = DateTimeOffset.UtcNow
            };
            db.Tasks.Add(task);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/tasks/{task.Id}", ToDto(task));
        });

        group.MapPut("/{id:int}", async (int id, UpdateTaskRequest req, AppDbContext db, CancellationToken ct) =>
        {
            if (Validate(req.Title) is { } problem) return problem;

            var task = await db.Tasks.FindAsync([id], ct);
            if (task is null) return Results.NotFound();

            task.Title = req.Title.Trim();
            task.IsDone = req.IsDone;
            await db.SaveChangesAsync(ct);
            return Results.Ok(ToDto(task));
        });

        group.MapDelete("/{id:int}", async (int id, AppDbContext db, CancellationToken ct) =>
        {
            var task = await db.Tasks.FindAsync([id], ct);
            if (task is null) return Results.NotFound();

            db.Tasks.Remove(task);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        return app;
    }

    private static TaskDto ToDto(TaskItem t) => new(t.Id, t.Title, t.IsDone, t.CreatedAt);

    private static IResult? Validate(string? title)
    {
        if (string.IsNullOrWhiteSpace(title))
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["title"] = ["Title is required."]
            });

        if (title.Trim().Length > MaxTitleLength)
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["title"] = [$"Title must be {MaxTitleLength} characters or fewer."]
            });

        return null;
    }
}
