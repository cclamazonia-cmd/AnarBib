// ═══════════════════════════════════════════════════════════
// AnarBib — le catalogue dit ce qui se lit en ligne (04/10/2026).
// Migration 20261004215035 ; suite SQL acces_numerique_catalogue_tests.sql.
//
// has_online_reading (vues matérialisées) ne comptait que les PDF réservés :
// 19 livres à PDF public n'avaient aucun badge. Le badge vient désormais de
// catalog_digital_access_v1, par livre affiché.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn() } }));
const { digitalBadge } = await import('@/hooks/useDigitalAccess');

const pub = (usages) => ({ book_id: 1, public_usages: usages, has_restricted: false, can_read_restricted: false });
const res = (open, libs) => ({ book_id: 2, public_usages: [], has_restricted: true, can_read_restricted: open, restricted_libraries: libs });

describe('digitalBadge', () => {
  it('rien en ligne : pas de badge', () => {
    expect(digitalBadge(undefined)).toBeNull();
    expect(digitalBadge([undefined, null])).toBeNull();
  });
  it('public : lecture avant écoute, vision et lien', () => {
    expect(digitalBadge(pub(['link_externo', 'leitura_online']))).toEqual({ kind: 'public', usage: 'leitura_online' });
    expect(digitalBadge(pub(['escuta_online']))).toEqual({ kind: 'public', usage: 'escuta_online' });
  });
  it('le public l’emporte sur le réservé', () => {
    expect(digitalBadge([res(false, [{ slug: 'btl', name: 'BTL' }]), pub(['visualizacao_online'])]).kind).toBe('public');
  });
  it('réservé : nomme les détentrices, sans doublon, et dit si l’appelant peut lire', () => {
    expect(digitalBadge(res(false, [{ slug: 'btl', name: 'BTL' }]))).toEqual({ kind: 'reserved', libs: ['BTL'] });
    expect(digitalBadge([res(true, [{ slug: 'btl', name: 'BTL' }]), res(false, [{ slug: 'btl', name: 'BTL' }, { slug: 'x', name: 'X' }])]))
      .toEqual({ kind: 'reserved-open', libs: ['BTL', 'X'] });
  });
});

describe('le catalogue ne lit plus has_online_reading pour ses badges', () => {
  // E6 lot 4 (10/10/2026) : la table et ses rendus de lignes vivent dans src/components/catalog/CatalogResultsTable.jsx ;
  // la page garde la requête d'accès numérique (useDigitalAccess) et lui passe accesNumerique.
  const src = readFileSync(path.resolve(__dirname, '../pages/public/CatalogPage.jsx'), 'utf8')
    + readFileSync(path.resolve(__dirname, '../components/catalog/CatalogResultsTable.jsx'), 'utf8');
  it('badge des éditions et des œuvres par l’accès réel', () => {
    expect(src).not.toMatch(/book\.has_online_reading\s*&&/);
    expect(src).toContain('useDigitalAccess(idsAffiches');
    expect(src).toContain('{badgeNumerique([book.book_id])}');
    expect(src).toContain('{badgeNumerique(eds.map((e) => e.book_id))}');
  });
});

describe('la fiche dit à qui la version numérique est réservée', () => {
  const src = readFileSync(path.resolve(__dirname, '../pages/public/BookPage.jsx'), 'utf8');
  it('interroge l’accès réel pour tout le monde, anonyme compris', () => {
    expect(src).toContain("supabase.rpc('catalog_digital_access_v1', { p_book_ids: [bookId] })");
    expect(src).toMatch(/if \(!publicAccessFound\) \{\s*try \{\s*const acc = await supabase\.rpc\('catalog_digital_access_v1'/);
  });
  it('nomme les détentrices, propose la connexion, et traduit les droits', () => {
    expect(src).toContain("t({ id: 'book.digital.reserved' })");
    expect(src).toContain("t({ id: isAuth ? 'book.digital.reservedNotMember' : 'book.digital.reservedLogin' })");
    expect(src).toContain('/login?next=');
    expect(src).toContain('catalogacao.digital.rights.${digitalAccess.rights}');
    expect(src).not.toContain('<span> — {digitalAccess.rights}</span>');
  });
});
