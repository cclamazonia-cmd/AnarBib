// =========================================================================
// harvest-oai-pmh — Lot 3b : le moissonnage OAI-PMH ramene vraiment des notices
// =========================================================================
// Appelee en server-to-server par public.fn_import_harvest_oai (pg_net), avec
// l'auth interne x-import-secret (ANARBIB_PARTNER_IMPORT_SECRET) — le meme
// secret et le meme en-tete que process-partner-catalog-import et
// receive-fonds-bundle : c'est la meme famille, l'import de catalogue
// partenaire, et un secret de plus serait un secret de plus a perdre.
//
// CE QU'ELLE FAIT
//   1. negocie le prefixe de metadonnees (ListMetadataFormats) si celui
//      demande n'est pas servi — c'est ce que le commentaire de la colonne
//      oai_metadata_prefix appelle depuis toujours « auto-negocie par l'EF » ;
//   2. moissonne au plus `lots_per_cycle` lots (ListRecords + resumptionToken) ;
//   3. depose les notices en staging_rows, les fait rapprocher du catalogue par
//      ingest.fn_match_partner_catalog_run, rafraichit les compteurs du run ;
//   4. RELACHE LE VERROU dans tous les cas.
//
// LE POINT QUI COMPTE PLUS QUE LE RESTE : LE VERROU
//   fn_import_harvest_oai pose oai_harvest_state.harvest_status = 'in_progress'
//   avant d'appeler cette fonction, et refuse tout nouveau moissonnage tant
//   qu'il tient. Jusqu'au 28/08/2026 cette EF n'existait pas : le verrou ne se
//   relachait jamais, donc le moissonnage marchait UNE fois par source puis
//   plus jamais. Tout chemin de sortie d'ici — succes, erreur OAI, exception,
//   entrepot injoignable — DOIT donc reposer harvest_status sur un etat
//   relachable. C'est fait dans un `finally`, pas dans les branches : une
//   branche s'oublie, un finally non.
//
//   Le verrou garde quand meme un trou que cette EF ne peut pas boucher : si
//   elle n'est jamais atteinte (pg_net en panne, demarrage a froid trop long),
//   personne n'ecrit ce finally. C'est repris cote SQL par la reprise de verrou
//   perime (voir la migration du meme paquet), sur le modele de unlock_stale
//   des sauvegardes.
// =========================================================================
import { secretKey } from '../_shared/core/secret-key.ts';
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from '../_shared/deps.ts';
import { parseMarcXml, buildParsedEntriesFromMarc, MARC_PARSER_VERSION } from '../process-partner-catalog-import/marc.ts';
import {
  OAI_PARSER_VERSION, parseOaiEnvelope, parseMetadataFormats, chooseMetadataPrefix,
  isMarcPrefix, buildOaiUrl, mapDublinCore, hasBibliographicContent,
} from './oai.ts';

const IMPORT_SECRET_HEADER = 'x-import-secret';
const IMPORT_SECRET_ENV = 'ANARBIB_PARTNER_IMPORT_SECRET';
const INSERT_BATCH_SIZE = 250;
const HTTP_TIMEOUT_MS = 20000;  // par requete ; pg_net coupe le tout a 120 s
// Pause entre deux lots. Un entrepot OAI-PMH est fait pour etre moissonne, mais
// enchainer les requetes sans respirer sur le serveur de quelqu'un d'autre n'est
// pas une facon de se presenter. 1 s ne coute rien a un cycle (5 lots = 5 s de
// plus) et change tout vu d'en face.
const INTER_LOT_PAUSE_MS = 1000;
// Plafond de ce qu'on accepte d'attendre quand l'entrepot nous demande de
// patienter. Au-dela on rend la main : le jeton de reprise est deja ecrit, le
// cycle suivant repartira d'ou celui-ci s'arrete.
const MAX_RETRY_AFTER_MS = 30000;
// Contact fedéral dans le User-Agent : convention OAI-PMH (notre propre provider
// publie <adminEmail> pour la meme raison). Une admin d'en face doit pouvoir
// ecrire a quelqu'un plutot que de bloquer une IP muette.
const HARVESTER_CONTACT = (Deno.env.get('OAI_ADMIN_EMAIL') || 'fede@anarbib.org').trim();
const USER_AGENT = `AnarBib-OAI-Harvester/1.0 (+${HARVESTER_CONTACT})`;
// Garde-fou : un entrepot qui rendrait un jeton sans fin. Cale sous le budget
// pg_net (20 lots x 20 s = 400 s > 120 s : c est pg_net qui tranchera avant, et
// le resumptionToken deja ecrit fera repartir le cycle suivant d ou il en est).
const MAX_LOTS_HARD_CAP = 20;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-import-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), { status, headers: corsHeaders });
}

