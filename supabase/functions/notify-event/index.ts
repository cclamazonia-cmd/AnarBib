import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { ADMIN_EMAIL, WEBHOOK_SECRET } from "../_shared/core/env.ts";
import type { NotifyPayload } from "../_shared/core/types.ts";
import { dispatchNotifyEvent } from "../_shared/core/dispatch.ts";
import { authorizeWebhook, jsonResponse, parseJsonPayload } from "../_shared/core/webhook.ts";

async function handleNotifyEvent(req: Request) {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "POST, OPTIONS",
        "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
      },
    });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method not allowed" });
  }
  const { payload, manualTest } = await parseJsonPayload<NotifyPayload>(req);
  const auth = authorizeWebhook(req, manualTest, {
    secretEnv: WEBHOOK_SECRET,
    allowDashboardBearerForManualTest: true,
  });
  if (!auth.ok) {
    return jsonResponse(401, { ok: false, error: "Unauthorized" });
  }
  try {
    if (!payload?.event || !payload?.record_id) {
      return jsonResponse(400, { ok: false, error: "Bad payload" });
    }
    const event = String(payload.event).trim();
    const recordId = Number(payload.record_id);
    if (!event) return jsonResponse(400, { ok: false, error: "Invalid event" });
    if (!Number.isFinite(recordId) || recordId <= 0) return jsonResponse(400, { ok: false, error: "Invalid record_id" });
    const result = await dispatchNotifyEvent(event, recordId, payload);
    if (!result) return jsonResponse(200, { ok: true, ignored: true, event, record_id: recordId });
    return jsonResponse(200, { ok: true, event, record_id: recordId, manual_test: manualTest, resolved_admin_email: ADMIN_EMAIL, ...result });
  } catch (error) {
    return jsonResponse(500, { ok: false, error: String((error as Error)?.message || error) });
  }
}
serve(handleNotifyEvent);
