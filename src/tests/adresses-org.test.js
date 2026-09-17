// ═══════════════════════════════════════════════════════════
// AnarBib — aucune adresse de contact en .org dans un texte lisible (17/09/2026)
//
// Décision Xavier du 16/09/2026 : « éviter au max désormais de s'appuyer sur du
// .org ». Le canal humain montré aux gens est celui de l'oficina
// (HumanChannelInlineCallout : anarbib@proton.me + salon Matrix). La passe du
// 17/09 a retiré contato@anarbib.org de la politique de confidentialité (page et
// dix locales), de la notice de l'export RGPD, du repli du mail d'invitation et
// d'AIDER.md ; ce test empêche qu'elle revienne par une nouvelle chaîne.
//
// Ce qui reste en .org l'est pour une raison technique, et chaque adresse est
// nommée ci-dessous — liste FERMÉE, à justifier pour l'allonger :
//   - anarbib@anarbib.org  expéditeur Resend (le domaine d'envoi authentifié) ;
//   - fede@anarbib.org     boîte éditoriale de la gazette et de la cartographie ;
//   - admin@anarbib.org / admins@anarbib.org  alertes d'exploitation (OPS) ;
//   - <exemple>@anarbib.org  exemples de saisie d'un champ, pas un contact.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, dirname, relative } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const RACINES = ['src', 'supabase/functions', 'AIDER.md', 'README.md', 'CONTRIBUTING.md'];
const EXT = /\.(jsx?|tsx?|json|md|html|css)$/;
const EXCLUS = /(^|\/)(node_modules|dist|\.git)(\/|$)|src\/tests\//;

const TOLEREES = new Set([
  'anarbib@anarbib.org', 'fede@anarbib.org', 'admin@anarbib.org', 'admins@anarbib.org',
  'exemplo@anarbib.org', 'exemple@anarbib.org', 'ejemplo@anarbib.org', 'example@anarbib.org',
  'esempio@anarbib.org', 'beispiel@anarbib.org', 'ekzemplo@anarbib.org', 'voorbeeld@anarbib.org',
]);

function* fichiers(p) {
  const abs = join(ROOT, p);
  if (EXCLUS.test(p.replace(/\\/g, '/'))) return;
  const st = statSync(abs);
  if (st.isDirectory()) { for (const e of readdirSync(abs)) yield* fichiers(join(p, e)); }
  else if (EXT.test(p)) yield p;
}

describe('adresses de contact en .org — texte lisible', () => {
  const trouvees = [];
  for (const racine of RACINES) {
    for (const f of fichiers(racine)) {
      const t = readFileSync(join(ROOT, f), 'utf8');
      for (const m of t.matchAll(/[a-zA-Z0-9._-]+@anarbib\.org/g)) {
        if (!TOLEREES.has(m[0])) trouvees.push(`${relative(ROOT, join(ROOT, f)).replace(/\\/g, '/')} : ${m[0]}`);
      }
    }
  }
  it('contato@anarbib.org (ou toute autre adresse hors liste) n\'apparaît plus', () => {
    expect(trouvees).toEqual([]);
  });
  it('la liste des adresses tolérées ne s\'allonge que par une entrée nommée ici', () => {
    expect(TOLEREES.size).toBe(12);
  });
});
