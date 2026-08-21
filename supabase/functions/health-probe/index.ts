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

  const charge = await req.json().catch(() => ({}));

  let resultats = await Promise.all(sondes(unLivre?.id ?? null).map(mesurer));

  // `force_fail` : force le tour en échec, pour ÉPROUVER LA CHAÎNE D'ALERTE.
  // Une alarme jamais déclenchée n'est pas une alarme : sans ça, on ne découvre
  // qu'un e-mail se perd (adresse périmée, refus du fournisseur, secret tourné)
  // que le jour où ça compte. À lancer deux fois de suite pour ouvrir un
  // incident, puis une fois sans le drapeau pour le refermer.
  // Protégé par le secret webhook comme le reste : vérifié plus haut.
  if (charge?.force_fail === true) {
    resultats = resultats.map((r) => ({
      ...r,
      ok: false,
      error: 'TEST force_fail — échec simulé, le service va bien',
    }));
  }

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

  // `kind` (migration 20260820100000) : sans ce filtre, un tour vert du service
  // public refermerait un incident de SAUVEGARDE et enverrait un « service
  // rétabli » qui ne voudrait rien dire. Les deux familles sont disjointes.
  const { data: incidentOuvert } = await supabaseAdmin
    .from('service_health_incidents')
    .select('id, opened_at, reason')
    .eq('kind', 'service')
    .is('closed_at', null)
    .order('opened_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let action = 'rien';

  if (!tourOk && deuxMauvais && !incidentOuvert) {
    const { data: inc, error: errIncService } = await supabaseAdmin
      .from('service_health_incidents')
      .insert({ kind: 'service', reason: raison || 'degradation' })
      .select('id')
      .single();
    // Ne PAS alerter si l'incident n'a pas pu etre enregistre. Sans trace en
    // base, la condition d'ouverture redeviendrait vraie au tour suivant et le
    // courriel repartirait A CHAQUE TOUR — le mecanisme cense n'alerter qu'une
    // fois par incident se retourne alors en boucle. Un systeme d'alerte qui
    // peut inonder detruit sa propre credibilite : on filtre l'expediteur, et
    // le jour ou l'alerte compte, personne ne la voit.
    if (errIncService || !inc) {
      action =
        `incident service NON enregistre (${errIncService?.message ?? 'raison inconnue'}) — alerte retenue`;
    } else {
      const estUnTest = charge?.force_fail === true;
      const n = await alerter(
        estUnTest
          ? '[TEST] AnarBib — vérification de la chaîne d’alerte'
          : 'AnarBib — le service public est dégradé',
        estUnTest ? 'Ceci est un test de la chaîne d’alerte' : 'Le service public est dégradé',
        (estUnTest
          ? `<p style="margin:0 0 10px"><strong>Message de test.</strong> Le service fonctionne normalement ; cet envoi sert uniquement à vérifier que les alertes arrivent bien. Aucune action n'est requise.</p>`
          : '') +
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
        .eq('id', inc.id);
      action = `incident ouvert, ${n} destinataire(s) alerté(s)`;
    }
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

  // ─── Témoin de vie des sauvegardes (#BG2-16) ──────────────────────────────
  // Les trois timers restic tournent sur un poste de travail : ils ne tirent que
  // machine allumée. La chaîne `OnFailure=` de systemd détecte les ERREURS, pas
  // les SILENCES — c'est l'angle mort nommé au §7.5 du runbook de restauration.
  // On le comble ici : le poste PRODUIT les sauvegardes, Supabase CONSTATE leur
  // absence. L'observateur est ailleurs que l'observé.
  //
  // Un seul tour suffit à alerter, contrairement aux sondes réseau ci-dessus :
  // un silence de 36 heures n'est pas un hoquet.
  let actionBackup = 'rien';
  let backupOk: boolean | null = null;
  const { data: bk } = await supabaseAdmin.rpc('fn_backup_heartbeat_status');
  if (bk && typeof bk === 'object') {
    backupOk = (bk as any).ok === true;
    const flux = ((bk as any).flux ?? []) as any[];
    const muets = flux.filter((f) => f.muet);

    // ─── Un incident par FLUX, et non un seul pour les trois ─────────────
    // Jusqu'au 21/08, la condition d'ouverture était « aucun incident backup
    // ouvert ». Un second flux qui tombait pendant qu'un premier était déjà en
    // défaut ne déclenchait donc RIEN, et le courriel déjà parti ne le
    // mentionnerait jamais : l'anti-répétition, censé éviter deux fois la même
    // alerte, supprimait aussi les alertes DIFFÉRENTES. Chaque flux porte
    // désormais son propre incident, identifié par `subject`, et l'unicité est
    // tenue par la base — index unique partiel, migration 20260821120000.
    const { data: incidentsBackup } = await supabaseAdmin
      .from('service_health_incidents')
      .select('id, subject, opened_at, reason')
      .eq('kind', 'backup')
      .is('closed_at', null);

    const dejaOuverts = new Set((incidentsBackup ?? []).map((i) => i.subject ?? ''));
    const enDefaut = new Set(muets.map((f) => f.flow as string));

    const aOuvrir = muets.filter((f) => !dejaOuverts.has(f.flow));
    const aFermer = (incidentsBackup ?? []).filter(
      (i) => i.subject && !enDefaut.has(i.subject),
    );

    const raisonDe = (f: any) =>
      f.raison ?? `${f.flow} muet depuis ${f.age_heures ?? '?'} h`;

    // Un incident par flux, mais UN SEUL courriel par tour. Le cas le plus
    // fréquent est aussi le plus bénin — poste éteint, les trois flux muets
    // ensemble — et trois courriels pour une seule cause useraient exactement
    // la crédibilité que ce dispositif existe pour protéger. On tient donc la
    // comptabilité flux par flux, et on ne prend la parole qu'une fois.
    //
    // Les insertions sont faites UNE PAR UNE, et non en lot : en lot, un seul
    // doublon — c'est-à-dire un tour concurrent ayant déjà ouvert ce flux —
    // ferait échouer l'enregistrement des autres, et retiendrait leur alerte
    // avec. Le flux dont l'incident n'a pas pu être écrit est laissé de côté :
    // il sera repris au tour suivant.
    const ouvertsCeTour: { flux: any; id: number }[] = [];
    const refuses: string[] = [];
    for (const f of aOuvrir) {
      const { data: inc, error } = await supabaseAdmin
        .from('service_health_incidents')
        .insert({ kind: 'backup', subject: f.flow, reason: raisonDe(f) })
        .select('id')
        .single();
      // Ne PAS alerter sur un flux dont l'incident n'a pas été enregistré :
      // sans trace en base, la condition d'ouverture redeviendrait vraie au
      // tour suivant et le courriel repartirait toutes les cinq minutes.
      if (error || !inc) refuses.push(`${f.flow} (${error?.message ?? 'raison inconnue'})`);
      else ouvertsCeTour.push({ flux: f, id: inc.id });
    }

    if (ouvertsCeTour.length) {
      const nouveaux = ouvertsCeTour.map((o) => o.flux);
      const interrompus = nouveaux.filter((f) => f.interrompu);
      const n = await alerter(
        interrompus.length
          ? 'AnarBib — une sauvegarde a commencé et ne s’est jamais terminée'
          : 'AnarBib — les sauvegardes ne donnent plus signe de vie',
        interrompus.length ? 'Un tir s’est arrêté en route' : 'Les sauvegardes sont muettes',
        `<p style="margin:0 0 10px">${
          interrompus.length
            ? `<strong>Un tir a commencé et ne s'est jamais terminé.</strong> Ce n'est pas un silence : le script a démarré, signalé son départ, puis s'est arrêté en chemin — machine mise en veille, WSL éteint, ou processus tué. Le verrou laissé chez l'hébergeur sera nettoyé tout seul au prochain tir (<code>unlock_stale</code>).`
            : `Un ou plusieurs flux de sauvegarde n'ont pas signalé de tir réussi dans le délai attendu. <strong>Ça ne veut pas dire qu'ils ont échoué : ça veut dire qu'ils n'ont rien dit.</strong> La cause la plus probable est un poste de travail resté éteint, ou une instance WSL qui n'a pas démarré.`
        }</p>
         <p style="margin:0 0 10px">Nouveaux flux en défaut à ce tour : <strong>${esc(
           nouveaux.map((f: any) => f.flow).join(', '),
         )}</strong>.${
          dejaOuverts.size
            ? ` Un incident était déjà ouvert pour : ${esc(
                [...dejaOuverts].filter(Boolean).join(', '),
              )}.`
            : ''
        }</p>
         <p style="margin:0 0 10px">État des trois flux :</p>
         <ul style="margin:0 0 10px;padding-left:18px">${flux
           .map(
             (f) =>
               `<li>${esc(f.flow)} — ${
                 f.muet ? `<strong>${f.interrompu ? 'TIR INTERROMPU' : 'MUET'}</strong>` : 'ok'
               } — ${
                 // `age_heures` est l'âge du dernier témoin d'ARRIVÉE : l'afficher
                 // pour un tir interrompu donnerait le mauvais nombre. La `raison`
                 // porte déjà la durée depuis le DÉPART.
                 f.interrompu
                   ? esc(String(f.raison ?? 'tir commencé, jamais terminé'))
                   : `dernier signal il y a ${esc(String(f.age_heures ?? '?'))} h (seuil ${esc(
                       String(f.seuil_heures ?? '?'),
                     )} h)`
               }</li>`,
           )
           .join('')}</ul>
         <p style="margin:0">Un e-mail de rétablissement suivra dès que ces flux auront signalé un tir réussi. Chaque flux se ferme séparément.</p>`,
      );
      await supabaseAdmin
        .from('service_health_incidents')
        .update({ notified_at: new Date().toISOString() })
        .in(
          'id',
          ouvertsCeTour.map((o) => o.id),
        );
      actionBackup = `${ouvertsCeTour.length} incident(s) sauvegardes ouvert(s) [${nouveaux
        .map((f: any) => f.flow)
        .join(', ')}], ${n} destinataire(s) alerté(s)`;
    }

    // Fermeture : flux par flux également. Un flux revenu se ferme même si un
    // autre reste en défaut — c'est tout l'intérêt de la découpe, et c'est ce
    // que l'incident unique interdisait.
    if (aFermer.length) {
      await supabaseAdmin
        .from('service_health_incidents')
        .update({ closed_at: new Date().toISOString() })
        .in(
          'id',
          aFermer.map((i) => i.id),
        );
      const revenus = aFermer.map((i) => i.subject as string);
      const restants = [...enDefaut];
      const n = await alerter(
        restants.length
          ? 'AnarBib — une sauvegarde a repris, une autre reste en défaut'
          : 'AnarBib — les sauvegardes ont repris',
        restants.length ? 'Rétablissement partiel' : 'Sauvegardes rétablies',
        // NE PAS écrire « les trois flux ont de nouveau signalé un tir réussi » :
        // c'était faux le 20/08, où seul `court` avait tiré — `long` et `storage`
        // restaient tenus par des lignes d'amorçage vieilles de 29 h. Un message
        // de rétablissement ne doit pas affirmer plus que ce qu'il sait.
        `<p style="margin:0 0 10px">Tir réussi de nouveau signalé par : <strong>${esc(
          revenus.join(', '),
        )}</strong>. ${
          restants.length
            ? `<strong>Attention :</strong> ${esc(
                restants.join(', '),
              )} reste en défaut — son incident demeure ouvert.`
            : `Plus aucun flux n'est en défaut.`
        }</p>
         <p style="margin:0 0 10px">État des trois flux :</p>
         <ul style="margin:0 0 10px;padding-left:18px">${flux
           .map(
             (f) =>
               `<li>${esc(f.flow)} — dernier signal il y a ${esc(
                 String(f.age_heures ?? '?'),
               )} h${
                 f.temoin_amorcage
                   ? ' — <strong>ligne d’amorçage, aucun tir réel signalé à ce jour</strong>'
                   : ''
               }</li>`,
           )
           .join('')}</ul>
         <p style="margin:0">Causes relevées à l'ouverture : ${esc(
           aFermer.map((i) => i.reason).join(' ; '),
         )}</p>`,
      );
      actionBackup = `${actionBackup === 'rien' ? '' : actionBackup + ' ; '}${
        aFermer.length
      } incident(s) clos [${revenus.join(', ')}], ${n} destinataire(s) prévenu(s)`;
    }

    if (refuses.length) {
      actionBackup = `${
        actionBackup === 'rien' ? '' : actionBackup + ' ; '
      }incident NON enregistré pour ${refuses.join(', ')} — alerte retenue`;
    }
  }

  // ─── Sondes STRUCTURELLES (cohérence interne) ────────────────────────
  // Deux fonctions de contrôle existaient depuis le 17/08 et le 21/08 sans que
  // RIEN ne les lise — ni cron, ni edge function, ni écran. Elles répondaient
  // dans le vide. C'est la panne muette qu'elles étaient censées prévenir,
  // reproduite sur elles-mêmes.
  //
  // Différence de nature avec les sondes ci-dessus : celles-ci n'observent pas
  // un service extérieur mais la cohérence de la base. Elles sont donc
  // DÉTERMINISTES — pas de hoquet réseau possible, un seul tour suffit à
  // alerter, comme pour le témoin de sauvegarde.
  //
  // Chaque sonde porte son propre `kind` : un incident de notifications ne doit
  // pas être tenu ouvert par un défaut de ressources numériques. Ces valeurs
  // sont contraintes côté base (migration 20260821060000) : en ajouter une ici
  // sans élargir la CHECK ferait échouer l'insertion en silence, donc partir une
  // alerte à CHAQUE tour.
  const sondesStructurelles: {
    kind: string;
    rpc: string;
    sujetOuvert: string;
    titreOuvert: string;
    quoi: string;
  }[] = [
    {
      kind: 'notifications',
      rpc: 'fn_healthcheck_notifications',
      sujetOuvert: 'AnarBib — un flux de notifications est cassé',
      titreOuvert: 'Notifications : incohérence détectée',
      quoi: 'les notifications',
    },
    {
      kind: 'ressources_numeriques',
      rpc: 'fn_healthcheck_digital_resources',
      sujetOuvert: 'AnarBib — une ressource numérique est devenue illisible',
      titreOuvert: 'Ressources numériques : incohérence détectée',
      quoi: 'les ressources numériques',
    },
  ];

  const actionsStructurelles: Record<string, string> = {};
  const etatsStructurels: Record<string, boolean | null> = {};

  for (const sonde of sondesStructurelles) {
    let action = 'rien';
    let etat: boolean | null = null;

    // Une sonde qui ne répond pas (fonction absente, droits manquants) ne doit
    // ni alerter ni clore : on ne sait rien, on le dit, et on passe.
    const { data: bilan, error: errSonde } = await supabaseAdmin.rpc(sonde.rpc);
    if (errSonde || !bilan || typeof bilan !== 'object') {
      actionsStructurelles[sonde.kind] = errSonde
        ? `sonde injoignable : ${errSonde.message}`
        : 'sonde sans réponse exploitable';
      etatsStructurels[sonde.kind] = null;
      continue;
    }

    etat = (bilan as any).ok === true;

    const { data: inc } = await supabaseAdmin
      .from('service_health_incidents')
      .select('id, opened_at, reason')
      .eq('kind', sonde.kind)
      .is('closed_at', null)
      .order('opened_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!etat && !inc) {
      // Le détail exact vit dans le JSON de la sonde et évolue avec elle. On ne
      // le recopie pas ici : on nomme les rubriques non vides, et on joint le
      // bilan brut. Un message d'alerte qui paraphrase sa source finit toujours
      // par mentir quand la source change.
      const rubriques = Object.entries(bilan as Record<string, unknown>)
        .filter(([k, v]) => k !== 'ok' && k !== 'genere_le' && Array.isArray(v) && v.length > 0)
        .map(([k, v]) => `${k} (${(v as unknown[]).length})`);
      const raison = rubriques.join(' ; ') || 'bilan non ok, sans rubrique renseignée';

      const { data: cree, error: errInsert } = await supabaseAdmin
        .from('service_health_incidents')
        .insert({ kind: sonde.kind, reason: raison })
        .select('id')
        .single();

      // Contrairement au bloc `backup` ci-dessus, on VERIFIE l'insertion. Si elle
      // échoue (CHECK trop étroite, par exemple), n'alerter surtout pas : sans
      // incident enregistré la condition resterait vraie et le courriel repartirait
      // toutes les cinq minutes.
      if (errInsert || !cree) {
        actionsStructurelles[sonde.kind] =
          `incident NON enregistré (${errInsert?.message ?? 'raison inconnue'}) — alerte retenue`;
        etatsStructurels[sonde.kind] = etat;
        continue;
      }

      const n = await alerter(
        sonde.sujetOuvert,
        sonde.titreOuvert,
        `<p style="margin:0 0 10px">Le contrôle automatique de ${esc(sonde.quoi)} signale une incohérence. <strong>Ce n'est pas une panne de service :</strong> le site répond normalement. C'est un état interne qui ne fait pas ce qu'il annonce, et qui ne se verrait autrement pas.</p>
         <p style="margin:0 0 10px">Rubriques concernées : ${esc(raison)}</p>
         <p style="margin:0 0 10px">Bilan complet de la sonde :</p>
         <pre style="margin:0 0 10px;padding:10px;background:#f4f4f4;border-radius:4px;white-space:pre-wrap;font-size:12px">${esc(
           JSON.stringify(bilan, null, 2),
         )}</pre>
         <p style="margin:0">Un e-mail de rétablissement suivra dès que la sonde repassera au vert.</p>`,
      );
      await supabaseAdmin
        .from('service_health_incidents')
        .update({ notified_at: new Date().toISOString() })
        .eq('id', cree.id);
      action = `incident ${sonde.kind} ouvert, ${n} destinataire(s) alerté(s)`;
    } else if (etat && inc) {
      await supabaseAdmin
        .from('service_health_incidents')
        .update({ closed_at: new Date().toISOString() })
        .eq('id', inc.id);
      const depuis = new Date(inc.opened_at).toLocaleString('fr-FR');
      const n = await alerter(
        `AnarBib — ${sonde.quoi} : incohérence résolue`,
        'Cohérence rétablie',
        `<p style="margin:0 0 10px">Le contrôle automatique de ${esc(sonde.quoi)} est repassé au vert. L'incident ouvert le ${esc(depuis)} est clos.</p>
         <p style="margin:0">Cause relevée à l'ouverture : ${esc(inc.reason)}</p>`,
      );
      action = `incident ${sonde.kind} clos, ${n} destinataire(s) prévenu(s)`;
    }

    actionsStructurelles[sonde.kind] = action;
    etatsStructurels[sonde.kind] = etat;
  }

  // Purge de l'historique (evite une table qui grossit sans fin).
  const limite = new Date(Date.now() - RETENTION_JOURS * 86400_000).toISOString();
  await supabaseAdmin.from('service_health_probes').delete().lt('checked_at', limite);

  return jsonResponse(200, {
    ok: true,
    tour_ok: tourOk,
    action,
    resultats,
    sauvegardes_ok: backupOk,
    action_sauvegardes: actionBackup,
    sondes_structurelles: etatsStructurels,
    actions_structurelles: actionsStructurelles,
  });
});
