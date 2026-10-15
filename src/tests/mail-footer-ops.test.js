// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-footer-ops.test.js
//
// Les courriels d'alerte d'exploitation — sonde en échec, sauvegarde
// incohérente — partaient avec le pied de page lectrice : « En cas de
// question, contacte la bibliothèque » suivi du numéro de téléphone. Le
// destinataire de ces messages EST l'exploitation : on lui disait de se
// téléphoner à soi-même (item F2).
//
// Ce test exerce le VRAI `layout.ts` (même harnais qu'à côté, dans
// mail-footer-regimento.test.js) avec un TÉLÉPHONE RENSEIGNÉ — c'est le cas
// de la production, où NETWORK_LIBRARIAN_PHONE existe. Il vérifie les deux
// moitiés du correctif, parce que la version texte de renderEmail fabrique
// son propre pied sans regarder `footerHtml` : corriger le HTML seul aurait
// laissé le téléphone dans la moitié des clients mail.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import { avecLocales } from './helpers/locales-ts.js';

const R = new URL('../../supabase/functions/_shared/', import.meta.url);

function charger(rel, stubs) {
  const code = transformSync(readFileSync(new URL(rel, R), 'utf8'), {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(avecLocales(stubs), mod, mod.exports);
  return mod.exports;
}

const PROJET = 'https://exemple.supabase.co';
// Téléphone volontairement RENSEIGNÉ : c'est l'état de la production, et
// c'est précisément ce que le pied d'exploitation doit savoir taire.
const envStub = {
  ADMIN_EMAIL: 'a@x.org', ADMIN_NAME: 'Coord', LOGO_URL: '',
  LIBRARIAN_PHONE: '+00 000 000 000',
  SENDER_EMAIL: 'no-reply@x.org', SENDER_NAME: 'AnarBib',
  supabaseAdmin: {
    storage: {
      from: (b) => ({
        getPublicUrl: (k) => ({ data: { publicUrl: `${PROJET}/storage/v1/object/public/${b}/${k}` } }),
      }),
    },
  },
};
const brandingStub = {
  replaceBrandTokens: (t) => t,
  resolvedBrandName: (c) => c?.library_short_name || 'AnarBib',
  resolvedSubjectTag: (c) => c?.library_short_name || 'AnarBib',
};

function chargerLayout() {
  const i18n = charger('i18n/mail-strings.ts', avecLocales(() => ({})));
  const routing = charger('context/library-mail-routing.ts', (spec) => {
    if (spec.includes('core/env')) return envStub;
    if (spec.includes('shared/branding')) return brandingStub;
    if (spec.includes('i18n/mail-strings')) return i18n;
    throw new Error(`import inattendu : ${spec}`);
  });
  return charger('mail/layout.ts', (spec) => {
    if (spec.includes('core/env')) return envStub;
    if (spec.includes('context/library-mail-routing')) return routing;
    if (spec.includes('shared/format')) return { esc: (t) => String(t ?? '') };
    if (spec.includes('i18n/mail-strings')) return i18n;
    throw new Error(`import inattendu : ${spec}`);
  });
}

// Le contexte des alertes réseau, tel que health-probe le construit.
const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared',
};

describe("le pied de page d'exploitation ne renvoie pas l'opératrice à elle-même", () => {
  it('footerOps : ni téléphone, ni « contacte la bibliothèque »', () => {
    const { footerOps } = chargerLayout();
    const fr = footerOps('fr').html;
    expect(fr).not.toContain('+00 000');
    expect(fr).not.toContain('Téléphone');
    expect(fr).not.toContain('contacte la bibliothèque');
    expect(fr).toContain('health-probe');
    expect(fr).toContain('service_health_incidents');
    expect(fr).toContain('acquitter');
  });

  // 16/10/2026 : le téléphone est celui de LA bibliothèque (public_phone du contexte),
  // jamais la variable globale LIBRARIAN_PHONE — posée ici exprès, elle ne doit plus sortir.
  const BIBLIO_CTX = { ...NETWORK_CTX, library_id: 'lib-a', library_short_name: 'BTL', public_phone: '+55 11 0000-0000' };

  it('le pied lectrice garde le téléphone DE SA BIBLIOTHÈQUE ; le réseau n’en a pas, le global jamais', () => {
    const { footerPadrao } = chargerLayout();
    const biblio = footerPadrao(BIBLIO_CTX, 'fr');
    expect(biblio).toContain('+55 11 0000-0000');
    expect(biblio).not.toContain('+00 000');
    expect(footerPadrao(NETWORK_CTX, 'fr')).not.toContain('+00 000');
    expect(footerPadrao(NETWORK_CTX, 'fr')).not.toContain('Téléphone');
    expect(footerPadrao({ ...BIBLIO_CTX, public_phone: null }, 'fr')).not.toContain('Téléphone');
  });

  it('la VERSION TEXTE suit : footerTextLines remplace téléphone et règlement', () => {
    const { renderEmail, footerOps } = chargerLayout();
    const ops = footerOps('fr');
    const { text } = renderEmail({
      title: 'AnarBib — sonde : incident',
      introHtml: '<p>La sonde ne répond plus.</p>',
      footerHtml: ops.html,
      footerTextLines: ops.textLines,
      context: NETWORK_CTX,
      locale: 'fr',
    });
    expect(text).not.toContain('+00 000');
    expect(text).not.toContain('Téléphone');
    expect(text).toContain('health-probe');
    expect(text).toContain('backup_heartbeats');
  });

  it("sans footerTextLines, la version texte porte le téléphone de la bibliothèque, comme le HTML", () => {
    const { renderEmail } = chargerLayout();
    const courriel = (context) => renderEmail({
      title: 'Un courriel lectrice ordinaire',
      introHtml: '<p>Bonjour.</p>',
      footerHtml: '',
      context,
      locale: 'fr',
    }).text;
    expect(courriel(BIBLIO_CTX)).toContain('Téléphone: +55 11 0000-0000');
    expect(courriel(BIBLIO_CTX)).not.toContain('+00 000');
    expect(courriel(NETWORK_CTX)).not.toContain('Téléphone');
  });

  it('la ligne finale ne répète pas « AnarBib » : un courriel réseau dit qu’il vient du réseau', () => {
    const { renderEmail } = chargerLayout();
    const { html, text } = renderEmail({ title: 'T', introHtml: '<p>x</p>', footerHtml: '', context: NETWORK_CTX, locale: 'fr' });
    expect(text.trim().split('\n').pop()).toBe('Message automatique du réseau AnarBib.');
    expect(html).not.toContain('AnarBib — AnarBib');
  });

  it('les dix locales répondent, sans fuite du portugais', () => {
    const { footerOps } = chargerLayout();
    expect(footerOps('pt-BR').html).toContain('Onde olhar');
    expect(footerOps('el').html).toContain('health-probe');
    expect(footerOps('de').html).not.toContain('Onde olhar');
  });
});
