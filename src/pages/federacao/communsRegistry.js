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
import charteMainTendue from '../../../docs/notes-audit/anarbib-charte-relationnelle-v0.1.md?raw';
import charteInclusive  from '../../../docs/notes-audit/anarbib-charte-langage-inclusif-v2.md?raw';
import cadrageEntraide  from '../../../docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15.md?raw';
import manuel           from '../../../docs/manual.md?raw';
import cotation         from '../../../docs/cotation-et-cdd.md?raw';
import guideScan        from '../../../docs/guides/guide-scan-qr-pt-BR.md?raw';

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

const GOUVERNANCE_BY_LOCALE = {
  ca: gouvCa, de: gouvDe, el: gouvEl, en: gouvEn, eo: gouvEo,
  es: gouvEs, fr: gouvFr, it: gouvIt, nl: gouvNl, 'pt-BR': gouvPtBR,
};

export const COMMUNS_CATS = ['chartes', 'guides', 'vademecums', 'cadrages'];

export const COMMUNS_DOCS = [
  {
    id: 'main-tendue', cat: 'chartes',
    titleKey: 'federacao.communs.doc.mainTendue.title',
    descKey: 'federacao.communs.doc.mainTendue.desc',
    md: charteMainTendue,
  },
  {
    id: 'langage-inclusif', cat: 'chartes',
    titleKey: 'federacao.communs.doc.langageInclusif.title',
    descKey: 'federacao.communs.doc.langageInclusif.desc',
    md: charteInclusive,
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
    md: manuel,
  },
  {
    id: 'cotation', cat: 'vademecums',
    titleKey: 'federacao.communs.doc.cotation.title',
    descKey: 'federacao.communs.doc.cotation.desc',
    md: cotation,
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
    id: 'cadrage-entraide', cat: 'cadrages',
    titleKey: 'federacao.communs.doc.cadrageEntraide.title',
    descKey: 'federacao.communs.doc.cadrageEntraide.desc',
    md: cadrageEntraide,
  },
];

// Résout le markdown d'un doc dans la locale courante (byLocale → locale, repli fr)
// et retire un éventuel frontmatter YAML (sinon affiché en vrac par react-markdown).
export function resolveDocMd(doc, locale) {
  const raw = doc.byLocale ? (doc.byLocale[locale] || doc.byLocale.fr) : doc.md;
  return String(raw || '').replace(/^---\s*\n[\s\S]*?\n---\s*\n/, '');
}
