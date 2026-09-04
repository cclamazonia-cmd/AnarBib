// CHEMIN DÉPÔT : supabase/functions/work-titles-autofill/index.ts
//
// Pré-traduit le titre des œuvres dans les locales qui leur manquent (lot 3 OPAC par
// œuvre, décision 4 du 04/09/2026 : « titre d'origine + pré-traduction automatique,
// avertissement corrige-moi »). Périmètre : les œuvres à plusieurs éditions, celles
// dont le titre s'affiche à l'OPAC — une œuvre à une seule édition montre le titre de
// cette édition.
//
// Déclenchée par pg_cron toutes les 10 minutes (fn_work_titles_autofill_call, qui ne
// sonne que s'il reste quelque chose à faire), ou ponctuellement avec { work_id }.
// L'état vit en base : fn_work_titles_pending dit quoi faire, fn_work_titles_autofill_apply
// pose les titres (source = 'auto', needs_review = true) sans jamais écraser un titre
// manuel ni un titre d'édition, et date la tentative (une erreur se rejoue après 7 jours).
//
// Déploiement : par la CI (tag deployed-functions). Secrets : SUPABASE_URL,
// SUPABASE_SECRET_KEYS (défaut), ANTHROPIC_API_KEY, GAZETTE_CRON_SECRET (secret partagé
// des crons, même domaine de confiance que la gazette).

import { secretKey } from "../_shared/core/secret-key.ts";
import { createClient } from "../_shared/deps.ts";

const LOCALES = ["pt-BR", "fr", "es", "it", "en", "de", "ca", "eo", "nl", "el"];
const LOCALE_NAMES: Record<string, string> = {
  "pt-BR": "português do Brasil", fr: "français", es: "español", it: "italiano", en: "English",
  de: "Deutsch", ca: "català", eo: "Esperanto", nl: "Nederlands", el: "ελληνικά",
};
const ANTHROPIC_MODEL = "claude-opus-5";
const BATCH = 5; // œuvres par tick

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!, secretKey()!,
  { auth: { persistSession: false } },
);

// Un appel Messages, avec le repli serveur en cas de refus (recommandé sur Opus 5).
// Si la plateforme ne connaît pas encore ce bêta, on rejoue sans : un titre de livre
// n'a pas à dépendre d'un en-tête optionnel.
async function claude(system: string, user: string): Promise<string> {
  const body: Record<string, unknown> = {
    model: ANTHROPIC_MODEL, max_tokens: 2000, system,
    messages: [{ role: "user", content: user }],
  };
  const call = (withFallback: boolean) => fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01", "content-type": "application/json",
      ...(withFallback ? { "anthropic-beta": "server-side-fallback-2026-07-01" } : {}),
    },
    body: JSON.stringify(withFallback ? { ...body, fallbacks: "default" } : body),
  });
  let r = await call(true);
  let j = await r.json();
  if (r.status === 400 && /fallback|beta/i.test(JSON.stringify(j))) {
    r = await call(false);
    j = await r.json();
  }
  if (!r.ok) throw new Error("anthropic: " + JSON.stringify(j).slice(0, 300));
  if (j.stop_reason === "refusal") throw new Error("anthropic: refusal");
  const text = (j.content ?? []).filter((c: any) => c.type === "text").map((c: any) => c.text).join("");
  return text;
}
function parseJson(s: string): Record<string, unknown> {
  const a = s.indexOf("{"), b = s.lastIndexOf("}");
  if (a < 0 || b < a) throw new Error("réponse sans JSON");
  return JSON.parse(s.slice(a, b + 1));
}

type Pending = {
  work_id: number; uniform_title: string; author_name: string | null;
  titles: Record<string, { title: string; source: string }>;
  editions: Array<{ titulo: string; idioma: string | null; ano: string | null; editora: string | null }>;
  missing: string[];
};

async function fillOne(w: Pending): Promise<number> {
  const missing = (w.missing ?? []).filter((l) => LOCALES.includes(l));
  if (!missing.length) {
    await sb.rpc("fn_work_titles_autofill_apply", { p_work_id: w.work_id, p_titles: {}, p_error: null });
    return 0;
  }
  const system =
    "Tu es catalogueur·se d'un réseau de bibliothèques anarchistes. On te donne une œuvre " +
    "(son titre uniforme, son auteur·rice, les titres déjà connus par langue, et ses éditions). " +
    "Donne le titre de cette œuvre dans chacune des locales demandées. Si une traduction publiée " +
    "existe dans cette langue, donne son titre consacré ; sinon une traduction sobre et littérale " +
    "du titre d'origine, sans sous-titre ni mention d'édition. Ne traduis pas les noms propres. " +
    "Garde la casse d'usage de chaque langue. Réponds UNIQUEMENT par un objet JSON " +
    '{ "<locale>": "<titre>" } contenant exactement les locales demandées.';
  const user = JSON.stringify({
    uniform_title: w.uniform_title,
    author: w.author_name,
    known_titles: w.titles,
    editions: w.editions,
    wanted: missing.map((l) => ({ locale: l, language: LOCALE_NAMES[l] })),
  });
  const out = parseJson(await claude(system, user));
  const titles: Record<string, string> = {};
  for (const l of missing) {
    const v = out?.[l];
    if (typeof v === "string" && v.trim()) titles[l] = v.trim().slice(0, 400);
  }
  const { data, error } = await sb.rpc("fn_work_titles_autofill_apply", {
    p_work_id: w.work_id, p_titles: titles, p_error: null,
  });
  if (error) throw error;
  return Number(data ?? 0);
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("GAZETTE_CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { work_id } = await req.json().catch(() => ({}));
  const { data, error } = await sb.rpc("fn_work_titles_pending", { p_limit: work_id ? 1000 : BATCH });
  if (error) return Response.json({ ok: false, error: String(error.message ?? error) }, { status: 500 });
  let rows: Pending[] = (data ?? []) as Pending[];
  if (work_id) rows = rows.filter((r) => Number(r.work_id) === Number(work_id));

  let done = 0, posed = 0;
  const errors: Array<{ work_id: number; error: string }> = [];
  for (const w of rows) {
    try { posed += await fillOne(w); done++; }
    catch (e) {
      const msg = String((e as any)?.message ?? e).slice(0, 500);
      errors.push({ work_id: w.work_id, error: msg });
      await sb.rpc("fn_work_titles_autofill_apply", { p_work_id: w.work_id, p_titles: {}, p_error: msg });
    }
  }
  return Response.json({ ok: true, processed: rows.length, done, titles_posed: posed, errors });
});
