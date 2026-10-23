// src/lib/catalogFilters.js
// Construction des filtres serveur (PostgREST) pour la grille du catalogue OPAC.
// Extrait de CatalogPage afin d'être testable unitairement (fonction pure, sans React).
//
// Session : Catalogue longue traîne (recherche + fiche auteur)

// Colonnes balayées par la recherche libre (texte brut).
// Les filtres que l'URL porte, et eux seuls. L'URL est la source de vérité d'un
// lien profond : un lien partagé doit produire le même écran chez tout le monde,
// sans rien hériter de ce qui traîne en session. `biblioteca` est à part, la
// route pouvant la porter comme segment.
export const URL_FILTER_KEYS = ['q', 'autor', 'editora', 'ano', 'subject', 'idioma'];

/**
 * Lit les filtres d'un lien profond. Rend des chaînes (jamais null), et dit si
 * l'URL porte une intention — sans quoi l'appelant ne doit RIEN remettre à zéro.
 *
 * @param {URLSearchParams} sp
 * @param {string} routeLibrarySlug  bibliothèque portée par la route, prioritaire
 */
export function lireFiltresURL(sp, routeLibrarySlug = '') {
  const get = (k) => sp.get(k) || '';
  const library = routeLibrarySlug || get('biblioteca');
  const filtres = { library };
  for (const k of URL_FILTER_KEYS) filtres[k] = get(k);
  filtres.hasIntent = Boolean(library) || URL_FILTER_KEYS.some((k) => sp.has(k));
  return filtres;
}

export const SEARCH_COLS = ['titulo', 'autor', 'editora', 'bib_ref', 'cdd', 'assuntos', 'subtitulo', 'isbn'];

/**
 * Construit l'objet de filtres passé à apiQuery (clé = paramètre PostgREST).
 *
 * Recherche libre MULTI-MOTS : chaque mot doit apparaître dans AU MOINS une des
 * colonnes balayées (ET entre les mots, OU entre les colonnes). Ainsi
 * « Bakounine Dieu » retrouve une notice contenant les deux termes même
 * lorsqu'ils ne sont pas contigus — ce que l'ancien `ilike %phrase%` global
 * (un seul motif sur toute la chaîne) ratait systématiquement.
 *
 * Toutes les clauses composables (recherche, intervalle d'année, multi-biblio)
 * sont regroupées sous un UNIQUE paramètre `and` : PostgREST n'accepte qu'une
 * seule clé `and`/`or` au niveau racine. L'ancienne version écrivait `f['or']`
 * À LA FOIS pour la recherche ET pour le filtre multi-biblio — la seconde
 * écrasait silencieusement la première (la recherche libre était donc IGNORÉE
 * dès qu'on cochait ≥ 2 bibliothèques). La consolidation corrige ce bug.
 */
