// Edge Function : deposit-digital-candidate (NUMDIF D16, 15/10/2026, REGISTRE §47 NUMDIF-4).
// Session : File de candidats PDF.
//
// Verse des candidats PDF validés (file ingest.digital_candidates, D13) SANS clé
// manipulée par une personne : appelée par la coordination de la bibliothèque
// détentrice, depuis l'onglet « Candidats PDF » de la page Importations (D15),
// avec son jeton. Remplace la commande lancée à la main le 14/10 avec la clé
// sb_secret (versement des deux Reclus, ressources 77 et 78).
//
// PAR LOTS, AVEC REPRISE (consigne de Xavier du 15/10) : le corps porte une
// liste `candidate_ids` (ou un seul `candidate_id`). Les candidats passent un
// par un ; la fonction s'arrête AVANT d'en commencer un nouveau quand son
// budget de temps est dépensé, et rend `remaining` : l'écran rappelle avec le
// reste. L'état vit en base — versé, ou refus noté (deposit_error) : un lot
// interrompu (onglet fermé, coupure) se reprend en relançant le lot, sans
// rien refaire de ce qui est versé. Un refus n'arrête pas le lot.
//
// Pour chaque candidat :
//   1. GARDE sous le jeton de l'appelant (fn_digital_candidate_deposit_garde) :
//      coordination de la bibliothèque du candidat, ou administration du
//      réseau ; bibliothèque encore détentrice ; candidat « à verser » ;
//   2. téléchargement de l'URL validée CÔTÉ SERVEUR, en FLUX vers une zone
//      PRIVÉE (pdf-restrito, numdif-staging/…) — jamais tout le fichier en
//      mémoire, jusqu'à 500 Mo (limite des seaux) ; un refus de la source
//      (401/403/429/503, Cloudflare) arrête ce candidat, sans contournement ;
//   3. EMPREINTES calculées au passage (empreintes.ts, natives depuis le 16/10 :
//      en JS pur, un PDF de plus de ~45 Mo dépassait les 2 s de CPU) : SHA-256, et SHA-1
//      pour une source MediaWiki qui ne donne que lui ; comparée à celle figée
//      à la validation — SHA-256 s'il est connu, sinon SHA-1, et le SHA-256 se
//      calcule à ce premier téléchargement. Différente : le fichier de la zone
//      privée est effacé, le refus est noté sur le candidat et rendu ;
//   4. le fichier vérifié passe au seau que fixe le cas (NUMDIF-2) —
//      anarbib-pdf-public ou pdf-restrito — au chemin
//      books/<book_id>/<horodatage ms>_<nom>.pdf. Un fichier non vérifié n'est
//      donc jamais public, pas même un instant ;
//   5. enregistrement à la clé de service (ingest.fn_digital_candidate_deposit_record),
//      qui revérifie tout et crée la ressource ; en cas d'échec, l'objet est retiré.
// Chaque refus porte un `code` que l'écran traduit (src/lib/edgeError.js →
// error.edge.<code>) ou relaie le HINT de la base (error.digital_candidate.*).

import { secretKey } from '../_shared/core/secret-key.ts';
import { createClient } from '../_shared/deps.ts';
import { doubleFacteurManquant } from '../_shared/core/double-facteur.ts';
import { Sha1, Sha256 } from './empreintes.ts';
import { sanitize } from './nom.ts';
import { AdresseRefusee, fetchSortant } from '../_shared/core/adresse-sortante.ts';

