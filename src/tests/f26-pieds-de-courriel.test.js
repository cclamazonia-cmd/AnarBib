// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/f26-pieds-de-courriel.test.js
//
// F26 (19/10/2026) — « Retirer des pieds de courriel le repli en portugais et le
// secret supprimé ». Le 16/10, le pied des courriels a été mis en commun et
// localisé (layout.footerText / layout.footerTextNetwork) ; la devise globale
// FOOTER_TEXT n'était plus lue, et le secret a été SUPPRIMÉ le 19/10. Quatre
// fonctions construisaient encore leur propre pied en lisant ce secret (ou
// NETWORK_FOOTER_TEXT), et tombaient donc sur un repli écrit en dur en portugais :
//   notify-library-request, notify-rede-digest, notify-network-weekly-report,
//   notify-document-permission-request.
// La quatrième était en outre rédigée ENTIÈREMENT en pt-BR, dans le code, alors
// qu'elle écrit aux coordinations de deux bibliothèques et aux admins réseau :
// elle passe par tMail (clés docperm.*), dans la langue de chaque destinataire.
//
// Ce banc tient les trois promesses : (1) aucune des quatre ne lit plus la devise
// ni n'imprime de repli portugais ; (2) les clés docperm.* existent dans les onze
// langues, et aucune n'est la copie du pt-BR ; (3) la quatrième, exécutée pour de
// vrai (helpers/monter-ef.js), parle à chacun·e sa langue, pied compris.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { join } from 'path';
import { monterEF, mailA, FONCTIONS } from './helpers/monter-ef.js';

const QUATRE = [
  'notify-library-request/index.ts',
  'notify-rede-digest/index.ts',
  'notify-network-weekly-report/index.ts',
  'notify-document-permission-request/index.ts',
];

/** Le source sans ses commentaires : un commentaire qui raconte l'histoire n'est pas une lecture. */
const code = (rel) => readFileSync(join(FONCTIONS, rel), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/(^|[^:])\/\/.*$/gm, '$1');

// Les trois replis d'avant, mot pour mot, et la phrase de la quatrième.
const REPLIS_PT = [
  'Em caso de dúvida, responda a este e-mail.',
  'AnarBib — Rede de bibliotecas libertárias.',
  'Mensagem automática de coordenação do AnarBib.',
];

describe('F26 — les quatre fonctions ne lisent plus la devise globale', () => {
  for (const rel of QUATRE) {
    it(`${rel} : ni FOOTER_TEXT, ni NETWORK_FOOTER_TEXT, ni repli portugais`, () => {
      const src = code(rel);
      expect(src).not.toMatch(/FOOTER_TEXT/);
      for (const repli of REPLIS_PT) expect(src).not.toContain(repli);
      // le pied commun, et lui seul
      expect(src).toContain('layout.footerTextNetwork');
    });
  }

  it('notify-weekly-report n’importe plus la devise (import mort retiré)', () => {
    expect(code('notify-weekly-report/index.ts')).not.toMatch(/\bFOOTER_TEXT\b/);
  });

  it('la clé `footer` de notify-library-request/strings.ts (« réponds à cet e-mail ») a disparu', () => {
    const src = readFileSync(join(FONCTIONS, 'notify-library-request/strings.ts'), 'utf8');
    expect(src).not.toMatch(/^\s*"?footer"?\s*:/m);
  });
});

// Prose portugaise dans les littéraux : les mots que le courriel d'avant portait.
const PROSE_PT = /\b(bibliotecas?|consulta|troca|solicitante|destinat[aá]ria|registrad[ao]|aceit[ao]|recusad[ao]|mensagem|observa[cç][aã]o|exemplar(?:es)?|resposta|regimento|abrir|d[uú]vida|acervos?)\b/i;

