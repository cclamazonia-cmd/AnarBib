// =============================================================================
// _shared/data/consultas.ts - Paquet 26 L4 v2.2
// =============================================================================
// Bundles DB pour les handlers consultas (calque _shared/data/reservas.ts mais
// simplifie grace aux caches denormalises de consulta_linhas_v2 - pas besoin
// de joindre book_holdings + books).
//
// 2 fonctions exportees :
//   - getConsultaV2Bundle(consultaId)            -> handleConsultaCriadaV2 + lifecycle
//   - getConsultaWorkflowBundle(consultaId, lns) -> handleConsultaV2WorkflowEvent
//
// recordId = consulta_id (= consultas_locais_v2.id), passe par le trigger DB
// via fn_dispatch_circulation_notify_event(event, NEW.consulta_id, payload).
//
// v2.3 : double cast 'as unknown as Record<string,unknown>[]' pour neutraliser
// le check d'overlap TS2352 sur GenericStringError (qui est {error:true} & String,
// sans index signature). Recommandation explicite du compilateur TS.
// v2.2 : cast Record<string,unknown>[] avant .map() (rejete: TS2352 overlap).
// v2.1 : typage explicite (consultaId: number, lineNos?: number[]).
//
// Schemas (audit 13/05/2026) :
//   - consultas_locais_v2 : id, user_id, library_id, status_global, notes,
//     created_at, updated_at
//   - consulta_linhas_v2  : id, consulta_id, line_no, holding_id, sub_id,
//     bib_ref, book_id, item_status, titulo_cache, autor_cache, editora_cache,
//     ano_cache, expires_at, consulted_at, cancelled_at, expired_at, ...
//   - consulta_item_workflow_v2 : id, consulta_id, line_no, workflow_stage,
//     consultation_starts_at, consultation_ends_at, consultation_scheduled_for,
//     schedule_reply_status, schedule_reply_at, schedule_reply_note,
//     workflow_note, updated_at, updated_by
// =============================================================================

import { supabaseAdmin } from "../core/env.ts";

// -----------------------------------------------------------------------------
// Bundle lifecycle : consulta + profile + lignes (titres via caches).
// -----------------------------------------------------------------------------

export async function getConsultaV2Bundle(consultaId: number) {
  // 1. Consulta agregat
  const { data: consulta, error: e1 } = await supabaseAdmin
    .from("consultas_locais_v2")
    .select("id,user_id,library_id,created_at,updated_at,notes,status_global")
    .eq("id", consultaId)
    .maybeSingle();
  if (e1) throw e1;
  if (!consulta) throw new Error("Consulta não encontrada.");

  // 2. Profile lecteur (la PK est profiles.id, pas profiles.user_id - calque reserva)
  const consultaRec = consulta as Record<string, unknown>;
  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,phone,address,consent_email,preferred_language")
    .eq("id", consultaRec.user_id as string)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  // 3. Lignes avec leurs caches denormalises (pas de JOIN books)
  const { data: lignes, error: e3 } = await supabaseAdmin
    .from("consulta_linhas_v2")
    .select(
      "line_no,sub_id,bib_ref,titulo_cache,autor_cache,editora_cache,ano_cache," +
      "item_status,expires_at,consulted_at,cancelled_at,expired_at,holding_id"
    )
    .eq("consulta_id", consultaId)
    .order("line_no", { ascending: true });
  if (e3) throw e3;

  // Normalisation a plat (alias *_cache -> noms simples pour coherence reserva)
  // Cast Record<string,unknown>[] pour neutraliser GenericStringError (calque reservas.ts)
  const items = ((lignes || []) as unknown as Record<string, unknown>[]).map((l) => ({
    line_no: Number(l.line_no || 0) || undefined,
    sub_id: String(l.sub_id || "").trim() || null,
    bib_ref: String(l.bib_ref || "").trim() || null,
    titulo: String(l.titulo_cache || "").trim() || null,
    autor: String(l.autor_cache || "").trim() || null,
    editora: String(l.editora_cache || "").trim() || null,
    ano: String(l.ano_cache || "").trim() || null,
    item_status: String(l.item_status || "").trim() || null,
    expires_at: String(l.expires_at || "").trim() || null,
    consulted_at: String(l.consulted_at || "").trim() || null,
    cancelled_at: String(l.cancelled_at || "").trim() || null,
    expired_at: String(l.expired_at || "").trim() || null,
    holding_id: l.holding_id
  }));

  return {
    consulta: consulta as Record<string, unknown>,
    profile: profile as Record<string, unknown>,
    items
  };
}

