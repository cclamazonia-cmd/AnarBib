// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-transport-routage.test.js
//
// CE QUE CE TEST PROTÈGE (F7, second critère — 23/09/2026).
// Huit fonctions portaient chacune leur copie de l'appel à Resend. On les
// ramène une par une sur `_shared/transport/email.ts`. Le danger de ce
// regroupement n'est pas la panne : c'est le glissement silencieux d'en-tête.
// Chaque fonction a sa politique d'expéditeur, et deux d'entre elles n'ont
// JAMAIS envoyé de `Reply-To` — `notify-rede-digest` n'en a jamais posé, et
// `notify-library-request` l'a vu retirer exprès par F14 (22/09/2026), parce
// qu'une adresse de réponse hors du domaine d'envoi fait passer le message pour
// une usurpation. Si la consolidation rajoutait cet en-tête, rien ne casserait,
// rien ne serait rouge, et nos messages commenceraient à tomber en indésirable.
//
// On vérifie donc ce que le transport MET DANS LE PAYLOAD, pas qu'il marche.

import { describe, it, expect, beforeEach } from 'vitest';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { transformSync } from 'esbuild';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const FONCTIONS = path.join(RACINE, 'supabase', 'functions');

let dernierEnvoi = null;

function chargeTransport(env = { RESEND_API_KEY: 'cle-de-banc' }) {
  const src = readFileSync(path.join(FONCTIONS, '_shared/transport/email.ts'), 'utf8');
  const code = transformSync(src, { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

  const stubs = {
    'library-mail-routing': {
      resolveMailRouting: () => ({
        senderEmail: 'contexte@exemple.test',
        senderName: 'Routage du contexte',
        replyToEmail: 'reponse-du-contexte@exemple.test',
        replyToName: 'Reponse du contexte',
      }),
      transportDisabledReason: () => null,
    },
    layout: { renderEmail: () => ({ html: '', text: '' }), footerPadrao: () => '' },
    'inline-images': { inlineLogosInHtml: async (h) => h },
    format: {
      firstNameOnly: (x) => x,
      fullName: (x) => x,
      isValidEmail: (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || '')),
    },
    smtp: { sendViaSmtp: async () => 'smtp-ok', resolveTimeout: () => 15000 },
  };
  const requireDetourne = (id) => {
    const cle = Object.keys(stubs).find((k) => id.includes(k));
    if (!cle) throw new Error('module non prevu par le banc : ' + id);
    return stubs[cle];
  };

  dernierEnvoi = null;
  globalThis.fetch = async (url, init) => {
    dernierEnvoi = { url: String(url), payload: JSON.parse(init.body) };
    return { ok: true, status: 200, text: async () => '{"id":"banc"}' };
  };

  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', code)(
    requireDetourne, mod, mod.exports, { env: { get: (k) => env[k] ?? '' } },
  );
  return mod.exports;
}

const CORPS = { subject: 'Sujet', html: '<p>corps</p>', text: 'corps' };

describe('transport partage — le routage explicite l emporte sur le contexte', () => {
  beforeEach(() => { dernierEnvoi = null; });

  it('utilise le routage passe en argument pour le From, pas celui du contexte', async () => {
    const { sendEmail } = chargeTransport();
    await sendEmail({
      toEmail: 'dest@exemple.test',
      ...CORPS,
      routing: { senderEmail: 'biblio@exemple.test', senderName: 'Biblioteca Libertária' },
    });
    expect(dernierEnvoi.url).toBe('https://api.resend.com/emails');
    expect(dernierEnvoi.payload.from).toBe('Biblioteca Libertária <biblio@exemple.test>');
    expect(dernierEnvoi.payload.from).not.toContain('contexte@exemple.test');
  });

  it('noReplyTo coupe l adresse de reponse meme si le routage en porte une', async () => {
    const { sendEmail } = chargeTransport();
    await sendEmail({
      toEmail: 'dest@exemple.test',
      ...CORPS,
      routing: {
        senderEmail: 'biblio@exemple.test',
        senderName: 'Rede',
        replyToEmail: 'humain@exemple.test',
        replyToName: 'Humain',
        noReplyTo: true,
      },
    });
    expect(dernierEnvoi.payload.reply_to).toBeUndefined();
  });

  it('garde le Reply-To quand le routage en donne un sans noReplyTo', async () => {
    const { sendEmail } = chargeTransport();
    await sendEmail({
      toEmail: 'dest@exemple.test',
      ...CORPS,
      routing: { senderEmail: 'a@exemple.test', senderName: 'A', replyToEmail: 'b@exemple.test', replyToName: 'B' },
    });
    expect(dernierEnvoi.payload.reply_to).toBe('B <b@exemple.test>');
  });

  it('sans routage explicite, retombe sur le routage du contexte (comportement d origine)', async () => {
    const { sendEmail } = chargeTransport();
    await sendEmail({ toEmail: 'dest@exemple.test', ...CORPS, context: { library_id: 'peu importe' } });
    expect(dernierEnvoi.payload.from).toBe('Routage du contexte <contexte@exemple.test>');
    expect(dernierEnvoi.payload.reply_to).toBe('Reponse du contexte <reponse-du-contexte@exemple.test>');
  });

  it('sans service configure, leve — le silence reste interdit (DOC-SILENCE-1)', async () => {
    const { sendEmail } = chargeTransport({});
    await expect(
      sendEmail({ toEmail: 'dest@exemple.test', ...CORPS, routing: { senderEmail: 'a@b.test', senderName: 'A' } }),
    ).rejects.toThrow(/Aucun service/);
  });
});

// ─── Liste FERMÉE : qui a encore le droit d'appeler Resend en direct ────────
// Elle ne doit que retrecir. Une fonction convertie sort de la liste ; une
// fonction neuve qui recopierait l'appel fait rougir ce test au lieu de
// s'installer sans bruit.
const ENCORE_EN_DIRECT = [
  'request-password-reset',
];

describe('F7 — une seule implementation d envoi', () => {
  it('seules les fonctions de la liste fermee citent encore api.resend.com', () => {
    const coupables = readdirSync(FONCTIONS)
      .filter((d) => !d.startsWith('_') && existsSync(path.join(FONCTIONS, d, 'index.ts')))
      .filter((d) => readFileSync(path.join(FONCTIONS, d, 'index.ts'), 'utf8').includes('api.resend.com'))
      .sort();
    expect(coupables).toEqual(ENCORE_EN_DIRECT);
  });

  it('les fonctions converties passent bien par le module partage', () => {
    for (const f of [
      'notify-weekly-report', 'notify-network-weekly-report', 'notify-rede-digest',   // lot 1, 23/09
      'notify-document-permission-request', 'notify-mid-loan-reading',               // lot 2, 24/09
      'notify-library-request', 'register',                                        // lot 3, 24/09
    ]) {
      const src = readFileSync(path.join(FONCTIONS, f, 'index.ts'), 'utf8');
      expect(src).not.toContain('api.resend.com');
      expect(src).toContain('_shared/transport/email.ts');
    }
  });
});
