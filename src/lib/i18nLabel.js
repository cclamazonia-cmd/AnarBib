// =============================================================================
// i18nLabel.js — sélection d'un libellé multilingue stocké en base (jsonb).
// =============================================================================
// Helper partagé pour les dictionnaires { <locale>: "libellé", … } venant de la
// base. Renvoie le libellé de la locale active, avec repli en cascade.
//
// `pivot` = langue de repli quand la locale active manque. Pour le thésaurus
// PARTAGÉ FICEDL, la langue-pivot de la source est le FRANÇAIS (fr) → pivot 'fr'
// par défaut. (Le thésaurus-matière INTERNE d'AnarBib, lui, a pour pivot 'pt-BR'
// et garde son propre helper local côté catalogage — périmètres distincts.)
//
// ANTI-FORK : on AFFICHE le libellé tel qu'il est stocké, jamais on ne le
// reformate. Un libellé identique au français (terme non traduit à la source)
// est affiché tel quel.
// =============================================================================

/**
 * @param {Record<string,string>|null|undefined} labels  dictionnaire locale→libellé
 * @param {string} locale  locale active (ex. 'pt-BR', 'fr', 'ca')
 * @param {string} [pivot='fr']  langue de repli (pivot de la source)
 * @returns {string}
 */
export function pickLabel(labels, locale, pivot = 'fr') {
  if (!labels || typeof labels !== 'object') return '';
  const short = (locale || '').split('-')[0];
  return (
    labels[locale] ||
    labels[short] ||
    labels[pivot] ||
    Object.values(labels).find((v) => typeof v === 'string' && v) ||
    ''
  );
}

/** Vrai si aucun libellé n'existe dans la locale active (ni sa forme courte). */
export function isLabelMissing(labels, locale) {
  if (!labels || typeof labels !== 'object') return true;
  const short = (locale || '').split('-')[0];
  return !labels[locale] && !labels[short];
}
