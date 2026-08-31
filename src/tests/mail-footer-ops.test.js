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

const R = new URL('../../supabase/functions/_shared/', import.meta.url);

function charger(rel, stubs) {
  const code = transformSync(readFileSync(new URL(rel, R), 'utf8'), {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(stubs, mod, mod.exports);
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
  const i18n = charger('i18n/mail-strings.ts', () => ({}));
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

  it('le pied lectrice, lui, garde son téléphone — les deux publics coexistent', () => {
    const { footerPadrao } = chargerLayout();
    expect(footerPadrao(NETWORK_CTX, 'fr')).toContain('+00 000');
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

  it("sans footerTextLines, la version texte garde l'ancien pied — rien ne change pour les 14 autres fonctions", () => {
    const { renderEmail } = chargerLayout();
    const { text } = renderEmail({
      title: 'Un courriel lectrice ordinaire',
      introHtml: '<p>Bonjour.</p>',
      footerHtml: '',
      context: NETWORK_CTX,
      locale: 'fr',
    });
    expect(text).toContain('Téléphone: +00 000 000 000');
  });

  it('les dix locales répondent, sans fuite du portugais', () => {
    const { footerOps } = chargerLayout();
    expect(footerOps('pt-BR').html).toContain('Onde olhar');
    expect(footerOps('el').html).toContain('health-probe');
    expect(footerOps('de').html).not.toContain('Onde olhar');
  });
});
