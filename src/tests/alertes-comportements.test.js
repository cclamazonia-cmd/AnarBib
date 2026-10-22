// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/alertes-comportements.test.js
//
// 22/10/2026 — health-probe ne voyait que les pannes. Deux sondes de vigilance,
// `abus` (les freins anti-abus) et `consultations` (les lectures nominatives par
// un même compte), migration 20261022223116.
//
// Ce que ce banc tient :
//   * les deux sondes sont branchées, marquées `vigilance`, et leur kind est dans
//     la CHECK (health-probe-kinds-check.test.js le vérifie aussi, en général) ;
//   * leurs courriels partent aux admins, à la boîte de supervision ET à la boîte
//     institutionnelle du réseau, ensemble (décision de Xavier du 22/10/2026) ;
//   * le journal COMPTE et ne nomme pas : aucune colonne pour la personne
//     consultée, et les trois fonctions nominatives y écrivent ;
//   * les fonctions de sonde et de purge restent à service_role.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { monterEF } from './helpers/monter-ef.js';

const SONDE = readFileSync(new URL('../../supabase/functions/health-probe/index.ts', import.meta.url), 'utf8');
const MIGRATION = readFileSync(
  new URL('../../supabase/migrations/20261022223116_les_comportements_anormaux_ouvrent_un_incident.sql', import.meta.url),
  'utf8',
);

function entreeDeSonde(kind) {
  const i = SONDE.indexOf(`kind: '${kind}'`);
  if (i < 0) return '';
  return SONDE.slice(i, SONDE.indexOf('}', i));
}

describe('health-probe — les sondes de vigilance sont branchées', () => {
  it.each([
    ['abus', 'fn_healthcheck_abus'],
    ['consultations', 'fn_healthcheck_consultations'],
  ])('%s appelle %s et se déclare de vigilance', (kind, rpc) => {
    const e = entreeDeSonde(kind);
    expect(e).toContain(`rpc: '${rpc}'`);
    expect(e).toContain('vigilance: true');
  });

  it('les deux courriels (ouverture et clôture) demandent la boîte du réseau pour une sonde de vigilance', () => {
    const appels = SONDE.match(/\{ avecBoiteReseau: sonde\.vigilance === true \}/g) || [];
    expect(appels).toHaveLength(2);
  });

  it('destinataires() garde la variable de supervision et ajoute la boîte du réseau en plus', () => {
    expect(SONDE).toContain("cc: Deno.env.get('HEALTH_ALERT_CC')");
    expect(SONDE).toContain('adressesSupplementaires(boiteCollectiveReseau())');
  });

  it('la purge du journal (RET-3) passe à chaque tour', () => {
    expect(SONDE).toContain("rpc('fn_consultations_purger')");
  });
});

describe('health-probe — à qui part une alerte de vigilance', () => {
  // On rejoue la composition de destinataires() sur le module réel.
  function monter(admins, env) {
    const ef = monterEF({
      env,
      repondre: (_s, table) => {
        if (table === 'network_administrators') return { data: admins.map((_p, i) => ({ user_id: `u-${i}` })), error: null };
        if (table === 'profiles') return { data: admins.map((p, i) => ({ id: `u-${i}`, ...p })), error: null };
        return { data: null, error: null };
      },
    });
    const mod = ef.charger('_shared/context/network-admins.ts');
    const client = ef.charger('_shared/core/env.ts').supabaseAdmin;
    const vigilance = () =>
      mod.destinatairesAdminsReseau(client, {
        cc: env.HEALTH_ALERT_CC ?? '',
        extras: mod.adressesSupplementaires(mod.boiteCollectiveReseau()).map((email) => ({ email })),
      });
    return { vigilance };
  }
  const emails = (r) => r.map((c) => c.email).sort();

  it('admins + supervision + boîte du réseau, quand les deux boîtes diffèrent', async () => {
    const { vigilance } = monter([{ email: 'adm@exemplo.test', first_name: 'A' }], {
      HEALTH_ALERT_CC: 'supervision@exemplo.test',
      NETWORK_ADMIN_CC: 'reseau@exemplo.test',
    });
    expect(emails(await vigilance())).toEqual(['adm@exemplo.test', 'reseau@exemplo.test', 'supervision@exemplo.test']);
  });

  it('une seule copie quand la boîte du réseau retombe sur celle de supervision', async () => {
    const { vigilance } = monter([{ email: 'adm@exemplo.test', first_name: 'A' }], {
      HEALTH_ALERT_CC: 'supervision@exemplo.test',
    });
    expect(emails(await vigilance())).toEqual(['adm@exemplo.test', 'supervision@exemplo.test']);
  });

  it('part quand même si aucun·e admin n’est actif·ve : une alerte qui viserait un·e admin n’est pas étouffée', async () => {
    const { vigilance } = monter([], { NETWORK_ADMIN_CC: 'reseau@exemplo.test' });
    expect(emails(await vigilance())).toEqual(['reseau@exemplo.test']);
  });
});

describe('migration — le journal compte et ne nomme pas', () => {
  const table = MIGRATION.match(/CREATE TABLE IF NOT EXISTS private\.consultations_nominatives \(([\s\S]*?)\n\);/);

  it('les colonnes sont exactement : id, le, par, fonction, library_id, nb', () => {
    expect(table).not.toBeNull();
    const colonnes = table[1]
      .split('\n')
      .map((l) => l.trim().split(/\s+/)[0])
      .filter(Boolean);
    expect(colonnes).toEqual(['id', 'le', 'par', 'fonction', 'library_id', 'nb']);
  });

  it.each([
    'api.get_reader_roster',
    'public.fn_network_admin_find_user_by_email',
    'public.fn_painel_reader_other_memberships',
  ])('%s écrit au journal et n’est plus en lecture seule', (nom) => {
    const debut = MIGRATION.indexOf(`CREATE OR REPLACE FUNCTION ${nom}(`);
    expect(debut).toBeGreaterThan(0);
    const corps = MIGRATION.slice(debut, MIGRATION.indexOf('$function$;', debut));
    expect(corps).toContain('private.fn_noter_consultation(');
    expect(corps).toMatch(/VOLATILE SECURITY DEFINER/);
  });

  it('aucun appel au journal ne lui passe l’identifiant de la personne consultée', () => {
    const appels = MIGRATION.match(/fn_noter_consultation\([^;]*;/g) || [];
    expect(appels.length).toBeGreaterThanOrEqual(3);
    for (const a of appels) {
      expect(a).not.toMatch(/p_user_id|v_id\b(?! IS NULL)|p_email|v_email/);
    }
  });

  it('sondes, purge et écriture restent fermées à anon et authenticated', () => {
    for (const sig of [
      'private.fn_noter_consultation(text, uuid, integer)',
      'public.fn_healthcheck_consultations(integer, integer, integer, integer)',
      'public.fn_healthcheck_abus(integer, integer, integer)',
      'public.fn_consultations_purger()',
    ]) {
      expect(MIGRATION).toContain(`REVOKE EXECUTE ON FUNCTION ${sig} FROM PUBLIC, anon, authenticated;`);
    }
  });

  it('le bilan des freins ne rend ni clé ni adresse', () => {
    const debut = MIGRATION.indexOf('CREATE OR REPLACE FUNCTION public.fn_healthcheck_abus(');
    const corps = MIGRATION.slice(debut, MIGRATION.indexOf('$function$;', debut));
    expect(corps).not.toMatch(/r\.key|'cle'|'key'/);
  });
});
