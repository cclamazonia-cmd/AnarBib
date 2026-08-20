/* ──────────────────────────────────────────────────────────────────────────
 *  fieldRegistry.js — Registre déclaratif de la fiche Catalogação
 *  Track A · Lot 1   (spec-catalogacao-fiche-et-paliers v0.3, §3.2/§3.3/§4/§5)
 *
 *  RÔLE
 *  ────
 *  Source unique et déclarative des champs de la fiche : groupes, champs,
 *  paliers (tiers), filtrage matériel, et helpers de visibilité.
 *  Importé par BookDraftForm (Lot 2 livré) : le rendu ad-hoc `inp()/sel()`
 *  a été remplacé par `renderRegistryField()` piloté par ce registre.
 *  Les blocs spéciaux (contrib, cover, ISBD) restent en rendu dédié.
 *
 *  PRINCIPE D'AUTORITÉ
 *  ───────────────────
 *  - `id`     = clé d'état réelle (EMPTY_FORM de BookDraftForm = colonnes
 *               book_drafts 1:1). Ne JAMAIS diverger : c'est l'ancre du wiring.
 *  - `label`  = clé i18n réellement référencée dans le render actuel
 *               (catalogacao.field.* / .ui.* / .section.* / .material.*).
 *  - tier/mat/span = la SPEC fait foi (§5.1–5.4). Le registre est la nouvelle
 *               vérité ; il remplace le mécanisme `completeOnly` + `.mode-complete-only`.
 *
 *  DÉCISIONS D'INTERPRÉTATION & ÉCARTS SPEC↔RENDER (à valider) — voir aussi le
 *  message de livraison :
 *  (D1) `editora.mat` : aligné sur la maquette normative = 6 types
 *       (livro/periodico/zine/cartaz/tract/dossie ; exclut tese/artigo/relatorio).
 *       Idem : `issn.mat=[periodico,artigo]`, `local.mat`=6 types, `colecao` tier 3
 *       mat [livro,tese] — tous calés sur maquette_fiche_catalogacao_v2.html.
 *  (D2) Blocs spéciaux : `special:'contrib'` (autores §5.5, état `contributors[]`
 *       qui synthétise `autor`), `special:'cover'` (§5.3, bouton « Buscar capa »
 *       hors périmètre), `special:'fine'` (zones ISBD générées §5.2 + MARC).
 *       Leur rendu est dédié (Lot 2) ; le registre les marque, sans les détailler.
 *  (D3) Selects/segments : `opts` repris VERBATIM du render
 *       (circulation 2 valeurs, recto_verso 3 valeurs, tipo_material = 12 codes).
 *  (D4) `idioma` : RÉSOLU — select avec 36 langues (10 locales AnarBib +
 *       26 langues courantes en bibliothèque/tradition anarchiste).
 *       L'option vide en tête assure la compatibilité avec les fiches existantes
 *       stockant du texte libre.
 *  (D5) `loanable` (circulação §5.6) : RÉSOLU — 3 valeurs effectives
 *       (emprestavel / consulta / ambos). CAT-E6 levé le 06/06.
 *  (D6) `viaf`/`isni`/`wikidata` (§5.2, tier 3) : RETIRÉS du niveau livre —
 *       ces identifiants appartiennent au niveau autorité (authors table,
 *       save payload, publish_book_draft RPC, trigger de propagation).
 *  (D7) Tiers alignés sur le mapping §5.4 (guide `.simple`→1 / `.complete`→3) :
 *       quelques champs changent de palier vs le render ad-hoc actuel
 *       (ex. `diffusion_place` 1→3, `edicao`/`colecao` complete→avançado).
 *       C'est l'objet du refactor, pas une régression.
 *  (D7b) `tierOverride` : quand un champ partagé entre types a des paliers
 *       différents selon le type (ex. `physical_format` tier 1 pour cartaz,
 *       tier 3 pour tract ; `approximate_date` tier 1 pour tract, tier 2 pour
 *       cartaz ; `isbn` tier 1 pour livro, tier 3 pour artigo),
 *       `tierOverride: { <mat>: <tier> }` porte l'exception. `isFieldVisible`
 *       applique `tierOverride[material] ?? field.tier`.
 *  (D8) Spans : RÉSOLU — le Lot 2 rend le registre autoritatif. titulo span 2
 *       conforme spec §5.1.
 *
 *  CLÉS i18n : toutes les clés référencées par le registre existent dans les
 *  10 locales (3412 clés, parité gardée par CI).
 * ────────────────────────────────────────────────────────────────────────── */

