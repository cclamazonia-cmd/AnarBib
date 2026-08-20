// AnarBib / BLMF staging
// Edge Function générique pour assets numériques publiés
// Objet:
// - remplace la logique PDF-only par un point d'entrée unique
// - public + conta_ativa
// - stockage local ou lien externe
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SIGNED_URL_TTL_SECONDS = Number(Deno.env.get("DIGITAL_ASSET_SIGNED_URL_TTL_SECONDS") ?? "900");
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type",
      "access-control-allow-methods": "GET, POST, OPTIONS"
    }
  });
}
function parseAssetId(req) {
  const url = new URL(req.url);
  const rawFromQuery = url.searchParams.get("asset_id") ?? url.searchParams.get("assetId");
  if (rawFromQuery && /^\d+$/.test(rawFromQuery)) return Number(rawFromQuery);
  return null;
}
function inferViewerKind(resourceType, mimeType, sourceUrl) {
  const rt = String(resourceType || "").toLowerCase();
  const mt = String(mimeType || "").toLowerCase();
  const su = String(sourceUrl || "").toLowerCase();
  if (rt === "link_externo") return "external_link";
  if (rt === "audio" || mt.startsWith("audio/")) return "audio";
  if (rt === "video" || mt.startsWith("video/")) return "video";
  if (rt === "image" || mt.startsWith("image/")) return "image";
  if (rt === "epub" || mt === "application/epub+zip" || su.endsWith(".epub")) return "epub";
  if (rt === "pdf_publico" || rt === "pdf_restrito" || mt === "application/pdf" || su.endsWith(".pdf")) return "pdf";
  return "generic";
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") return json({
    ok: true
  }, 200);
  try {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({
        ok: false,
        error: "Missing Supabase env vars"
      }, 500);
    }
    const authHeader = req.headers.get("authorization") ?? "";
    const assetIdFromQuery = parseAssetId(req);
    let assetId = assetIdFromQuery;
    if (!assetId && req.method !== "GET") {
      try {
        const body = await req.json();
        const raw = body?.asset_id ?? body?.assetId;
        if (raw && /^\d+$/.test(String(raw))) assetId = Number(raw);
      } catch  {
      // no-op
      }
    }
    if (!assetId || !Number.isFinite(assetId) || assetId <= 0) {
      return json({
        ok: false,
        error: "Missing or invalid asset_id"
      }, 400);
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: authHeader ? {
          authorization: authHeader
        } : {}
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    const { data, error } = await userClient.rpc("get_accessible_digital_asset_by_id_v2", {
      p_asset_id: assetId
    });
    if (error) {
      return json({
        ok: false,
        error: error.message
      }, 403);
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      return json({
        ok: false,
        error: "Asset not found or not accessible"
      }, 404);
    }
    const resourceType = String(row.resource_type || "");
    const mimeType = String(row.mime_type || "");
    const sourceUrl = row.source_url ? String(row.source_url) : null;
    const storageBucket = row.storage_bucket ? String(row.storage_bucket) : null;
    const storagePath = row.storage_path ? String(row.storage_path) : null;
    const viewerKind = inferViewerKind(resourceType, mimeType, sourceUrl);
    let accessUrl = null;
    let accessMode = "metadata_only";
    if (storageBucket && storagePath) {
      const { data: signed, error: signedError } = await serviceClient.storage.from(storageBucket).createSignedUrl(storagePath, SIGNED_URL_TTL_SECONDS);
      if (signedError || !signed?.signedUrl) {
        return json({
          ok: false,
          error: signedError?.message || "Unable to create signed URL"
        }, 500);
      }
      accessUrl = signed.signedUrl;
      accessMode = "storage_signed";
    } else if (sourceUrl) {
      accessUrl = sourceUrl;
      accessMode = "external_url";
    }
    // ── Provenance : ne jamais exposer l'URL source d'un document RESTREINT
    //    servi depuis le stockage. ──────────────────────────────────────────
    // `source_url` a deux roles distincts dans cette fonction :
    //   * pour une ressource purement EXTERNE, c'est le chemin de lecture
    //     (accessMode = 'external_url') — il doit rester expose ;
    //   * pour une ressource servie depuis le STOCKAGE, l'acces passe par une
    //     URL signee a duree limitee, et source_url n'est plus que de la
    //     provenance.
    //
    // Dans ce second cas, si la ressource n'est pas publique, renvoyer
    // source_url revient a livrer une copie permanente et non revocable du
    // document — souvent un lien de telechargement direct (MEGA, Drive…) avec
    // sa cle. Cela defait exactement ce que la restriction protege : le PDF
    // servi est filigrane au nom du lecteur, l'original ne l'est pas.
    // Constate le 2026-08-20 sur la ressource 61 (bucket pdf-restrito) : la
    // page lecteur affichait le nom de la source mais pointait vers le fichier.
    //
    // Le masquage est fait ICI, cote serveur, et non dans l'interface : masquer
    // a l'ecran laisserait le lien dans la reponse de l'API.
    const estPublic = String(row.access_scope || "") === "publico";
    const provenanceExposable = accessMode !== "storage_signed" || estPublic;

    return json({
      ok: true,
      asset: {
        asset_id: row.asset_id,
        book_id: row.book_id,
        resource_type: row.resource_type,
        usage_type: row.usage_type,
        access_scope: row.access_scope,
        mime_type: row.mime_type,
        language_code: row.language_code,
        source_name: row.source_name,
        source_url: provenanceExposable ? row.source_url : null,
        attribution_text: row.attribution_text,
        rights_status: row.rights_status,
        label: row.label,
        is_primary: row.is_primary,
        requires_active_account: row.requires_active_account,
        access_granted: row.access_granted
      },
      viewer_kind: viewerKind,
      access_mode: accessMode,
      access_url: accessUrl,
      expires_in_seconds: accessMode === "storage_signed" ? SIGNED_URL_TTL_SECONDS : null
    });
  } catch (error) {
    return json({
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
