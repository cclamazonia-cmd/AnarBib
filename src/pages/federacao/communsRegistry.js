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

// ── Guide scan — 10 locales (co-écriture par communauté de langue, via Cowork) ─
import gsCa   from '../../../docs/guides/guide-scan-qr-ca.md?raw';
import gsDe   from '../../../docs/guides/guide-scan-qr-de.md?raw';
import gsEl   from '../../../docs/guides/guide-scan-qr-el.md?raw';
import gsEn   from '../../../docs/guides/guide-scan-qr-en.md?raw';
import gsEo   from '../../../docs/guides/guide-scan-qr-eo.md?raw';
import gsEs   from '../../../docs/guides/guide-scan-qr-es.md?raw';
import gsFr   from '../../../docs/guides/guide-scan-qr-fr.md?raw';
import gsIt   from '../../../docs/guides/guide-scan-qr-it.md?raw';
import gsNl   from '../../../docs/guides/guide-scan-qr-nl.md?raw';
import gsPtBR from '../../../docs/guides/guide-scan-qr-pt-BR.md?raw';

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

// ── Guide « Le thésaurus FICEDL » — 10 locales ──────────────────────────────
import gtfCa   from '../../../docs/guides/guide-thesaurus-ficedl-ca.md?raw';
import gtfDe   from '../../../docs/guides/guide-thesaurus-ficedl-de.md?raw';
import gtfEl   from '../../../docs/guides/guide-thesaurus-ficedl-el.md?raw';
import gtfEn   from '../../../docs/guides/guide-thesaurus-ficedl-en.md?raw';
import gtfEo   from '../../../docs/guides/guide-thesaurus-ficedl-eo.md?raw';
import gtfEs   from '../../../docs/guides/guide-thesaurus-ficedl-es.md?raw';
import gtfFr   from '../../../docs/guides/guide-thesaurus-ficedl-fr.md?raw';
import gtfIt   from '../../../docs/guides/guide-thesaurus-ficedl-it.md?raw';
import gtfNl   from '../../../docs/guides/guide-thesaurus-ficedl-nl.md?raw';
import gtfPtBR from '../../../docs/guides/guide-thesaurus-ficedl-pt-BR.md?raw';

// ── Fiche « Numériser un ouvrage » — fr + pt-BR ─────────────────────────────
// Volontairement PAS traduite dans les dix langues : le corps du réseau qui
// numérise est lusophone, et la doctrine des communs veut que chaque version
// soit écrite par sa communauté de langue, pas déversée par traduction. Les
// huit locales absentes retombent sur le fr (cf. resolveDocMd).
import gnuFr   from '../../../docs/guides/guide-digitalizar-fr.md?raw';
import gnuPtBR from '../../../docs/guides/guide-digitalizar-pt-BR.md?raw';

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

const THESAURUS_FICEDL_BY_LOCALE = {
  ca: gtfCa, de: gtfDe, el: gtfEl, en: gtfEn, eo: gtfEo,
  es: gtfEs, fr: gtfFr, it: gtfIt, nl: gtfNl, 'pt-BR': gtfPtBR,
};

const GUIDE_SCAN_BY_LOCALE = {
  ca: gsCa, de: gsDe, el: gsEl, en: gsEn, eo: gsEo,
  es: gsEs, fr: gsFr, it: gsIt, nl: gsNl, 'pt-BR': gsPtBR,
};

// Deux locales seulement, à dessein — les huit autres retombent sur fr.
const GUIDE_NUMERISATION_BY_LOCALE = { fr: gnuFr, 'pt-BR': gnuPtBR };

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
    // Co-écrit par communauté de langue (via Cowork), 10 locales présentes.
    // Repli fr si une locale manquait (sans objet ici). Source : pt-BR.
    id: 'guide-scan', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.guideScan.title',
    descKey: 'federacao.communs.doc.guideScan.desc',
    byLocale: GUIDE_SCAN_BY_LOCALE,
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
    // Ce qui se décide DEVANT le scanner : trois réglages, cinq contrôles, le
    // sort des captures. Le pourquoi est dans DECISION_profil_numerisation ;
    // cette fiche-ci est faite pour être lue debout, pas en réunion.
    id: 'guide-numerisation', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.guideNumerisation.title',
    descKey: 'federacao.communs.doc.guideNumerisation.desc',
    byLocale: GUIDE_NUMERISATION_BY_LOCALE,
  },
  {
    // Le vocabulaire matière commun (thésaurus FICEDL) : ce qu'il est, à quelles
    // conditions AnarBib s'y branche, comment s'en servir. 10 locales (source fr
    // validée + 9 traductions par communauté de langue). Adossé au guide-indexar.
    id: 'thesaurus-ficedl', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.thesaurusFicedl.title',
    descKey: 'federacao.communs.doc.thesaurusFicedl.desc',
    byLocale: THESAURUS_FICEDL_BY_LOCALE,
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
