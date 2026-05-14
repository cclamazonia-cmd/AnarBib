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
export function authorizeWebhook(req, manualTest, options = {}) {
  const expectedSecret = String(options.secretEnv || "").trim();
  const gotSecret = String(req.headers.get("x-webhook-secret") || "").trim();
  const authz = String(req.headers.get("authorization") || "").trim();
  const webhookOk = !!expectedSecret && !!gotSecret && gotSecret === expectedSecret;
  const bearerOk = /^Bearer\s+[A-Za-z0-9\-_.]+/.test(authz);
  const dashboardTestOk = !!options.allowDashboardBearerForManualTest && manualTest && bearerOk;
  return {
    ok: webhookOk || bearerOk || dashboardTestOk,
    webhookOk,
    dashboardTestOk,
    bearerOk
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