import { LANGUAGE_CODES } from '@/lib/languages';

// ── Paliers ────────────────────────────────────────────────────────────────
export const TIERS = { simple: 1, advanced: 2, complete: 3 };

// Valeurs localStorage (§4, arbitrage A3 : on insère 'advanced' sans remap).
// La clé de stockage exacte est branchée au Lot 2 (insertion du palier).
export const MODE_VALUES = ['simple', 'advanced', 'complete'];
const MODE_TO_TIER = { simple: 1, advanced: 2, complete: 3 };
const TIER_TO_MODE = { 1: 'simple', 2: 'advanced', 3: 'complete' };

export function tierFromMode(mode) {
  return MODE_TO_TIER[mode] || 1; // défaut prudent : Simples
}
export function modeFromTier(tier) {
  return TIER_TO_MODE[tier] || 'simple';
}

// ── Types de matériel (12 codes, ordre = MATERIAL_TYPE_KEYS de BookDraftForm) ─
// Source de vérité libellés : ref_types_materiel_catalogacao. Code interne
// `tract` conservé (libellé « Panfleto/volante »).
export const MATERIAL_CODES = [
  'livro', 'periodico', 'tract', 'cartaz', 'audio', 'audiovisual',
  'recurso_digital', 'dossie', 'tese', 'artigo', 'relatorio', 'zine',
];

// editora (D1, aligné maquette normative) : liste blanche des matériels « édités ».
// La maquette exclut tese/artigo/relatorio (universidade / fonte / org. émettrice à la place).
const EDITORA_MAT = ['livro', 'periodico', 'zine', 'cartaz', 'tract', 'dossie'];
// CDD (classification Dewey) : pertinent pour les documents textuels/physiques,
// pas pour les médias natifs (audiovisual/audio/recurso_digital). Les thèses la gardent.
const CDD_MAT = ['livro', 'periodico', 'tract', 'cartaz', 'dossie', 'tese', 'artigo', 'relatorio', 'zine'];

// Langues du catalogue — les 10 locales AnarBib (noms natifs, clés i18n existantes).
// L'option vide (placeholder) permet la compatibilité avec les fiches existantes
// qui stockent du texte libre dans `idioma` : elles affichent le placeholder
// jusqu'à ré-sélection explicite.
// 36 langues triees par code ISO — endonymes dans language.XX (i18n).
// Les 10 locales AnarBib + 26 langues courantes en bibliotheque/tradition anarchiste.
// Liste deplacee dans @/lib/languages (CONV-7, REGISTRE §37) : elle sert
// desormais AUSSI a l'affichage (BookPage/WorkPage) et au filtre de l'OPAC.
// Une seule copie — deux listes divergentes, c'est le drift garanti.
const IDIOMA_CODES = LANGUAGE_CODES;
const IDIOMA_OPTS = [
  { value: '', label: 'catalogacao.ph.language' },
  ...IDIOMA_CODES.map(c => ({ value: c, label: `language.${c}` })),
];

