// ═══════════════════════════════════════════════════════════════════════════
// communsRegistry — les « documents vivants » du réseau, rendus dans l'app.
//
// Les .md sont importés EN ?raw depuis leurs emplacements réels du dépôt
// (source unique, aucune dérive). v1 : bundlé statiquement, lecture seule.
// v2 (cadrage entraide) : adossé à Supabase pour édition par consentement +
// traduction par communauté de langue.
//
// Deux formes de doc :
//   • { md }       — un seul fichier (FR pour l'instant) ;
//   • { byLocale } — un fichier PAR locale (ex. le guide de gouvernance, déjà
//                    traduit dans les 10 langues) → servi dans la locale courante,
//                    repli fr. C'est le modèle de ce que Communs doit devenir.
//
// Antidote au « PDF mort » (charte relationnelle, facette ① / jurisprudence) :
// le commun vit AU POINT DE BESOIN, dans l'app, pas enfoui dans un repo.
// ═══════════════════════════════════════════════════════════════════════════

// ── Charte « la main tendue » (relationnelle) — 10 locales ──────────────────
import mtFr   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1.md?raw';
import mtCa   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-ca.md?raw';
import mtDe   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-de.md?raw';
import mtEl   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-el.md?raw';
import mtEn   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-en.md?raw';
import mtEo   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-eo.md?raw';
import mtEs   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-es.md?raw';
import mtIt   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-it.md?raw';
import mtNl   from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-nl.md?raw';
import mtPtBR from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1-pt-BR.md?raw';

// ── Charte de langage inclusif v2 — 10 locales ──────────────────────────────
import liFr   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2.md?raw';
import liCa   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-ca.md?raw';
import liDe   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-de.md?raw';
import liEl   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-el.md?raw';
import liEn   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-en.md?raw';
import liEo   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-eo.md?raw';
import liEs   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-es.md?raw';
import liIt   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-it.md?raw';
import liNl   from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-nl.md?raw';
import liPtBR from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2-pt-BR.md?raw';

// ── Manuel d'utilisation — 10 locales ───────────────────────────────────────
import maFr   from '../../../docs/manual.md?raw';
import maCa   from '../../../docs/manual-ca.md?raw';
import maDe   from '../../../docs/manual-de.md?raw';
import maEl   from '../../../docs/manual-el.md?raw';
import maEn   from '../../../docs/manual-en.md?raw';
import maEo   from '../../../docs/manual-eo.md?raw';
import maEs   from '../../../docs/manual-es.md?raw';
import maIt   from '../../../docs/manual-it.md?raw';
import maNl   from '../../../docs/manual-nl.md?raw';
import maPtBR from '../../../docs/manual-pt-BR.md?raw';

// ── Cotation & classification anarchiste — 10 locales ───────────────────────
import coFr   from '../../../docs/cotation-et-cdd.md?raw';
import coCa   from '../../../docs/cotation-et-cdd-ca.md?raw';
import coDe   from '../../../docs/cotation-et-cdd-de.md?raw';
import coEl   from '../../../docs/cotation-et-cdd-el.md?raw';
import coEn   from '../../../docs/cotation-et-cdd-en.md?raw';
import coEo   from '../../../docs/cotation-et-cdd-eo.md?raw';
import coEs   from '../../../docs/cotation-et-cdd-es.md?raw';
import coIt   from '../../../docs/cotation-et-cdd-it.md?raw';
import coNl   from '../../../docs/cotation-et-cdd-nl.md?raw';
import coPtBR from '../../../docs/cotation-et-cdd-pt-BR.md?raw';

// ── Cadrage entraide au catalogage — 10 locales ─────────────────────────────
import cdFr   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15.md?raw';
import cdCa   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-ca.md?raw';
import cdDe   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-de.md?raw';
import cdEl   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-el.md?raw';
import cdEn   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-en.md?raw';
import cdEo   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-eo.md?raw';
import cdEs   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-es.md?raw';
import cdIt   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-it.md?raw';
import cdNl   from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-nl.md?raw';
import cdPtBR from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15-pt-BR.md?raw';

// ── Guide scan — encore mono-pt-BR (co-écriture par langue à venir) ──────────
import guideScan   from '../../../docs/guides/guide-scan-qr-pt-BR.md?raw';

// ── Guide « Indexer un sujet » — 10 locales ─────────────────────────────────
import giCa   from '../../../docs/guides/guide-indexar-assunto-ca.md?raw';
import giDe   from '../../../docs/guides/guide-indexar-assunto-de.md?raw';
import giEl   from '../../../docs/guides/guide-indexar-assunto-el.md?raw';
import giEn   from '../../../docs/guides/guide-indexar-assunto-en.md?raw';
import giEo   from '../../../docs/guides/guide-indexar-assunto-eo.md?raw';
import giEs   from '../../../docs/guides/guide-indexar-assunto-es.md?raw';
import giFr   from '../../../docs/guides/guide-indexar-assunto-fr.md?raw';
import giIt   from '../../../docs/guides/guide-indexar-assunto-it.md?raw';
import giNl   from '../../../docs/guides/guide-indexar-assunto-nl.md?raw';
import giPtBR from '../../../docs/guides/guide-indexar-assunto-pt-BR.md?raw';

