// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — Une RPC à statut voit son `ok` lu (item B15, doctrine DOC-RPC-4)
//
// CE QUE CE TEST EMPÊCHE DE REVENIR.
//
// Trente-quatre RPC appelées par le front rendent `{ ok, reason, … }` au lieu
// de lever. Relevé le 31/08/2026 : vingt-six appels n'inspectaient pas le
// `ok`, et dix-huit écrivaient `const { error } = await supabase.rpc(...)` —
// la charge utile jetée à la destructuration, le `ok` INATTEIGNABLE. Sur
// `BookPage`, un `ok:false` affichait « consultation demandée » à une lectrice
// dont rien n'avait été créé.
//
// Le contrat de statut est gardé (il permet le traitement ligne par ligne des
// lots) ; ce qui est imposé, c'est de le lire. Un appel est conforme s'il
// appelle `assertRpcOk`, ou s'il inspecte `ok` lui-même.
//
// D'OÙ VIENT `RPC_A_STATUT`, ET CE QU'ELLE NE VOIT PAS.
//
// Une liste en dur dont personne ne connaît la provenance devient fausse en
// silence. Voici donc la requête qui l'a produite, le 31/08/2026 :
//
//   select n.nspname, p.proname
//     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
//    where n.nspname in ('api','public')
//      and pg_get_function_result(p.oid) in ('jsonb','json')
//      and p.prosrc ~* '''ok''';
//
// SON ANGLE MORT, mesuré : la requête ne voit que les fonctions qui
// CONSTRUISENT le statut. Elle manque les FAÇADES, qui le relaient sans le
// contenir — et ce sont elles que le front appelle. `api.renew_my_loan` relaie
// `fn_v2_extend_core` à deux sauts ; `fn_import_dispatch` relaie
// `ingest.fn_dispatch_partner_catalog_import`. Les deux ont été ajoutées à la
// main, et l'une d'elles ne l'aurait jamais été sans une relecture de code.
//
// Corollaire : une entrée ajoutée à la main doit dire POURQUOI la requête ne
// l'a pas trouvée. Une entrée retirée doit dire ce qui a été vérifié en base —
// c'est ainsi qu'`advance_reservation` est sortie (elle rend un `integer` et
// lève : il n'y a aucun `ok` à lire).
//
// LA DETTE EST NOMMÉE, PAS CACHÉE — et elle est vide depuis le 31/08/2026.
// Les quatre sites déclarés ont été repris le jour même, après vérification EN
// BASE de ce que chaque fonction rend réellement. Trois relevaient bien de la
// doctrine ; le quatrième reposait sur un relevé faux (voir plus bas
// `advance_reservation`). La liste ne doit que RÉTRÉCIR : y ajouter une ligne
// demande de le justifier ici.
//
// CE QUE LA REPRISE A CORRIGÉ, ET CE QU'ELLE N'A PAS CORRIGÉ. Sur les deux
// appels d'ImportacoesPage, le défaut était vivant et plus grave que l'énoncé :
// ils ignoraient `error` autant que `ok`, donc un refus (coordenador requis,
// format invalide) laissait l'import partir avec l'adaptateur NON posé. Sur
// AccountPage, `api.create_consulta_local` lève sur refus et ne rend jamais
// `ok:false` : lier la charge utile y est une garde de contrat, pas la
// réparation d'une panne. Dire lequel est lequel fait partie du travail.
// ─────────────────────────────────────────────────────────────────────────────
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