// Options de sélecteurs/segments — reprises verbatim du render (D3).
const MATERIAL_OPTS = MATERIAL_CODES.map(c => ({ value: c, label: `catalogacao.material.${c}` }));
const CIRCULATION_OPTS = [
  { value: 'emprestavel', label: 'catalogacao.ui.loanable' },
  { value: 'consulta', label: 'catalogacao.ui.consultOnly' },
  { value: 'ambos', label: 'catalogacao.ui.circulationBoth' },
  // §5.6 : 3 valeurs effectives (différé D5 / CAT-E6 levé le 06/06).
];
const RECTO_VERSO_OPTS = [
  { value: '', label: 'catalogacao.ph.rectoVerso.none' },
  { value: 'recto', label: 'catalogacao.ph.rectoVerso.recto' },
  { value: 'verso', label: 'catalogacao.ph.rectoVerso.both' },
];

/* ── Registre : groupes ordonnés (l'ordre visuel fin relève de la maquette/Lot 2) ──
 * Champ  : { id, label, tier, mat?, type?, span?, ph?, phEx?, rows?, req?, watch?, opts?, pilot? }
 *   - mat omis  ⇒ 'all'
 *   - type omis ⇒ 'text'
 *   - span omis ⇒ 1
 *   - ph  = clé i18n du placeholder ; phEx = placeholder littéral (ex. '2016')
 * Groupe : { id, title, tag, tier?, mat?, special?, fields:[…] }
 */