function litteraux(src) {
  const morceaux = new Set();
  for (const m of src.matchAll(/>([^<>{}`]+)</g)) morceaux.add(m[1]);
  for (const m of src.matchAll(/"((?:[^"\\\n]|\\.)+)"|'((?:[^'\\\n]|\\.)+)'|`([^`]+)`/g)) {
    const s = (m[1] || m[2] || m[3]).replace(/\$\{[^}]*\}/g, ' ').replace(/<[^>]*>/g, '\n');
    for (const bout of s.split('\n')) morceaux.add(bout);
  }
  return [...morceaux].map((t) => t.replace(/\s+/g, ' ').trim()).filter((t) => /\p{L}+\s+\p{L}+/u.test(t));
}

describe('F26 — notify-document-permission-request n’a plus de texte portugais en dur', () => {
  it('aucun littéral ne porte de prose portugaise', () => {
    const fautes = litteraux(code('notify-document-permission-request/index.ts')).filter((t) => PROSE_PT.test(t));
    expect(fautes, fautes.join('\n')).toEqual([]);
  });

  it('contre-épreuve : la garde voit les phrases d’avant', () => {
    for (const avant of ['Consulta de troca documental interbibliotecas', 'Biblioteca destinatária',
      'Observação registrada pela biblioteca destinatária:', 'Manual / regimento da rede: abrir', 'aceita', 'recusada']) {
      expect(PROSE_PT.test(avant), avant).toBe(true);
    }
  });
});

const mail = monterEF().charger('_shared/i18n/mail-strings.ts');
const LOCALES = mail._supportedLocales();
const CLES = mail._allKeys().filter((k) => k.startsWith('docperm.'));

describe('F26 — les clés docperm.* dans les onze langues', () => {
  it('onze langues, et un jeu de clés non vide', () => {
    expect(LOCALES).toHaveLength(11);
    expect(CLES.length).toBeGreaterThanOrEqual(35);
  });

  it('chaque clé est traduite dans toutes les langues', () => {
    const incompletes = CLES.filter((k) => !mail._isComplete(k));
    expect(incompletes).toEqual([]);
  });

  it('chaque clé citée par la fonction existe (y compris accepted/refused)', () => {
    const src = code('notify-document-permission-request/index.ts');
    const citees = new Set([...src.matchAll(/["'`](docperm\.[A-Za-z_.]+)["'`]/g)].map((m) => m[1]));
    for (const m of src.matchAll(/`docperm\.\$\{issue\}\.([A-Za-z_]+)`/g)) {
      citees.add(`docperm.accepted.${m[1]}`);
      citees.add(`docperm.refused.${m[1]}`);
    }
    if (/`docperm\.verdict\.\$\{issue\}`/.test(src)) ['accepted', 'refused'].forEach((i) => citees.add(`docperm.verdict.${i}`));
    expect(citees.size).toBeGreaterThan(20);
    const absentes = [...citees].filter((k) => !CLES.includes(k));
    expect(absentes).toEqual([]);
  });

  it('aucune phrase n’est la copie du pt-BR dans une autre langue', () => {
    const copies = [];
    for (const k of CLES) {
      const pt = mail.tMailTexte('pt-BR', k);
      if (pt.length <= 25 || !/\s/.test(pt)) continue;
      for (const l of LOCALES) if (l !== 'pt-BR' && mail.tMailTexte(l, k) === pt) copies.push(`${k} [${l}]`);
    }
    expect(copies).toEqual([]);
  });

  it('pt-BR au « você » : ni « tu » européen ni impératif à la 2e personne du singulier', () => {
    const fautes = CLES.map((k) => [k, mail.tMailTexte('pt-BR', k)]).filter(([, v]) => /\b(tu|teu|tua|contigo|responde|vós|vosso)\b/i.test(v));
    expect(fautes).toEqual([]);
  });

  it('français sans vouvoiement (ni « vous », ni impératif en -ez)', () => {
    const fautes = CLES.map((k) => [k, mail.tMailTexte('fr', k)]).filter(([, v]) => /\b(vous|votre|vos)\b|\b\p{L}+ez\b/iu.test(v));
    expect(fautes).toEqual([]);
  });
});

// ─── La fonction exécutée ─────────────────────────────────────────────────────
const SECRET = 'secret-docperm';
const DEMANDE = {
  id: 'dpr-1', requester_library_id: 'lib-a', target_library_id: 'lib-b',
  requested_action: 'proposta_troca_exemplares', object_type: 'books',
  object_ref: JSON.stringify({ local_document: { titulo: "L'Homme & la Terre", autor: 'RECLUS, Élisée', exemplar_count: 2 }, partner_document: { titulo: 'Dieu et l’État', exemplar_count: 1 } }),
  message: 'Une proposition <entre nous>.', status: 'pending', response_note: null,
  created_at: '2026-10-19T10:00:00Z', decided_at: null,
};
const ADMIN = { id: 'u-adm', email: 'admin@exemplo.test', first_name: 'Ravachol', preferred_language: 'de' };

function monter({ demande = DEMANDE, env = {}, localesEnErreur = false } = {}) {
  return monterEF({
    entree: 'notify-document-permission-request/index.ts',
    env: {
      WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST: SECRET, SENDER_EMAIL: 'no-reply@exemplo.test', BRAND_NAME: 'AnarBib',
      FOOTER_TEXT: 'Devise globale à ne plus lire', NETWORK_FOOTER_TEXT: 'Devise réseau à ne plus lire', ...env,
    },
    repondre: (_s, table) => {
      if (table === 'document_permission_requests') return { data: demande, error: null };
      if (table === 'libraries') return { data: [{ id: 'lib-a', name: 'Bibliothèque A', short_name: 'BLA' }, { id: 'lib-b', name: 'Bibliotheek B', short_name: 'BB' }], error: null };
      if (table === 'library_contact_profiles') return { data: [
        { library_id: 'lib-a', contact_name: 'Louise Michel', contact_role: null, contact_email: 'a@exemplo.test' },
        { library_id: 'lib-b', contact_name: 'Domela Nieuwenhuis', contact_role: null, contact_email: 'b@exemplo.test' },
      ], error: null };
      if (table === 'v_library_notification_context') {
        if (localesEnErreur) return { data: null, error: { message: 'vue indisponible' } };
        return { data: [{ library_id: 'lib-a', default_locale: 'fr' }, { library_id: 'lib-b', default_locale: 'nl' }], error: null };
      }
      if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
      if (table === 'profiles') return { data: [ADMIN], error: null };
      return { data: null, error: null };
    },
  });
}
const POST = (event_type) => new Request('http://stub/functions/v1/notify-document-permission-request', {
  method: 'POST', headers: { 'content-type': 'application/json', 'x-webhook-secret': SECRET },
  body: JSON.stringify({ request_id: DEMANDE.id, event_type }),
});
const noms = { requester: 'BLA', target: 'BB' };

function sansDevise(envois) {
  for (const e of envois) {
    expect(e.html).not.toMatch(/Devise (globale|réseau)/);
    for (const repli of REPLIS_PT) expect(e.html).not.toContain(repli);
    expect(e.text).not.toMatch(/&#0?39;|&amp;/);
  }
}

describe('F26 — notify-document-permission-request parle la langue de chaque destinataire', () => {
  it('création : bibliothèque destinataire en nl, demandeuse en fr, admin en de, boîte collective en pt-BR', async () => {
    const ef = monter({ env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    const { statut, corps } = await ef.appeler(POST('document_permission_request_created'));
    expect(statut).toBe(200);
    expect(corps.ok).toBe(true);
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['a@exemplo.test', 'admin@exemplo.test', 'admins@exemplo.test', 'b@exemplo.test']);

    const cible = mailA(ef.envois, 'b@exemplo.test');
    expect(cible.subject).toBe(`[AnarBib] ${mail.tMailTexte('nl', 'docperm.created.subject', noms)}`);
    expect(cible.html).toContain('<html lang="nl">');
    expect(cible.html).toContain(mail.tMailTexte('nl', 'layout.footerTextNetwork'));
    expect(cible.html).toContain(mail.tMailTexte('nl', 'docperm.lbl.localDoc'));
    expect(cible.html).toContain(mail.tMailTexte('nl', 'docperm.action.proposta_troca_exemplares'));
    expect(cible.html).toContain('Une proposition &lt;entre nous&gt;.');
    expect(cible.text).toContain(`L'Homme & la Terre — RECLUS, Élisée — ${mail.tMailTexte('nl', 'docperm.doc.copies', { count: 2 })}`);

    const accuse = mailA(ef.envois, 'a@exemplo.test');
    expect(accuse.subject).toBe(`[AnarBib] ${mail.tMailTexte('fr', 'docperm.ack.subject', noms)}`);
    expect(accuse.html).toContain('<html lang="fr">');
    expect(accuse.html).toContain('Message automatique du réseau AnarBib.');
    expect(accuse.text).toContain(mail.tMailTexte('fr', 'docperm.ack.p3'));
    expect(accuse.text).toContain(mail.tMailTexte('fr', 'greeting.named', { name: 'Louise' }));

    expect(mailA(ef.envois, 'admin@exemplo.test').subject).toBe(`[AnarBib] ${mail.tMailTexte('de', 'docperm.created.subject', noms)}`);
    expect(mailA(ef.envois, 'admins@exemplo.test').subject).toBe(`[AnarBib] ${mail.tMailTexte('pt-BR', 'docperm.created.subject', noms)}`);
    sansDevise(ef.envois);
    for (const e of ef.envois) expect(e.reply_to ?? null).toBeNull();
  });

  it('acceptation sans remarque : chaque bibliothèque dans sa langue, phrase « pas de remarque »', async () => {
    const ef = monter({ demande: { ...DEMANDE, status: 'accepted', decided_at: '2026-10-19T12:00:00Z' } });
    await ef.appeler(POST('document_permission_request_accepted'));
    expect(ef.envois).toHaveLength(2);
    const fr = mailA(ef.envois, 'a@exemplo.test');
    const nl = mailA(ef.envois, 'b@exemplo.test');
    expect(fr.subject).toBe(`[AnarBib] ${mail.tMailTexte('fr', 'docperm.decision.subject', { target: 'BB', verdict: mail.tMailTexte('fr', 'docperm.verdict.accepted') })}`);
    expect(fr.text).toContain(mail.tMailTexte('fr', 'docperm.accepted.p2'));
    expect(fr.text).toContain(mail.tMailTexte('fr', 'docperm.lbl.decidedAt'));
    expect(nl.subject).toContain(mail.tMailTexte('nl', 'docperm.verdict.accepted'));
    expect(nl.html).toContain(mail.tMailTexte('nl', 'docperm.module'));
    sansDevise(ef.envois);
  });

  it('refus avec remarque : la remarque est citée, échappée', async () => {
    const ef = monter({ demande: { ...DEMANDE, status: 'refused', response_note: 'Pas cette fois & merci', decided_at: '2026-10-19T12:00:00Z' } });
    await ef.appeler(POST('document_permission_request_refused'));
    const fr = mailA(ef.envois, 'a@exemplo.test');
    expect(fr.text).toContain(mail.tMailTexte('fr', 'docperm.refused.title'));
    expect(fr.html).toContain('Pas cette fois &amp; merci');
    expect(fr.text).toContain(mail.tMailTexte('fr', 'docperm.noteIntro'));
    sansDevise(ef.envois);
  });

  it('langue des bibliothèques illisible : l’avis part quand même, dans la langue de référence', async () => {
    const ef = monter({ localesEnErreur: true });
    const { statut } = await ef.appeler(POST('document_permission_request_created'));
    expect(statut).toBe(200);
    expect(mailA(ef.envois, 'b@exemplo.test').subject).toBe(`[AnarBib] ${mail.tMailTexte('pt-BR', 'docperm.created.subject', noms)}`);
  });
});

// ─── Suite de F26 (20/10/2026) : le rapport hebdomadaire du réseau ──────────────
// notify-network-weekly-report était composé en pt-BR seul, dans le code (son
// pied suivait donc le pt-BR). Il se rend désormais dans la langue de chaque
// destinataire : clés net.*, une composition par langue.
const PROSE_PT_RAPPORT = /\b(relat[oó]rio|semanal|bibliotecas?|empr[eé]stimos?|devolu[cç][oõ]es|renova[cç][oõ]es|atrasos?|inscri[cç][oõ]es|sa[ií]das|caixa|desativad[oa]s?|plataforma|coordena[cç][aã]o|s[ií]ntese|criad[oa]s?|propostas?|pontos|aten[cç][aã]o|configura[cç][aã]o)\b/i;
const CLES_NET = mail._allKeys().filter((k) => k.startsWith('net.'));

describe('suite de F26 — notify-network-weekly-report n’a plus de texte portugais en dur', () => {
  it('aucun littéral ne porte de prose portugaise', () => {
    const fautes = litteraux(code('notify-network-weekly-report/index.ts')).filter((t) => PROSE_PT_RAPPORT.test(t));
    expect(fautes, fautes.join('\n')).toEqual([]);
  });

  it('contre-épreuve : la garde voit les phrases d’avant', () => {
    for (const avant of ['Relatório semanal da rede', 'Bibliotecas com caixa semanal local', 'Pontos de atenção de configuração',
      'sem e-mail de relatório semanal', 'Coordenação de rede', 'Transporte próprio da biblioteca']) {
      expect(PROSE_PT_RAPPORT.test(avant), avant).toBe(true);
    }
  });

  it('les clés net.* : complètes dans les onze langues, aucune copie du pt-BR', () => {
    expect(CLES_NET.length).toBeGreaterThanOrEqual(55);
    expect(CLES_NET.filter((k) => !mail._isComplete(k))).toEqual([]);
    const copies = [];
    for (const k of CLES_NET) {
      const pt = mail.tMailTexte('pt-BR', k);
      if (pt.length <= 25 || !/\s/.test(pt)) continue;
      for (const l of LOCALES) if (l !== 'pt-BR' && mail.tMailTexte(l, k) === pt) copies.push(`${k} [${l}]`);
    }
    expect(copies).toEqual([]);
  });

  it('chaque clé citée par la fonction existe, et chaque statut de prêt a son libellé', () => {
    const src = code('notify-network-weekly-report/index.ts');
    const citees = [...src.matchAll(/["'](net\.[A-Za-z_.]+[A-Za-z_])["']/g)].map((m) => m[1]);
    expect(citees.length).toBeGreaterThan(40);
    expect(citees.filter((k) => !CLES_NET.includes(k))).toEqual([]);
    for (const s of ['preparacao', 'aguardando_saida', 'emprestado', 'parcialmente_devolvido', 'em_devolucao', 'devolvido', 'cancelado', 'atrasado']) {
      expect(CLES_NET, s).toContain(`net.ill.${s}`);
    }
    for (const m of ['platform_shared', 'platform_shared_local_reply', 'library_own_transport', 'disabled']) {
      expect(CLES_NET, m).toContain(`net.mode.${m}`);
    }
  });

  it('français sans vouvoiement, pt-BR sans « tu »', () => {
    const fautes = CLES_NET.flatMap((k) => [['fr', mail.tMailTexte('fr', k)], ['pt-BR', mail.tMailTexte('pt-BR', k)]]
      .filter(([l, v]) => (l === 'fr' ? /\b(vous|votre|vos)\b|\b\p{L}+ez\b/iu : /\b(tu|teu|tua|vós|vosso)\b/i).test(v))
      .map(([l]) => `${k} [${l}]`));
    expect(fautes).toEqual([]);
  });
});

describe('suite de F26 — le rapport hebdomadaire part dans la langue de chaque destinataire', () => {
  const SECRET_RAPPORT = 'secret-rapport';
  const ADMIN_FR = { id: 'u-adm', email: 'xavier@exemplo.test', first_name: 'Xavier', preferred_language: 'fr' };
  function monterRapport() {
    return monterEF({
      entree: 'notify-network-weekly-report/index.ts',
      env: { WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT: SECRET_RAPPORT, SENDER_EMAIL: 'no-reply@exemplo.test', NETWORK_ADMIN_CC: 'admins@exemplo.test',
        FOOTER_TEXT: 'Devise globale à ne plus lire', NETWORK_FOOTER_TEXT: 'Devise réseau à ne plus lire' },
      repondre: (_s, table, a) => {
        if (table === 'libraries') return { data: [{ id: 'lib-a', name: 'Bibliothèque A', short_name: 'BA', is_active: true }, { id: 'lib-b', name: 'Bibliotheek B', short_name: 'BB', is_active: true }], error: null };
        if (table === 'v_library_notification_context') return { data: [
          { library_id: 'lib-a', library_short_name: 'BA', delivery_mode: 'platform_shared', weekly_report_email: 'ba@exemplo.test', channel_active: true },
          { library_id: 'lib-b', library_short_name: 'BB', delivery_mode: 'library_own_transport', weekly_report_email: null, channel_active: false },
        ], error: null };
        if (table === 'interlibrary_loans_v2') {
          if (a('in')) return { data: [{ id: 'p-1' }], error: null };
          return { data: [{ id: 'p-1', lender_library_id: 'lib-a', borrower_library_id: 'lib-b', status_global: 'emprestado', created_at: '2026-10-14T09:00:00Z' }], error: null };
        }
        if (table === 'interlibrary_loan_items_v2') return { data: [{ interlibrary_loan_id: 'p-1' }, { interlibrary_loan_id: 'p-1' }], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
        if (table === 'profiles') return { data: [ADMIN_FR], error: null };
        return { data: [], error: null };
      },
    });
  }
  const appelerRapport = (ef) => ef.appeler(new Request('http://ef.local/', {
    method: 'POST', headers: { 'x-webhook-secret': SECRET_RAPPORT, 'content-type': 'application/json' },
    body: JSON.stringify({ week_start: '2026-10-12', week_end: '2026-10-18' }),
  }));

  it('l’admin le lit en français, la boîte collective en pt-BR, pied compris', async () => {
    const ef = monterRapport();
    const { statut, corps } = await appelerRapport(ef);
    expect(statut, JSON.stringify(corps)).toBe(200);
    const fr = mailA(ef.envois, 'xavier@exemplo.test');
    const pt = mailA(ef.envois, 'admins@exemplo.test');

    expect(fr.subject).toBe(mail.tMailTexte('fr', 'net.subject', { brand: 'AnarBib', start: '12/10/2026', end: '18/10/2026' }));
    expect(fr.html).toContain('<html lang="fr">');
    for (const cle of ['net.kicker', 'net.tbl.perLibrary', 'net.sum.illCreated', 'net.col.lender', 'net.ill.emprestado',
      'net.attn.channelDisabled', 'net.attn.noWeeklyEmail', 'layout.footerTextNetwork']) {
      expect(fr.html, cle).toContain(mail.tMailTexte('fr', cle).replace(/'/g, '&#039;'));
    }
    expect(fr.html).toContain(mail.tMailTexte('fr', 'net.mode.disabledSuffix', { mode: mail.tMailTexte('fr', 'net.mode.library_own_transport') }));
    expect(fr.html).not.toMatch(/Relatório|Síntese|Bibliotecas|Coordenação|Emprestado/);
    expect(fr.text).toContain(mail.tMailTexte('fr', 'layout.footerTextNetwork'));

    expect(pt.subject).toBe(mail.tMailTexte('pt-BR', 'net.subject', { brand: 'AnarBib', start: '12/10/2026', end: '18/10/2026' }));
    expect(pt.html).toContain('<html lang="pt-BR">');
    expect(pt.html).toContain(mail.tMailTexte('pt-BR', 'net.ill.emprestado'));
    for (const e of ef.envois) {
      expect(e.html).not.toMatch(/Devise (globale|réseau)/);
      for (const repli of REPLIS_PT) expect(e.html).not.toContain(repli);
    }
  });
});

// ─── Suite de F26 (20/10/2026) : le rapport hebdomadaire d'UNE bibliothèque ─────
// notify-weekly-report, le dernier rapport rédigé en pt-BR seul dans le code : il
// part à la coordination d'une bibliothèque (weekly_report_email), dans la langue
// de cette bibliothèque (default_locale de la vue de contexte). Clés wr.*, et net.*
// pour les libellés qu'il partage avec le rapport du réseau.
// Mots portugais du courriel d'avant ; (?<!\p{L}) plutôt que \b, qui ignore « últimas ».
const PROSE_PT_BIBLIO = /(?<!\p{L})(relat[oó]rio|semanal|leitor(?:es)?|empr[eé]stimos?|devolu[cç][oõ]es|renova[cç][oõ]es|atrasos|inscri[cç][oõ]es|sa[ií]das?|solicita[cç][oõ]es|pendentes|compartilhamentos?|digitais|emprestadora|tomadora|fornecedora|vencimento|parceira|papel|livros?|[uú]ltim[oa]s|agrupadas|rodap[eé]|per[ií]odo|criad[oa]s|registradas|aceitas|removido|inativo|encerrado|recusado|indispon[ií]vel)(?!\p{L})/iu;
const CLES_WR = mail._allKeys().filter((k) => k.startsWith('wr.'));

describe('suite de F26 — notify-weekly-report n’a plus de texte portugais en dur', () => {
  it('aucun littéral ne porte de prose portugaise', () => {
    const fautes = litteraux(code('notify-weekly-report/index.ts')).filter((t) => PROSE_PT_BIBLIO.test(t));
    expect(fautes, fautes.join('\n')).toEqual([]);
  });

  it('contre-épreuve : la garde voit les phrases d’avant', () => {
    for (const avant of ['Relatório semanal automático', 'Solicitações pendentes recebidas', 'Compartilhamentos digitais em curso (fim da semana)',
      'Devoluções (últimas 50 linhas agrupadas por empréstimo)', 'Leitor(a/e)', 'Biblioteca parceira', 'Saída com circulação pendente',
      'Rodapé local:', 'Período:', 'Emprestadora', 'Indisponível']) {
      expect(PROSE_PT_BIBLIO.test(avant), avant).toBe(true);
    }
  });

  it('les clés wr.* : complètes dans les onze langues, aucune copie du pt-BR', () => {
    expect(CLES_WR.length).toBeGreaterThanOrEqual(50);
    expect(CLES_WR.filter((k) => !mail._isComplete(k))).toEqual([]);
    const copies = [];
    for (const k of CLES_WR) {
      const pt = mail.tMailTexte('pt-BR', k);
      if (pt.length <= 25 || !/\s/.test(pt)) continue;
      for (const l of LOCALES) if (l !== 'pt-BR' && mail.tMailTexte(l, k) === pt) copies.push(`${k} [${l}]`);
    }
    expect(copies).toEqual([]);
  });

  it('chaque clé citée par la fonction existe, et chaque état a son libellé', () => {
    const src = code('notify-weekly-report/index.ts');
    const citees = [...src.matchAll(/["']((?:wr|net)\.[A-Za-z_.]+[A-Za-z_])["']/g)].map((m) => m[1]);
    expect(citees.length).toBeGreaterThan(50);
    const toutes = mail._allKeys();
    expect(citees.filter((k) => !toutes.includes(k))).toEqual([]);
    for (const s of ['demande', 'accepte', 'refuse', 'indisponible', 'numerisation', 'transmis', 'cloture']) expect(CLES_WR, s).toContain(`wr.flux.${s}`);
    for (const s of ['removed', 'inactive', 'terminated', 'left_with_pending_circulation']) expect(CLES_WR, s).toContain(`wr.exit.${s}`);
    for (const s of ['preparacao', 'aguardando_saida', 'emprestado', 'parcialmente_devolvido', 'em_devolucao', 'devolvido', 'cancelado', 'atrasado']) {
      expect(CLES_NET, s).toContain(`net.ill.${s}`);
    }
  });

  it('français sans vouvoiement, pt-BR sans « tu »', () => {
    const fautes = CLES_WR.flatMap((k) => [['fr', mail.tMailTexte('fr', k)], ['pt-BR', mail.tMailTexte('pt-BR', k)]]
      .filter(([l, v]) => (l === 'fr' ? /\b(vous|votre|vos)\b|\b\p{L}+ez\b/iu : /\b(tu|teu|tua|vós|vosso)\b/i).test(v))
      .map(([l]) => `${k} [${l}]`));
    expect(fautes).toEqual([]);
  });
});

describe('suite de F26 — le rapport d’une bibliothèque part dans la langue de la bibliothèque', () => {
  const SECRET_BIBLIO = 'secret-rapport-biblio';
  const LECTRICE = { id: 'u-1', email: 'louise@exemplo.test', first_name: 'Louise', last_name: 'Michel' };
  const avecOp = (chaine, op, col, val) => chaine.some((c) => c.op === op && c.args[0] === col && (val === undefined || c.args[1] === val));
  function monterBiblio(default_locale) {
    return monterEF({
      entree: 'notify-weekly-report/index.ts',
      env: { WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT: SECRET_BIBLIO, SENDER_EMAIL: 'no-reply@exemplo.test',
        FOOTER_TEXT: 'Devise globale à ne plus lire', NETWORK_FOOTER_TEXT: 'Devise réseau à ne plus lire' },
      repondre: (schema, table, a, chaine) => {
        if (a('select')?.args[1]?.head) return { data: null, error: null, count: 2 };
        if (table === 'library_document_governance') return { data: { config: { reports: { weekly_library_summary_enabled: true } } }, error: null };
        if (table === 'v_library_notification_context') return { data: {
          library_id: 'lib-a', library_name: 'De Vrije Gedachte', library_short_name: 'DVG', delivery_mode: 'platform_shared',
          weekly_report_email: 'rapport@exemplo.test', channel_active: true, default_locale,
        }, error: null };
        if (table === 'reader_membership_events') {
          return avecOp(chaine, 'eq', 'event_type', 'saida')
            ? { data: [{ user_id: 'u-1', changed_at: '2026-10-15T10:00:00Z', new_status: 'left_with_pending_circulation' }], error: null }
            : { data: [{ user_id: 'u-1', changed_at: '2026-10-13T08:00:00Z' }], error: null };
        }
        if (table === 'profiles') return { data: [LECTRICE], error: null };
        if (table === 'emprestimos_v2') return { data: [{ id: 12, user_id: 'u-1', created_at: '2026-10-13T09:00:00Z', due_at: '2026-11-03', extended_at: '2026-10-16T14:30:00Z' }], error: null };
        if (schema === 'api' && table === 'emprestimo_itens_painel_ui') return { data: [{ emprestimo_id: 12, line_no: 1, titulo: 'Dieu et l’État', user_name: 'Louise' }], error: null };
        if (table === 'interlibrary_loans_v2') return { data: [{ id: 'p-1', request_id: 'EEB-7', lender_library_id: 'lib-a', borrower_library_id: 'lib-b', status_global: 'emprestado', created_at: '2026-10-14T09:00:00Z' }], error: null };
        if (table === 'interlibrary_loan_items_v2') return { data: [{ interlibrary_loan_id: 'p-1' }, { interlibrary_loan_id: 'p-1' }], error: null };
        if (table === 'libraries') return { data: [{ id: 'lib-b', name: 'Bibliothèque B', short_name: 'BB' }], error: null };
        if (table === 'ill_digital_shares') return { data: [{ id: 'd-1', requester_library_id: 'lib-b', source_library_id: 'lib-a', flux_state: 'numerisation',
          requested_at: '2026-10-14T11:00:00Z', books: { titulo: "L'Anarchie & l'ordre" }, requester: { short_name: 'BB' }, source: { short_name: 'DVG' } }], error: null };
        return { data: table === 'library_public_contact' ? null : [], error: null };
      },
    });
  }
  const appelerBiblio = (ef) => ef.appeler(new Request('http://ef.local/', {
    method: 'POST', headers: { 'x-webhook-secret': SECRET_BIBLIO, 'content-type': 'application/json' },
    body: JSON.stringify({ library_id: 'lib-a', week_start: '2026-10-12', week_end: '2026-10-18' }),
  }));
  const html = (l, cle, params) => mail.tMailTexte(l, cle, params).replace(/&/g, '&amp;').replace(/'/g, '&#039;');
  const jour = (iso, l) => mail.formatDateLocale(`${iso}T00:00:00.000Z`, l);

  for (const l of ['nl', 'fr']) {
    it(`bibliothèque en ${l} : objet, corps, états et pied dans sa langue`, async () => {
      const ef = monterBiblio(l);
      const { statut, corps } = await appelerBiblio(ef);
      expect(statut, JSON.stringify(corps)).toBe(200);
      expect(corps.locale).toBe(l);
      expect(ef.envois).toHaveLength(1);
      const e = mailA(ef.envois, 'rapport@exemplo.test');

      const periode = { start: jour('2026-10-12', l), end: jour('2026-10-18', l) };
      expect(e.subject).toBe(corps.subject);
      expect(e.subject.endsWith(mail.tMailTexte(l, 'wr.subject', { tag: '', ...periode }).trim())).toBe(true);
      expect(e.html).toContain(`<html lang="${l}">`);
      for (const cle of ['wr.kicker', 'wr.lbl.library', 'net.lbl.period', 'wr.sum.pendingRequests', 'net.sum.readersIn', 'wr.sum.digitalOngoing',
        'wr.tbl.readersOut', 'wr.tbl.digital', 'wr.col.reader', 'wr.col.dueDate', 'wr.col.partner', 'net.col.createdAt',
        'net.ill.emprestado', 'wr.flux.numerisation', 'wr.exit.left_with_pending_circulation', 'wr.role.lender', 'wr.role.provider',
        'layout.footerText']) {
        expect(e.html, cle).toContain(html(l, cle));
      }
      expect(e.html).toContain(html(l, 'wr.title', { brand: '' }).trim());
      // dates de la langue : le jour seul, ou le jour et l'heure (UTC) d'un horodatage
      expect(e.html).toContain(jour('2026-11-03', l));
      expect(e.html).toContain(`${jour('2026-10-16', l)} 14:30 UTC`);
      expect(e.html).toContain('L&#039;Anarchie &amp; l&#039;ordre');
      expect(e.html).not.toMatch(/Relatório|Biblioteca:|Período|Leitor\(a\/e\)|Empréstimo|Devoluções|Compartilhamento|Emprestadora|Fornecedora|Rodapé|Digitalização/);

      expect(e.text).toContain(mail.tMailTexte(l, 'layout.footerText'));
      expect(e.text).toContain(mail.tMailTexte(l, 'wr.sum.pendingRequests'));
      expect(e.text).not.toMatch(/&#0?39;|&amp;|Rodapé/);
      expect(e.html).not.toMatch(/Devise (globale|réseau)/);
      for (const repli of REPLIS_PT) expect(e.html).not.toContain(repli);
    });
  }

  it('langue absente ou inconnue : le rapport part en pt-BR, la langue de référence', async () => {
    for (const l of [null, 'xx']) {
      const ef = monterBiblio(l);
      const { statut, corps } = await appelerBiblio(ef);
      expect(statut).toBe(200);
      expect(corps.locale).toBe('pt-BR');
      const e = mailA(ef.envois, 'rapport@exemplo.test');
      expect(e.html).toContain('<html lang="pt-BR">');
      expect(e.html).toContain(mail.tMailTexte('pt-BR', 'wr.kicker'));
      expect(e.html).toContain(jour('2026-11-03', 'pt-BR'));
    }
  });
});
