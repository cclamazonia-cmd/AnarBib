// ═══════════════════════════════════════════════════════════
// AnarBib — le dépôt numérique part des droits (05/10/2026).
// Migration 20261005092916 ; suite SQL depot_numerique_droits_tests.sql.
//   * les règles : accès proposés selon les droits, espace et type déduits,
//     justification requise ;
//   * le panneau : les étapes s'ouvrent dans l'ordre ; sous droits, la lecture
//     publique est fermée tant que la bibliothèque ne l'a pas ouverte, et passe
//     par l'avertissement légal quand elle l'a fait ;
//   * le dépôt depuis l'OCR part en accès réservé.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

let ouverte = false;
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({
      select: () => ({ eq: () => ({ maybeSingle: () => Promise.resolve({ data: { name: 'BTL', digital_public_under_rights: ouverte }, error: null }) }) }),
    }),
    storage: { from: () => ({}) },
  },
}));
const confirmer = vi.fn(() => Promise.resolve(true));
vi.mock('@/contexts/ConfirmContext', () => ({ useConfirm: () => confirmer }));

const fr = JSON.parse(readFileSync(path.resolve(__dirname, '../i18n/locales/fr.json'), 'utf8'));
const mod = await import('@/pages/catalogacao/DigitalResourcesPanel');
const { familleDe, seauPour, typePour, accesPossibles, justificationRequise, default: DigitalResourcesPanel } = mod;

afterEach(() => { cleanup(); confirmer.mockClear(); ouverte = false; });

describe('règles du dépôt', () => {
  it('famille, espace et type déduits du fichier et de l’accès', () => {
    expect(familleDe('application/pdf')).toBe('pdf');
    expect(familleDe('', 'livre.EPUB')).toBe('epub');
    expect(familleDe('video/mp4')).toBe('video');
    expect(familleDe('text/plain', 'a.txt')).toBeNull();
    expect(seauPour('pdf', 'publico')).toBe('anarbib-pdf-public');
    expect(seauPour('pdf', 'conta_ativa')).toBe('pdf-restrito');
    expect(seauPour('epub', 'conta_ativa')).toBe('anarbib-epub-restricted');
    expect(seauPour('image', 'publico')).toBe('anarbib-media-public');
    expect(typePour('pdf', 'conta_ativa')).toBe('pdf_restrito');
    expect(typePour('epub', 'publico')).toBe('epub');
    expect(typePour(null, 'publico')).toBe('link_externo');
  });
  it('accès proposés selon les droits et le réglage de la bibliothèque', () => {
    expect(accesPossibles('', true)).toEqual([]);
    expect(accesPossibles('dominio_publico', false).map((o) => o.value)).toEqual(['publico', 'conta_ativa']);
    expect(accesPossibles('sob_direitos', false)).toEqual([{ value: 'conta_ativa', enabled: true }, { value: 'publico', enabled: false }]);
    expect(accesPossibles('sob_direitos', true).find((o) => o.value === 'publico').enabled).toBe(true);
  });
  it('justification : licence, cession, et sous droits mis en public', () => {
    expect(justificationRequise('dominio_publico', 'publico')).toBe(false);
    expect(justificationRequise('licenca_livre', 'publico')).toBe(true);
    expect(justificationRequise('cessao_autoral', 'conta_ativa')).toBe(true);
    expect(justificationRequise('sob_direitos', 'conta_ativa')).toBe(false);
    expect(justificationRequise('sob_direitos', 'publico')).toBe(true);
  });
});

function monter() {
  render(
    <IntlProvider locale="fr" messages={fr}>
      <DigitalResourcesPanel draftId="12" ownerLibraryId="lib-1" resources={[]} onChanged={() => {}} setMsg={() => {}} />
    </IntlProvider>,
  );
  fireEvent.click(screen.getByText(fr['catalogacao.digital.newResource']));
}

describe('le panneau, étape par étape', () => {
  it('les droits n’apparaissent qu’après « quoi », l’accès qu’après les droits', () => {
    monter();
    expect(screen.queryByText(fr['catalogacao.dep.step.rights'])).toBeNull();
    fireEvent.click(screen.getByLabelText(fr['catalogacao.dep.kind.file']));
    expect(screen.getByText(fr['catalogacao.dep.step.rights'])).toBeTruthy();
    expect(screen.queryByText(fr['catalogacao.dep.step.access'])).toBeNull();
    fireEvent.click(screen.getByText(fr['catalogacao.digital.rights.dominio_publico']));
    expect(screen.getByText(fr['catalogacao.dep.step.access'])).toBeTruthy();
  });

  it('sous droits, bibliothèque fermée : réservé d’office, lecture publique fermée', async () => {
    ouverte = false;
    monter();
    fireEvent.click(screen.getByLabelText(fr['catalogacao.dep.kind.file']));
    fireEvent.click(screen.getByText(fr['catalogacao.digital.rights.sob_direitos']));
    await screen.findByText(fr['catalogacao.dep.access.publicLocked']);
    const radios = screen.getAllByRole('radio', { name: /./ }).filter((r) => r.name === 'dep-access');
    const [reserve, publique] = radios;
    expect(reserve.checked).toBe(true);
    expect(publique.disabled).toBe(true);
  });

  it('sous droits, bibliothèque ouverte : la lecture publique passe par l’avertissement et exige une justification', async () => {
    ouverte = true;
    monter();
    fireEvent.click(screen.getByLabelText(fr['catalogacao.dep.kind.file']));
    fireEvent.click(screen.getByText(fr['catalogacao.digital.rights.sob_direitos']));
    await waitFor(() => {
      const r = screen.getAllByRole('radio').filter((x) => x.name === 'dep-access');
      expect(r[1].disabled).toBe(false);
    });
    const publique = screen.getAllByRole('radio').filter((x) => x.name === 'dep-access')[1];
    fireEvent.click(publique);
    await waitFor(() => expect(confirmer).toHaveBeenCalledTimes(1));
    expect(confirmer.mock.calls[0][0].tone).toBe('danger');
    await screen.findByText(`${fr['catalogacao.dep.justification.sob_direitos']} *`);
  });
});

describe('le dépôt depuis l’OCR part en accès réservé', () => {
  it('pdf-restrito, conta_ativa, correspondance acquise', () => {
    const s = readFileSync(path.resolve(__dirname, '../pages/catalogacao/BookDraftForm.jsx'), 'utf8');
    const bloc = s.slice(s.indexOf('async function attachOcrPdf'), s.indexOf('function f(key)'));
    expect(bloc).toContain("const bucket = 'pdf-restrito';");
    expect(bloc).toContain("access_scope: 'conta_ativa'");
    expect(bloc).toContain('bibliographic_match_validated: true');
    expect(bloc).not.toContain('anarbib-pdf-public');
  });
});
