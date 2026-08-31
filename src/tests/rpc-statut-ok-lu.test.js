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
// LA DETTE EST NOMMÉE, PAS CACHÉE. Quatre sites resistent à la correction
// mécanique et sont listés ci-dessous avec leur raison. La liste ne doit que
// RÉTRÉCIR : y ajouter une ligne demande de le justifier ici.
// ─────────────────────────────────────────────────────────────────────────────
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

// RPC dont le contrat rend `{ ok, … }` — relevé en base le 31/08/2026 :
// fonctions de `api` et `public` rendant un jsonb dont le corps pose une clé `ok`.
const RPC_A_STATUT = new Set([
  'advance_consulta', 'advance_reservation', 'cancel_consulta_as_reader',
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
]);

// Dette déclarée au 31/08/2026. Chaque entrée porte sa raison.
const DETTE = new Set([
  // `let error` partagé entre deux branches (consulta / réservation) : lier la
  // charge utile demande de restructurer la fonction, pas d'ajouter une ligne.
  'src/pages/account/AccountPage.jsx::create_consulta_local',
  // Idem, dans une boucle à plusieurs branches du Painel.
  'src/pages/painel/PanelPage.jsx::advance_reservation',
  // Appels sans aucune destructuration : ils ignorent même `error`. Les
  // reprendre, c'est décider quoi faire d'un échec, pas seulement lire `ok`.
  'src/pages/importacoes/ImportacoesPage.jsx::fn_import_set_adapter_overrides',
  'src/pages/importacoes/ImportacoesPage.jsx::fn_import_set_profile',
]);

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