const MAX_OCTETS = 500 * 1024 * 1024;        // file_size_limit de pdf-restrito et anarbib-pdf-public
// D27 (20/10/2026) : ce qu'UN appel tient vraiment. La plateforme coupe une
// fonction à 2 s de CPU (HTTP 546) ; le flux et les empreintes natives en
// coûtent ~12 ms par Mo (98 Mo : ~1,25 s au banc du 16/10), d'où une marge de
// ~150-180 Mo. Au-delà, l'appel mourait en route, sans refus noté ni message,
// en laissant un objet partiel dans la zone privée. Le refus se dit désormais
// AVANT le téléchargement (taille relevée à la validation, ou annoncée par la
// source), et le flux s'arrête proprement s'il dépasse sans l'avoir annoncé.
// L'écran (CandidatsPdfPanel) le dit avant même l'appel. Un plus gros fichier
// se verse à la main (scripts/maptiles/televerser-tus.mjs, par morceaux).
const LIMITE_APPEL = 140 * 1000 * 1000;
const MAX_PAR_APPEL = 25;
const BUDGET_MS = 100_000;                    // on ne commence plus de candidat au-delà
const ZONE_PRIVEE = 'pdf-restrito';
const UA = 'AnarBib-NUMDIF/1.0 (versement d\'une bibliotheque du reseau AnarBib)';
// 19/10/2026 : file_url est saisie par une coordination. Le téléchargement passe
// par fetchSortant (adresses publiques seulement, chaque redirection revérifiée)
// et porte un délai : une source qui pend ne tient plus la fonction jusqu'à sa
// coupure.
const DELAI_TELECHARGEMENT_MS = 120_000;

// Le nom tiré de l'URL : un « % » mal formé ne lève plus (URIError), il reste tel quel.
function dernierSegment(url: string): string {
  const brut = new URL(url).pathname.split('/').pop() || '';
  try { return decodeURIComponent(brut); } catch { return brut; }
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}
function refus(code: string, error: string, status: number, extra: Record<string, unknown> = {}) {
  return json({ error, code, ok: false, ...extra }, status);
}

type Issue = { id: number; ok: boolean; code?: string; error?: string; hint?: string | null;
  resource_id?: number | null; access_scope?: string; bytes?: number; sha256?: string; [k: string]: unknown };
