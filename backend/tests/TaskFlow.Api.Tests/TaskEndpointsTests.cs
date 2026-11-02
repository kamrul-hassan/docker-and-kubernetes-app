using System.Net;
using System.Net.Http.Json;
using TaskFlow.Api.Endpoints;

namespace TaskFlow.Api.Tests;

public class TaskEndpointsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Create_then_get_returns_task()
    {
        var created = await _client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("Buy milk"));
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);

        var task = await created.Content.ReadFromJsonAsync<TaskDto>();
        Assert.NotNull(task);
        Assert.Equal("Buy milk", task.Title);
        Assert.False(task.IsDone);

        var fetched = await _client.GetFromJsonAsync<TaskDto>($"/api/tasks/{task.Id}");
        Assert.Equal(task.Id, fetched!.Id);
    }

    [Fact]
    public async Task Create_with_empty_title_returns_400()
    {
        var response = await _client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("  "));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Update_marks_task_done()
    {
        var created = await _client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("Ship it"));
        var task = (await created.Content.ReadFromJsonAsync<TaskDto>())!;

        var updated = await _client.PutAsJsonAsync($"/api/tasks/{task.Id}", new UpdateTaskRequest("Ship it", true));
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.True((await updated.Content.ReadFromJsonAsync<TaskDto>())!.IsDone);
    }

    [Fact]
    public async Task Delete_removes_task()
    {
        var created = await _client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("Temporary"));
        var task = (await created.Content.ReadFromJsonAsync<TaskDto>())!;

        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/api/tasks/{task.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/tasks/{task.Id}")).StatusCode);
    }

    [Fact]
    public async Task Health_endpoints_return_200()
    {
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/health/live")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/health/ready")).StatusCode);
    }
}
