// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/gazette-decision-mail.test.js
//
// Banc du handler gazette.* de notify-event (supabase/functions/_shared/domain/
// gazette.ts), même harnais que notify-oai-opening.test.js : le VRAI module est
// transpilé en mémoire, `mail-strings.ts` aussi (il porte les 10 locales) ; la
// base, le rendu HTML et l'envoi sont stubés — `safeSendEmail` et `renderEmail`
// servent de mouchards : on lit qui reçoit quoi, dans quelle langue, avec quel
// lien.
//
// CE QUI EST GARDÉ ICI (GAZ-7, 15/09/2026) : la décision est dite à la personne
// qui a écrit, dans SA langue, avec le motif tel quel et un lien de reprise qui
// porte le jeton ; sans adresse, la ligne est sautée EN LE DISANT (DOC-SILENCE-1)
// et non marquée « envoyée » ; l'avis au réseau d'une reprise dit qu'elle en est
// une.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/_shared/domain/gazette.ts', import.meta.url);
const STRINGS = new URL('../../supabase/functions/_shared/i18n/mail-strings.ts', import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CODE = cjs(SRC);
const STRINGS_CODE = cjs(STRINGS);

const JETON = 'c'.repeat(64);

function monter(outbox) {
  const envois = [];
  const rendus = [];
  const ecrits = [];

  const table = (nom) => {
    const chaine = [];
    const proxy = new Proxy({}, {
      get(_c, prop) {
        if (prop === 'then') return (ok) => ok(repondre(nom, chaine));
        return (...args) => {
          chaine.push({ op: prop, args });
          if (prop === 'update') ecrits.push({ table: nom, donnees: args[0] });
          return proxy;
        };
      },
    });
    return proxy;
  };
  const repondre = (nom, chaine) => {
    if (nom === 'gazette_submission_notification_outbox') {
      if (chaine.some((c) => c.op === 'update')) return { data: null, error: null };
      const [, id] = chaine.find((c) => c.op === 'eq')?.args ?? [];
      return { data: outbox.find((o) => o.id === id) ?? null, error: null };
    }
    return { data: [], error: null };
  };

  const DenoStub = { env: { get: () => undefined } };
  const requireStub = (spec) => {
    if (spec.endsWith('i18n/mail-strings.ts')) return evaluer(STRINGS_CODE);
    if (spec.endsWith('context/library-notification-context.ts')) {
      return { resolveLibraryNotificationContext: async () => ({ default_locale: 'pt-BR' }) };
    }
    if (spec.endsWith('core/env.ts')) return { supabaseAdmin: { from: table } };
    if (spec.endsWith('mail/layout.ts')) {
      return {
        renderEmail: (opts) => { rendus.push(opts); return { html: opts.introHtml, text: '' }; },
        footerPadrao: () => '',
      };
    }
    if (spec.endsWith('transport/email.ts')) {
      return {
        safeSendEmail: async (cible, sujet, html) => { envois.push({ email: cible.email, nom: cible.name, sujet, html }); return { sent: 1 }; },
        userTargetFromProfile: (p) => (p?.email ? { email: p.email, name: p.first_name } : null),
      };
    }
    throw new Error(`import inattendu : ${spec}`);
  };
  function evaluer(code) {
    const mod = { exports: {} };
    new Function('require', 'module', 'exports', 'Deno', code)(requireStub, mod, mod.exports, DenoStub);
    return mod.exports;
  }
  const { handleGazetteEvent } = evaluer(CODE);

  return async function traiter(id) {
    envois.length = 0; rendus.length = 0; ecrits.length = 0;
    const resultat = await handleGazetteEvent(id);
    const statutOutbox = ecrits.find((e) => e.table === 'gazette_submission_notification_outbox')?.donnees ?? null;
    return { resultat, envois: [...envois], rendus: [...rendus], statutOutbox };
  };
}

const rejet = (over = {}) => ({
  id: 1, status: 'queued', event: 'gazette.contribution.rejected',
  payload: {
    to: 'louise@test.local', to_name: 'Louise', locale: 'fr', submission_id: 'sub-1', rubric: 'reseau',
    title: 'Ma brève', review_note: 'Trop long : 300 mots maximum.\nEt sans le lien vers le tract.',
    resubmit_token: JETON, expires_at: '2026-11-14T19:35:25Z',
    ...over,
  },
});

describe('gazette.contribution.rejected — la décision est dite, dans la langue de la personne', () => {
  it('un courriel à la personne, en français, avec le motif tel quel et le lien de reprise porteur du jeton', async () => {
    const traiter = monter([rejet()]);
    const r = await traiter(1);
    expect(r.envois).toHaveLength(1);
    expect(r.envois[0].email).toBe('louise@test.local');
    expect(r.envois[0].nom).toBe('Louise');
    expect(r.envois[0].sujet).toContain('Ta brève « Ma brève »');
    // le motif, tel que le staff l'a écrit (échappé, sauts de ligne conservés)
    expect(r.envois[0].html).toContain('Trop long : 300 mots maximum.\nEt sans le lien vers le tract.');
    // le lien de reprise porte le jeton, vers l'onglet Gazette
    const box = r.rendus[0].actionBox;
    expect(box).toBeTruthy();
    expect(box.kind).toBe('action');
    expect(box.ctaUrl).toBe(`https://app.anarbib.org/federacao/gazeta?reprise=${JETON}`);
    expect(box.ctaLabel).toBe('Corriger et renvoyer');
    // l'échéance est dite, dans le corps
    expect(r.envois[0].html).toMatch(/jusqu'au .*2026/);
    expect(r.statutOutbox).toMatchObject({ status: 'sent' });
    expect(r.resultat.recipients_count).toBe(1);
  });

  it('la langue est celle de la brève : en grec, le sujet est grec', async () => {
    const traiter = monter([rejet({ locale: 'el' })]);
    const r = await traiter(1);
    expect(r.envois[0].sujet).toContain('δεν κρατήθηκε');
    expect(r.rendus[0].actionBox.ctaLabel).toBe('Διόρθωση και επαναποστολή');
  });

  it('sans locale, repli sur la langue de base du réseau (pt-BR), jamais une clé brute', async () => {
    const traiter = monter([rejet({ locale: null })]);
    const r = await traiter(1);
    expect(r.envois[0].sujet).toContain('Tua nota');
    expect(r.envois[0].sujet).not.toContain('gazette.contribution');
  });

  it('sans adresse : rien n’est envoyé, la ligne est SAUTÉE en le disant, pas marquée envoyée', async () => {
    const traiter = monter([rejet({ to: '' })]);
    const r = await traiter(1);
    expect(r.envois).toHaveLength(0);
    expect(r.statutOutbox).toMatchObject({ status: 'skipped', skip_reason: 'no_recipients' });
    expect(r.statutOutbox.sent_at).toBeUndefined();
  });

  it('le HTML du motif est échappé : un motif qui contient une balise ne l’injecte pas', async () => {
    const traiter = monter([rejet({ review_note: '<script>alert(1)</script> trop long' })]);
    const r = await traiter(1);
    expect(r.envois[0].html).not.toContain('<script>');
    expect(r.envois[0].html).toContain('&lt;script&gt;');
  });
});

describe('gazette.contribution.accepted — la bonne nouvelle aussi', () => {
  it('un courriel à la personne, dans sa langue, avec le lien vers la gazette', async () => {
    const traiter = monter([{
      id: 2, status: 'queued', event: 'gazette.contribution.accepted',
      payload: { to: 'louise@test.local', to_name: 'Louise', locale: 'es', submission_id: 'sub-1', rubric: 'reseau', title: 'Mi nota' },
    }]);
    const r = await traiter(2);
    expect(r.envois).toHaveLength(1);
    expect(r.envois[0].sujet).toContain('Tu nota « Mi nota »');
    expect(r.envois[0].html).toContain('https://app.anarbib.org/federacao/gazeta');
    expect(r.rendus[0].actionBox).toBeUndefined();
    expect(r.statutOutbox).toMatchObject({ status: 'sent' });
    expect(r.envois[0].html).not.toContain('correcciones');
  });

  it('retenue AVEC corrections du staff (GAZ-9) : le courriel le dit et montre le texte qui paraîtra', async () => {
    const traiter = monter([{
      id: 4, status: 'queued', event: 'gazette.contribution.accepted',
      payload: { to: 'louise@test.local', to_name: 'Louise', locale: 'fr', submission_id: 'sub-1', rubric: 'reseau',
        title: 'Titre corrigé', body: 'Corps corrigé.\nDeuxième ligne.', corrected: true },
    }]);
    const r = await traiter(4);
    expect(r.envois).toHaveLength(1);
    expect(r.envois[0].html).toContain("L'équipe a apporté quelques corrections");
    expect(r.envois[0].html).toContain('<b>Titre corrigé</b>');
    expect(r.envois[0].html).toContain('Corps corrigé.\nDeuxième ligne.');
  });
});

describe('gazette.contribution.received — l’avis au réseau d’une reprise dit qu’elle en est une', () => {
  const recu = (over = {}) => ({
    id: 3, status: 'queued', event: 'gazette.contribution.received',
    payload: { to: 'fede@anarbib.org', locale: 'fr', rubric: 'reseau', title: 'Ma brève (v2)', excerpt: 'Plus court.', contributor_name: 'Louise', ...over },
  });

  it('avec parent_submission_id : la ligne « reprise » est dans le corps', async () => {
    const traiter = monter([recu({ parent_submission_id: 'sub-1' })]);
    const r = await traiter(3);
    expect(r.envois).toHaveLength(1);
    expect(r.envois[0].email).toBe('fede@anarbib.org');
    expect(r.envois[0].html).toContain("Reprise d'une brève rejetée précédemment");
  });

  it('sans parent : rien de plus qu’avant', async () => {
    const traiter = monter([recu()]);
    const r = await traiter(3);
    expect(r.envois[0].html).not.toContain('Reprise');
  });
});

describe('mail-strings — les nouvelles clés existent dans les 10 locales', () => {
  it('chaque clé GAZ-7 est complète', () => {
    const strings = (() => {
      const mod = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', STRINGS_CODE)(() => ({}), mod, mod.exports, {});
      return mod.exports;
    })();
    const cles = [
      'gazette.contribution.received.resubmitted',
      'gazette.contribution.rejected.sub', 'gazette.contribution.rejected.intro',
      'gazette.contribution.rejected.resubmit.title', 'gazette.contribution.rejected.resubmit.cta',
      'gazette.contribution.rejected.resubmit.expires',
      'gazette.contribution.accepted.sub', 'gazette.contribution.accepted.intro',
      'gazette.contribution.accepted.corrected',
    ];
    for (const k of cles) expect(strings._isComplete(k), k).toBe(true);
  });
});
