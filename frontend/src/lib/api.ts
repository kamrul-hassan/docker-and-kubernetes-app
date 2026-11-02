import "server-only";

export type Task = {
  id: number;
  title: string;
  isDone: boolean;
  createdAt: string;
};

// Read at request time, so one image works in every environment.
function apiUrl(path: string) {
  const base = process.env.API_URL ?? "http://localhost:5080";
  return `${base.replace(/\/$/, "")}${path}`;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(apiUrl(path), {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`API ${init?.method ?? "GET"} ${path} failed: ${res.status}`);
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

export const api = {
  listTasks: () => request<Task[]>("/api/tasks"),
  createTask: (title: string) =>
    request<Task>("/api/tasks", { method: "POST", body: JSON.stringify({ title }) }),
  updateTask: (id: number, title: string, isDone: boolean) =>
    request<Task>(`/api/tasks/${id}`, {
      method: "PUT",
      body: JSON.stringify({ title, isDone }),
    }),
  deleteTask: (id: number) => request<void>(`/api/tasks/${id}`, { method: "DELETE" }),
};
