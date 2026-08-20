// ─────────────────────────────────────────────────────────────────────────
// Qui peut arbitrer un doublon de façon destructeur ? (paquet DOUBLONS P4)
//
// Trois gestes du catalogage détruisent des données sans retour arrière :
// fusionner deux notices, fusionner deux autorités, écarter définitivement une
// paire. Ils sont réservés à la coordination depuis le 21/08/2026.
//
// Ce fichier ne fait que MASQUER les boutons. La garde qui compte est en base
// (public.fn_is_dedup_arbiter), et elle seule est opposable : une interface se
// contourne. Les deux doivent dire la même chose, sinon on promet un bouton
// qui échouera — ou on cache une action pourtant permise.
//
// Volontairement limité à ce que la base honore réellement : la contrainte
// CHECK de user_library_memberships n'accepte que reader, librarian et
// coordenador. « administrador » figure encore dans la hiérarchie du
// LibraryContext mais ne peut plus être porté par un rattachement ; l'inclure
// ici afficherait un bouton que la base refuserait.
//
// Nuance connue et assumée : effectiveRole décrit le rôle dans la bibliothèque
// COURANTE, alors que la base accepte une coordination dans n'importe quelle
// bibliothèque. Quelqu'un qui coordonne la biblio B mais consulte la biblio A
// verra donc moins de boutons que la base ne lui en accorderait. On préfère
// cacher un bouton permis qu'en proposer un qui casse — et pour la fusion de
// notices, la garde de rattachement exige de toute façon la coordination
// d'une des bibliothèques détentrices.
// ─────────────────────────────────────────────────────────────────────────

const ARBITER_ROLES = new Set(['coordenador', 'network_admin']);

export function canArbitrateDuplicates(effectiveRole) {
  return ARBITER_ROLES.has(effectiveRole || '');
}
