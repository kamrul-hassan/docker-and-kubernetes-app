// Liveness/readiness probe for Kubernetes. Does not call the API.
export const dynamic = "force-dynamic";

export function GET() {
  return Response.json({ status: "ok" });
}
