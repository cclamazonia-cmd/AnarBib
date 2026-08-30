// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-internal-task-signature.test.js
//
// `notify-internal-task` ne partage pas son code d'envoi avec le reste du
// réseau : elle tourne sur une copie privée de la pile courriel
// (supabase/functions/notify-internal-task/_shared/, 9 fichiers d'infrastructure
// dupliqués, ~694 lignes d'écart avec le canonique — item F6 du backlog).
//
// Cette copie était restée à une version antérieure au chantier i18n layout :
// elle ne lisait que `signature_short`, le champ texte simple, et son
// `resolveMailRouting` n'acceptait même pas de locale. La BLMF ayant sa
// signature courte renseignée en six langues, ses avis de tâche interne
// partaient signés « Equipe da BLMF » à tout le monde, quand tous ses autres
// courriels disaient « L'équipe de la BLMF » à qui lit en français.
//
// Une divergence de ce genre ne se voit pas : le message part, il est
// simplement signé dans la mauvaise langue, et personne ne compare deux
// courriels envoyés par deux fonctions différentes. D'où ce test — il exerce le
// VRAI fichier (esbuild le transpile en mémoire, les deux imports sont stubés)
// sur le contexte réel de la BLMF, relevé en base le 30/08/2026.
//
// Le dernier cas est le plus important : sans locale, le comportement doit être
// exactement celui d'avant. Une correction qui change ce qu'elle ne devait pas
// toucher n'est pas une correction.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL(
  '../../supabase/functions/notify-internal-task/_shared/context/library-mail-routing.ts',
  import.meta.url,
);
const CODE = transformSync(readFileSync(SRC, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

function charger() {
  const requireStub = (spec) => {
    if (spec.includes('core/env')) return {
      ADMIN_EMAIL: 'admin@exemple.org', ADMIN_NAME: 'Coordination',
      FOOTER_TEXT: 'Pied de page par défaut', LOGO_URL: '',
      SENDER_EMAIL: 'no-reply@exemple.org', SENDER_NAME: 'AnarBib',
      supabaseAdmin: { storage: { from: () => ({ getPublicUrl: () => ({ data: { publicUrl: '' } }) }) } },
    };
    if (spec.includes('shared/branding')) return {
      replaceBrandTokens: (t) => t,
      resolvedBrandName: (c) => c?.library_short_name || 'AnarBib',
      resolvedSubjectTag: (c) => c?.library_short_name || 'AnarBib',
    };
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', CODE)(requireStub, mod, mod.exports);
  return mod.exports;
}

// Relevé le 30/08/2026 dans library_notification_profiles pour la BLMF.
const ctxBLMF = {
  library_short_name: 'BLMF',
  signature_short: 'Equipe da BLMF',
  signature_short_i18n: {
    'pt-BR': 'Equipe da BLMF',
    fr: "L'équipe de la BLMF",
    en: 'The BLMF team',
    es: 'El equipo de la BLMF',
    it: 'Il team della BLMF',
    de: 'Das BLMF-Team',
  },
  delivery_mode: 'platform_shared_local_reply',
  channel_active: true,
};

describe('la signature de pied de page suit la langue du message', () => {
  it('rend la signature localisée quand la locale est connue', () => {
    const { resolveMailRouting } = charger();
    expect(resolveMailRouting(ctxBLMF, 'fr').footerText).toBe("L'équipe de la BLMF");
    expect(resolveMailRouting(ctxBLMF, 'de').footerText).toBe('Das BLMF-Team');
    expect(resolveMailRouting(ctxBLMF, 'pt-BR').footerText).toBe('Equipe da BLMF');
  });

  it('replie sur signature_short pour une locale absente de la table', () => {
    const { resolveMailRouting } = charger();
    // `el` n'est pas dans les six langues renseignées par la BLMF.
    expect(resolveMailRouting(ctxBLMF, 'el').footerText).toBe('Equipe da BLMF');
  });

  it('sans locale, se comporte exactement comme avant la correction', () => {
    const { resolveMailRouting } = charger();
    expect(resolveMailRouting(ctxBLMF).footerText).toBe('Equipe da BLMF');
    expect(resolveMailRouting(ctxBLMF, null).footerText).toBe('Equipe da BLMF');
  });

  it('une biblio sans signature retombe sur le pied de page par défaut', () => {
    const { resolveMailRouting } = charger();
    const sansRien = { library_short_name: 'BTL', channel_active: true };
    expect(resolveMailRouting(sansRien, 'fr').footerText).toBe('Pied de page par défaut');
  });

  it('accepte une locale sans que la biblio ait de table i18n', () => {
    const { resolveMailRouting } = charger();
    const sansI18n = { library_short_name: 'MLEG', signature_short: 'Equipe MLEG', channel_active: true };
    expect(resolveMailRouting(sansI18n, 'fr').footerText).toBe('Equipe MLEG');
  });
});

describe("l'interrupteur d'envoi reste identique au module canonique", () => {
  // Ce que la copie NE doit pas perdre en divergeant : la regle d'extinction
  // du canal, verifiee identique octet pour octet le 30/08.
  it('coupe sur channel_active=false comme sur delivery_mode=disabled', () => {
    const { transportDisabledReason } = charger();
    expect(transportDisabledReason({ channel_active: false })).toBe('delivery_disabled');
    expect(transportDisabledReason({ delivery_mode: 'disabled' })).toBe('delivery_disabled');
    expect(transportDisabledReason({ delivery_mode: 'library_own_transport' })).toBe('missing_local_channel');
    expect(transportDisabledReason({ channel_active: true, delivery_mode: 'platform_shared' })).toBeNull();
  });
});
