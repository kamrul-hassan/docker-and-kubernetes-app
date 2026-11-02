namespace TaskFlow.Api.Data;

public class TaskItem
{
    public int Id { get; set; }
    public required string Title { get; set; }
    public bool IsDone { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