// RPC dont le contrat rend `{ ok, … }` — relevé en base le 31/08/2026 :
// fonctions de `api` et `public` rendant un jsonb dont le corps pose une clé `ok`.
// `advance_reservation` a été RETIRÉE de cette liste le 31/08/2026 : le relevé
// initial la comptait à tort. Vérifié en base, `api.advance_reservation` rend
// un `integer` (le nombre de lignes avancées) et LÈVE sur refus
// (`transition_not_allowed`, `target_stage_has_dedicated_rpc`…) — il n'y a
// aucun `ok` à lire, et le code du Painel qui la lit déjà via `error` est
// correct. L'inscrire ici obligeait à déclarer une dette qui n'existait pas.
const RPC_A_STATUT = new Set([
  'advance_consulta', 'cancel_consulta_as_reader',
  'create_consulta_local', 'dismiss_consulta_cancelled', 'reply_consulta_schedule',
  'renew_my_loan', 'discard_book_cascade', 'freeze_account', 'unfreeze_account',
  'restrict_member', 'unrestrict_member', 'get_member_restriction',
  'generate_my_reader_card', 'revoke_my_reader_card', 'resolve_reader_card',
  'recolement_start', 'recolement_scan', 'recolement_finish', 'recolement_open_sessions',
  'fn_confirm_digital_asset_rights', 'fn_delete_my_account', 'fn_import_archive_run',
  'fn_import_create', 'fn_import_delete_run', 'fn_import_harvest_oai',
  'fn_import_profile_create', 'fn_import_profile_delete', 'fn_import_register_deposit_source',
  'fn_import_set_adapter_overrides', 'fn_import_set_profile', 'fn_partner_register_deposit_source',
  'fn_publish_digital_asset_from_resource', 'fn_restore_deleted_draft',
  'fn_team_promote_to_librarian',
  // Ajoutée le 31/08/2026 : façade à DEUX SAUTS, invisible à la requête
  // ci-dessous. Elle ne construit aucun statut — elle relaie
  // `ingest.fn_dispatch_partner_catalog_import`, qui rend `{ok:true, …}`
  // ou lève. Six refus au total entre les deux niveaux, et l'appel du
  // front n'en attrapait aucun.
  'fn_import_dispatch',
]);

// Dette déclarée : AUCUNE au 31/08/2026. Le dispositif reste — c'est lui qui
// rend le prochain contournement coûteux : y inscrire un site oblige à écrire
// ici pourquoi, sous une ligne qui dit que la liste était vide. Le second test
// refuse par ailleurs une entrée devenue sans objet, pour que la liste ne
// puisse pas rétrécir sur le papier seulement.
const DETTE = new Set([]);

function fichiersSource(dir, acc = []) {
  for (const e of readdirSync(dir)) {
    if (e === 'tests' || e === 'node_modules') continue;
    const p = join(dir, e);
    if (statSync(p).isDirectory()) fichiersSource(p, acc);
    else if (/\.(jsx?|tsx?)$/.test(e)) acc.push(p);
  }
  return acc;
}

describe('Une RPC à statut voit son `ok` lu', () => {
  it('aucun appel ne jette la charge utile en silence', () => {
    const fautifs = [];
    for (const f of fichiersSource('src')) {
      const lignes = readFileSync(f, 'utf8').split('\n');
      lignes.forEach((ligne, i) => {
        const m = /\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]/.exec(ligne);
        if (!m || !RPC_A_STATUT.has(m[1])) return;
        const cle = `${f.replace(/\\/g, '/')}::${m[1]}`;
        if (DETTE.has(cle)) return;
        const fenetre = lignes.slice(Math.max(0, i - 2), i + 20).join('\n');
        const lu = /assertRpcOk\s*\(/.test(fenetre)
          || /\bok\s*(===|!==)/.test(fenetre)
          || /\?\.\s*ok\b/.test(fenetre)
          || /\bdata\s*\.\s*ok\b/.test(fenetre);
        if (!lu) fautifs.push(`${cle} (ligne ${i + 1})`);
      });
    }
    expect(fautifs, `Ces appels ignorent le statut rendu :\n  ${fautifs.join('\n  ')}`).toEqual([]);
  });

  it('la dette déclarée ne contient que des sites qui existent encore', () => {
    const vus = new Set();
    for (const f of fichiersSource('src')) {
      const texte = readFileSync(f, 'utf8');
      for (const m of texte.matchAll(/\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]/g)) {
        vus.add(`${f.replace(/\\/g, '/')}::${m[1]}`);
      }
    }
    // Une entrée de dette qui ne correspond plus à rien est une entrée à retirer :
    // sans ça, la liste ne rétrécirait jamais vraiment.
    const perimees = [...DETTE].filter((d) => !vus.has(d));
    expect(perimees, `Dette périmée, à retirer de la liste :\n  ${perimees.join('\n  ')}`).toEqual([]);
  });
});
