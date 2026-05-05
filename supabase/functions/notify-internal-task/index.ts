import { serveJsonWebhook } from "./_shared/core/webhook.ts";
import { handleInternalTaskNotification } from "./_shared/handlers/internal-task.ts";
const WEBHOOK_SECRET = (Deno.env.get("WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK") || "").trim();
Deno.serve((req)=>serveJsonWebhook(req, {
    secretEnv: WEBHOOK_SECRET,
    allowDashboardBearerForManualTest: true
  }, async (payload)=>handleInternalTaskNotification(payload || {})));
