// Libellé traduit d'un rôle de contributeur (book_contributors.role).
//
// Les rôles sont stockés sous leur code d'origine, en portugais (« autor »,
// « organizador », « tradutor »…). Chaque code a son libellé dans les dix
// locales sous `catalogacao.role.<code>` — mais la page du livre et la page
// Auteur écrivaient le code brut entre parenthèses, d'où « (organizador) »
// au milieu d'une fiche en français (vu en prod le 08/10/2026, /livro/1225).
// Même famille que le « tombo » laissé brut : la garde i18n ne voit pas un
// affichage qui court-circuite la traduction.
//
// Repli sur le code brut si une clé manque (rôle inconnu des locales) :
// mieux vaut « (coletivo) » qu'une clé « catalogacao.role.coletivo » à
// l'écran et une erreur react-intl en console.
export function roleLabel(role, intl) {
  if (!role) return '';
  const id = `catalogacao.role.${role}`;
  const known = intl && intl.messages && Object.prototype.hasOwnProperty.call(intl.messages, id);
  return known ? intl.formatMessage({ id }) : role;
}