function clean(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const t = String(v).trim();
  return t === '' ? null : t;
}

const dors = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Levee quand l'entrepot demande explicitement qu'on lève le pied. */
class BackOff extends Error {
  constructor(public readonly afterMs: number, public readonly status: number) {
    super(`L'entrepot demande d'attendre (HTTP ${status}, Retry-After ${Math.round(afterMs / 1000)} s).`);
  }
}

// Retry-After s'ecrit en secondes OU en date HTTP : les deux formes existent
// dans la nature, et n'en lire qu'une revient a ne pas la lire.
function retryAfterMs(header: string | null): number | null {
  const raw = (header ?? '').trim();
  if (!raw) return null;
  if (/^\d+$/.test(raw)) return Number(raw) * 1000;
  const when = Date.parse(raw);
  if (Number.isNaN(when)) return null;
  return Math.max(0, when - Date.now());
}

async function fetchOai(url: string): Promise<string> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), HTTP_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { 'Accept': 'text/xml, application/xml', 'User-Agent': USER_AGENT },
      signal: ctrl.signal,
    });
    // 503 et 429 sont la facon NORMALE dont un serveur OAI-PMH dit « pas
    // maintenant » — souvent pendant qu'il prepare un gros lot. Les traiter
    // comme une panne, c'est repasser la semaine suivante taper au meme
    // endroit ; les honorer, c'est attendre le delai annonce et reessayer une
    // fois. Au-dela du plafond on abandonne PROPREMENT le cycle : le jeton de
    // reprise est deja en base, rien n'est perdu.
    if (res.status === 503 || res.status === 429) {
      const wait = retryAfterMs(res.headers.get('retry-after'));
      if (wait !== null && wait <= MAX_RETRY_AFTER_MS) {
        await dors(wait);
        const retry = await fetch(url, {
          method: 'GET',
          headers: { 'Accept': 'text/xml, application/xml', 'User-Agent': USER_AGENT },
          signal: ctrl.signal,
        });
        const retryText = await retry.text();
        if (!retry.ok) throw new BackOff(wait, retry.status);
        return retryText;
      }
      throw new BackOff(wait ?? 0, res.status);
    }
    const text = await res.text();
    // Un entrepot peut repondre 200 avec une <error> OAI (protocole), ou un vrai
    // code HTTP (transport). On ne confond pas les deux : ici c'est le transport.
    if (!res.ok) throw new Error(`HTTP ${res.status} de l'entrepot (${text.slice(0, 200)})`);
    return text;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed. Use POST.' }, 405);

  const expectedSecret = Deno.env.get(IMPORT_SECRET_ENV);
  if (!expectedSecret) return json({ error: `Missing secret ${IMPORT_SECRET_ENV}` }, 500);
  const providedSecret = req.headers.get(IMPORT_SECRET_HEADER);
  if (!providedSecret || providedSecret !== expectedSecret) return json({ error: 'Unauthorized' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = secretKey();
  if (!supabaseUrl || !serviceRoleKey) return json({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, 500);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const ingestRpc = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    db: { schema: 'ingest' },
  });

  let runId: number | null = null;
  let sourceId: number | null = null;
  let totalBefore = 0;
  // Ce que le `finally` doit savoir pour relacher le verrou correctement.
  const outcome = {
    settled: false,           // une branche a-t-elle decide de l'etat final ?
    harvestStatus: 'error',
    resumptionToken: null as string | null,
    lots: 0,
    inserted: 0,
    lastError: null as string | null,
    complete: false,
  };

  try {
    const body = await req.json().catch(() => ({}));
    runId = Number((body as Record<string, unknown>)?.run_id);
    if (!Number.isInteger(runId) || runId <= 0) {
      return json({ error: 'Body must contain a positive integer run_id.' }, 400);
    }
    const maxLotsAsked = Number((body as Record<string, unknown>)?.max_lots);

    const { data: run, error: runError } = await admin.schema('ingest')
      .from('partner_catalog_import_runs').select('*').eq('id', runId).maybeSingle();
    if (runError) throw runError;
    if (!run) return json({ error: `Import run ${runId} not found.` }, 404);
    if (run.detected_format !== 'oai_pmh') {
      return json({ error: `Run ${runId} n'est pas un run de moissonnage (detected_format=${run.detected_format}).` }, 400);
    }
    sourceId = Number(run.source_id);

    const { data: source, error: srcError } = await admin.schema('ingest')
      .from('partner_catalog_sources').select('*').eq('id', sourceId).maybeSingle();
    if (srcError) throw srcError;
    if (!source) return json({ error: `Source ${sourceId} introuvable.` }, 404);
    const endpoint = clean(source.oai_endpoint_url);
    if (!endpoint) return json({ error: `Source ${sourceId} n'a pas d'oai_endpoint_url.` }, 400);

    const { data: state, error: stError } = await admin.schema('ingest')
      .from('oai_harvest_state').select('*').eq('source_id', sourceId).maybeSingle();
    if (stError) throw stError;
    if (!state) return json({ error: `Etat de moissonnage introuvable pour source ${sourceId}.` }, 404);
    totalBefore = Number(state.total_records_harvested) || 0;
    // Le jeton DEJA en base devient la valeur par defaut du resultat. Sans ca, le
    // finally reposait null sur tout chemin d'erreur : un incident au milieu d'un
    // cycle EFFACAIT la position de reprise. Les lignes n'etant inserees qu'apres
    // la boucle, repartir du jeton de DEBUT de cycle est exactement juste — ni
    // doublon, ni trou. Le chemin de succes l'ecrase par le jeton final.
    outcome.resumptionToken = clean(state.pending_resumption_token);

    const maxLots = Math.min(
      MAX_LOTS_HARD_CAP,
      Math.max(1, Number.isInteger(maxLotsAsked) && maxLotsAsked > 0 ? maxLotsAsked : (state.lots_per_cycle || 5)),
    );

    await admin.schema('ingest').from('partner_catalog_import_runs').update({
      run_status: 'processing',
      started_at: new Date().toISOString(),
      finished_at: null,
      parser_version: OAI_PARSER_VERSION,
    }).eq('id', runId);

    // ── 1. Premiere requete, puis les deux rattrapages ───────────────────
    let prefix = clean(source.oai_metadata_prefix) ?? 'marcxml';
    let negotiated = false;
    let resumedFromToken = clean(state.pending_resumption_token);

    // `from` : moissonnage incremental, on ne redemande que ce qui a bouge
    // depuis le dernier cycle ABOUTI. Granularite jour (YYYY-MM-DD), la seule
    // que tous les entrepots acceptent — la granularite seconde ne l'est pas.
    const fromDate = () => (state.last_harvest_at ? String(state.last_harvest_at).slice(0, 10) : null);
    const freshListUrl = () => buildOaiUrl(endpoint, {
      verb: 'ListRecords', metadataPrefix: prefix, set: clean(source.oai_set), from: fromDate(),
    });

    let xml = await fetchOai(resumedFromToken
      ? buildOaiUrl(endpoint, { verb: 'ListRecords', resumptionToken: resumedFromToken })
      : freshListUrl());
    let env = parseOaiEnvelope(xml);

    // Rattrapage 1 — jeton perime. Les jetons OAI ont une duree de vie, et un
    // cycle interrompu peut revenir des jours plus tard. Sans ce rattrapage la
    // source resterait bloquee sur un jeton mort jusqu'a ce que quelqu'un le
    // vide a la main en base : un cul-de-sac de plus, pour rien.
    if (env.errorCode === 'badResumptionToken' && resumedFromToken) {
      resumedFromToken = null;
      xml = await fetchOai(freshListUrl());
      env = parseOaiEnvelope(xml);
    }

    // Rattrapage 2 — prefixe non servi. On ne demande ListMetadataFormats que
    // si le prefixe voulu se fait refuser : un aller-retour de moins sur le cas
    // courant, et le choix de la coordination est respecte tant qu'il tient.
    if (env.errorCode === 'cannotDisseminateFormat') {
      const available = parseMetadataFormats(await fetchOai(buildOaiUrl(endpoint, { verb: 'ListMetadataFormats' })));
      const chosen = chooseMetadataPrefix(prefix, available);
      if (!chosen || chosen === prefix) {
        throw new Error(`L'entrepot ne sert pas ${prefix} et n'offre rien d'utilisable (${available.join(', ') || 'aucun format annonce'}).`);
      }
      prefix = chosen;
      negotiated = true;
      // Un jeton est lie au prefixe qui l'a produit : changer de prefixe le
      // perime, on repart de la tete de liste.
      resumedFromToken = null;
      xml = await fetchOai(freshListUrl());
      env = parseOaiEnvelope(xml);
      // Le prefixe negocie devient celui de la source : la negociation ne se
      // rejoue pas a chaque cycle, et l'ecran montre ce qui est vraiment servi.
      await admin.schema('ingest').from('partner_catalog_sources')
        .update({ oai_metadata_prefix: prefix, updated_at: new Date().toISOString() }).eq('id', sourceId);
    }

    // ── 2. Boucle des lots ───────────────────────────────────────────────
    // On repart de row_no et des cles deja vues : un jeton rejoue (reprise
    // apres incident) ne doit pas dupliquer des notices dans le meme run.
    const { data: existingRows } = await admin.schema('ingest')
      .from('partner_catalog_staging_rows').select('row_no, external_key').eq('run_id', runId);
    let rowNo = (existingRows ?? []).reduce((mx: number, r: { row_no: number }) => Math.max(mx, r.row_no || 0), 0);
    const seenKeys = new Set<string>(
      ((existingRows ?? []).map((r: { external_key: string | null }) => r.external_key)
        .filter(Boolean)) as string[],
    );

    let token: string | null = null;
    let lots = 0;
    let deletedSkipped = 0;
    let emptySkipped = 0;
    let duplicateSkipped = 0;
    let completeListSize: number | null = null;
    const staging: Record<string, unknown>[] = [];

    for (;;) {
      if (env.errorCode) {
        // noRecordsMatch n'est PAS une panne : c'est « rien de neuf depuis la
        // derniere fois », la reponse normale d'un moissonnage incremental.
        if (env.errorCode === 'noRecordsMatch') { token = null; break; }
        throw new Error(`Erreur OAI-PMH ${env.errorCode} : ${env.errorMessage ?? 'sans message'}`);
      }
      lots += 1;
      if (completeListSize === null) completeListSize = env.completeListSize;

      for (const rec of env.records) {
        if (rec.deleted) { deletedSkipped += 1; continue; }
        if (!rec.metadata) { emptySkipped += 1; continue; }

        let mapped: Record<string, unknown>;
        let rawPayload: Record<string, unknown>;
        let parserVersion = OAI_PARSER_VERSION;
        const oaiHeader = { identifier: rec.identifier, datestamp: rec.datestamp, sets: rec.setSpecs, prefix };

        if (isMarcPrefix(prefix)) {
          // On reutilise le parseur MARC de l'import de fichiers : meme dialecte
          // detecte, meme mapping — donc une notice moissonnee et la MEME notice
          // televersee en fichier produisent la meme ligne de revision.
          const marcRecords = parseMarcXml(rec.metadata);
          if (!marcRecords.length) { emptySkipped += 1; continue; }
          const entry = buildParsedEntriesFromMarc(marcRecords, [], null)[0];
          mapped = entry.mapped;
          rawPayload = { oai: oaiHeader, ...entry.rawPayload };
          parserVersion = MARC_PARSER_VERSION;
        } else {
          mapped = mapDublinCore(rec.metadata) as unknown as Record<string, unknown>;
          rawPayload = { oai: oaiHeader, dc_xml: rec.metadata };
        }

        if (!hasBibliographicContent(mapped)) { emptySkipped += 1; continue; }

        // L'identifiant OAI de l'en-tete prime sur la zone de controle MARC :
        // c'est LUI qui est stable d'un moissonnage a l'autre, et c'est sur lui
        // que porte la dedup ci-dessous.
        const externalKey = clean(rec.identifier) ?? clean(mapped.externalKey as string);
        if (externalKey && seenKeys.has(externalKey)) { duplicateSkipped += 1; continue; }
        if (externalKey) seenKeys.add(externalKey);

        rowNo += 1;
        const norm = {
          title: mapped.title ?? null,
          subtitle: mapped.subtitle ?? null,
          responsibility_statement: mapped.responsibilityStatement ?? null,
          authors: mapped.authorsArray ?? [],
          publisher: mapped.publisher ?? null,
          place_of_publication: mapped.placeOfPublication ?? null,
          publication_year: mapped.publicationYear ?? null,
          edition_statement: mapped.editionStatement ?? null,
          language: mapped.language ?? null,
          isbn: mapped.isbn ?? null,
          issn: mapped.issn ?? null,
          subjects: mapped.subjectsArray ?? [],
          item_type: mapped.itemType ?? null,
          external_key: externalKey,
        };
        staging.push({
          run_id: runId,
          source_file_id: null,
          row_no: rowNo,
          external_key: externalKey,
          item_type: norm.item_type,
          title: norm.title,
          subtitle: norm.subtitle,
          responsibility_statement: norm.responsibility_statement,
          authors: norm.authors,
          publisher: norm.publisher,
          place_of_publication: norm.place_of_publication,
          publication_year: norm.publication_year,
          edition_statement: norm.edition_statement,
          language: norm.language,
          isbn: norm.isbn,
          issn: norm.issn,
          subjects: norm.subjects,
          raw_payload: rawPayload,
          normalized_payload: {
            ...norm,
            notes: (mapped as { notes?: string | null }).notes ?? null,
            parser_version: parserVersion,
            oai_metadata_prefix: prefix,
            oai_datestamp: rec.datestamp,
          },
          parse_status: 'parsed',
          // Etat neutre du vocabulaire : c'est fn_match_partner_catalog_run,
          // appele plus bas, qui ecrit le vrai statut. Ecrire 'new_record' ici
          // affirmerait sans verifier qu'il n'y a pas de doublon — et
          // l'assistant promeut automatiquement les 'new_record'.
          match_status: 'unreviewed',
          review_status: 'pending',
          confidence: 0,
          warnings: [],
          editorial_decision: 'pending',
          selected_for_draft: false,
        });
      }

      token = env.resumptionToken;
      if (!token || lots >= maxLots) break;
      await dors(INTER_LOT_PAUSE_MS);
      env = parseOaiEnvelope(await fetchOai(buildOaiUrl(endpoint, { verb: 'ListRecords', resumptionToken: token })));
    }

    // ── 3. Ecriture ──────────────────────────────────────────────────────
    for (let i = 0; i < staging.length; i += INSERT_BATCH_SIZE) {
      const { error } = await admin.schema('ingest')
        .from('partner_catalog_staging_rows').insert(staging.slice(i, i + INSERT_BATCH_SIZE));
      if (error) throw error;
    }

    let matchingResult: unknown = null;
    let counterResult: unknown = null;
    if (staging.length) {
      const { data: mres, error: merr } = await ingestRpc.rpc('fn_match_partner_catalog_run', { p_run_id: runId, p_row_ids: null });
      if (merr) throw merr;
      matchingResult = mres;
      const { data: cres, error: cerr } = await ingestRpc.rpc('fn_refresh_partner_catalog_run_counters', { p_run_id: runId });
      if (cerr) throw cerr;
      counterResult = cres;
    }

    const complete = !token;
    const finishedAt = new Date().toISOString();
    const summary = {
      parser: OAI_PARSER_VERSION,
      oai_metadata_prefix: prefix,
      prefix_negotiated: negotiated,
      resumed_from_token: !!resumedFromToken,
      endpoint,
      set: clean(source.oai_set),
      lots_harvested: lots,
      inserted_rows: staging.length,
      deleted_skipped: deletedSkipped,
      empty_skipped: emptySkipped,
      duplicate_skipped: duplicateSkipped,
      complete_list_size: completeListSize,
      harvest_complete: complete,
      resumption_token_pending: !complete,
      matched_at: finishedAt,
      matching_result: matchingResult,
      counter_refresh_result: counterResult,
    };

    await admin.schema('ingest').from('partner_catalog_import_runs').update({
      // fn_refresh_partner_catalog_run_counters a deja pu poser
      // 'ready_for_review' quand il y a des lignes ; on l'ecrit aussi pour le
      // cas 0 ligne, ou il n'a pas ete appele. Un moissonnage sans nouveaute
      // n'est pas un echec : c'est un run vide, revu en un coup d'oeil.
      run_status: 'ready_for_review',
      imported_rows: staging.length,
      parser_version: OAI_PARSER_VERSION,
      summary,
      finished_at: finishedAt,
    }).eq('id', runId);

    outcome.settled = true;
    // 'paused' quand il reste un jeton (le cycle a rendu la main sans avoir tout
    // vu), 'completed' quand la liste est epuisee. Les deux relachent le verrou :
    // fn_import_harvest_oai ne refuse que 'in_progress'.
    outcome.harvestStatus = complete ? 'completed' : 'paused';
    outcome.resumptionToken = token;
    outcome.lots = lots;
    outcome.inserted = staging.length;
    outcome.complete = complete;

    return json({ ok: true, run_id: runId, source_id: sourceId, ...summary });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    outcome.settled = true;
    // Un back-off demande par l'entrepot n'est PAS une panne de notre cote : le
    // marquer 'error' ferait croire a une source cassee et, pire, ferait perdre
    // le jeton de reprise. On repose l'etat sur 'paused' — relachable, reprenable
    // au cycle suivant — en gardant le message pour que ca se lise a l'ecran.
    outcome.harvestStatus = err instanceof BackOff ? 'paused' : 'error';
    outcome.lastError = message.slice(0, 2000);
    if (runId) {
      try {
        const { data: run } = await admin.schema('ingest')
          .from('partner_catalog_import_runs').select('error_log').eq('id', runId).maybeSingle();
        const log = Array.isArray(run?.error_log) ? run.error_log : [];
        log.push({ at: new Date().toISOString(), parser: OAI_PARSER_VERSION, message });
        await admin.schema('ingest').from('partner_catalog_import_runs').update({
          run_status: 'failed', error_log: log, finished_at: new Date().toISOString(),
        }).eq('id', runId);
      } catch { /* le verrou passe avant le journal : ne pas masquer l'erreur d'origine */ }
    }
    return json({ ok: false, run_id: runId, error: message }, 500);
  } finally {
    // LE RELACHEMENT DU VERROU. Dans un finally et pas dans les branches : c'est
    // la seule ecriture dont l'oubli rend la source inmoissonnable POUR TOUJOURS,
    // et une branche s'oublie. `settled` reste faux si on est sorti avant d'avoir
    // rien decide (run introuvable, run non-OAI, source sans endpoint) : on n'a
    // pose aucun verrou nous-meme, mais fn_import_harvest_oai, si — on le
    // relache donc des lors qu'on connait la source.
    if (sourceId) {
      const patch: Record<string, unknown> = {
        harvest_status: outcome.settled ? outcome.harvestStatus : 'error',
        pending_resumption_token: outcome.resumptionToken,
        lots_completed_this_cycle: outcome.lots,
        last_error: outcome.lastError ?? (outcome.settled ? null : 'EF interrompue avant traitement.'),
        total_records_harvested: totalBefore + outcome.inserted,
      };
      // last_harvest_at n'avance QUE sur un cycle abouti : l'avancer sur un cycle
      // partiel ferait sauter, au prochain from=, tout ce que le jeton n'a pas
      // encore rendu — des notices perdues sans que rien ne le signale.
      if (outcome.complete) patch.last_harvest_at = new Date().toISOString();
      try {
        await admin.schema('ingest').from('oai_harvest_state').update(patch).eq('source_id', sourceId);
      } catch { /* la reprise de verrou perime, cote SQL, couvre ce dernier cas */ }
    }
  }
});