// ── Guide de gouvernance — 10 locales (déjà existant) ───────────────────────
import gouvCa   from '../../../docs/governance/guide-gouvernance-ca.md?raw';
import gouvDe   from '../../../docs/governance/guide-gouvernance-de.md?raw';
import gouvEl   from '../../../docs/governance/guide-gouvernance-el.md?raw';
import gouvEn   from '../../../docs/governance/guide-gouvernance-en.md?raw';
import gouvEo   from '../../../docs/governance/guide-gouvernance-eo.md?raw';
import gouvEs   from '../../../docs/governance/guide-gouvernance-es.md?raw';
import gouvFr   from '../../../docs/governance/guide-gouvernance-fr.md?raw';
import gouvIt   from '../../../docs/governance/guide-gouvernance-it.md?raw';
import gouvNl   from '../../../docs/governance/guide-gouvernance-nl.md?raw';
import gouvPtBR from '../../../docs/governance/guide-gouvernance-pt-BR.md?raw';

const MAIN_TENDUE_BY_LOCALE = {
  ca: mtCa, de: mtDe, el: mtEl, en: mtEn, eo: mtEo,
  es: mtEs, fr: mtFr, it: mtIt, nl: mtNl, 'pt-BR': mtPtBR,
};

const LANGAGE_INCLUSIF_BY_LOCALE = {
  ca: liCa, de: liDe, el: liEl, en: liEn, eo: liEo,
  es: liEs, fr: liFr, it: liIt, nl: liNl, 'pt-BR': liPtBR,
};

const MANUEL_BY_LOCALE = {
  ca: maCa, de: maDe, el: maEl, en: maEn, eo: maEo,
  es: maEs, fr: maFr, it: maIt, nl: maNl, 'pt-BR': maPtBR,
};

const COTATION_BY_LOCALE = {
  ca: coCa, de: coDe, el: coEl, en: coEn, eo: coEo,
  es: coEs, fr: coFr, it: coIt, nl: coNl, 'pt-BR': coPtBR,
};

const CADRAGE_BY_LOCALE = {
  ca: cdCa, de: cdDe, el: cdEl, en: cdEn, eo: cdEo,
  es: cdEs, fr: cdFr, it: cdIt, nl: cdNl, 'pt-BR': cdPtBR,
};

const GOUVERNANCE_BY_LOCALE = {
  ca: gouvCa, de: gouvDe, el: gouvEl, en: gouvEn, eo: gouvEo,
  es: gouvEs, fr: gouvFr, it: gouvIt, nl: gouvNl, 'pt-BR': gouvPtBR,
};

const GUIDE_INDEXAR_BY_LOCALE = {
  ca: giCa, de: giDe, el: giEl, en: giEn, eo: giEo,
  es: giEs, fr: giFr, it: giIt, nl: giNl, 'pt-BR': giPtBR,
};

export const COMMUNS_CATS = ['chartes', 'guides', 'vademecums', 'cadrages'];

export const COMMUNS_DOCS = [
  {
    id: 'main-tendue', cat: 'chartes',
    titleKey: 'federacao.communs.doc.mainTendue.title',
    descKey: 'federacao.communs.doc.mainTendue.desc',
    byLocale: MAIN_TENDUE_BY_LOCALE,
  },
  {
    id: 'langage-inclusif', cat: 'chartes',
    titleKey: 'federacao.communs.doc.langageInclusif.title',
    descKey: 'federacao.communs.doc.langageInclusif.desc',
    byLocale: LANGAGE_INCLUSIF_BY_LOCALE,
  },
  {
    id: 'gouvernance', cat: 'guides',
    titleKey: 'federacao.communs.doc.gouvernance.title',
    descKey: 'federacao.communs.doc.gouvernance.desc',
    byLocale: GOUVERNANCE_BY_LOCALE,
  },
  {
    id: 'manuel', cat: 'guides',
    titleKey: 'federacao.communs.doc.manuel.title',
    descKey: 'federacao.communs.doc.manuel.desc',
    byLocale: MANUEL_BY_LOCALE,
  },
  {
    id: 'cotation', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.cotation.title',
    descKey: 'federacao.communs.doc.cotation.desc',
    byLocale: COTATION_BY_LOCALE,
  },
  {
    // Écrit en pt-BR (pour Rodrigo/BTL) ; servi tel quel partout (repli), les
    // co-écritures par langue viendront — cf. cadrage §3. Module : session MOBILE.
    id: 'guide-scan', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.guideScan.title',
    descKey: 'federacao.communs.doc.guideScan.desc',
    md: guideScan,
  },
  {
    // Artisanat de l'indexation matière (pour les catalogueur·euses), 10 locales —
    // co-écriture par communauté de langue (via Cowork). Adossé au thésaurus.
    id: 'guide-indexar', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.indexarAssunto.title',
    descKey: 'federacao.communs.doc.indexarAssunto.desc',
    byLocale: GUIDE_INDEXAR_BY_LOCALE,
  },
  {
    id: 'cadrage-entraide', cat: 'cadrages',
    titleKey: 'federacao.communs.doc.cadrageEntraide.title',
    descKey: 'federacao.communs.doc.cadrageEntraide.desc',
    byLocale: CADRAGE_BY_LOCALE,
  },
];

// Résout le markdown d'un doc dans la locale courante (byLocale → locale, repli fr)
// et retire un éventuel frontmatter YAML (sinon affiché en vrac par react-markdown).
export function resolveDocMd(doc, locale) {
  const raw = doc.byLocale ? (doc.byLocale[locale] || doc.byLocale.fr) : doc.md;
  return String(raw || '').replace(/^---\s*\n[\s\S]*?\n---\s*\n/, '');
}
