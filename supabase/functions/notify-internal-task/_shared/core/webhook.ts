const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8"
};
export function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS
  });
}
export async function parseJsonPayload(req) {
  const payload = await req.json().catch(()=>null);
  const manualTest = !!(payload && typeof payload === "object" && "manual_test" in payload && payload.manual_test === true);
  return {
    payload,
    manualTest
  };
}
// Copie vendue (bundle notify-internal-task) du helper partagé. Durcie le
// 2026-08-17 comme _shared/core/webhook.ts : le repli « Bearer bien formé +
// manual_test » est retiré (verify_jwt = false ⇒ le Bearer n'est validé par
// personne, et `manual_test` est un drapeau fourni par l'appelant).
export function authorizeWebhook(req, manualTest, options = {}) {
  const expectedSecret = String(options.secretEnv || "").trim();
  const gotSecret = String(req.headers.get("x-task-invite-secret") || req.headers.get("x-webhook-secret") || "").trim();
  const webhookOk = !!expectedSecret && !!gotSecret && gotSecret === expectedSecret;
  return {
    ok: webhookOk,
    webhookOk,
    dashboardTestOk: false
  };
}
export async function serveJsonWebhook(req, options, handler) {
  if (req.method !== "POST") return jsonResponse(405, {
    ok: false,
    error: "Method not allowed"
  });
  const { payload, manualTest } = await parseJsonPayload(req);
  const auth = authorizeWebhook(req, manualTest, options);
  if (!auth.ok) return jsonResponse(401, {
    ok: false,
    error: "Unauthorized"
  });
  try {
    const result = await handler(payload, {
      manualTest
    });
    return jsonResponse(200, result);
  } catch (error) {
    return jsonResponse(500, {
      ok: false,
      error: String(error?.message || error)
    });
  }
}
