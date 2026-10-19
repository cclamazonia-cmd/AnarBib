// Edge Function : realign-digital-resource (NUMDIF, 19/10/2026, REGISTRE §47 NUMDIF-2 et NUMDIF-4).
// Session : Anarchief — ouvrir le lot Overige.
//
// Met une ressource PDF DÉJÀ versée par la file NUMDIF au seau que fixe
// aujourd'hui le cas de son candidat. Premier usage : le lot « Overige
// bestanden » d'Anarchief.org, passé de statut_inconnu à diffusion_autorisee
// après le mail de l'archiviste du 19/10 (migration
// 20261019145347_numdif_overige_a_b_et_realignement) — 156 PDF de pdf-restrito
// (privé) vers anarbib-pdf-public. L'autre sens (retrait à première demande :
// cas repassé en statut_inconnu) prend le même chemin.
//
// Appelée par la coordination de la bibliothèque détentrice ou par
// l'administration du réseau, avec son jeton (double authentification). Le
// corps porte `resource_ids` (ou un seul `resource_id`) ; les ressources passent
// une par une, la fonction s'arrête AVANT d'en commencer une nouvelle quand son
// budget de temps est dépensé et rend `remaining`. Une ressource déjà au bon
// seau répond « aligned » sans rien toucher : relancer un lot ne refait rien.
//
// Pour chaque ressource :
//   1. GARDE sous le jeton (fn_digital_resource_realign_garde) : ressource
//      active issue d'un candidat versé, portée de l'appelant, bibliothèque
//      encore détentrice ; seau et chemin actuels, SHA-256, destination ;
//   2. lecture du fichier EN PLACE et SHA-256 (avant) : il doit être celui qui
//      a été validé et versé ;
//   3. COPIE côté serveur vers le seau du cas, au MÊME chemin ;
//   4. lecture de la COPIE et SHA-256 (après) : différente → la copie est
//      effacée, rien n'a bougé ;
//   5. enregistrement à la clé de service (ingest.fn_digital_resource_realign_record),
//      qui revérifie tout et met la ressource au cas ; refus → la copie est
//      effacée ;
//   6. effacement de l'original. S'il échoue, la ressource est déjà juste et
//      l'ancien objet est rendu dans `orphan` (à retirer, aucune ressource ne
//      le désigne).
// La ressource désigne donc toujours un objet présent, et sa portée ne
// contredit jamais son seau. Empreintes natives (node:crypto) : en JavaScript
// pur, un appel meurt à 2 s de CPU vers 45-50 Mo (voir
// deposit-digital-candidate/empreintes.ts).

import { createHash } from 'node:crypto';
import { secretKey } from '../_shared/core/secret-key.ts';
import { createClient } from '../_shared/deps.ts';
import { doubleFacteurManquant } from '../_shared/core/double-facteur.ts';

const MAX_OCTETS = 150 * 1024 * 1024;        // deux lectures + deux empreintes par fichier : marge de CPU d'un appel
const MAX_PAR_APPEL = 10;
const BUDGET_MS = 100_000;                    // on ne commence plus de ressource au-delà

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

type Issue = { id: number; ok: boolean; code?: string; error?: string; hint?: string | null; [k: string]: unknown };
const echec = (id: number, code: string, error: string, extra: Record<string, unknown> = {}): Issue =>
  ({ id, ok: false, code, error, ...extra });

