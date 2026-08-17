// Edge Function : health-probe
//
// Supervision minimale du service public. Appelee par le cron
// `anarbib-health-probe` toutes les 5 minutes (cf. migration
// 20260817_service_health_probes).
//
// Elle interroge les points d'entree PUBLICS comme le ferait un visiteur
// anonyme, enregistre code HTTP et latence dans service_health_probes, puis :
//   - ouvre un incident + alerte par e-mail apres DEUX tours consecutifs
//     mauvais (un seul tour peut etre un hoquet reseau) ;
//   - ferme l'incident + envoie un e-mail de retablissement des que ca repasse.
//
// Limite assumee : la sonde vit dans Supabase. Une panne TOTALE de Supabase
// l'emporte avec le service. Elle couvre la DEGRADATION (lenteurs, 500 sous
// charge), qui est le risque mesure lors du test de charge du 17/08.
//
// AUTHENTIFICATION : x-webhook-secret verifie cote base par
// fn_check_health_probe_secret(), sans repli. Meme convention stricte que
// notify-security-notice.

import { supabaseAdmin } from '../_shared/core/env.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail } from '../_shared/transport/email.ts';

const BASE = (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/+$/, '');
const ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

// Au-dela, on considere le service degrade meme si le code HTTP est bon.
// Repere : en fonctionnement normal ces appels sont a ~100-200 ms (mesure 17/08),
// et le statement_timeout du role anon est de 3 s.
const SEUIL_LENT_MS = 3000;
const RETENTION_JOURS = 30;

const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared',
};

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8' };
const jsonResponse = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

const esc = (v: unknown) =>
  String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

type Sonde = { endpoint: string; url: string; init?: RequestInit };

