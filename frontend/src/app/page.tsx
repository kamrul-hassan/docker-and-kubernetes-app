import { api, type Task } from "@/lib/api";
import { TaskRow } from "@/components/TaskRow";
import { createTask } from "./actions";

// Render on every request so data and API_URL are read at runtime, not at build time.
export const dynamic = "force-dynamic";

export default async function Home() {
  let tasks: Task[] = [];
  let error: string | null = null;
  try {
    tasks = await api.listTasks();
  } catch (e) {
    error = e instanceof Error ? e.message : "Could not reach the API";
  }

  const remaining = tasks.filter((t) => !t.isDone).length;

  return (
    <main>
      <header>
        <h1>TaskFlow</h1>
        <p className="muted">Next.js · ASP.NET Core 10 · PostgreSQL</p>
      </header>

      <form action={createTask} className="new-task">
        <input name="title" placeholder="What needs doing?" maxLength={200} required autoComplete="off" />
        <button type="submit">Add</button>
      </form>

      {error ? (
        <p className="error">⚠ {error}</p>
      ) : tasks.length === 0 ? (
        <p className="muted empty">No tasks yet. Add the first one above.</p>
      ) : (
        <>
          <ul className="tasks">
            {tasks.map((t) => (
              <TaskRow key={t.id} task={t} />
            ))}
          </ul>
          <p className="muted count">
            {remaining} of {tasks.length} remaining
          </p>
        </>
      )}
    </main>
  );
}
