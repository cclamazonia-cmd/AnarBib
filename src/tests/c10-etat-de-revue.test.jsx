// ═══════════════════════════════════════════════════════════
// AnarBib — C10 (05/10/2026) : deux sens, deux noms.
// Migration 20261005162356 ; suite SQL c10_etat_de_revue_tests.sql.
//
// `digital_assets.review_state` (l'état de REVUE d'un fichier : to_review,
// public_domain_confirmed…) s'appelait rights_status, comme le vocabulaire des
// droits d'auteur des ressources (dominio_publico, licenca_livre…). Ici :
//   * l'application et les Edge Functions lisent review_state là où il s'agit
//     de l'état de revue, et rien d'autre n'a changé de nom ;
//   * un paquet de fonds d'avant (rights_status) reste lisible ;
//   * le piège access_scope (conta_ativa par défaut) est rappelé dans le
//     formulaire de catalogage, dans la liste et à l'étape de l'accès.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({
      select: () => ({ eq: () => ({ maybeSingle: () => Promise.resolve({ data: { name: 'BTL', digital_public_under_rights: false }, error: null }) }) }),
    }),
    storage: { from: () => ({}) },
  },
}));
vi.mock('@/contexts/ConfirmContext', () => ({ useConfirm: () => () => Promise.resolve(true) }));

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const { libreMaisReservee, default: DigitalResourcesPanel } = await import('@/pages/catalogacao/DigitalResourcesPanel');

afterEach(cleanup);

describe('l’état de revue s’appelle review_state dans l’application et les fonctions', () => {
  it('ce qui lit digital_assets dit review_state', () => {
    expect(lire('src/components/library/LibraryDigitalSharesSection.jsx'))
      .toContain(".from('digital_assets')\n        .select('id, title, asset_kind, review_state, is_public')");
    const imp = lire('src/pages/importacoes/ImportacoesPage.jsx');
    expect(imp).not.toMatch(/a\.rights_status|rights_status: 'public_domain_confirmed'/);
    expect(imp.match(/a\.review_state === 'to_review'/g)).toHaveLength(3);
  });

  it('l’export des fonds écrit review_state ; les deux réceptions lisent aussi un paquet d’avant', () => {
    const exp = lire('supabase/functions/export-fonds-bundle/index.ts');
    expect(exp).toContain('review_state: a.review_state');
    expect(exp).not.toContain('rights_status');
    for (const f of ['supabase/functions/deposit-fonds-direct/index.ts', 'supabase/functions/receive-fonds-bundle/index.ts']) {
      expect(lire(f), f).toContain('rights_status: clean(a?.review_state ?? a?.rights_status)');
    }
  });

  it('le vocabulaire des droits garde son nom (ressources, fiche, liseuse)', () => {
    expect(lire('src/pages/catalogacao/DigitalResourcesPanel.jsx')).toContain('rights_status: df.rights_status');
    expect(lire('src/pages/public/BookPage.jsx')).toContain('rights: row.rights_status');
  });
});

describe('le piège access_scope est rappelé dans le formulaire', () => {
  it('libre de droits mais réservé aux comptes : rappelé ; les autres cas : non', () => {
    expect(libreMaisReservee('dominio_publico', 'conta_ativa')).toBe(true);
    expect(libreMaisReservee('licenca_livre', 'conta_ativa')).toBe(true);
    expect(libreMaisReservee('dominio_publico', 'publico')).toBe(false);
    expect(libreMaisReservee('sob_direitos', 'conta_ativa')).toBe(false);
    expect(libreMaisReservee('cessao_autoral', 'conta_ativa')).toBe(false);
  });

  const monter = (resources) => render(
    <IntlProvider locale="fr" messages={fr}>
      <DigitalResourcesPanel draftId="12" ownerLibraryId="lib-1" resources={resources} onChanged={() => {}} setMsg={() => {}} />
    </IntlProvider>,
  );
  const ressource = (rights, access) => ({ id: 7, rights_status: rights, access_scope: access, storage_path: 'x.pdf', label: 'Doc' });

  it('dans la liste, sous une ressource du domaine public restée en accès réservé', () => {
    monter([ressource('dominio_publico', 'conta_ativa')]);
    expect(screen.getByText(fr['catalogacao.dep.access.freeButReserved'])).toBeTruthy();
  });

  it('pas sous une ressource ouverte à tout le monde', () => {
    monter([ressource('dominio_publico', 'publico')]);
    expect(screen.queryByText(fr['catalogacao.dep.access.freeButReserved'])).toBeNull();
  });

  it('à l’étape de l’accès, quand on édite une telle ressource', () => {
    monter([ressource('licenca_livre', 'conta_ativa')]);
    fireEvent.click(screen.getByText(fr['common.edit']));
    expect(screen.getAllByText(fr['catalogacao.dep.access.freeButReserved']).length).toBe(2);
  });

  it('le rappel existe dans les dix langues', () => {
    for (const l of ['fr', 'pt-BR', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el']) {
      expect(JSON.parse(lire(`src/i18n/locales/${l}.json`))['catalogacao.dep.access.freeButReserved'], l).toBeTruthy();
    }
  });
});
