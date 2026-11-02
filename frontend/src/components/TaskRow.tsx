"use client";

import { useTransition } from "react";
import { deleteTask, toggleTask } from "@/app/actions";
import type { Task } from "@/lib/api";

export function TaskRow({ task }: { task: Task }) {
  const [pending, startTransition] = useTransition();

  return (
    <li className={`task ${task.isDone ? "done" : ""} ${pending ? "pending" : ""}`}>
      <label>
        <input
          type="checkbox"
          checked={task.isDone}
          disabled={pending}
          onChange={() => startTransition(() => toggleTask(task.id, task.title, !task.isDone))}
        />
        <span>{task.title}</span>
      </label>
      <button
        type="button"
        className="delete"
        aria-label={`Delete ${task.title}`}
        disabled={pending}
        onClick={() => startTransition(() => deleteTask(task.id))}
      >
        ×
      </button>
    </li>
  );
}