export const REGISTRY = [
  // ── 1. Núcleo bibliographique (mat all) ───────────────────────────────────
  {
    id: 'nucleo',
    title: 'catalogacao.section.core',
    tag: 'catalogacao.tag.core',
    mat: 'all',
    fields: [
      { id: 'tipo_material', label: 'catalogacao.field.materialType', tier: 1, type: 'select', opts: MATERIAL_OPTS, pilot: true },
      { id: 'bib_ref', label: 'catalogacao.field.bibRef', tier: 3, ph: 'catalogacao.ph.refCompat' },
      { id: 'titulo', label: 'catalogacao.field.title', tier: 1, span: 2, req: true },
      { id: 'subtitulo', label: 'catalogacao.field.subtitle', tier: 2, span: 2 },
      { id: 'edicao', label: 'catalogacao.field.edition', tier: 2, mat: ['livro', 'zine', 'dossie'], phEx: '2. ed.' },
      { id: 'editora', label: 'catalogacao.field.publisher', tier: 1, mat: EDITORA_MAT },
      { id: 'colecao', label: 'catalogacao.field.collection', tier: 3, mat: ['livro', 'tese'] },
      { id: 'local_publicacao', label: 'catalogacao.field.place', tier: 2, mat: ['livro', 'periodico', 'zine', 'cartaz', 'tract', 'dossie'], ph: 'catalogacao.ph.city' },
      { id: 'paginas', label: 'catalogacao.field.pages', tier: 2, mat: ['livro', 'zine', 'dossie', 'tese'], type: 'number' },
      { id: 'ano', label: 'catalogacao.field.year', tier: 1, phEx: '2016' },
      { id: 'idioma', label: 'catalogacao.field.language', tier: 1, type: 'select', opts: IDIOMA_OPTS }, // (D4) résolu : select 36 langues
      { id: 'isbn', label: 'catalogacao.field.isbn', tier: 1, mat: ['livro', 'artigo'], watch: 'dup', phEx: '978-2-347-00368-5', tierOverride: { artigo: 3 } },
      { id: 'issn', label: 'catalogacao.field.issn', tier: 1, mat: ['periodico', 'artigo'], phEx: '0251-1479' },
      { id: 'cdd', label: 'catalogacao.field.cdd', tier: 1, mat: CDD_MAT, phEx: '335' },
      { id: 'circulation_default', label: 'catalogacao.ui.circulation', tier: 1, type: 'seg', opts: CIRCULATION_OPTS },
      { id: 'subjects', label: 'catalogacao.field.subjects', tier: 2, type: 'textarea', span: 3, ph: 'catalogacao.ph.subjects' },
      { id: 'notas', label: 'catalogacao.field.notes', tier: 2, type: 'textarea', span: 3, rows: 3, ph: 'catalogacao.ph.notes' },
    ],
  },

  // ── 2. Autores e responsabilidades (special) ──────────────────────────────
  // §5.5 : en tier 1 → champ `autor` libre ; en tier ≥2 → bloc contributeurs
  // typés (état React `contributors[]`) qui SYNTHÉTISE `autor`. Le rendu adapte
  // selon le palier ; on déclare `autor` comme représentation tier 1.
  {
    id: 'contribuintes',
    title: 'catalogacao.ui.contributors',
    tag: 'catalogacao.tag.core',
    tier: 1,
    mat: 'all',
    special: 'contrib',
    fields: [
      { id: 'autor', label: 'catalogacao.field.author', tier: 1, span: 3 },
    ],
  },

  // ── 3. Periódico (mat periodico) ──────────────────────────────────────────
  {
    id: 'periodico',
    title: 'catalogacao.section.periodical',
    tag: 'catalogacao.tag.material',
    mat: ['periodico'],
    fields: [
      { id: 'titulo_periodico', label: 'catalogacao.field.periodTitle', tier: 1, mat: ['periodico'], ph: 'catalogacao.ph.periodTitle' },
      { id: 'volume', label: 'catalogacao.field.volume', tier: 1, mat: ['periodico'], phEx: '12' },
      { id: 'numero', label: 'catalogacao.field.issue', tier: 1, mat: ['periodico'], phEx: '3' },
      { id: 'data_edicao', label: 'catalogacao.field.pubDate', tier: 1, mat: ['periodico'], phEx: 'jan.-mar. 2024' },
      { id: 'fasciculo', label: 'catalogacao.field.fascicule', tier: 3, mat: ['periodico'], phEx: 'Especial' },
      { id: 'periodicidade', label: 'catalogacao.field.frequency', tier: 3, mat: ['periodico'], phEx: 'Trimestral' },
    ],
  },

  // ── 4. Capa (special, bouton tous paliers — §5.3) ─────────────────────────
  {
    id: 'capa',
    title: 'catalogacao.ui.chooseCover',
    tag: 'catalogacao.tag.core',
    tier: 1,
    mat: 'all',
    special: 'cover',
    fields: [
      // Le chemin manuel reste un détail tier 3 ; le bouton « Buscar capa » est
      // rendu par le special à tous les paliers (ancre cover_object_path).
      { id: 'cover_object_path', label: 'catalogacao.field.coverUpload', tier: 3, span: 3, phEx: 'books/0000123/front.jpg' },
    ],
  },

  // ── 5. Material efêmero militante : panfleto + cartaz (mat tract/cartaz) ──
  {
    id: 'material_tract',
    title: 'catalogacao.section.tract',
    tag: 'catalogacao.tag.material',
    mat: ['tract', 'cartaz'],
    fields: [
      { id: 'tract_campaign', label: 'catalogacao.field.campaign', tier: 1, ph: 'catalogacao.ph.tractCampaign' },
      { id: 'emitter_org', label: 'catalogacao.field.emitterOrg', tier: 1, ph: 'catalogacao.ph.emitterOrg' },
      { id: 'approximate_date', label: 'catalogacao.field.approxDate', tier: 1, ph: 'catalogacao.ph.approxDate', tierOverride: { cartaz: 2 } },
      { id: 'physical_format', label: 'catalogacao.field.physicalFormat', tier: 1, ph: 'catalogacao.ph.physicalFormat', tierOverride: { tract: 3 } },
      { id: 'diffusion_place', label: 'catalogacao.field.diffusionPlace', tier: 3, ph: 'catalogacao.ph.diffusion' }, // (D7)
      { id: 'print_technique', label: 'catalogacao.field.printTechnique', tier: 3, ph: 'catalogacao.ph.printTechnique' },
      { id: 'physical_state', label: 'catalogacao.field.physicalState', tier: 3, ph: 'catalogacao.ph.physicalState' },
      { id: 'recto_verso', label: 'catalogacao.ui.rectoVerso', tier: 3, type: 'seg', opts: RECTO_VERSO_OPTS },
    ],
  },

  // ── 6. Áudio (mat audio) ──────────────────────────────────────────────────
  {
    id: 'material_audio',
    title: 'catalogacao.section.audio',
    tag: 'catalogacao.tag.material',
    mat: ['audio'],
    fields: [
      { id: 'audio_duration', label: 'catalogacao.field.duration', tier: 1, ph: 'catalogacao.ph.audioDuration' },
      { id: 'audio_support', label: 'catalogacao.field.support', tier: 1, ph: 'catalogacao.ph.audioSupport' },
      { id: 'gravadora', label: 'catalogacao.field.gravadora', tier: 1, phEx: 'Sub Pop' },
      { id: 'audio_participants', label: 'catalogacao.field.participants', tier: 1, span: 2, ph: 'catalogacao.ph.audioParticipants' },
      { id: 'audio_format', label: 'catalogacao.field.audioFormat', tier: 3, ph: 'catalogacao.ph.audioFormatTech' },
      // Langue : portée par le champ cœur `idioma` (évite le doublon).
      { id: 'audio_recording_type', label: 'catalogacao.field.recordingType', tier: 3, ph: 'catalogacao.ph.recordingType' },
    ],
  },

  // ── 7. Audiovisual (mat audiovisual) ──────────────────────────────────────
  {
    id: 'material_audiovisual',
    title: 'catalogacao.section.audiovisual',
    tag: 'catalogacao.tag.material',
    mat: ['audiovisual'],
    fields: [
      { id: 'audiovisual_duration', label: 'catalogacao.field.duration', tier: 1, ph: 'catalogacao.ph.avDuration' },
      { id: 'audiovisual_support', label: 'catalogacao.field.support', tier: 1, ph: 'catalogacao.ph.avSupport' },
      { id: 'audiovisual_director', label: 'catalogacao.field.director', tier: 1, ph: 'catalogacao.ph.avDirector' },
      { id: 'distribuidora', label: 'catalogacao.field.distribuidora', tier: 1, phEx: 'Califórnia Filmes' },
      // Langue : portée par le champ cœur `idioma` (évite le doublon) ; ici on garde
      // les sous-titres, distincts de la langue parlée.
      { id: 'audiovisual_subtitles', label: 'catalogacao.field.subtitles', tier: 3, ph: 'catalogacao.ph.avSubtitles' },
      { id: 'audiovisual_participants', label: 'catalogacao.field.participants', tier: 3, span: 2, ph: 'catalogacao.ph.avParticipants' },
      { id: 'audiovisual_access_note', label: 'catalogacao.field.accessNote', tier: 3, span: 2, ph: 'catalogacao.ph.accessNote' },
    ],
  },

  // ── 8. Recurso digital nativo (mat recurso_digital) ──────────────────────
  {
    id: 'material_digital',
    title: 'catalogacao.section.digital',
    tag: 'catalogacao.tag.material',
    mat: ['recurso_digital'],
    fields: [
      { id: 'digital_native_url', label: 'catalogacao.field.url', tier: 1, span: 2, phEx: 'https://…' },
      { id: 'digital_native_access', label: 'catalogacao.field.accessCondition', tier: 1, ph: 'catalogacao.ph.digitalAccess' },
      { id: 'digital_native_restriction', label: 'catalogacao.field.restriction', tier: 3, ph: 'catalogacao.ph.digitalRestriction' },
      { id: 'digital_native_usage', label: 'catalogacao.field.usage', tier: 3, ph: 'catalogacao.ph.digitalUsage' },
      { id: 'digital_native_file_note', label: 'catalogacao.field.fileNote', tier: 3, ph: 'catalogacao.ph.fileNote' },
    ],
  },

  // ── 9. Dossiê (mat dossie) ────────────────────────────────────────────────
  {
    id: 'material_dossie',
    title: 'catalogacao.material.dossie',
    tag: 'catalogacao.tag.material',
    mat: ['dossie'],
    fields: [
      { id: 'dossier_scope', label: 'catalogacao.field.scope', tier: 1, span: 2, ph: 'catalogacao.ph.dossierScope' },
      { id: 'dossier_period', label: 'catalogacao.field.period', tier: 1, ph: 'catalogacao.ph.dossierPeriod' },
      { id: 'dossier_organizations', label: 'catalogacao.field.organizations', tier: 3, span: 2, ph: 'catalogacao.ph.dossierOrgs' },
      { id: 'dossier_context', label: 'catalogacao.field.context', tier: 3, ph: 'catalogacao.ph.context' },
    ],
  },

  // ── 10. Tese / dissertação (mat tese) ──────────────────────────────────────
  {
    id: 'material_tese',
    title: 'catalogacao.section.tese',
    tag: 'catalogacao.tag.material',
    mat: ['tese'],
    fields: [
      { id: 'tese_university', label: 'catalogacao.field.university', tier: 1, ph: 'catalogacao.ph.university' },
      { id: 'tese_advisor', label: 'catalogacao.field.advisor', tier: 3, ph: 'catalogacao.ph.advisor' },
    ],
  },

  // ── 11. Artigo / capítulo (mat artigo) ────────────────────────────────────
  {
    id: 'material_artigo',
    title: 'catalogacao.section.artigo',
    tag: 'catalogacao.tag.material',
    mat: ['artigo'],
    fields: [
      { id: 'artigo_source', label: 'catalogacao.field.source', tier: 1, span: 2, ph: 'catalogacao.ph.articleSource' },
      { id: 'artigo_volume', label: 'catalogacao.field.volume', tier: 3, phEx: '12' },
      { id: 'artigo_issue', label: 'catalogacao.field.issue', tier: 3, phEx: '3' },
      { id: 'artigo_pages', label: 'catalogacao.field.pages', tier: 3, phEx: '45-72' },
    ],
  },

  // ── 12. Relatório / documento interno (mat relatorio) ─────────────────────
  {
    id: 'material_relatorio',
    title: 'catalogacao.section.relatorio',
    tag: 'catalogacao.tag.material',
    mat: ['relatorio'],
    fields: [
      { id: 'relatorio_org', label: 'catalogacao.field.emitterOrg', tier: 1, span: 2, ph: 'catalogacao.ph.emitterOrg' },
      { id: 'relatorio_recipient', label: 'catalogacao.field.recipient', tier: 3, ph: 'catalogacao.ph.recipient' },
      { id: 'relatorio_internal_notes', label: 'catalogacao.field.internalNotes', tier: 3, type: 'textarea', span: 2, rows: 2 },
    ],
  },

  // ── 13. Zine / fanzine (mat zine) ─────────────────────────────────────────
  {
    id: 'material_zine',
    title: 'catalogacao.section.zine',
    tag: 'catalogacao.tag.material',
    mat: ['zine'],
    fields: [
      { id: 'zine_print_run', label: 'catalogacao.field.printRun', tier: 3, phEx: '200' },
      { id: 'zine_technique', label: 'catalogacao.field.printTechnique', tier: 3, ph: 'catalogacao.ph.printTechnique' },
      { id: 'zine_format', label: 'catalogacao.field.physicalFormat', tier: 3, ph: 'catalogacao.ph.physicalFormat' },
    ],
  },

  // ── 14. Aquisição & proveniência (tier 3, legacy fiche-level — §5.7) ──────
  {
    id: 'aquisicao',
    title: 'catalogacao.ui.acquisitionTitle',
    tag: 'catalogacao.tag.complete',
    tier: 3,
    mat: 'all',
    fields: [
      { id: 'acquisition_mode', label: 'catalogacao.field.acquisitionMode', tier: 3, ph: 'catalogacao.ph.acquisitionMode' },
      { id: 'acquisition_date', label: 'catalogacao.field.acquisitionDate', tier: 3, type: 'date' },
      { id: 'source_label', label: 'catalogacao.field.sourceLabel', tier: 3, phEx: 'Nome da pessoa ou entidade' },
      { id: 'owner_library', label: 'catalogacao.field.ownerLibrary', tier: 3, type: 'library_select' },
      { id: 'holder_library', label: 'catalogacao.field.holderLibrary', tier: 3, type: 'library_select' },
      { id: 'mutualization_status', label: 'catalogacao.field.mutualizationStatus', tier: 3 },
      { id: 'partner_source', label: 'catalogacao.field.partnerSource', tier: 3 },
      { id: 'source_record_id', label: 'catalogacao.field.sourceRecordId', tier: 3 },
      { id: 'source_record_url', label: 'catalogacao.field.sourceRecordUrl', tier: 3, span: 2 },
      { id: 'import_format', label: 'catalogacao.field.importFormat', tier: 3 },
      { id: 'import_method', label: 'catalogacao.field.importMethod', tier: 3 },
      { id: 'provenance_note', label: 'catalogacao.field.provenanceNote', tier: 3, type: 'textarea', span: 3, rows: 2 },
    ],
  },

  // ── 11. Autoridade / ISBD / MARC (special 'fine', tier 3 — §5.2) ──────────
  {
    id: 'autoridade',
    title: 'catalogacao.ui.archTitle',
    tag: 'catalogacao.tag.complete',
    tier: 3,
    mat: 'all',
    special: 'fine',
    fields: [
      { id: 'marc_json', label: 'catalogacao.field.marcJson', tier: 3, type: 'textarea', span: 3, rows: 4, phEx: '{"anarbib_subjects": [...]}' },
      // Zones ISBD 0–8 : générées, rendu dédié par le special 'fine'
      // (clés catalogacao.isbd.zone0..zone8 + book.isbd.zone7).
      // viaf/isni/wikidata retirés du niveau livre — ces identifiants
      // appartiennent au niveau autorité (authors.viaf_id/isni/wikidata_id).
    ],
  },
];

