// =============================================================================
// ficedlPartners.js — nommage et dédoublonnage des liens « catalogues partenaires ».
// =============================================================================
// Les fiches du thésaurus FICEDL portent des `catalog_links` aspirés tels quels
// (ANTI-FORK) : chaque lien garde le libellé de l'attribut `title=` du SPIP
// source. Or ces libellés sont FAUX en amont sur trois hôtes — copier-coller
// jamais corrigé côté FICEDL (constaté le 27/08/2026 sur mot1 « action
// directe », mais le tableau des occurrences le montre systématique) :
//
//   bibliotheque.cira-marseille.info  →  « mot marseille »               (376 liens)
//   archives.cira-marseille.info      →  « …du CCL » (c'est RA.forum)    (370 liens)
//   ml.ficedl.info (forme .html)      →  le libellé du terme lui-même    (309 liens)
//
// Le lien pointe au bon endroit, seul le NOM ment. On ne touche donc pas à la
// donnée aspirée : on nomme le partenaire d'après son HÔTE au moment de
// l'affichage. Deux hôtes de plus mentent de la même façon depuis qu'ils sont
// relevés (22/10/2026) : canto et ephemera s'annoncent « mot canto » et
// « mot ephemera », et ficedl.info « mot ficedl ». Noms propres uniquement — ils se lisent dans les 10 locales, le
// titre de section (« dans les catalogues partenaires ») étant déjà traduit.
//
// Au passage : ml.ficedl.info sert deux URL pour la même cible (`?motN` et
// `motN.html`), d'où un doublon sur 308 fiches. Le dédoublonnage se fait sur
// (hôte + numéro de mot), pas sur l'URL brute — un même partenaire peut avoir
// PLUSIEURS descripteurs distincts sur un terme (38 fiches), et ceux-là restent.
// =============================================================================

/**
 * Partenaires du réseau FICEDL, dans l'ordre d'affichage souhaité.
 * `host` teste le nom d'hôte, `path` (optionnel) affine quand un hôte héberge
 * plusieurs ressources.
 */
export const FICEDL_PARTNERS = [
  { id: 'cira-lausanne', name: 'CIRA Lausanne', host: /(^|\.)cira\.ch$/i },
  { id: 'cira-marseille', name: 'CIRA Marseille', host: /^bibliotheque\.cira-marseille\.info$/i },
  { id: 'raforum', name: 'RA.forum', host: /^archives\.cira-marseille\.info$/i, path: /^\/raforum\//i },
  { id: 'ccl-lille', name: 'CCL Lille', host: /^lille\.cybertaria\.org$/i },
  { id: 'placard', name: 'Placard', host: /^placard\.ficedl\.info$/i },
  { id: 'cartoliste', name: 'Cartoliste', host: /^cartoliste\.ficedl\.info$/i },
  { id: 'monde-libertaire', name: 'Le Monde libertaire', host: /^ml\.ficedl\.info$/i },
  // Huit hôtes de plus depuis le 22/10/2026. Ils étaient dans les fiches depuis
  // le début : c'est NOTRE relevé qui les jetait, parce qu'il reconnaissait un
  // catalogue du réseau par une liste de sept hôtes écrite à la main. Sur les
  // fiches relues ce jour-là, 62 % des liens partaient ainsi en silence. Les
  // noms ci-dessous sont ceux que la source donne elle-même, raccourcis au nom
  // propre comme les précédents ; le nom complet est en commentaire.
  { id: 'bianco', name: 'Bianco', host: /^bianco\.ficedl\.info$/i },                   // presse anarchiste francophone
  { id: 'bettini', name: 'Bettini', host: /^bettini\.ficedl\.info$/i },                // periodici anarchici
  { id: 'madrid-santos', name: 'Madrid Santos', host: /^madrid-santos\.ficedl\.info$/i }, // prensa anarquista y anarcosindicalista en España (1869-1939)
  { id: 'lidiap', name: 'LIDIAP', host: /^lidiap\.ficedl\.info$/i },                   // List of digitized anarchist periodicals
  { id: 'canto', name: 'Canto', host: /^canto\.ficedl\.info$/i },                      // chansons
  { id: 'ephemera', name: 'Ephemera', host: /^ephemera\.ficedl\.info$/i },              // artefacts & ephemera
  { id: 'cgecaf', name: 'Cgécaf', host: /^cgecaf\.ficedl\.info$/i },                   // Catalogue général des éditions et collections anarchistes francophones
  { id: 'ficedl', name: 'FICEDL', host: /^(www\.)?ficedl\.info$/i },                   // le site de la fédération, qui tient son propre index par mot-clé
];

function parse(href) {
  try {
    return new URL(href);
  } catch {
    return null;
  }
}

/** Partenaire reconnu pour cette URL, ou null (hôte inconnu / URL invalide). */
export function partnerOf(href) {
  const u = parse(href);
  if (!u) return null;
  return (
    FICEDL_PARTNERS.find((p) => p.host.test(u.hostname) && (!p.path || p.path.test(u.pathname))) || null
  );
}

/** Nom à afficher : celui du partenaire, à défaut le libellé aspiré, à défaut l'URL. */
export function partnerLinkName(link) {
  if (!link || !link.href) return '';
  const partner = partnerOf(link.href);
  return partner ? partner.name : link.name || link.href;
}

// Deux URL désignent la même cible SPIP dès qu'elles portent le même numéro de
// mot (`?mot3` et `mot3.html`). Sinon, on retombe sur chemin + requête.
function targetKey(href) {
  const u = parse(href);
  if (!u) return href;
  const mot = (u.pathname + u.search).match(/mot(\d+)/i);
  return `${u.hostname.toLowerCase()}#${mot ? `mot${mot[1]}` : u.pathname + u.search}`;
}

/**
 * Liens prêts à afficher : dédoublonnés par cible, ordonnés par partenaire
 * (hôtes inconnus en fin de liste), chacun enrichi d'un `displayName`.
 *
 * Un même partenaire peut porter DEUX descripteurs distincts pour un seul terme
 * (38 fiches, surtout RA.forum). Les entrées sont alors numérotées : sans quoi
 * la liste afficherait deux fois le même nom, qu'on lirait comme un doublon.
 *
 * @param {Array<{name?: string, href: string}>} links
 */
export function normalizePartnerLinks(links) {
  const seen = new Set();
  const out = [];
  for (const link of Array.isArray(links) ? links : []) {
    if (!link || !link.href) continue;
    const key = targetKey(link.href);
    if (seen.has(key)) continue;
    seen.add(key);
    const partner = partnerOf(link.href);
    out.push({
      ...link,
      key,
      partnerId: partner ? partner.id : null,
      displayName: partner ? partner.name : link.name || link.href,
      rank: partner ? FICEDL_PARTNERS.indexOf(partner) : FICEDL_PARTNERS.length,
    });
  }
  out.sort((a, b) => a.rank - b.rank);

  const total = {};
  for (const l of out) if (l.partnerId) total[l.partnerId] = (total[l.partnerId] || 0) + 1;
  const nth = {};
  for (const l of out) {
    if (!l.partnerId || total[l.partnerId] < 2) continue;
    nth[l.partnerId] = (nth[l.partnerId] || 0) + 1;
    l.displayName = `${l.displayName} (${nth[l.partnerId]})`;
  }
  return out;
}
