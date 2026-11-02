"use server";

import { revalidatePath } from "next/cache";
import { api } from "@/lib/api";

export async function createTask(formData: FormData) {
  const title = String(formData.get("title") ?? "").trim();
  if (!title) return;
  await api.createTask(title);
  revalidatePath("/");
}

export async function toggleTask(id: number, title: string, isDone: boolean) {
  await api.updateTask(id, title, isDone);
  revalidatePath("/");
}

export async function deleteTask(id: number) {
  await api.deleteTask(id);
  revalidatePath("/");
}
