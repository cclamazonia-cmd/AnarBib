// ═══════════════════════════════════════════════════════════
// AnarBib — G16 (05/10/2026) : l'écran des transitions parle la langue de la
// base.
//
// Il envoyait « pro » / « contre » / « abstain » quand la base n'acceptait que
// 'for' / 'against' : tout vote aurait été refusé. Il demandait 5 caractères
// pour justifier un vote contre, la base 20. Son historique omettait les
// propositions acceptées (en carence) et rejetées. Ces gardes relisent la
// migration G16 et les locales : l'écran et la base ne peuvent plus diverger
// sans qu'un test rougisse.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: {} }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: null }) }));

const { VOTE_CHOICES, RATIONALE_MIN, HISTORY_STATUSES } = await import('@/components/TransitionsPanel.jsx');

const MIG = readFileSync(path.resolve(__dirname,
  '../../supabase/migrations/20261005101029_le_vote_des_transitions_parle_la_langue_de_la_base.sql'), 'utf8');
const LOC = path.resolve(__dirname, '../i18n/locales');
const locales = readdirSync(LOC).filter((f) => f.endsWith('.json'))
  .map((f) => [f, JSON.parse(readFileSync(path.join(LOC, f), 'utf8'))]);

describe('G16 — le vote des transitions', () => {
  it("les trois boutons envoient exactement les valeurs que la CHECK de la base accepte", () => {
    const check = MIG.match(/library_profile_votes_vote_check\s+CHECK \(vote = ANY \(ARRAY\[([^\]]+)\]/);
    expect(check).toBeTruthy();
    const base = [...check[1].matchAll(/'([a-z]+)'::text/g)].map((m) => m[1]).sort();
    expect(VOTE_CHOICES.map((c) => c.value).sort()).toEqual(base);
    expect(base).toEqual(['abstain', 'against', 'for']);
  });

  it('le minimum de justification d\'un vote contre est celui de la base', () => {
    expect(MIG).toMatch(new RegExp(`length\\(rationale_against\\) >= ${RATIONALE_MIN}\\)`));
    for (const [f, j] of locales) expect(j['transitions.error.rationaleRequired'], f).toContain(String(RATIONALE_MIN));
  });

  it("l'historique montre tout ce qui n'est plus ouvert, accepté et rejeté compris", () => {
    expect([...HISTORY_STATUSES].sort()).toEqual(
      ['accepted_majority', 'accepted_unanimous', 'cancelled', 'completed', 'expired', 'rejected']);
  });

  it('chaque bouton, chaque statut et la fin de carence ont leur libellé dans les dix locales', () => {
    expect(locales).toHaveLength(10);
    for (const [f, j] of locales) {
      for (const c of VOTE_CHOICES) expect(j[`transitions.vote.${c.label}`], `${f} ${c.label}`).toBeTruthy();
      for (const s of HISTORY_STATUSES) expect(j[`transitions.status.${s}`], `${f} ${s}`).toBeTruthy();
      expect(j['transitions.graceUntil'], f).toContain('{date}');
    }
  });
});