// -----------------------------------------------------------------------------
// Bundle workflow : idem + colonnes workflow (stages, creneaux, replies)
// filtrees sur les line_nos passes par le payload du trigger.
// -----------------------------------------------------------------------------

export async function getConsultaWorkflowBundle(consultaId: number, lineNos?: number[]) {
  // 1. Consulta agregat
  const { data: consulta, error: e1 } = await supabaseAdmin
    .from("consultas_locais_v2")
    .select("id,user_id,library_id,created_at,updated_at,notes,status_global")
    .eq("id", consultaId)
    .maybeSingle();
  if (e1) throw e1;
  if (!consulta) throw new Error("Consulta não encontrada.");

  // 2. Profile
  const consultaRec = consulta as Record<string, unknown>;
  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,phone,address,consent_email,preferred_language")
    .eq("id", consultaRec.user_id as string)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  // 3. Lignes + workflow joint via PostgREST (FK naturelle consulta_id + line_no).
  //    Alias 'wf' sur la relation embarquee.
  let q = supabaseAdmin
    .from("consulta_linhas_v2")
    .select(
      "line_no,sub_id,bib_ref,titulo_cache,autor_cache,editora_cache,ano_cache," +
      "item_status,expires_at,consulted_at,cancelled_at,expired_at,holding_id," +
      "wf:consulta_item_workflow_v2(" +
        "workflow_stage,consultation_starts_at,consultation_ends_at," +
        "consultation_scheduled_for,schedule_reply_status,schedule_reply_at," +
        "schedule_reply_note,workflow_note" +
      ")"
    )
    .eq("consulta_id", consultaId)
    .order("line_no", { ascending: true });

  if (Array.isArray(lineNos) && lineNos.length > 0) {
    q = q.in("line_no", lineNos);
  }

  const { data: lignes, error: e3 } = await q;
  if (e3) throw e3;

  // Normalisation a plat - la relation embarquee peut etre array ou object
  // selon la cardinalite PostgREST detectee.
  // Cast Record<string,unknown>[] pour neutraliser GenericStringError (calque reservas.ts)
  const items = ((lignes || []) as unknown as Record<string, unknown>[]).map((l) => {
    const wfRaw = l.wf;
    const wf = (Array.isArray(wfRaw) ? wfRaw[0] : wfRaw) as Record<string, unknown> | null | undefined;
    return {
      line_no: Number(l.line_no || 0) || undefined,
      sub_id: String(l.sub_id || "").trim() || null,
      bib_ref: String(l.bib_ref || "").trim() || null,
      titulo: String(l.titulo_cache || "").trim() || null,
      autor: String(l.autor_cache || "").trim() || null,
      editora: String(l.editora_cache || "").trim() || null,
      ano: String(l.ano_cache || "").trim() || null,
      item_status: String(l.item_status || "").trim() || null,
      expires_at: String(l.expires_at || "").trim() || null,
      consulted_at: String(l.consulted_at || "").trim() || null,
      cancelled_at: String(l.cancelled_at || "").trim() || null,
      expired_at: String(l.expired_at || "").trim() || null,
      holding_id: l.holding_id,
      // Workflow joint
      workflow_stage: String(wf?.workflow_stage || "").trim() || null,
      consultation_starts_at: String(wf?.consultation_starts_at || "").trim() || null,
      consultation_ends_at: String(wf?.consultation_ends_at || "").trim() || null,
      consultation_scheduled_for: String(wf?.consultation_scheduled_for || "").trim() || null,
      schedule_reply_status: String(wf?.schedule_reply_status || "").trim() || null,
      schedule_reply_at: String(wf?.schedule_reply_at || "").trim() || null,
      schedule_reply_note: String(wf?.schedule_reply_note || "").trim() || null,
      workflow_note: String(wf?.workflow_note || "").trim() || null
    };
  });

  return {
    consulta: consulta as Record<string, unknown>,
    profile: profile as Record<string, unknown>,
    items
  };
}
