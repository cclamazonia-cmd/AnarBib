// F14 (22/09/2026) — Aucun courriel de la plateforme ne porte un Reply-To d'un autre
// domaine que l'expéditeur. Trouvé pendant l'essai de bascule authentifié : le mail de
// bienvenue arrivait dans les indésirables de Riseup (6,9 / 6) parce que l'expéditeur
// était no-reply@notifications.anarbib.org et le Reply-To anarbib@proton.me
// (FREEMAIL_FORGED_REPLYTO 2,5 + FROM_NOT_REPLYTO_SAME_DOMAIN 3,0 + FROM_NOT_REPLYTO 1,0).
// L'adresse humaine se met dans le corps, jamais dans l'en-tête.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = join(__dirname, '..', '..');
const FN = join(ROOT, 'supabase', 'functions');
const lire = (p) => readFileSync(join(ROOT, p), 'utf8');

// Liste FERMÉE des fonctions qui posent un reply_to hors du routage par bibliothèque,
// avec la raison pour laquelle chacune est admise.
// 23/09/2026 (F7, lot 1) — `notify-weekly-report` SORT de cette liste : elle ne pose
// plus l'en-tête elle-même, elle passe par `_shared/transport/email.ts` en lui donnant
// son routage, résolu depuis le contexte de la bibliothèque. Le contenu du payload
// partagé est figé par `src/tests/mail-transport-routage.test.js`.
// 24/09/2026 (F7, lot 2) — le balayage voit désormais aussi un Reply-To passé en
// routage explicite (`replyToEmail: ...`). `notify-network-weekly-report` y REVIENT :
// son adresse de réponse vient de `resolveEnvReplyToEmail()`, une résolution
// d'environnement, exactement ce que cette liste surveille.
const ADMISES = {
  'notify-document-permission-request': 'REPLY_TO_EMAIL / ANARBIB_REPLY_TO_EMAIL, vides en production → aucun en-tête (passé en routage explicite depuis F7 lot 2)',
  'notify-mid-loan-reading': 'reply-to de la bibliothèque (canal local), pas de la plateforme (passé en routage explicite depuis F7 lot 2)',
  'notify-network-weekly-report': 'resolveEnvReplyToEmail() : résolution d\'environnement qui retombe sur SENDER_EMAIL (routage explicite depuis F7 lot 1)',
  'notify-oai-opening': 'FEDERAL_EMAIL, même domaine que l\'expéditeur',
  'register': 'ANARBIB_REPLY_TO_EMAIL, vide en production → retombe sur SENDER_EMAIL',
};

function fichiersTs(dir, acc = []) {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) { if (n !== '_shared') fichiersTs(p, acc); }
    else if (n.endsWith('.ts') && !n.includes('.test.')) acc.push(p);
  }
  return acc;
}

describe('F14 — Reply-To du même domaine que l\'expéditeur', () => {
  it('seules les fonctions admises posent un reply_to depuis une constante ou l\'environnement', () => {
    const trouvees = new Set();
    for (const f of fichiersTs(FN)) {
      const src = readFileSync(f, 'utf8');
      for (const ligne of src.split('\n')) {
        // Depuis F7 lot 2 (24/09/2026), un Reply-To peut aussi etre passe en routage
        // explicite au module partage (`replyToEmail: ...`) : on le balaye pareil.
        if (!/\b(reply_to(_email)?|replyToEmail)\s*[:=]/.test(ligne)) continue;
        if (/ctx\??\./.test(ligne) || /^\s*\/\//.test(ligne)) continue;
        trouvees.add(f.slice(FN.length + 1).split(/[\\/]/)[0]);
      }
    }
    expect([...trouvees].sort()).toEqual(Object.keys(ADMISES).sort());
  });

  it('le rapport hebdomadaire ne retombe plus sur ADMIN_EMAIL pour son Reply-To', () => {
    const src = lire('supabase/functions/notify-network-weekly-report/index.ts');
    const fn = src.slice(src.indexOf('function resolveEnvReplyToEmail'), src.indexOf('function resolveEnvNetworkWeeklyRecipient'));
    expect(fn).not.toContain('ADMIN_EMAIL');
    expect(fn).toContain('SENDER_EMAIL');
  });

  it('l\'invitation et la demande d\'entrée n\'écrivent plus de Reply-To Proton', () => {
    expect(lire('supabase/functions/notify-library-invitation/index.ts')).not.toMatch(/reply_to_email:\s*CONTACT_EMAIL/);
    expect(lire('supabase/functions/notify-library-request/index.ts')).not.toContain('payload.reply_to');
  });

  it('le mail de bienvenue donne l\'adresse humaine dans son corps, dix langues', () => {
    const src = lire('supabase/functions/_shared/i18n/mail-strings.ts');
    const i = src.indexOf('"welcome.autoMessage": {');
    const bloc = src.slice(i, src.indexOf('\n  },', i));
    expect((bloc.match(/anarbib@proton\.me/g) || []).length).toBe(10);
    expect(bloc).not.toMatch(/encaminhadas|transmises|forwarded/);
  });

  it('le fichier d\'exemple documente les deux variables et la règle', () => {
    const env = lire('deploy/functions.env.example');
    expect(env).toMatch(/^ANARBIB_REPLY_TO_EMAIL=$/m);
    expect(env).toMatch(/^NETWORK_REPLY_TO_EMAIL=$/m);
    expect(env).toContain('FREEMAIL_FORGED_REPLYTO');
  });
});
