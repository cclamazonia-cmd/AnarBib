// =============================================================================
// AnarBib -- identifiants publics (profiles.public_id)
// =============================================================================
// Depuis les migrations 20260817123058 (generate_public_id réparée) et
// 20260820200000 (retrait du DEFAULT séquentiel), un identifiant public est
// une suite de VINGT caractères hexadécimaux minuscules — plus « U000123 ».
//
// Vingt caractères d'affilée ne se lisent pas et se dictent encore moins. On
// les affiche donc par groupes de quatre :
//
//   7b3f0c9a2e5d18406c1f  ->  7b3f 0c9a 2e5d 1840 6c1f
//
// Deux fonctions, toujours utilisées par paires :
//   - formatPublicId   : AU RENDU uniquement (jamais dans un état React, jamais
//                        dans ce qu'on envoie au serveur) ;
//   - normalizePublicId: à la SAISIE, avant tout envoi — recolle les groupes,
//                        pour qu'un identifiant copié depuis l'écran fonctionne.
//
// Les deux laissent passer inchangé tout ce qui n'est pas un identifiant au
// format canonique : e-mail, identité locale (qui peut contenir des espaces),
// et les rares identifiants séquentiels « U000xxx » qui n'ont pas encore été
// régénérés.
// =============================================================================

const CANONICAL = /^[0-9a-f]{20}$/i;

// Découpe un identifiant canonique en groupes de quatre, pour l'affichage.
// Toute autre valeur (y compris non-chaîne) est rendue telle quelle.
export function formatPublicId(value) {
  if (typeof value !== 'string') return value;
  const compact = value.trim();
  if (!CANONICAL.test(compact)) return value;
  return compact.toLowerCase().match(/.{4}/g).join(' ');
}

// Inverse de formatPublicId : enlève les espaces (y compris ceux du milieu) et
// met en minuscules, mais SEULEMENT si le résultat est un identifiant
// canonique. Une identité locale « Jean Dupont » ou une adresse e-mail
// ressortent simplement débarrassées de leurs espaces de bord.
export function normalizePublicId(value) {
  const raw = (value ?? '').trim();
  const compact = raw.replace(/\s+/g, '');
  return CANONICAL.test(compact) ? compact.toLowerCase() : raw;
}
