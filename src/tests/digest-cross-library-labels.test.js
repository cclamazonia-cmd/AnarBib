// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/digest-cross-library-labels.test.js
//
// Le récapitulatif hebdomadaire des actions inter-bibliothèques affichait les
// identifiants de code tels quels : « team_promote_to_coordenador » dans la
// colonne Action, « library_team_invitation » dans la colonne Objet.
//
// Ce n'est pas une notification de service, c'est un INSTRUMENT DE
// TRANSPARENCE : il existe pour que le pouvoir des administrateur·rices réseau
// ne s'exerce pas en silence. Il rate sa cible s'il faut connaître le schéma de
// la base pour le lire.
//
// Le fichier ne portait par ailleurs que quatre locales sur dix — un lecteur
// germanophone ou hellénophone recevait donc l'ensemble en portugais.
//
// Ce test garde les deux dimensions : les 14 libellés existent, dans les 10
// locales, et aucun ne rend l'identifiant brut.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL(
  '../../supabase/functions/notify-cross-library-digest/strings.ts',
  import.meta.url,
);

function charger() {
  const code = transformSync(readFileSync(SRC, 'utf8'), {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(() => ({}), mod, mod.exports);
  return mod.exports;
}

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// Relevé le 31/08/2026 sur les corps des fonctions qui appellent
// fn_log_cross_library_action, et sur fn_is_critical_action_type.
const ACTIONS = [
  'team_promote_to_coordenador',
  'team_promote_to_librarian',
  'team_request_remove_member',
  'team_suspend_member',
  'update_library',
  'update_library_membership_rules',
  'update_library_retention_policies',
  'update_library_service_state',
];
const OBJETS = [
  'library',
  'library_membership_rule',
  'library_retention_policy',
  'library_service_state',
  'library_team_invitation',
  'user_library_membership',
];

describe('le récapitulatif parle humain, dans les dix langues', () => {
  it('sert les dix locales du réseau', () => {
    const { STRINGS } = charger();
    expect(Object.keys(STRINGS).sort()).toEqual([...LOCALES].sort());
  });

  it('donne un libellé à chacune des huit actions, partout', () => {
    const { tr } = charger();
    for (const loc of LOCALES) {
      for (const a of ACTIONS) {
        const label = tr(loc, `action.${a}`);
        expect(label, `${loc} / ${a}`).toBeTruthy();
        // `tr` replie sur la clé : si on la retrouve, le libellé manque.
        expect(label, `${loc} / ${a} rend l'identifiant`).not.toBe(`action.${a}`);
        expect(label, `${loc} / ${a} contient l'identifiant`).not.toContain(a);
      }
    }
  });

  it('donne un libellé à chacun des six objets, partout', () => {
    const { tr } = charger();
    for (const loc of LOCALES) {
      for (const o of OBJETS) {
        const label = tr(loc, `target.${o}`);
        expect(label, `${loc} / ${o}`).toBeTruthy();
        expect(label, `${loc} / ${o} rend l'identifiant`).not.toBe(`target.${o}`);
      }
    }
  });

  it('garde les chaînes de cadre dans toutes les locales, pas seulement quatre', () => {
    const { STRINGS } = charger();
    const cadre = ['subtitle', 'greeting', 'footer', 'library.subject', 'library.title',
      'library.intro', 'network.subject', 'network.title', 'network.intro',
      'col.when', 'col.who', 'col.what', 'col.where', 'col.target', 'critical'];
    for (const loc of LOCALES) {
      for (const k of cadre) {
        expect(STRINGS[loc][k], `${loc} / ${k}`).toBeTruthy();
      }
    }
  });

  it("affiche l'identifiant plutôt qu'un vide si un type nouveau arrive sans libellé", () => {
    const { tr } = charger();
    // Comportement voulu : une omission future se VOIT dans le message, elle ne
    // laisse pas une case vide que personne ne remarque.
    expect(tr('fr', 'action.type_invente_demain')).toBe('action.type_invente_demain');
  });

  it("dit qu'une proposition n'est pas un acte accompli, dans les dix langues", () => {
    const { tr } = charger();
    // `team_promote_to_coordenador` couvre DEUX choses que seul le payload
    // sépare : une promotion faite, et une proposition soumise à ratification
    // collégiale. Le récapitulatif du 30/08 en portait une du second type et
    // l'annonçait comme un fait accompli — rendre lisible une information
    // fausse est un recul sur l'identifiant brut, qui n'induisait personne
    // en erreur.
    for (const loc of LOCALES) {
      const avecCompte = tr(loc, 'stage.proposed', { count: '2' });
      expect(avecCompte, `${loc} / stage.proposed`).toBeTruthy();
      expect(avecCompte, `${loc} : le nombre n'est pas substitué`).toContain('2');
      expect(avecCompte, `${loc} : placeholder resté brut`).not.toContain('{count}');

      const sansCompte = tr(loc, 'stage.proposed.sansCompte');
      expect(sansCompte, `${loc} / sansCompte`).toBeTruthy();
      expect(sansCompte, `${loc} : ne doit pas réclamer un nombre`).not.toContain('{count}');
    }
  });

  it('ne laisse pas une locale retomber en portugais sans le dire', () => {
    const { tr } = charger();
    // Si de/el n'existaient pas, tr replierait sur pt-BR : on vérifie que non.
    expect(tr('de', 'greeting')).not.toBe(tr('pt-BR', 'greeting'));
    expect(tr('el', 'col.what')).not.toBe(tr('pt-BR', 'col.what'));
  });
});