const echec = (id: number, code: string, error: string, extra: Record<string, unknown> = {}): Issue =>
  ({ id, ok: false, code, error, ...extra });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return refus('bad_request', 'Method not allowed. Use POST.', 405);
  const debut = Date.now();

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return refus('auth_required', 'Missing Authorization header.', 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = secretKey();
  if (!supabaseUrl || !anonKey || !serviceKey) return refus('server_error', 'Server misconfigured.', 500);

  // double authentification, avant de lire le corps et avant toute autre requête
  if (await doubleFacteurManquant(supabaseUrl, anonKey, authHeader)) {
    return refus('aal2_required', 'Double authentification requise.', 403);
  }

  let body: any;
  try { body = await req.json(); } catch { return refus('bad_request', 'Body must be valid JSON.', 400); }
  const brut = Array.isArray(body?.candidate_ids) ? body.candidate_ids : (body?.candidate_id != null ? [body.candidate_id] : []);
  const ids = [...new Set(brut.map(Number))].filter((n) => Number.isInteger(n) && n > 0) as number[];
  if (!ids.length) return refus('bad_request', 'candidate_ids requis.', 400);
  if (ids.length > MAX_PAR_APPEL) return refus('bad_request', `Au plus ${MAX_PAR_APPEL} candidats par appel.`, 400);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const issues: Issue[] = [];
  const remaining: number[] = [];
  let service: ReturnType<typeof createClient> | null = null;

  for (const id of ids) {
    if (issues.length > 0 && Date.now() - debut > BUDGET_MS) { remaining.push(id); continue; }

    // 1. la garde, sous le jeton de l'appelant — échec fermé, et AVANT la clé de service
    const { data: g, error: gardeErr } = await userClient.rpc('fn_digital_candidate_deposit_garde', { p_id: id });
    if (gardeErr || !g || !g.file_url || !(g.sha256 || g.sha1) || !g.destination?.storage_bucket) {
      issues.push(gardeErr?.hint === 'error.digital_candidate.not_found'
        ? echec(id, 'candidate_not_found', `Candidat ${id} introuvable.`, { hint: gardeErr.hint })
        : echec(id, 'forbidden', gardeErr?.message || 'Accès refusé.', { hint: gardeErr?.hint ?? null }));
      continue;
    }
    const noterEchec = async (raison: string) => {
      try { await userClient.rpc('fn_digital_candidate_deposit_failed', { p_id: id, p_reason: raison }); } catch (_) { /* best-effort */ }
    };
    const tropLourd = async (octets: number | null) => {
      await noterEchec(`trop lourd pour un versement par le serveur (${octets ? Math.round(octets / 1e6) + ' Mo, ' : ''}${LIMITE_APPEL / 1e6} Mo au plus par appel)`);
      issues.push(echec(id, 'file_too_large', `Fichier trop lourd pour un versement par le serveur (${LIMITE_APPEL / 1e6} Mo au plus).`,
        { bytes: octets, max: LIMITE_APPEL }));
    };

    // D27 : la taille relevée à la validation suffit à refuser, sans rien télécharger
    const relevee = Number(g.file_size_bytes) || 0;
    if (relevee > LIMITE_APPEL) { await tropLourd(relevee); continue; }

    // 2. le téléchargement côté serveur, en flux
    let reponse: Response;
    try {
      reponse = await fetchSortant(g.file_url, { headers: { 'User-Agent': UA }, signal: AbortSignal.timeout(DELAI_TELECHARGEMENT_MS) });
    } catch (e) {
      const refusee = e instanceof AdresseRefusee;
      await noterEchec(refusee ? `adresse refusée : ${(e as Error).message}` : `source injoignable : ${String((e as Error)?.message || e).slice(0, 200)}`);
      issues.push(echec(id, 'source_unreachable', refusee ? 'L\'adresse de la source n\'est pas admise.' : 'La source ne répond pas.'));
      continue;
    }
    const cloudflare = Boolean(reponse.headers.get('cf-mitigated')) || (reponse.headers.get('server') || '').toLowerCase().includes('cloudflare');
    if ([401, 403, 429, 503].includes(reponse.status) || (cloudflare && reponse.status >= 400)) {
      await reponse.body?.cancel();
      await noterEchec(`source fermée aux automates (HTTP ${reponse.status}${cloudflare ? ', Cloudflare' : ''})`);
      issues.push(echec(id, 'source_refused', `La source refuse le téléchargement (HTTP ${reponse.status}).`, { status: reponse.status }));
      continue;
    }
    if (!reponse.ok || !reponse.body) {
      await noterEchec(`HTTP ${reponse.status}`);
      issues.push(echec(id, 'source_unreachable', `La source répond HTTP ${reponse.status}.`, { status: reponse.status }));
      continue;
    }
    const annonce = Number(reponse.headers.get('content-length')) || 0;
    if (annonce > LIMITE_APPEL) {
      await reponse.body.cancel();
      await tropLourd(annonce);
      continue;
    }

    // 3. les empreintes, au passage du flux vers la zone privée
    const h256 = new Sha256();
    const h1 = new Sha1();
    let lu = 0;
    let tete = new Uint8Array(0);
    let raisonFlux: 'not_a_pdf' | 'file_too_large' | null = null;
    const lecteur = reponse.body.getReader();
    const flux = new ReadableStream<Uint8Array>({
      async pull(ctl) {
        const { done, value } = await lecteur.read();
        if (done) { ctl.close(); return; }
        lu += value.byteLength;
        if (lu > Math.min(MAX_OCTETS, LIMITE_APPEL)) { raisonFlux = 'file_too_large'; await lecteur.cancel(); ctl.error(new Error('trop lourd')); return; }
        if (tete.length < 5) {
          const t = new Uint8Array(tete.length + value.byteLength); t.set(tete); t.set(value, tete.length); tete = t.subarray(0, 5);
          if (tete.length >= 5 && new TextDecoder('latin1').decode(tete) !== '%PDF-') {
            raisonFlux = 'not_a_pdf'; await lecteur.cancel(); ctl.error(new Error('pas un PDF')); return;
          }
        }
        h256.update(value); h1.update(value);
        ctl.enqueue(value);
      },
      cancel() { lecteur.cancel(); },
    });

    if (!service) service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const horodatage = Date.now();
    const zone = `numdif-staging/${id}/${horodatage}.pdf`;
    const { error: upErr } = await service.storage.from(ZONE_PRIVEE).upload(zone, flux, { contentType: 'application/pdf', upsert: false });
    if (upErr || raisonFlux) {
      try { await service.storage.from(ZONE_PRIVEE).remove([zone]); } catch (_) { /* best-effort */ }
      if (raisonFlux === 'not_a_pdf') {
        await noterEchec('la réponse n\'est pas un PDF');
        issues.push(echec(id, 'not_a_pdf', 'La source ne rend pas un PDF.'));
      } else if (raisonFlux === 'file_too_large') {
        await tropLourd(lu);
      } else {
        await noterEchec(`dépôt dans le stockage échoué : ${upErr?.message}`);
        issues.push(echec(id, 'server_error', `Dépôt dans le stockage échoué : ${upErr?.message}`));
      }
      continue;
    }
    const sha256 = h256.hex();
    const sha1 = h1.hex();
    const attendue = g.sha256 ? { alg: 'SHA-256', valeur: g.sha256, obtenue: sha256 } : { alg: 'SHA-1', valeur: g.sha1, obtenue: sha1 };
    if (attendue.obtenue !== attendue.valeur) {
      try { await service.storage.from(ZONE_PRIVEE).remove([zone]); } catch (_) { /* best-effort */ }
      await noterEchec(`empreinte ${attendue.alg} différente : attendue ${attendue.valeur}, obtenue ${attendue.obtenue}`);
      issues.push(echec(id, 'fingerprint_mismatch', 'Le fichier téléchargé n\'est plus celui qui a été validé.',
        { algorithm: attendue.alg, expected: attendue.valeur, actual: attendue.obtenue, hint: 'error.digital_candidate.fingerprint_mismatch' }));
      continue;
    }

    // 4. le fichier vérifié passe au seau que fixe le cas de source
    const bucket: string = g.destination.storage_bucket;
    const nom = sanitize(g.original_filename || dernierSegment(g.file_url));
    const chemin = `books/${g.book_id}/${horodatage}_${nom}`;
    const { error: mvErr } = await service.storage.from(ZONE_PRIVEE).move(zone, chemin,
      bucket === ZONE_PRIVEE ? undefined : { destinationBucket: bucket });
    if (mvErr) {
      try { await service.storage.from(ZONE_PRIVEE).remove([zone]); } catch (_) { /* best-effort */ }
      await noterEchec(`passage au seau ${bucket} échoué : ${mvErr.message}`);
      issues.push(echec(id, 'server_error', `Passage au seau ${bucket} échoué : ${mvErr.message}`));
      continue;
    }

    // 5. l'enregistrement, qui revérifie tout et crée la ressource
    const { data: rec, error: recErr } = await service.schema('ingest').rpc('fn_digital_candidate_deposit_record', {
      p_id: id, p_uid: g.caller, p_bucket: bucket, p_path: chemin, p_sha256: sha256, p_sha1: sha1, p_size: lu,
    });
    if (recErr) {
      try { await service.storage.from(bucket).remove([chemin]); } catch (_) { /* best-effort */ }
      await noterEchec(`enregistrement refusé : ${recErr.message}`);
      issues.push(echec(id, 'deposit_refused', recErr.message, { hint: recErr.hint ?? null }));
      continue;
    }
    issues.push({ id, ok: true, resource_id: rec?.resource_id ?? null, access_scope: rec?.access_scope ?? g.destination.access_scope,
      bucket, path: chemin, bytes: lu, sha256 });
  }

  const versés = issues.filter((x) => x.ok).length;
  const premier = issues.find((x) => !x.ok);
  // Un appel d'UN candidat garde le contrat simple : son refus est la réponse.
  if (ids.length === 1 && premier) {
    const { id: _id, ok: _ok, code, error, ...extra } = premier;
    return refus(code || 'server_error', error || 'Refus.', code === 'candidate_not_found' ? 404 : code === 'forbidden' ? 403 : 409, extra);
  }
  return json({ ok: true, deposited: versés, failed: issues.length - versés, results: issues, remaining,
    resource_id: ids.length === 1 ? issues[0]?.resource_id ?? null : undefined,
    access_scope: ids.length === 1 ? issues[0]?.access_scope : undefined });
});
