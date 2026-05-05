import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
function json(data, init = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...init.headers || {}
    }
  });
}
function excerptText(raw, maxLen = 500) {
  const clean = String(raw || "").replace(/\s+/g, " ").trim();
  return clean.length > maxLen ? clean.slice(0, maxLen) : clean;
}
function looksConfirmed(capabilityKey, status, bodyText, contentType) {
  const text = String(bodyText || "").toLowerCase();
  const ctype = String(contentType || "").toLowerCase();
  const key = String(capabilityKey || "").toLowerCase();
  if (status < 200 || status >= 300) return false;
  if (key === "html_home") {
    return text.includes("recherche") || text.includes("catalog") || text.includes("catalogue") || text.includes("opac");
  }
  if (key === "html_notice_guess_1") {
    return text.includes("notice") || text.includes("permalink") || text.includes("isbd") || text.includes("esemplari") || text.includes("etat des collections");
  }
  if (key.includes("oai")) {
    return text.includes("identify") || text.includes("oai-pmh") || text.includes("<identify>") || ctype.includes("xml");
  }
  if (key.includes("jsonrpc")) {
    return ctype.includes("json") || text.includes("json-rpc") || text.includes("jsonrpc");
  }
  if (key.includes("soap")) {
    return text.includes("definitions") || text.includes("wsdl") || ctype.includes("xml");
  }
  if (key.includes("koha_rest")) {
    return ctype.includes("json") || text.includes("openapi") || text.includes("swagger");
  }
  if (key.includes("koha_ilsdi")) {
    return text.includes("ils-di") || text.includes("ilsdi") || ctype.includes("xml") || ctype.includes("html");
  }
  if (key.includes("koha_sru")) {
    return text.includes("explainresponse") || text.includes("sru") || ctype.includes("xml");
  }
  return false;
}
async function fetchWithTimeout(url, timeoutMs = 12000) {
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "user-agent": "AnarBib probe-partner-catalog/1.0",
        "accept": "application/json,text/xml,application/xml,text/html;q=0.9,*/*;q=0.8"
      }
    });
  } finally{
    clearTimeout(timer);
  }
}
async function resolvePartner(body) {
  const partnerId = Number(body?.partner_id || 0);
  const partnerSlug = String(body?.partner_slug || "").trim();
  if (partnerId) {
    const { data, error } = await supabase.from("catalog_partners").select("*").eq("id", partnerId).maybeSingle();
    if (error) throw error;
    if (!data) throw new Error(`Partner not found for id=${partnerId}`);
    return data;
  }
  if (partnerSlug) {
    const { data, error } = await supabase.from("catalog_partners").select("*").eq("slug", partnerSlug).maybeSingle();
    if (error) throw error;
    if (!data) throw new Error(`Partner not found for slug=${partnerSlug}`);
    return data;
  }
  throw new Error("Missing partner_id or partner_slug");
}
async function loadCapabilities(partnerId, onlyCapabilityKey) {
  let query = supabase.from("catalog_partner_capabilities").select("partner_id, capability_key, endpoint_url, auth_mode, is_confirmed, notes").eq("partner_id", partnerId).order("capability_key", {
    ascending: true
  });
  if (onlyCapabilityKey) {
    query = query.eq("capability_key", onlyCapabilityKey);
  }
  const { data, error } = await query;
  if (error) throw error;
  return data || [];
}
Deno.serve(async (req)=>{
  try {
    if (req.method !== "POST") {
      return json({
        error: "Use POST"
      }, {
        status: 405
      });
    }
    const body = await req.json();
    const onlyCapabilityKey = String(body?.capability_key || "").trim() || null;
    const partner = await resolvePartner(body);
    const capabilities = await loadCapabilities(partner.id, onlyCapabilityKey || undefined);
    if (!capabilities.length) {
      return json({
        ok: false,
        error: "No capabilities found for partner",
        partner
      }, {
        status: 404
      });
    }
    const results = [];
    for (const capability of capabilities){
      const endpointUrl = String(capability.endpoint_url || "").trim();
      if (!endpointUrl) {
        results.push({
          capability_key: capability.capability_key,
          endpoint_url: endpointUrl,
          probe_ok: false,
          error: "Empty endpoint_url"
        });
        continue;
      }
      let probeOk = false;
      let httpStatus = null;
      let contentType = "";
      let responseExcerpt = "";
      let errorMessage = "";
      try {
        const response = await fetchWithTimeout(endpointUrl);
        httpStatus = response.status;
        contentType = response.headers.get("content-type") || "";
        const rawText = await response.text();
        responseExcerpt = excerptText(rawText, 500);
        probeOk = looksConfirmed(capability.capability_key, response.status, rawText, contentType);
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }
      const { error: updateError } = await supabase.from("catalog_partner_capabilities").update({
        is_confirmed: probeOk ? true : capability.is_confirmed,
        last_checked_at: new Date().toISOString(),
        last_http_status: httpStatus,
        last_content_type: contentType || null,
        last_probe_ok: probeOk,
        last_error: errorMessage || null,
        last_response_excerpt: responseExcerpt || null,
        updated_at: new Date().toISOString()
      }).eq("partner_id", partner.id).eq("capability_key", capability.capability_key);
      if (updateError) throw updateError;
      const { error: logError } = await supabase.from("catalog_partner_probe_runs").insert({
        partner_id: partner.id,
        capability_key: capability.capability_key,
        endpoint_url: endpointUrl,
        probe_ok: probeOk,
        http_status: httpStatus,
        content_type: contentType || null,
        response_excerpt: responseExcerpt || null,
        error_message: errorMessage || null
      });
      if (logError) throw logError;
      results.push({
        capability_key: capability.capability_key,
        endpoint_url: endpointUrl,
        probe_ok: probeOk,
        http_status: httpStatus,
        content_type: contentType,
        response_excerpt: responseExcerpt,
        error: errorMessage
      });
    }
    return json({
      ok: true,
      partner: {
        id: partner.id,
        slug: partner.slug,
        display_name: partner.display_name
      },
      count: results.length,
      results
    });
  } catch (error) {
    return json({
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    }, {
      status: 500
    });
  }
});