// SHA-256 d'un objet du stockage, morceau par morceau
async function empreinte(service: any, bucket: string, chemin: string): Promise<{ sha256: string; octets: number } | { erreur: string }> {
  const { data, error } = await service.storage.from(bucket).download(chemin);
  if (error || !data) return { erreur: error?.message || 'objet illisible' };
  const h = createHash('sha256');
  let octets = 0;
  const lecteur = (data as Blob).stream().getReader();
  for (;;) {
    const { done, value } = await lecteur.read();
    if (done) break;
    octets += value.byteLength;
    h.update(value);
  }
  return { sha256: h.digest('hex'), octets };
}

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
  const brut = Array.isArray(body?.resource_ids) ? body.resource_ids : (body?.resource_id != null ? [body.resource_id] : []);
  const ids = [...new Set(brut.map(Number))].filter((n) => Number.isInteger(n) && n > 0) as number[];
  if (!ids.length) return refus('bad_request', 'resource_ids requis.', 400);
  if (ids.length > MAX_PAR_APPEL) return refus('bad_request', `Au plus ${MAX_PAR_APPEL} ressources par appel.`, 400);

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
    const { data: g, error: gardeErr } = await userClient.rpc('fn_digital_resource_realign_garde', { p_resource_id: id });
    if (gardeErr || !g || !g.sha256 || !g.from?.bucket || !g.from?.path || !g.destination?.storage_bucket) {
      issues.push(echec(id, 'forbidden', gardeErr?.message || 'Accès refusé.', { hint: gardeErr?.hint ?? null }));
      continue;
    }
    if (g.aligned) { issues.push({ id, ok: true, aligned: true, bucket: g.from.bucket, path: g.from.path }); continue; }

    if (!service) service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const de: string = g.from.bucket;
    const vers: string = g.destination.storage_bucket;
    const chemin: string = g.from.path;

    // 2. le fichier en place est celui qui a été versé (empreinte AVANT)
    const avant = await empreinte(service, de, chemin);
    if ('erreur' in avant) { issues.push(echec(id, 'server_error', `Lecture de ${de}/${chemin} échouée : ${avant.erreur}`)); continue; }
    if (avant.octets > MAX_OCTETS) { issues.push(echec(id, 'file_too_large', 'Fichier trop lourd pour un appel.', { bytes: avant.octets, max: MAX_OCTETS })); continue; }
    if (avant.sha256 !== g.sha256) {
      issues.push(echec(id, 'fingerprint_mismatch', 'Le fichier en place n\'est pas celui qui a été versé.',
        { algorithm: 'SHA-256', expected: g.sha256, actual: avant.sha256, moment: 'avant' }));
      continue;
    }

    // 3. la copie côté serveur, au même chemin (même seau : la portée seule change, rien à copier)
    let copieFaite = false;
    if (vers !== de) {
      const { error: cpErr } = await service.storage.from(de).copy(chemin, chemin, { destinationBucket: vers });
      if (cpErr) {
        // une copie laissée par un appel interrompu se reprend si c'est le même fichier ; sinon on n'y touche pas
        const deja = await empreinte(service, vers, chemin);
        if ('erreur' in deja || deja.sha256 !== g.sha256) {
          issues.push(echec(id, 'server_error', `Copie vers ${vers} échouée : ${cpErr.message}`));
          continue;
        }
      } else {
        copieFaite = true;
      }
    }
    const effacerCopie = async () => {
      if (copieFaite) { try { await service!.storage.from(vers).remove([chemin]); } catch (_) { /* best-effort */ } }
    };

    // 4. la copie est le même fichier (empreinte APRÈS)
    const apres = await empreinte(service, vers, chemin);
    if ('erreur' in apres || apres.sha256 !== g.sha256) {
      await effacerCopie();
      issues.push(echec(id, 'fingerprint_mismatch', 'La copie n\'est pas identique au fichier versé.',
        { algorithm: 'SHA-256', expected: g.sha256, actual: 'erreur' in apres ? null : apres.sha256, moment: 'apres' }));
      continue;
    }

    // 5. l'enregistrement, qui revérifie tout et met la ressource au cas
    const { data: rec, error: recErr } = await service.schema('ingest').rpc('fn_digital_resource_realign_record', {
      p_resource_id: id, p_uid: g.caller, p_from_bucket: de, p_from_path: chemin, p_bucket: vers, p_path: chemin, p_sha256: apres.sha256,
    });
    if (recErr) {
      await effacerCopie();
      issues.push(echec(id, 'deposit_refused', recErr.message, { hint: recErr.hint ?? null }));
      continue;
    }

    // 6. l'original s'efface ; un échec ne laisse qu'un objet que plus rien ne désigne
    let orphan: { bucket: string; path: string } | null = null;
    if (vers !== de) {
      const { error: rmErr } = await service.storage.from(de).remove([chemin]);
      if (rmErr) orphan = { bucket: de, path: chemin };
    }
    issues.push({ id, ok: true, aligned: false, from: de, bucket: vers, path: chemin, bytes: apres.octets,
      sha256_avant: avant.sha256, sha256_apres: apres.sha256, access_scope: rec?.access_scope ?? g.destination.access_scope, orphan });
  }

  const faits = issues.filter((x) => x.ok).length;
  const premier = issues.find((x) => !x.ok);
  // Un appel d'UNE ressource garde le contrat simple : son refus est la réponse.
  if (ids.length === 1 && premier) {
    const { id: _id, ok: _ok, code, error, ...extra } = premier;
    return refus(code || 'server_error', error || 'Refus.', code === 'forbidden' ? 403 : 409, extra);
  }
  return json({ ok: true, realigned: faits, failed: issues.length - faits, results: issues, remaining });
});