export function buildServerFilters({ search, authorFilter, authorIdFilter, alphaFilter, publisherFilter, yearFilter, libraryShortNames, availabilityFilter, isAuth, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter, authorIds = null }) {
  const f = {};
  const andClauses = [];

  // Recherche libre. Une phrase entre guillemets ("apoio mútuo") compte pour UN
  // terme contigu ; le reste est découpé en mots. ET entre les termes, OU entre
  // les colonnes. On retire les caractères qui casseraient la grammaire
  // and()/or() de PostgREST (et les guillemets, structurels), et on plafonne à
  // 6 termes (anti-URL pathologique). Chaque terme => un groupe or() sur toutes
  // les colonnes.
  const terms = [];
  const tokenRe = /"([^"]+)"|(\S+)/g;
  let tk;
  while ((tk = tokenRe.exec(String(search || ''))) !== null) {
    const term = (tk[1] ?? tk[2]).replace(/[(),"]/g, '').trim();
    if (term) terms.push(term);
    if (terms.length >= 6) break;
  }
  for (const term of terms) {
    const esc = `%${term}%`;
    andClauses.push(`or(${SEARCH_COLS.map(c => `${c}.ilike.${esc}`).join(',')})`);
  }

  // #OPAC10 parcours A–Z (préfixe d'auteur·rice) prioritaire ; sinon filtre par
  // LIEN d'autorité (author_id, regroupe les graphies) ; sinon texte brut.
  if (alphaFilter && String(alphaFilter).trim()) f['autor'] = `ilike.${String(alphaFilter).trim()}%`;
  else if (authorIdFilter && String(authorIdFilter).trim()) f['author_id'] = `eq.${String(authorIdFilter).trim()}`;
  else if (authorFilter.trim()) {
    // Mot par mot (comme api.catalog_works_v1) : les notices écrivent « GOLDMAN,
    // Emma », la saisie « Emma Goldman » doit la trouver. Chaque mot est cherché
    // dans `autor` (la saisie libre) OU `author_display` (le nom d'autorité que
    // la ligne affiche) : « Confederación » trouve la notice saisie « C.N.T. »
    // et affichée « Confederación Nacional del Trabajo » (06/10). Un groupe or()
    // par mot, dans le `and` consolidé.
    const words = authorFilter.split(/[\s,;]+/).map(w => w.replace(/[(),"]/g, '')).filter(Boolean).slice(0, 6);
    const motClauses = words.map(w => `or(autor.ilike.%${w}%,author_display.ilike.%${w}%)`);
    const ids = Array.isArray(authorIds) ? authorIds.map(Number).filter(Number.isFinite) : [];
    if (ids.length > 0 && motClauses.length > 0) {
      // E38 (12/10/2026) : la page a résolu le nom en identifiants d'autorité
      // (api.catalog_author_ids_v1 : forme retenue, forme de tri, variantes,
      // alias — comme catalog_works_v1 en liste par œuvre). Une notice compte
      // si son lien principal (author_id) ou l'un de ses contributeurs
      // (author_chips) porte l'une de ces autorités, OU si son texte porte
      // chaque mot — l'ILIKE reste pour les notices sans autorité liée.
      const parLien = [`author_id.in.(${ids.join(',')})`, ...ids.map(id => `author_chips.cs.[{"author_id":${id}}]`)];
      andClauses.push(`or(${[...parLien, `and(${motClauses.join(',')})`].join(',')})`);
    } else {
      for (const c of motClauses) andClauses.push(c);
    }
  }
  if (publisherFilter.trim()) f['editora'] = `ilike.%${publisherFilter.trim()}%`;

  // Année : valeur exacte (clé `ano`) ou intervalle (→ clauses consolidées).
  if (yearFilter.trim()) {
    const raw = yearFilter.trim();
    const m = raw.match(/^(\d{4})\s*[-–]\s*(\d{4})$/);
    if (m) { andClauses.push(`ano.gte.${m[1]}`); andClauses.push(`ano.lte.${m[2]}`); }
    else f['ano'] = `eq.${raw}`;
  }

  // Bibliothèque(s) : une seule → `cs` direct ; plusieurs → groupe or() consolidé.
  if (Array.isArray(libraryShortNames) && libraryShortNames.length > 0) {
    if (libraryShortNames.length === 1) f['holding_library_names_json'] = `cs.["${libraryShortNames[0]}"]`;
    else andClauses.push(`or(${libraryShortNames.map(sn => `holding_library_names_json.cs.["${sn}"]`).join(',')})`);
  }

  // Filtres avancés (colonnes distinctes : aucune collision de clé possible).
  if (isbnFilter.trim()) f['isbn'] = `ilike.%${isbnFilter.trim().replace(/[-\s]/g, '')}%`;
  // CONV-7 : `idioma` porte un code BCP-47. Le selecteur envoie un code ->
  // egalite stricte. On garde le `ilike` pour une saisie libre (URL forgee a
  // la main, favori d'avant la normalisation) : le residu hors table de
  // correspondance reste ainsi atteignable.
  if (languageFilter.trim()) {
    const lang = languageFilter.trim();
    // Un code de langue SANS région désigne la langue, donc ses variantes
    // régionales : « pt » prend « pt-BR » (1 278 notices sur 3 216 décrites au
    // 23/10/2026), « fr » prendrait « fr-CA ». CONV-7 garde ce qu'elle
    // protégeait — un code ne tombe pas dans un ILIKE large — mais l'égalité
    // stricte sur un code court ratait ses variantes, ce qui s'est vu quand les
    // descripteurs de langue du thésaurus FICEDL, nommés par le code court, ont
    // commencé à mener au catalogue : « portugais » rendait zéro notice.
    //
    // ⚠️ LA MÊME RÈGLE EST DANS `api.catalog_works_v1` (migration du 23/10) : le
    // mode « œuvres » filtre côté serveur, et n'avoir corrigé qu'ici laissait le
    // défaut entier sur l'écran par défaut. Les deux doivent bouger ensemble.
    if (/^[a-z]{2}$/.test(lang)) {
      andClauses.push(`or(idioma.eq.${lang},idioma.like.${lang}-*)`);
    } else if (/^[a-z]{2}(-[A-Z]{2})?$/.test(lang)) {
      f['idioma'] = `eq.${lang}`;
    } else {
      // Saisie libre (URL forgée à la main, favori d'avant la normalisation) :
      // le résidu hors table de correspondance reste atteignable.
      f['idioma'] = `ilike.%${lang}%`;
    }
  }
  if (cddFilter.trim()) f['cdd'] = `ilike.${cddFilter.trim()}%`;
  if (subjectsFilter.trim()) f['assuntos'] = `ilike.%${subjectsFilter.trim()}%`;
  if (materialFilter && materialFilter !== '__all__') f['tipo_material'] = `eq.${materialFilter}`;
  if (collectionFilter.trim()) f['colecao'] = `ilike.%${collectionFilter.trim()}%`;
  if (placeFilter.trim()) f['local_publicacao'] = `ilike.%${placeFilter.trim()}%`;

  if (availabilityFilter && availabilityFilter !== '__all__' && isAuth) {
    switch (availabilityFilter) {
      case 'available': f['session_status_hint'] = 'eq.no_acervo_da_sua_biblioteca'; f['session_available_count'] = 'gt.0'; break;
      case 'consult': f['session_status_hint'] = 'eq.consultavel_no_local'; break;
      case 'unavailable_user': f['session_status_hint'] = 'eq.indisponivel_para_voce'; break;
      case 'unavailable_now': f['session_status_hint'] = 'eq.no_acervo_da_sua_biblioteca'; f['session_available_count'] = 'eq.0'; break;
      case 'unavailable_other': f['session_has_holding'] = 'is.false'; break;
      case 'check': f['session_status_hint'] = 'eq.sem_biblioteca_de_sessao'; break;
    }
  }
  // Doctrine A1/A2/A3 : aucun filtre availabilityFilter ne s'applique pour l'anon.

  // Une seule clé `and` consolidée (recherche multi-mots + année + multi-biblio).
  if (andClauses.length) f['and'] = `(${andClauses.join(',')})`;
  return f;
}
