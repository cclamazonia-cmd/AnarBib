import type { JsonObject } from "./webhook_types.ts";
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
export function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
export type WebhookAuthOptions = { secretEnv?: string; allowDashboardBearerForManualTest?: boolean; };
export type ParsedWebhook<T> = { payload: T | null; manualTest: boolean; };
export async function parseJsonPayload<T>(req: Request): Promise<ParsedWebhook<T>> {
  const payload = (await req.json().catch(() => null)) as T | null;
  const manualTest = !!(payload && typeof payload === "object" && "manual_test" in (payload as Record<string, unknown>) && (payload as Record<string, unknown>).manual_test === true);
  return { payload, manualTest };
}
export function authorizeWebhook(req: Request, manualTest: boolean, options: WebhookAuthOptions = {}) {
  const expectedSecret = String(options.secretEnv || "").trim();
  const gotSecret = String(req.headers.get("x-webhook-secret") || "").trim();
  const authz = String(req.headers.get("authorization") || "").trim();
  const webhookOk = !!expectedSecret && !!gotSecret && gotSecret === expectedSecret;
  const bearerOk = /^Bearer\s+[A-Za-z0-9\-_.]+/.test(authz);
  const dashboardTestOk = !!options.allowDashboardBearerForManualTest && manualTest && bearerOk;
  return { ok: webhookOk || bearerOk || dashboardTestOk, webhookOk, dashboardTestOk, bearerOk };
}
export async function serveJsonWebhook<T>(req: Request, options: WebhookAuthOptions, handler: (payload: T | null, info: { manualTest: boolean }) => Promise<unknown>) {
  if (req.method !== "POST") return jsonResponse(405, { ok: false, error: "Method not allowed" });
  const { payload, manualTest } = await parseJsonPayload<T>(req);
  const auth = authorizeWebhook(req, manualTest, options);
  if (!auth.ok) return jsonResponse(401, { ok: false, error: "Unauthorized" });
  try { const result = await handler(payload, { manualTest }); return jsonResponse(200, result as JsonObject); }
  catch (error) { return jsonResponse(500, { ok: false, error: String((error as Error)?.message || error) }); }
}
