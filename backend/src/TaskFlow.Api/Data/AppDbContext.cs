using Microsoft.EntityFrameworkCore;

namespace TaskFlow.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TaskItem> Tasks => Set<TaskItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TaskItem>(b =>
        {
            b.ToTable("tasks");
            b.HasKey(t => t.Id).HasName("pk_tasks");
            b.Property(t => t.Id).HasColumnName("id");
            b.Property(t => t.Title).HasColumnName("title").HasMaxLength(200).IsRequired();
            b.Property(t => t.IsDone).HasColumnName("is_done");
            b.Property(t => t.CreatedAt).HasColumnName("created_at");
        });
    }
}
