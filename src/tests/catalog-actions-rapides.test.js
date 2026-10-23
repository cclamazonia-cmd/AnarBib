// =====================================================================
// E6, lot 5 du catalogue public (23/10/2026) — la réservation rapide, la
// consultation sur place et les favoris sortent de CatalogPage.jsx dans le
// crochet useCatalogQuickActions, lignes déplacées telles quelles. Ce test
// garde : le montage du crochet dans la page, les RPC et les garde-fous dans le
// crochet, aucun setter de cet état resté dans la page, la page sous 60 Ko.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const racine = path.resolve(__dirname, '..', '..');
const lire = (p) => readFileSync(path.join(racine, p), 'utf8');
const PAGE = 'src/pages/public/CatalogPage.jsx';
const CROCHET = 'src/pages/public/hooks/useCatalogQuickActions.js';

describe('useCatalogQuickActions', () => {
  it('la page monte le crochet et passe ce qu\'il rend à la table', () => {
    const page = lire(PAGE);
    expect(page).toContain("import { useCatalogQuickActions } from './hooks/useCatalogQuickActions';");
    expect(page).toContain('} = useCatalogQuickActions({ user, isAuth, t });');
    for (const id of ['handleQuickReserve', 'handleQuickConsulta', 'handleWishlist', 'quickReserveAvailable', 'quickConsultaAvailable',
      'reserveState', 'reservedBibRefs', 'consultedBibRefs', 'consultaState', 'wishlistedIds', 'wishlistBusy']) {
      expect(page.split(id).length - 1, id).toBeGreaterThanOrEqual(2);   // rendu par le crochet, lu par la table
    }
  });
  it('l\'état et les appels vivent dans le crochet, plus dans la page', () => {
    const page = lire(PAGE);
    const crochet = lire(CROCHET);
    for (const parti of ['setServiceState', 'setIsRestricted', 'setReserveState', 'setReservedBibRefs', 'setConsultedBibRefs',
      'setConsultaState', 'setWishlistedIds', 'setWishlistBusy', 'fn_v2_create_reserva_by_holdings', 'create_consulta_local',
      'user_wishlist', 'my_library_context']) {
      expect(page, parti).not.toContain(parti);
      expect(crochet, parti).toContain(parti);
    }
    // les garde-fous : bibliothèque en pause ou en consultation seule, profil restreint
    expect(crochet).toContain("if (svcMode === 'pausada' || svcMode === 'somente_consulta') return false;");
    expect(crochet).toContain("p_notes: '@@note:catalog.quickReserve.note'");
  });
  it('la page tient sous 60 Kio (E6)', () => {
    expect(statSync(path.join(racine, PAGE)).size).toBeLessThan(60 * 1024);
  });
});
