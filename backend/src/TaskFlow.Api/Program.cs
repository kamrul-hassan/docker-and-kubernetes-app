using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using TaskFlow.Api.Data;
using TaskFlow.Api.Endpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default"))
           // The pipeline runs `dotnet ef migrations has-pending-model-changes`,
           // so log this warning instead of failing app startup.
           .ConfigureWarnings(w => w.Log(RelationalEventId.PendingModelChangesWarning)));

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();

builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("database", tags: ["ready"]);

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

// `dotnet TaskFlow.Api.dll --migrate-only` applies EF migrations and exits.
// The Kubernetes init container uses it so the schema is current before the API starts.
if (args.Contains("--migrate-only"))
{
    await MigrateAsync(app);
    return;
}

if (app.Configuration.GetValue<bool>("Database:MigrateOnStartup"))
{
    await MigrateAsync(app);
}

app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseCors();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/", () => Results.Ok(new { service = "TaskFlow.Api", status = "ok" }));
app.MapTaskEndpoints();

// Liveness: the process is up. Readiness: the database is reachable.
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = c => c.Tags.Contains("ready") });

await app.RunAsync();

static async Task MigrateAsync(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    if (db.Database.IsRelational())
    {
        app.Logger.LogInformation("Applying database migrations...");
        await db.Database.MigrateAsync();
        app.Logger.LogInformation("Database migrations applied.");
    }
}

public partial class Program;