// ── Helpers de visibilité (§3.3, à la lettre) ───────────────────────────────
export function matchMat(mat, material) {
  if (mat == null || mat === 'all') return true;
  return Array.isArray(mat) && mat.includes(material);
}

export function isFieldVisible(field, tier, material) {
  const effectiveTier = field.tierOverride?.[material] ?? field.tier;
  return effectiveTier <= tier && matchMat(field.mat, material);
}

export function isGroupVisible(group, tier, material) {
  if (!matchMat(group.mat, material)) return false;
  if (group.tier != null && group.tier > tier) return false;
  if (group.special) return true; // groupe à rendu dédié : visible dès que mat+tier OK
  return (group.fields || []).some(fld => isFieldVisible(fld, tier, material));
}

// Groupes visibles, chacun avec ses champs déjà filtrés par (tier, material).
// Les groupes `special` conservent `fields` filtré (utile p.ex. au special 'cover'
// dont le chemin manuel n'apparaît qu'en tier 3) ; leur rendu reste dédié au Lot 2.
export function visibleGroups(tier, material) {
  return REGISTRY
    .filter(g => isGroupVisible(g, tier, material))
    .map(g => ({ ...g, fields: (g.fields || []).filter(fld => isFieldVisible(fld, tier, material)) }));
}

// Index id → champ (pratique pour le wiring/validation au Lot 2).
export const FIELD_BY_ID = Object.freeze(
  REGISTRY.reduce((acc, g) => {
    for (const fld of g.fields || []) acc[fld.id] = { ...fld, group: g.id };
    return acc;
  }, {}),
);