/** Points d'entree representatifs du parcours public. */
function sondes(bookId: number | null): Sonde[] {
  const h = { apikey: ANON, Authorization: `Bearer ${ANON}` };
  const list: Sonde[] = [
    {
      endpoint: 'auth',
      url: `${BASE}/auth/v1/health`,
      init: { headers: { apikey: ANON } },
    },
    {
      endpoint: 'recherche_catalogue',
      url: `${BASE}/rest/v1/rpc/catalog_search_ids_v1`,
      init: {
        method: 'POST',
        headers: { ...h, 'content-type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({ p_q: 'anarquismo' }),
      },
    },
    {
      endpoint: 'liste_bibliotheques',
      url: `${BASE}/rest/v1/public_libraries?select=slug&limit=10`,
      init: { headers: { ...h, 'Accept-Profile': 'api' } },
    },
  ];
  if (bookId) {
    list.push({
      endpoint: 'fiche_livre',
      url: `${BASE}/rest/v1/v_book_detail_public_v2?select=*&book_id=eq.${bookId}&limit=1`,
      init: { headers: h },
    });
  }
  return list;
}

async function mesurer(s: Sonde) {
  const t0 = Date.now();
  try {
    const r = await fetch(s.url, s.init);
    await r.arrayBuffer().catch(() => {});
    const latency = Date.now() - t0;
    const lent = latency > SEUIL_LENT_MS;
    return {
      endpoint: s.endpoint,
      ok: r.ok && !lent,
      status_code: r.status,
      latency_ms: latency,
      error: !r.ok ? `HTTP ${r.status}` : lent ? `lent (${latency} ms > ${SEUIL_LENT_MS})` : null,
    };
  } catch (e) {
    return {
      endpoint: s.endpoint,
      ok: false,
      status_code: null,
      latency_ms: Date.now() - t0,
      error: String((e as Error)?.message ?? e).slice(0, 300),
    };
  }
}

async function destinataires() {
  const { data } = await supabaseAdmin
    .from('network_administrators')
    .select('user_id')
    .eq('status', 'active');
  const ids = (data ?? []).map((r: any) => r.user_id).filter(Boolean);
  if (!ids.length) return [];
  const { data: profs } = await supabaseAdmin
    .from('profiles')
    .select('email, first_name')
    .in('id', ids);
  return (profs ?? [])
    .filter((p: any) => p.email)
    .map((p: any) => ({ email: String(p.email).trim(), name: p.first_name || undefined }));
}

async function alerter(sujet: string, titre: string, corpsHtml: string) {
  const cibles = await destinataires();
  const { html, text } = renderEmail({
    preheader: sujet,
    title: titre,
    introHtml: corpsHtml,
    footerHtml: footerPadrao(NETWORK_CTX, 'fr'),
    context: NETWORK_CTX,
    locale: 'fr',
  });
  for (const c of cibles) {
    await safeSendEmail(c, sujet, html, text, 'health_probe', NETWORK_CTX);
  }
  return cibles.length;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return jsonResponse(405, { ok: false, error: 'Method not allowed' });

  const provided = String(req.headers.get('x-webhook-secret') || '').trim();
  if (!provided) return jsonResponse(401, { ok: false, error: 'missing x-webhook-secret' });
  const { data: secretOk, error: secretErr } = await supabaseAdmin.rpc(
    'fn_check_health_probe_secret',
    { p_secret: provided },
  );
  if (secretErr) return jsonResponse(500, { ok: false, error: 'secret check failed' });
  if (secretOk !== true) return jsonResponse(401, { ok: false, error: 'unauthorized' });

  // Un livre public quelconque, pour sonder la fiche (la page la plus lourde).
  const { data: unLivre } = await supabaseAdmin
    .from('books')
    .select('id')
    .limit(1)
    .maybeSingle();

  const resultats = await Promise.all(sondes(unLivre?.id ?? null).map(mesurer));
  await supabaseAdmin.from('service_health_probes').insert(resultats);

  const tourOk = resultats.every((r) => r.ok);
  const echecs = resultats.filter((r) => !r.ok);
  const raison = echecs.map((r) => `${r.endpoint} : ${r.error}`).join(' ; ');

  // Le tour PRECEDENT etait-il mauvais lui aussi ? (on alerte a partir de deux
  // tours consecutifs, pour ne pas reagir a un hoquet isole)
  const { data: precedents } = await supabaseAdmin
    .from('service_health_probes')
    .select('checked_at, ok')
    .order('checked_at', { ascending: false })
    .limit(40);

  const parTour = new Map<string, boolean>();
  for (const p of (precedents ?? []) as any[]) {
    const cle = String(p.checked_at).slice(0, 16); // minute
    parTour.set(cle, (parTour.get(cle) ?? true) && p.ok);
  }
  const tours = [...parTour.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1)).map((e) => e[1]);
  const deuxMauvais = tours.length >= 2 && tours[0] === false && tours[1] === false;

  const { data: incidentOuvert } = await supabaseAdmin
    .from('service_health_incidents')
    .select('id, opened_at, reason')
    .is('closed_at', null)
    .order('opened_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let action = 'rien';

  if (!tourOk && deuxMauvais && !incidentOuvert) {
    const { data: inc } = await supabaseAdmin
      .from('service_health_incidents')
      .insert({ reason: raison || 'degradation' })
      .select('id')
      .single();
    const n = await alerter(
      'AnarBib — le service public est dégradé',
      'Le service public est dégradé',
      `<p style="margin:0 0 10px">La sonde automatique a relevé <strong>deux tours consécutifs en échec</strong> sur les points d'entrée publics.</p>
       <p style="margin:0 0 10px">Détail du dernier tour :</p>
       <ul style="margin:0 0 10px;padding-left:18px">${resultats
         .map(
           (r) =>
             `<li>${esc(r.endpoint)} — ${r.ok ? 'ok' : '<strong>KO</strong>'} — ${esc(String(r.latency_ms))} ms${
               r.error ? ` — ${esc(r.error)}` : ''
             }</li>`,
         )
         .join('')}</ul>
       <p style="margin:0">Un e-mail de rétablissement suivra dès que la sonde repassera au vert.</p>`,
    );
    await supabaseAdmin
      .from('service_health_incidents')
      .update({ notified_at: new Date().toISOString() })
      .eq('id', inc?.id);
    action = `incident ouvert, ${n} destinataire(s) alerté(s)`;
  } else if (tourOk && incidentOuvert) {
    await supabaseAdmin
      .from('service_health_incidents')
      .update({ closed_at: new Date().toISOString() })
      .eq('id', incidentOuvert.id);
    const depuis = new Date(incidentOuvert.opened_at).toLocaleString('fr-FR');
    const n = await alerter(
      'AnarBib — le service public est rétabli',
      'Service rétabli',
      `<p style="margin:0 0 10px">La sonde automatique est repassée au vert. L'incident ouvert le ${esc(depuis)} est clos.</p>
       <p style="margin:0">Cause relevée à l'ouverture : ${esc(incidentOuvert.reason)}</p>`,
    );
    action = `incident clos, ${n} destinataire(s) prévenu(s)`;
  }

  // Purge de l'historique (evite une table qui grossit sans fin).
  const limite = new Date(Date.now() - RETENTION_JOURS * 86400_000).toISOString();
  await supabaseAdmin.from('service_health_probes').delete().lt('checked_at', limite);

  return jsonResponse(200, {
    ok: true,
    tour_ok: tourOk,
    action,
    resultats,
  });
});
