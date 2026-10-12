// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/install-sh-transport-mail.test.js
//
// install.sh propose trois transports de courriel et écrit celui qu'on choisit
// dans deploy/functions.env : [1] SMTP, [2] Resend, [3] simulation (mock). Les
// trois existent dans _shared/transport/email.ts depuis F7 ; jusqu'au 12/10/2026
// le menu disait encore « seul 2 fonctionne aujourd'hui » et n'écrivait rien pour
// 1 et 3. Cette garde tient :
//   - les trois branches du menu et ce qu'elles écrivent ;
//   - l'absence des mentions « à venir » dans les dix langues ;
//   - les invites que l'assistant graphique de l'ISO Debian (dépôt
//     ASR2026/anarbib-debian-iso, anarbib-installer-gui, pexpect) attend mot
//     pour mot — les changer casse son installation automatique ;
//   - le modèle functions.env.example, qui ne dit plus que SMTP est « à venir ».

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');
const script = lire('install.sh');
const LANGUES = ['fr', 'en', 'pt', 'es', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// Le bloc du menu : de son commentaire d'en-tête à l'initialisation de la bibliothèque.
const bloc = script.slice(
  script.indexOf('# Mail configuration (interactive, only if not already set)'),
  script.indexOf('# Initialisation de la première bibliothèque'),
);

const chaine = (langue, cle) =>
  (script.match(new RegExp(`^\\s+${langue}:${cle}\\)\\s+(?:echo|printf) "([^"]*)"`, 'm')) || [])[1];

describe('install.sh — le menu de courriel écrit les trois transports', () => {
  it('a une branche par choix, et chacune pose MAIL_TRANSPORT', () => {
    expect(bloc).toMatch(/^\s+1\)\s*$/m);
    expect(bloc).toMatch(/^\s+2\)\s*$/m);
    expect(bloc).toMatch(/^\s+3\)\s*$/m);
    expect(bloc).toContain('ecrire_fenv MAIL_TRANSPORT smtp');
    expect(bloc).toContain('ecrire_fenv MAIL_TRANSPORT resend');
    expect(bloc).toContain('ecrire_fenv MAIL_TRANSPORT mock');
  });

  it('SMTP écrit hôte, port, utilisateur, mot de passe, expéditeur et SMTP_SECURE', () => {
    for (const cle of ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_SECURE', 'SENDER_EMAIL']) {
      expect(bloc).toContain(`ecrire_fenv ${cle} `);
    }
    expect(bloc).toContain('read -rs CFG_SMTP_PASS');
    expect(bloc).toMatch(/CFG_SMTP_PORT" = "465" \] && CFG_SMTP_SECURE="true"/);
  });

  it('saute le menu quand functions.env porte déjà un transport, mock compris', () => {
    expect(bloc).toMatch(/\[ -z "\$CURRENT_SMTP" \] && \[ -z "\$CURRENT_RESEND" \] && \[ "\$CURRENT_TRANSPORT" != "mock" \]/);
  });

  it("protège \\, & et | dans les valeurs écrites par sed, et ajoute la clé si elle manque", () => {
    expect(bloc).toContain("sed -e 's/[\\\\&|]/\\\\&/g'");
    expect(bloc).toMatch(/printf '%s=%s\\n' "\$cle" "\$2" >> deploy\/functions\.env/);
  });

  it('ne dit plus « à venir » ni « seul 2 fonctionne », dans aucune langue', () => {
    for (const l of LANGUES) {
      for (const cle of ['mail_opt1', 'mail_opt2', 'mail_opt3', 'mail_prompt', 'mail_not_yet']) {
        const v = chaine(l, cle);
        expect(v, `${l}:${cle}`).toBeTruthy();
        expect(v, `${l}:${cle}`).not.toMatch(/À VENIR|COMING SOON|EM BREVE|POR VENIR|IN ARRIVO|KOMMT NOCH|EN CAMÍ|VENONTA|KOMT NOG|ΕΡΧΕΤΑΙ/);
        expect(v, `${l}:${cle}`).not.toMatch(/\(.*\b2\b.*\)/);
      }
      // Le message tient sur deux echo ; la seconde ligne dit quoi faire.
      const entier = (script.match(new RegExp(`^\\s+${l}:mail_not_yet\\)[\\s\\S]*?;;`, 'm')) || [''])[0];
      expect(entier, `${l}:mail_not_yet`).toMatch(/MAIL_TRANSPORT=smtp, resend .{1,5} mock/);
      expect(entier, `${l}:mail_not_yet`).toContain('./install.sh');
    }
  });

  it("garde les invites françaises que l'assistant de l'ISO Debian attend (pexpect)", () => {
    // ASR2026/anarbib-debian-iso, anarbib-installer-gui : patterns
    //   r"Votre choix \[1/2/3\].*:", r"Clé API Resend.*:",
    //   r"Adresse d'expédition vérifiée sur Resend.*:",
    //   r"Nom de votre bibliothèque.*:", r"Courriel de l'administrateur.*:"
    expect(chaine('fr', 'mail_prompt')).toMatch(/Votre choix \[1\/2\/3\].*:/);
    expect(chaine('fr', 'resend_key')).toMatch(/Clé API Resend.*:/);
    expect(chaine('fr', 'resend_sender')).toMatch(/Adresse d'expédition vérifiée sur Resend.*:/);
    expect(chaine('fr', 'lib_prompt')).toMatch(/Nom de votre bibliothèque.*:/);
    expect(chaine('fr', 'admin_email_prompt')).toMatch(/Courriel de l'administrateur.*:/);
    // Et le choix [1] = SMTP, [2] = Resend, [3] = simulation, dans cet ordre (le GUI envoie 1/2/3).
    expect(chaine('fr', 'mail_opt1')).toMatch(/^\s*\[1\].*SMTP/);
    expect(chaine('fr', 'mail_opt2')).toMatch(/^\s*\[2\].*Resend/);
    expect(chaine('fr', 'mail_opt3')).toMatch(/^\s*\[3\].*[Ss]imulation/);
  });

  it('les libellés SMTP et mock existent dans les dix langues', () => {
    for (const l of LANGUES) {
      for (const cle of ['smtp_title', 'smtp_host', 'smtp_port', 'smtp_user', 'smtp_pass', 'smtp_sender', 'ok_smtp', 'ok_mock']) {
        expect(chaine(l, cle), `${l}:${cle}`).toBeTruthy();
      }
    }
  });

  it('functions.env.example décrit les trois transports et ne dit plus « à venir »', () => {
    const ex = lire('deploy/functions.env.example');
    expect(ex).not.toMatch(/À VENIR/);
    expect(ex).not.toMatch(/ne les lisent pas encore/);
    for (const t of ['MAIL_TRANSPORT=resend', 'MAIL_TRANSPORT=smtp', 'MAIL_TRANSPORT=mock']) {
      expect(ex).toContain(t);
    }
    expect(ex).toMatch(/^SMTP_SECURE=false$/m);
  });

  it('le transport serveur lit bien les trois modes que le menu écrit', () => {
    const transport = lire('supabase/functions/_shared/transport/email.ts');
    expect(transport).toContain('if (t === "mock") return true;');
    expect(transport).toMatch(/mailTransport === "smtp"/);
    expect(transport).toMatch(/Deno\.env\.get\("SMTP_SECURE"\)/);
  });
});
