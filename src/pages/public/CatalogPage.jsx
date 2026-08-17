import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { buildServerFilters } from '@/lib/catalogFilters';
import { toTurtle, toJsonLd, downloadText } from '@/lib/skosExport';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, EmptyState, Spinner } from '@/components/ui';
import UnifiedSearchCombobox from '@/components/UnifiedSearchCombobox';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import './CatalogPage.css';

const PAGE_SIZE = 100;
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''); // #OPAC10 parcours A–Z
// #OPAC7 — divisions CDD avec libellé curé (sens anarchiste, cf. cotation-et-cdd.md).
// Les autres codes retombent sur la classe principale Dewey.
function localizedSubjectLabel(li, locale) {
  if (!li || typeof li !== 'object') return '';
  return li[locale] || li[(locale || '').split('-')[0]] || li['pt-BR'] || Object.values(li)[0] || '';
}
const CDD_DIV_LABELS = new Set([
  '070', '301', '303', '305', '320', '321', '322', '323', '324', '331',
  '333', '334', '335', '355', '365', '370', '909', '920', '944', '946',
  '972', '980', '981',
]);

// URLs des manuels (stockes sur Supabase Storage, bucket library-ui-assets).
// Le manuel lecteur est un PDF multilingue unique (8 langues en interne).
const PUBLIC_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','publisher_display','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total','available_count',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json','cover_object_path',
].join(',');

const SESSION_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','publisher_display','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json',
  'session_library_id','session_library_slug','session_library_name',
  'session_exemplares_total','session_has_holding','session_status_hint',
  'session_available_count','session_loanable','cover_object_path',
].join(',');

// Sort options, availability options, and status labels are built inside the component using t()
// See useMemo blocks inside CatalogPage

const TIPO_ICONS = {
  livro:'📕', periodico:'📰', folheto:'📄', boletim:'📰',
  arquivo:'📂', zine:'✊', tract:'📜', cartaz:'🪧',
  audio:'🎧', audiovisual:'🎬', recurso_digital:'💻',
  dossie:'📁', outro:'📎',
};

// Miniatures de couverture : endpoint de transformation d'image de Supabase
// Storage → vraies vignettes (~7 Ko en width=64 vs ~155 Ko la pleine résolution).
const COVER_RENDER_BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/render/image/public/covers/';
function coverThumb(path) {
  // height + resize=contain REQUIS : avec width seul, l'endpoint render ne
  // rescale pas la hauteur → bande déformée. Box 64×96 (ratio couverture).
  return path ? `${COVER_RENDER_BASE}${path}?width=64&height=96&resize=contain&quality=70` : null;
}

// ── Helpers ────────────────────────────────────────────────

function parseLibraryNames(book) {
  try {
    const n = book.holding_library_names_json;
    if (!n) return book.biblioteca || book.library_name || '';
    if (typeof n === 'string') { const p = JSON.parse(n); return Array.isArray(p) ? p.join(', ') : typeof p === 'object' ? Object.values(p).join(', ') : String(n); }
    if (Array.isArray(n)) return n.join(', ');
    if (typeof n === 'object') return Object.values(n).join(', ');
    return String(n);
  } catch { return book.biblioteca || book.library_name || ''; }
}

function getStatusInfo(book, isAuth, t) {
  // Doctrine A1/A2/A3 (tableau BLMF) : pour un anon, l'affichage reste public et
  // non personnalise. Ne PAS exposer la distinction pret/consultation (loanable)
  // a un visiteur non connecte.
  if (!isAuth) {
    return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
  }
  const h = (book.session_status_hint || '').toLowerCase();
  if (!h || h === 'sem_biblioteca_de_sessao') {
    if (book.loanable === false) return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
    return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
  }
  if (h === 'indisponivel_para_voce') return { label: t({ id: 'catalog.avail.unavailUser' }), cls: 'bad' };
  if (h === 'consultavel_no_local') return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
  if (h === 'no_acervo_da_sua_biblioteca') {
    const c = Number(book.session_available_count) || 0;
    if (c > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: c }), cls: 'ok' };
    return { label: t({ id: 'catalog.avail.unavailNow' }), cls: 'bad' };
  }
  return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
}

// buildServerFilters est désormais une fonction pure extraite dans
// src/lib/catalogFilters.js (recherche multi-mots + tests unitaires
// src/tests/catalogFilters.test.js).

function sortLabel(v, opts) { return opts.find(o => o.value === v)?.label || ''; }

function useDebounce(value, delay = 400) {
  const [d, setD] = useState(value);
  useEffect(() => { const t = setTimeout(() => setD(value), delay); return () => clearTimeout(t); }, [value, delay]);
  return d;
}

// ── Export helpers ──────────────────────────────────────────

function exportCSV(books) {
  const header = ['ref','autor','titulo','ano','editora','biblioteca'];
  const rows = books.map(b => [b.bib_ref||'', (b.author_display||b.autor||'').replace(/"/g,'""'), (b.titulo||'').replace(/"/g,'""'), b.ano||'', ((b.publisher_display||b.editora)||'').replace(/"/g,'""'), parseLibraryNames(b).replace(/"/g,'""')]);
  const csv = [header.join(','), ...rows.map(r => r.map(c => `"${c}"`).join(','))].join('\n');
  const blob = new Blob(['\uFEFF'+csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = 'anarbib-catalogo.csv'; a.click();
  URL.revokeObjectURL(url);
}

function exportPDF(books, t) {
  const now = new Date().toLocaleDateString('pt-BR');
  const rows = books.map(b =>
    `<tr><td>${b.bib_ref||'—'}</td><td>${b.author_display||b.autor||'—'}</td><td>${b.titulo||'—'}${b.subtitulo?` — ${b.subtitulo}`:''}</td><td>${b.ano||'—'}</td><td>${b.publisher_display||b.editora||'—'}</td><td>${parseLibraryNames(b)||'—'}</td></tr>`
  ).join('');
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>AnarBib — ${t({id:'catalog.title'})} — ${now}</title>
<style>
  body{font-family:Georgia,serif;margin:24px;color:#111;font-size:11px;}
  h1{font-size:18px;margin:0 0 4px;}h2{font-size:12px;font-weight:normal;color:#555;margin:0 0 16px;}
  table{width:100%;border-collapse:collapse;margin-top:8px;}
  th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid #111;padding:4px 6px;color:#333;}
  td{padding:4px 6px;border-bottom:1px solid #ddd;font-size:10.5px;vertical-align:top;}
  tr:nth-child(even){background:#f7f7f7;}
  .footer{margin-top:16px;font-size:9px;color:#888;text-align:center;border-top:1px solid #ccc;padding-top:8px;}
  @media print{body{margin:12px;}@page{size:A4 landscape;margin:10mm;}}
</style></head><body>
<h1>AnarBib — ${t({id:'catalog.title'})}</h1>
<h2>${books.length} ${t({id:'catalog.results.count'},{count:books.length})} — ${now}</h2>
<table><thead><tr><th>${t({id:'catalog.table.ref'})}</th><th>${t({id:'catalog.table.author'})}</th><th>${t({id:'catalog.table.bookTitle'})}</th><th>${t({id:'catalog.table.year'})}</th><th>${t({id:'catalog.table.publisher'})}</th><th>${t({id:'catalog.table.libraries'})}</th></tr></thead><tbody>${rows}</tbody></table>
<div class="footer">AnarBib — ${t({id:'app.subtitle'})} — ${now}</div>
<script>window.onload=()=>window.print();</${'script'}>
</body></html>`;
  const w = window.open('', '_blank');
  if (w) { w.document.write(html); w.document.close(); }
}

// ── Persistance des filtres ─────────────────────────────────

const FILTER_STORAGE_KEY = 'anarbib:catalog:filters';

function loadSavedFilters() {
  try {
    const raw = localStorage.getItem(FILTER_STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
}

function saveFilters(filters) {
  try { localStorage.setItem(FILTER_STORAGE_KEY, JSON.stringify(filters)); } catch {}
}

// ── Composant ──────────────────────────────────────────────

export default function CatalogPage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.catalog' }));
  const { user } = useAuth();
  const { libraryName, libraryId, role: libraryRole } = useLibrary();
  const isStaff = libraryRole === 'librarian' || libraryRole === 'coordenador' || libraryRole === 'administrador';
  const navigate = useNavigate();
  // Alias profond /catalogo/:slug + query params (galerie anarbib.org, copySearchLink).
  const { slug: routeLibrarySlug } = useParams();
  const [urlSearchParams] = useSearchParams();
  const isAuth = !!user;
  const tableRef = useRef(null);
  const [regimentoUrl, setRegimentoUrl] = useState(null);

  // ── Réservation rapide depuis le catalogue (Paquet 27 quickReserve) ──
  // serviceState : connaître si la biblio est `pausada` / `somente_consulta`
  //   → on cache le bouton dans ces cas.
  // isRestricted : profil suspendu (sanction militante) → on cache aussi.
  // reserveState : statut par livre, clef = book_id (ou bib_ref en fallback).
  //   Valeurs : 'idle' | 'reserving' | 'done' | 'error:<message>'
  // reservedBibRefs : set des bib_ref déjà réservés avec succès dans la
  //   session courante du catalogue, pour ne pas montrer un bouton "actif"
  //   sur une ligne déjà traitée (UX : évite le double clic surpris).
  const [serviceState, setServiceState] = useState(null);
  const [isRestricted, setIsRestricted] = useState(false);
  const [reserveState, setReserveState] = useState({});
  const [reservedBibRefs, setReservedBibRefs] = useState(new Set());
  // Paquet B.2 (chantier consulta button) : miroir de reservedBibRefs / reserveState
  // pour la chaine consultation. Doctrine §8 : la consulta a son propre cycle.
  const [consultedBibRefs, setConsultedBibRefs] = useState(new Set());
  const [consultaState, setConsultaState] = useState({});
  // #OPAC9 : favoris (wishlist) ajoutés depuis la liste
  const [wishlistedIds, setWishlistedIds] = useState(new Set());
  const [wishlistBusy, setWishlistBusy] = useState(null);

  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [totalFetched, setTotalFetched] = useState(0);
  const [totalCount, setTotalCount] = useState(null);

  // Charger les filtres sauvegardés au montage uniquement (lazy initializer)
  const [filterState] = useState(() => loadSavedFilters() || {});
  const [search, setSearch] = useState(filterState.search || '');
  const [authorFilter, setAuthorFilter] = useState(filterState.authorFilter || '');
  const [authorIdFilter, setAuthorIdFilter] = useState(filterState.authorIdFilter || '');
  const [publisherFilter, setPublisherFilter] = useState(filterState.publisherFilter || '');
  const [yearFilter, setYearFilter] = useState(filterState.yearFilter || '');
  const [availabilityFilter, setAvailabilityFilter] = useState(filterState.availabilityFilter || '__all__');
  const [libraryFilter, setLibraryFilter] = useState(() => {
    const v = filterState.libraryFilter;
    if (Array.isArray(v)) return v;
    if (v && v !== '__all__') return [v];
    return [];
  });
  const [libMenuOpen, setLibMenuOpen] = useState(false);
  const libMenuRef = useRef(null);
  const [sortValue, setSortValue] = useState(filterState.sortValue || '__relevance__');
  // P4 v2 Lot C — repli des éditions par œuvre (côté client, sur les résultats chargés ; OFF par défaut)
  const [collapseEditions, setCollapseEditions] = useState(false);
  const [compact, setCompact] = useState(filterState.compact || false);
  const [filtersOpen, setFiltersOpen] = useState(true);
  const [exploreOpen, setExploreOpen] = useState(true); // bloc « Explorer » escamotable
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [isbnFilter, setIsbnFilter] = useState(filterState.isbnFilter || '');
  const [languageFilter, setLanguageFilter] = useState(filterState.languageFilter || '');
  const [cddFilter, setCddFilter] = useState(filterState.cddFilter || '');
  const [subjectsFilter, setSubjectsFilter] = useState(filterState.subjectsFilter || '');
  const [materialFilter, setMaterialFilter] = useState(filterState.materialFilter || '__all__');
  const [collectionFilter, setCollectionFilter] = useState(filterState.collectionFilter || '');
  const [placeFilter, setPlaceFilter] = useState(filterState.placeFilter || '');
  const [alphaFilter, setAlphaFilter] = useState(''); // #OPAC10 parcours A–Z par auteur·rice (non persisté)
  const [subjectFilter, setSubjectFilter] = useState(''); // #OPAC8 filtre par sujet (slug)
  const [subjectLabel, setSubjectLabel] = useState('');
  const [relatedSubjects, setRelatedSubjects] = useState([]); // v3-A « voir aussi »
  const [subjectTree, setSubjectTree] = useState(null);        // v3-C arbre des sujets
  const [openTreeNodes, setOpenTreeNodes] = useState({});      // id -> déplié ?
  // #OPAC7 / OPAC-F1 : facettes de découverte (CDD / auteur·rice / décennie)
  const [facets, setFacets] = useState(null);
  const [showAllCdd, setShowAllCdd] = useState(false);

  const dSearch = useDebounce(search);
  const dAuthor = useDebounce(authorFilter);
  const dPublisher = useDebounce(publisherFilter);
  const dYear = useDebounce(yearFilter);
  const dIsbn = useDebounce(isbnFilter);
  const dLanguage = useDebounce(languageFilter);
  const dCdd = useDebounce(cddFilter);
  const dSubjects = useDebounce(subjectsFilter);
  const dCollection = useDebounce(collectionFilter);
  const dPlace = useDebounce(placeFilter);

  // Sauvegarder les filtres dans sessionStorage à chaque modification
  useEffect(() => {
    saveFilters({ search, authorFilter, authorIdFilter, publisherFilter, yearFilter, availabilityFilter, libraryFilter, sortValue, compact, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter });
  }, [search, authorFilter, authorIdFilter, publisherFilter, yearFilter, availabilityFilter, libraryFilter, sortValue, compact, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter]);

  // ── Initialisation depuis l'URL (montage uniquement) ───────
  // Doctrine validée : l'URL est la source de vérité. Un lien profond
  // (galerie anarbib.org → /catalogo/:slug, ou « Copiar busca em link »)
  // doit produire un résultat déterministe, indépendant des filtres
  // sauvegardés dans localStorage.
  //   - filtre bibliothèque : :slug (route) prioritaire, sinon ?biblioteca=
  //   - autres filtres : appliqués SI l'URL les porte explicitement,
  //     sinon REMIS À ZÉRO (on ne garde rien de localStorage).
  // Le slug n'est pas validé côté client : un slug inexistant renvoie
  // simplement zéro résultat (buildServerFilters → library_slug=eq.<slug>),
  // et la vue serveur ne contient que des biblios légitimes.
  // [] en deps : exécution unique, volontaire (montage seulement).
  useEffect(() => {
    const qpLibrary = urlSearchParams.get('biblioteca');
    const libFromUrl = routeLibrarySlug || qpLibrary;
    // Si l'URL ne porte aucune intention (ni slug ni query param),
    // on ne touche à rien : comportement historique préservé.
    const hasUrlIntent = libFromUrl
      || urlSearchParams.has('q') || urlSearchParams.has('autor')
      || urlSearchParams.has('editora') || urlSearchParams.has('ano') || urlSearchParams.has('subject');
    if (!hasUrlIntent) return;

    // Filtre bibliothèque : URL prioritaire, sinon __all__.
    setLibraryFilter(libFromUrl ? [libFromUrl] : []);
    // Autres filtres : valeur de l'URL si présente, sinon remise à zéro.
    setSearch(urlSearchParams.get('q') || '');
    setAuthorFilter(urlSearchParams.get('autor') || '');
    setAuthorIdFilter('');
    setPublisherFilter(urlSearchParams.get('editora') || '');
    setYearFilter(urlSearchParams.get('ano') || '');
    setSubjectFilter(urlSearchParams.get('subject') || ''); setSubjectLabel('');
    // Filtres sans représentation URL : remis à zéro pour un écran propre.
    setAvailabilityFilter('__all__');
    setIsbnFilter(''); setLanguageFilter(''); setCddFilter('');
    setSubjectsFilter(''); setMaterialFilter('__all__');
    setCollectionFilter(''); setPlaceFilter('');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [libraryOptions, setLibraryOptions] = useState([{ value:'__all__', label: t({ id: 'catalog.avail.all' }) }]);

  // i18n-aware options
  const SORT_OPTIONS = useMemo(() => [
    { value: '__relevance__', label: t({ id: 'catalog.sort.relevance' }) },
    { value: 'bib_ref.asc', label: t({ id: 'catalog.sort.ref' }) },
    { value: 'autor.asc', label: t({ id: 'catalog.sort.author' }) },
    { value: 'titulo.asc', label: t({ id: 'catalog.sort.title' }) },
    { value: 'ano.desc', label: t({ id: 'catalog.sort.year' }) },
    { value: 'created_at.desc', label: t({ id: 'catalog.sort.newest' }) },
    { value: 'editora.asc', label: t({ id: 'catalog.sort.publisher' }) },
    { value: 'status', label: t({ id: 'catalog.sort.availability' }) },
  ], [t]);
  const AVAILABILITY_OPTIONS_AUTH = useMemo(() => [
    { value: '__all__', label: t({ id: 'catalog.avail.all' }) },
    { value: 'available', label: t({ id: 'catalog.avail.available' }) },
    { value: 'consult', label: t({ id: 'catalog.avail.consult' }) },
    { value: 'unavailable_user', label: t({ id: 'catalog.avail.unavailUser' }) },
    { value: 'unavailable_other', label: t({ id: 'catalog.avail.unavailOther' }) },
    { value: 'unavailable_now', label: t({ id: 'catalog.avail.unavailNow' }) },
    { value: 'check', label: t({ id: 'catalog.avail.check' }) },
  ], [t]);
  // Doctrine A1/A2/A3 : pour l'anon, aucun critere de disponibilite n'a de sens
  // (pas de contexte biblio). Seul __all__ subsiste ; le dropdown est conserve
  // pour homogeneite UI mais ne propose qu'une option.
  const AVAILABILITY_OPTIONS_ANON = useMemo(() => [
    { value: '__all__', label: t({ id: 'catalog.avail.all' }) },
  ], [t]);

  // Phase B.5.6: vues matérialisées allégées api.catalog_list_*_v1
  const viewName = isAuth ? 'catalog_list_session_v1' : 'catalog_list_anon_v1';
  const selectCols = isAuth ? SESSION_COLS : PUBLIC_COLS;

  // Resolve sort for PostgREST
  function resolveOrder() {
    if (sortValue === '__relevance__' || sortValue === 'status') return 'titulo.asc';
    return sortValue;
  }

  // Bibliothèques (Phase B.4a: api.libraries_public_v1 au lieu de catalog_books_public_v2)
  useEffect(() => {
    (async () => {
      const { data } = await apiQuery('libraries_public_v1', {
        select: 'slug,name,short_name,city',
        order: 'name.asc',
      });
      if (data?.length) {
        setLibraryOptions([
          { value: '__all__', label: t({ id: 'catalog.avail.all' }) },
          ...data.map(l => ({
            value: l.slug,
            label: l.city ? `${l.name || l.slug} — ${l.city}` : (l.name || l.slug),
            short_name: l.short_name, name: l.name, city: l.city,
          })),
        ]);
      }
    })();
  }, []);

  // Map biblio → ville (afficher la ville à côté du nom dans la liste — clarté lecteurs)
  const cityByLib = useMemo(() => {
    const m = {};
    for (const o of libraryOptions) {
      if (o.city) { if (o.short_name) m[o.short_name] = o.city; if (o.name) m[o.name] = o.city; }
    }
    return m;
  }, [libraryOptions]);

  // Slugs sélectionnés → short_names (filtre sur holding_library_names_json, gère les multi-biblios)
  const libraryShortNames = useMemo(
    () => libraryFilter.map(slug => libraryOptions.find(o => o.value === slug)?.short_name).filter(Boolean),
    [libraryFilter, libraryOptions]
  );
  // Fermeture du menu biblios au clic dehors (listener, PAS d'overlay → ne casse pas le scroll)
  useEffect(() => {
    if (!libMenuOpen) return;
    const onDown = (e) => { if (libMenuRef.current && !libMenuRef.current.contains(e.target)) setLibMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [libMenuOpen]);

  // Fetch
  const fetchBooks = useCallback(async (offset = 0, append = false) => {
    if (offset === 0) setLoading(true); else setLoadingMore(true);
    try {
      // (1b) Recherche INSENSIBLE AUX ACCENTS + classée par pertinence via le RPC
      // api.catalog_search_ids_v1 (branche anon/session selon la visibilité de
      // l'appelant·e). En cas d'erreur ou de RPC absent, on RETOMBE sur la
      // recherche multi-mots ilike (buildServerFilters) → dégradation gracieuse,
      // jamais pire que l'existant.
      let rankedIds = null; // null = pas de recherche RPC ; sinon book_id ordonnés par rang
      if (dSearch.trim()) {
        try {
          const { data: sr, error: srErr } = await supabase.schema('api')
            .rpc('catalog_search_ids_v1', { p_q: dSearch.trim() });
          if (!srErr && Array.isArray(sr)) rankedIds = sr.map(r => r.book_id);
        } catch { /* repli ilike ci-dessous */ }
      }
      const useRpc = rankedIds !== null;

      // Avec le RPC, le terme de recherche est géré côté serveur → on ne l'ajoute
      // PAS au ilike (search:''), mais tous les autres filtres restent actifs.
      const filters = buildServerFilters({ search: useRpc ? '' : dSearch, authorFilter:dAuthor, authorIdFilter, alphaFilter, publisherFilter:dPublisher, yearFilter:dYear, libraryShortNames, availabilityFilter, isAuth, isbnFilter:dIsbn, languageFilter:dLanguage, cddFilter:dCdd, subjectsFilter:dSubjects, materialFilter, collectionFilter:dCollection, placeFilter:dPlace });

      // #OPAC8 — filtre par sujet : résout les book_id via book_subjects (table dédiée).
      let subjectIds = null;
      if (subjectFilter) {
        const { data: sd } = await supabase.from('subjects').select('id').eq('slug', subjectFilter).maybeSingle();
        subjectIds = [];
        if (sd?.id) {
          const { data: bs } = await supabase.from('book_subjects').select('book_id').eq('subject_id', sd.id);
          subjectIds = (bs || []).map(r => r.book_id);
        }
      }

      // Contrainte book_id = recherche RPC ∩ sujet (selon ce qui est actif).
      let idConstraint = null;
      if (useRpc && subjectIds !== null) {
        const set = new Set(subjectIds);
        idConstraint = rankedIds.filter(id => set.has(id));
      } else if (useRpc) {
        idConstraint = rankedIds;
      } else if (subjectIds !== null) {
        idConstraint = subjectIds;
      }
      if (idConstraint !== null) {
        filters['book_id'] = idConstraint.length ? `in.(${idConstraint.join(',')})` : 'eq.-1';
      }

      if (useRpc) {
        // Recherche : ensemble borné (RPC ≤ 500) récupéré en un appel, trié par
        // pertinence (ordre du RPC) si le tri est « Pertinence » ; sinon on
        // respecte le tri choisi. Pas de pagination serveur dans ce mode.
        if (idConstraint.length === 0) {
          if (!append) setBooks([]);
          setTotalFetched(0); setHasMore(false); setTotalCount(0);
        } else {
          const byRelevance = sortValue === '__relevance__';
          const { data, error } = await apiQuery(viewName, { select:selectCols, order: byRelevance ? undefined : resolveOrder(), rangeFrom:0, rangeTo:idConstraint.length - 1, filters });
          if (error) throw error;
          let rows = data || [];
          if (byRelevance) {
            const pos = new Map(rankedIds.map((id, i) => [id, i]));
            rows = [...rows].sort((a, b) => (pos.get(a.book_id) ?? 1e9) - (pos.get(b.book_id) ?? 1e9));
          }
          setBooks(rows); setTotalFetched(rows.length); setHasMore(false); setTotalCount(rows.length);
        }
      } else {
        // Parcours (sans recherche, ou repli) : pagination serveur + tri choisi.
        const { data, error, totalCount: serverTotal } = await apiQuery(viewName, { select:selectCols, order:resolveOrder(), rangeFrom:offset, rangeTo:offset+PAGE_SIZE-1, filters });
        if (error) throw error;
        const result = data || [];
        if (append) setBooks(prev => [...prev, ...result]);
        else setBooks(result);
        setTotalFetched(offset + result.length);
        setHasMore(result.length === PAGE_SIZE);
        // Phase B.7 : totalCount via Content-Range (cohérent avec la grille, respecte la visibility).
        if (serverTotal != null) setTotalCount(serverTotal);
      }
    } catch (err) { console.error('Catalog fetch error:', err); if (!append) setBooks([]); }
    finally { setLoading(false); setLoadingMore(false); }
    // libraryShortNames (et pas seulement libraryFilter) DOIT être une dep : sur un
    // lien profond /catalogo/:slug, libraryFilter est posé au montage AVANT le chargement
    // async des options ; libraryShortNames se résout après → sans cette dep, le fetch
    // ne se rejoue pas et le filtre biblio reste inappliqué (course + closure périmée).
  }, [viewName, selectCols, sortValue, dSearch, dAuthor, authorIdFilter, alphaFilter, subjectFilter, dPublisher, dYear, libraryFilter, libraryShortNames, availabilityFilter, isAuth, dIsbn, dLanguage, dCdd, dSubjects, materialFilter, dCollection, dPlace]);

  useEffect(() => { fetchBooks(0); }, [fetchBooks]);

  // Repli des éditions (Lot C) : regroupe les notices chargées par work_id (une
  // ligne représentante + nb d'éditions chargées). Les notices sans œuvre restent
  // individuelles. La page Œuvre (/obra/:id) reste la référence du jeu complet.
  const displayBooks = useMemo(() => {
    if (!collapseEditions) return books;
    const byWork = new Map();
    const out = [];
    for (const b of books) {
      if (b.work_id) {
        const rep = byWork.get(b.work_id);
        if (rep) { rep._editionCount += 1; continue; }
        const fresh = { ...b, _editionCount: 1 };
        byWork.set(b.work_id, fresh);
        out.push(fresh);
      } else {
        out.push(b);
      }
    }
    return out;
  }, [collapseEditions, books]);

  // #OPAC7 — compteurs de facettes via api.catalog_facets_v1 (un appel JSONB).
  // Recalcule à chaque évolution des filtres (sémantique « expand » côté RPC).
  useEffect(() => {
    (async () => {
      const yr = (dYear || '').trim();
      const m = yr.match(/^(\d{4})\s*[-–]\s*(\d{4})$/);
      const isYear = /^\d{4}$/.test(yr);
      const p_filters = {
        q: dSearch || '', author_id: authorIdFilter || '', alpha: alphaFilter || '',
        publisher: dPublisher || '',
        year_from: m ? m[1] : (isYear ? yr : ''),
        year_to: m ? m[2] : (isYear ? yr : ''),
        library: libraryFilter.length === 1 ? libraryFilter[0] : '',
        cdd: dCdd || '', language: dLanguage || '',
        material: materialFilter !== '__all__' ? materialFilter : '',
        collection: dCollection || '', place: dPlace || '', subject: subjectFilter || '',
      };
      try {
        const { data } = await supabase.schema('api').rpc('catalog_facets_v1', { p_filters });
        setFacets(data || null);
      } catch { setFacets(null); }
    })();
  }, [dSearch, authorIdFilter, alphaFilter, dPublisher, dYear, libraryFilter, dCdd, dLanguage, materialFilter, dCollection, dPlace, subjectFilter]);

  // v3-A — « voir aussi » : sujets reliés au sujet filtré (skos:related).
  useEffect(() => {
    if (!subjectFilter) { setRelatedSubjects([]); return; }
    let cancelled = false;
    (async () => {
      try {
        const { data: sd } = await supabase.from('subjects').select('id').eq('slug', subjectFilter).maybeSingle();
        if (!sd?.id) { if (!cancelled) setRelatedSubjects([]); return; }
        const { data } = await supabase.schema('api').rpc('subject_related_v1', { p_subject_id: sd.id });
        if (!cancelled) setRelatedSubjects(Array.isArray(data) ? data : []);
      } catch { if (!cancelled) setRelatedSubjects([]); }
    })();
    return () => { cancelled = true; };
  }, [subjectFilter]);

  // v3-C — arbre des sujets (chargé une fois, à l'ouverture de l'exploration).
  useEffect(() => {
    if (!exploreOpen || subjectTree) return;
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.schema('api').rpc('subject_tree_v1');
        if (!cancelled) setSubjectTree(Array.isArray(data) ? data : []);
      } catch { if (!cancelled) setSubjectTree([]); }
    })();
    return () => { cancelled = true; };
  }, [exploreOpen, subjectTree]);

  // Regimento da biblioteca (if user logged in)
  useEffect(() => {
    if (!libraryId || !isAuth) return;
    (async () => {
      // FIX A.1 BUG #8: 'publicado' is rejected by CHECK constraint; valid value is 'published'.
      // Was making the regimento link silently invisible to authenticated readers in the public catalog.
      const { data } = await supabase.from('library_regulation_documents')
        .select('storage_bucket, storage_path_public')
        .eq('library_id', libraryId).eq('is_active', true).eq('publication_status', 'published')
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (data?.storage_path_public) {
        setRegimentoUrl(`https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/${data.storage_bucket || 'library-regimentos-public'}/${data.storage_path_public}`);
      }
    })();
  }, [libraryId, isAuth]);

  // ── Garde-fous pour la réservation rapide ──────────────────
  // Charge 2 contextes globaux stables : mode service de la biblio et statut
  // restreint du profil. Suffisant pour décider si le bouton apparaît.
  // Les doublons (réservation/emprunt actif sur même livre) sont laissés au
  // backend : trop coûteux à charger ici, et le RPC les rejette proprement.
  useEffect(() => {
    if (!isAuth) return;
    (async () => {
      // Mode service de la biblio de l'utilisateur connecte.
      // La vue api.my_library_context filtre deja par auth.uid()
      // via my_session_context : pas besoin de library_id ici.
      // Coherent avec la doctrine 'page = scope, no cross-calculation'.
      const svcRes = await supabase.schema('api').from('my_library_context')
        .select('service_mode, allows_new_reservations').maybeSingle();
      if (svcRes.data) setServiceState(svcRes.data);

      // profil : flag is_restricted seul (pas besoin du reste ici)
      const profRes = await supabase.from('profiles')
        .select('is_restricted').eq('id', user.id).maybeSingle();
      if (profRes.data) setIsRestricted(!!profRes.data.is_restricted);
    })();
  }, [isAuth, user?.id]);

  // ── Action de réservation rapide ───────────────────────────
  // Appelée par le bouton "Reservar" en bout de ligne. Pour 1 seul livre :
  //   1. fn_v2_resolve_catalog_refs_for_current_user → résout bib_ref vers
  //      holding_id de la session du lecteur (sa bibliothèque).
  //   2. fn_v2_create_reserva_by_holdings → crée la réservation. Le trigger
  //      DB trg_notify_reserva_workflow_change émet automatiquement
  //      'reserva_v2_criada' (cf. spec workflow réservation phase 4).
  // Pas de notifyEvent manuel à faire ici.
  const handleQuickReserve = useCallback(async (book) => {
    const key = String(book.book_id || book.bib_ref || '');
    const ref = String(book.bib_ref || '').trim();
    if (!ref) return;

    // Cache local : déjà réservé dans cette session ?
    if (reservedBibRefs.has(ref.toLowerCase())) return;

    setReserveState(s => ({ ...s, [key]: 'reserving' }));

    try {
      // 1. Résolution bib_ref → holding_id (côté session du lecteur)
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: [ref] });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      const row = rows[0];
      if (!row || !row.matched || !(Number(row.session_holding_id) > 0)) {
        // Cas "trouvé mais non disponible dans MA biblio" : message du backend si présent.
        throw new Error(row?.message || t({ id: 'catalog.quickReserve.notInMyLibrary' }));
      }

      // 2. Refus si l'exemplaire est consultation-only (ne devrait pas arriver
      //    car le bouton n'apparaît que sur status 'ok', mais on garde la
      //    ceinture-bretelles : un livre peut bouger entre l'affichage et le clic).
      if (row.session_loanable === false) {
        throw new Error(t({ id: 'catalog.quickReserve.consultationOnly' }));
      }

      // 3. Création de la réservation
      const createRes = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
        p_user_id: user.id,
        p_holding_ids: [Number(row.session_holding_id)],
        p_notes: '@@note:catalog.quickReserve.note', // Route B : code système (décodé à l'affichage)
      });
      if (createRes.error) throw createRes.error;

      // Succès : on marque le livre comme réservé pour éviter le double clic
      setReserveState(s => ({ ...s, [key]: 'done' }));
      setReservedBibRefs(prev => {
        const next = new Set(prev);
        next.add(ref.toLowerCase());
        return next;
      });
    } catch (err) {
      setReserveState(s => ({ ...s, [key]: `error:${localizeError(err, t) || 'erro'}` }));
    }
  }, [user?.id, t, reservedBibRefs]);

  // Paquet B.2 (chantier consulta button) : miroir de handleQuickReserve pour la
  // chaine consultation sur place. Appelle api.create_consulta_local (wrapper
  // SECURITY INVOKER, paquet 27.A.1) au lieu de fn_v2_create_reserva_by_holdings.
  const handleQuickConsulta = useCallback(async (book) => {
    const key = String(book.book_id || book.bib_ref || '');
    const ref = String(book.bib_ref || '').trim();
    if (!ref) return;
    if (consultedBibRefs.has(ref.toLowerCase())) return;

    setConsultaState(s => ({ ...s, [key]: 'reserving' }));

    try {
      // 1. Resolution bib_ref -> holding_id (cote session du lecteur)
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: [ref] });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      const row = rows[0];
      if (!row || !row.matched || !(Number(row.session_holding_id) > 0)) {
        throw new Error(row?.message || t({ id: 'catalog.quickReserve.notInMyLibrary' }));
      }

      // 2. Creation de la demande de consultation
      const createRes = await supabase.schema('api').rpc('create_consulta_local', {
        p_user_id: user.id,
        p_holding_ids: [Number(row.session_holding_id)],
        p_notes: '@@note:catalog.quickConsulta.note', // Route B : code système (décodé à l'affichage)
      });
      if (createRes.error) throw createRes.error;

      // Succes
      setConsultaState(s => ({ ...s, [key]: 'done' }));
      setConsultedBibRefs(prev => {
        const next = new Set(prev);
        next.add(ref.toLowerCase());
        return next;
      });
    } catch (err) {
      setConsultaState(s => ({ ...s, [key]: 'error:' + (localizeError(err, t) || 'erro') }));
    }
  }, [user?.id, t, consultedBibRefs]);

  // #OPAC9 — ajout aux favoris depuis la liste (table user_wishlist, RLS owner-only).
  const handleWishlist = useCallback(async (book) => {
    if (!user) return;
    const bid = book.book_id || book.id;
    if (!bid || wishlistedIds.has(bid)) return;
    setWishlistBusy(bid);
    try {
      const { error } = await supabase.from('user_wishlist')
        .upsert({ user_id: user.id, book_id: bid }, { onConflict: 'user_id,book_id' });
      if (error && error.code !== '23505') throw error; // 23505 = déjà présent → succès
      setWishlistedIds(prev => new Set(prev).add(bid));
    } catch (err) { console.error('wishlist error', err); }
    finally { setWishlistBusy(null); }
  }, [user?.id, wishlistedIds]);

  // Calcul dérivé : le bouton de réservation rapide est-il globalement actif ?
  // Cache pour le rendu de chaque ligne (évalué une fois par render).
  const quickReserveAvailable = useMemo(() => {
    if (!isAuth) return false;
    if (isRestricted) return false;
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    const allowsRes = serviceState?.allows_new_reservations !== false;
    if (!allowsRes) return false;
    if (svcMode === 'pausada' || svcMode === 'somente_consulta') return false;
    return true;
  }, [isAuth, isRestricted, serviceState]);

  // Paquet B.2 : disponibilite du bouton "Agendar consulta". Doctrine §8 :
  // pausada -> non ; somente_consulta -> oui ; funcionamento_normal -> oui.
  // Donc plus permissif que quickReserveAvailable.
  const quickConsultaAvailable = useMemo(() => {
    if (!isAuth) return false;
    if (isRestricted) return false;
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    if (svcMode === 'pausada') return false;
    return true;
  }, [isAuth, isRestricted, serviceState]);

  // Phase B.7 : le total count est désormais récupéré directement via Content-Range
  // dans fetchBooks (cohérent avec la grille, respecte la visibility automatiquement).
  // L'ancien fetch via api.books_count_v1 est retiré (il fuyait le compte network aux anon).

  // Fetch real available count from the server (not limited to displayed books)
  const [serverAvailableCount, setServerAvailableCount] = useState(null);
  useEffect(() => {
    if (!isAuth) { setServerAvailableCount(null); return; }
    (async () => {
      // Count books where session says available in user's library
      // Phase B.6: api.catalog_list_session_v1 au lieu de catalog_books_public_session_v2
      const { data } = await apiQuery('catalog_list_session_v1', {
        select: 'book_id',
        filters: {
          'session_status_hint': 'eq.no_acervo_da_sua_biblioteca',
          'session_available_count': 'gt.0',
        },
      });
      if (data) setServerAvailableCount(data.length);
    })();
  }, [isAuth]);

  // Stats
  const hasActiveFilters = dSearch || dAuthor || alphaFilter || subjectFilter || dPublisher || dYear || availabilityFilter !== '__all__' || libraryFilter.length > 0 || dIsbn || dLanguage || dCdd || dSubjects || materialFilter !== '__all__' || dCollection || dPlace;
  const availabilityOptions = isAuth ? AVAILABILITY_OPTIONS_AUTH : AVAILABILITY_OPTIONS_ANON;

  function handleHeaderSort(col) {
    setSortValue(prev => {
      const [pc,pd] = prev.split('.');
      return pc === col ? `${col}.${pd === 'asc' ? 'desc' : 'asc'}` : `${col}.asc`;
    });
  }
  function si(col) { const [c,d] = sortValue.split('.'); return c === col ? (d==='asc'?' ↑':' ↓') : ''; }

  // #OPAC7 — libellé de facette CDD : division curée (sens anarchiste) si connue,
  // sinon repli sur la classe principale Dewey. Évite la redondance « Ciências
  // sociais » répétée pour 335/320/370… (cf. cotation-et-cdd.md).
  function cddLabel(code) {
    const c = String(code || '');
    if (CDD_DIV_LABELS.has(c)) return t({ id: `catalog.cdd.div.${c}` });
    return t({ id: `catalog.cdd.main.${c[0] || '0'}` });
  }
  function pickCdd(code) { setCddFilter(prev => prev === code ? '' : code); setAdvancedOpen(true); }
  function pickDecade(decade) { const d = parseInt(decade, 10); if (d) setYearFilter(`${d}-${d + 9}`); }
  function pickAuthorFacet(a) {
    setAuthorFilter(a.label || '');
    setAuthorIdFilter(a.author_id ? String(a.author_id) : '');
    setAlphaFilter('');
  }
  function pickSubject(f) {
    setSubjectFilter(prev => prev === f.slug ? '' : f.slug);
    setSubjectLabel(localizedSubjectLabel(f.label_i18n, locale));
  }

  // v3-B — export SKOS public du thésaurus (Turtle / JSON-LD).
  async function downloadThesaurus(format) {
    try {
      const { data } = await supabase.schema('api').rpc('thesaurus_export_v1');
      if (!data) return;
      if (format === 'jsonld') downloadText('anarbib-thesaurus.jsonld', toJsonLd(data), 'application/ld+json');
      else downloadText('anarbib-thesaurus.ttl', toTurtle(data), 'text/turtle');
    } catch { /* noop */ }
  }

  function clearFilters() {
    setSearch(''); setAuthorFilter(''); setAuthorIdFilter(''); setAlphaFilter(''); setSubjectFilter(''); setPublisherFilter(''); setYearFilter('');
    setAvailabilityFilter('__all__'); setLibraryFilter([]); setSortValue('__relevance__');
    setIsbnFilter(''); setLanguageFilter(''); setCddFilter(''); setSubjectsFilter('');
    setMaterialFilter('__all__'); setCollectionFilter(''); setPlaceFilter('');
  }

  function buildSearchUrl() {
    // Forme propre alignée sur la route alias /catalogo/:slug.
    // La bibliothèque va dans le chemin ; les autres filtres en query params.
    const base = window.location.origin
      + (libraryFilter.length === 1 ? `/catalogo/${libraryFilter[0]}` : '/catalogo');
    const url = new URL(base);
    if (dSearch) url.searchParams.set('q', dSearch);
    if (dAuthor) url.searchParams.set('autor', dAuthor);
    if (dPublisher) url.searchParams.set('editora', dPublisher);
    if (dYear) url.searchParams.set('ano', dYear);
    if (subjectFilter) url.searchParams.set('subject', subjectFilter);
    return url.toString();
  }
  function copySearchLink() {
    navigator.clipboard.writeText(buildSearchUrl()).catch(() => {});
  }
  function emailSearchLink() {
    // #OPAC11 — partage par courriel (sans RSS : pas de flux trackable côté serveur).
    const body = encodeURIComponent(buildSearchUrl());
    const subject = encodeURIComponent(t({ id: 'catalog.actions.emailSubject' }));
    window.location.href = `mailto:?subject=${subject}&body=${body}`;
  }

  function scrollTable(dir) {
    const el = tableRef.current;
    if (!el) return;
    if (dir === 'top') el.scrollTo({ top: 0, behavior: 'smooth' });
    else el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' });
  }

  // ── Rendu ────────────────────────────────────────────────

  return (
    <PageShell>
      <Topbar />

      {/* ══ HERO ══════════════════════════════════════════════ */}
      <Hero
        title={t({ id: 'catalog.hero.title' })}
        subtitle={t({ id: 'catalog.hero.subtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions
          extraActions={
            <>
              <Button onClick={() => exportPDF(books, t)}>{t({ id: 'catalog.export.pdf' })}</Button>
              <Button variant="secondary" onClick={() => exportCSV(books)}>{t({ id: 'catalog.export.csv' })}</Button>
              {!user && (
                <Button variant="secondary" onClick={() => navigate('/cadastro')}>{t({ id: 'nav.login' })}</Button>
              )}
            </>
          }
        />
      </Hero>

      {/* ── Rebond OPAC → fiche publique (#PUB6) : quand le catalogue est scopé
            sur une bibliothèque via /catalogo/:slug, lien vers sa fiche. ── */}
      {routeLibrarySlug && (
        <div style={{ maxWidth: 1200, margin: '0 auto', padding: '10px 16px 0' }}>
          <Link to={`/bibliotecas/${routeLibrarySlug}`} style={{ color: '#93c5fd', textDecoration: 'none', fontSize: '.88rem' }}>
            {t({ id: 'catalog.aboutLibrary' })}
          </Link>
        </div>
      )}

      {/* ── Bandeau règlement de la bibliothèque ──────────────
          Identique au bandeau de la page conta (AccountPage) :
          icône PDF + hint i18n + bouton vers le PDF public.
          Affiché uniquement aux connectés (cohérent avec le chargement
          conditionnel de regimentoUrl plus haut). */}
      {regimentoUrl && (
        <div className="ab-regimento-banner">
          <span className="ab-regimento-banner__icon" aria-hidden="true">📄</span>
          <div className="ab-regimento-banner__text">
            {t({ id: 'account.regimento.hint' })}
          </div>
          <a href={regimentoUrl} target="_blank" rel="noopener noreferrer" className="ab-regimento-banner__cta">
            <Button variant="secondary">{t({ id: 'account.regimento.button' })}</Button>
          </a>
        </div>
      )}

      {isAuth && (
        <div className="ab-session-info">{t({ id: 'catalog.session.connected' })}</div>
      )}

      {/* ══ RECHERCHE UNIFIÉE (Phase B.7) ════════════════════ */}
      <section className="ab-unified-search-wrap">
        <UnifiedSearchCombobox
          onAuthorPick={(author) => {
            // Filtre la grille par LIEN d'autorite (author_id) plutot que par texte
            // brut : une fiche d'autorite regroupe toutes les graphies du contributeur
            // (corrige l'incoherence "1 vs N" entre clic-suggestion et saisie texte).
            // Repli sur le filtre texte si l'item n'a pas d'id.
            if (author.id) {
              setAuthorIdFilter(String(author.id));
              setAuthorFilter(author.label || author.filterValue || '');
            } else {
              setAuthorIdFilter('');
              setAuthorFilter(author.filterValue || author.label || '');
            }
            setSearch('');
            setFiltersOpen(true);
          }}
        />
      </section>

      {/* ══ FILTRES (escamotable) ════════════════════════════ */}
      <section className="ab-toolbar">
        <button type="button" className="ab-collapse-header" onClick={() => setFiltersOpen(o => !o)} aria-expanded={filtersOpen}>
          {t({ id: 'catalog.section.filters' })} <span className="ab-collapse-chevron">{filtersOpen ? '▾' : '▸'}</span>
        </button>
        {filtersOpen && (<>
        <div className="ab-filters-grid">
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.searchLabel' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.searchPlaceholder' })}
              value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.author' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.authorPlaceholder' })}
              value={authorFilter} onChange={e => { setAuthorFilter(e.target.value); setAuthorIdFilter(''); setAlphaFilter(''); }} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.publisher' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.publisherPlaceholder' })}
              value={publisherFilter} onChange={e => setPublisherFilter(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.year' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.yearPlaceholder' })}
              value={yearFilter} onChange={e => setYearFilter(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.availability' })}</label>
            <select className="ab-select" value={availabilityFilter} onChange={e => setAvailabilityFilter(e.target.value)}>
              {availabilityOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.sortLabel' })}</label>
            <select className="ab-select" value={sortValue} onChange={e => setSortValue(e.target.value)}>
              {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.libraryLabel' })}</label>
            <div style={{ position: 'relative' }} ref={libMenuRef}>
              <button type="button" className="ab-select" aria-expanded={libMenuOpen}
                style={{ textAlign: 'left', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%', gap: 6, flexWrap: 'wrap' }}
                onClick={() => setLibMenuOpen(o => !o)}>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {libraryFilter.length === 0
                    ? t({ id: 'catalog.avail.all' })
                    : libraryFilter.length === 1
                      ? (libraryOptions.find(o => o.value === libraryFilter[0])?.label || libraryFilter[0])
                      : t({ id: 'catalog.filters.libraryNSelected' }, { n: libraryFilter.length })}
                </span>
                <span aria-hidden="true">▾</span>
              </button>
              {libMenuOpen && (
                <div style={{ position: 'absolute', zIndex: 30, top: '100%', left: 0, right: 0, marginTop: 2, background: 'var(--brand-surface, #1e1e1e)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, maxHeight: 240, overflowY: 'auto', padding: 4, boxShadow: '0 8px 24px rgba(0,0,0,.45)' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                    <input type="checkbox" checked={libraryFilter.length === 0} onChange={() => setLibraryFilter([])} />
                    <span>{t({ id: 'catalog.avail.all' })}</span>
                  </label>
                  {libraryOptions.filter(o => o.value !== '__all__').map(o => (
                    <label key={o.value} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', cursor: 'pointer', borderRadius: 6 }}>
                      <input type="checkbox" checked={libraryFilter.includes(o.value)}
                        onChange={() => setLibraryFilter(prev => prev.includes(o.value) ? prev.filter(v => v !== o.value) : [...prev, o.value])} />
                      <span>{o.label}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div className="ab-field ab-field--action">
            <label className="ab-field__label">{t({ id: 'catalog.filters.clearAll' })}</label>
            <button className="ab-button ab-button--secondary" onClick={clearFilters} style={{ borderColor: 'var(--brand-action, #b32025)', color: 'var(--brand-action, #b32025)', fontWeight: 700 }}>↺ {t({ id: 'catalog.filters.clearButton' })}</button>
          </div>
        </div>

        {/* ── Advanced search toggle ──────────────────── */}
        <button
          className="ab-button ab-button--secondary"
          style={{ margin: '8px 0 0', fontSize: '.78rem', padding: '4px 14px' }}
          onClick={() => setAdvancedOpen(p => !p)}
        >
          {t({ id: 'catalog.advancedSearch.toggle' })} {advancedOpen ? '▲' : '▼'}
        </button>

        {/* ── Advanced search fields ─────────────────── */}
        {advancedOpen && (
          <div className="ab-filters-grid" style={{ marginTop: 8 }}>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.isbn' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.isbnPh' })}
                value={isbnFilter} onChange={e => setIsbnFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.language' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.languagePh' })}
                value={languageFilter} onChange={e => setLanguageFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.cdd' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.cddPh' })}
                value={cddFilter} onChange={e => setCddFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.subjects' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.subjectsPh' })}
                value={subjectsFilter} onChange={e => setSubjectsFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.material' })}</label>
              <select className="ab-select" value={materialFilter} onChange={e => setMaterialFilter(e.target.value)}>
                <option value="__all__">{t({ id: 'catalog.filters.materialAll' })}</option>
                {['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'].map(mt => (
                  <option key={mt} value={mt}>{t({ id: `catalogacao.material.${mt}` })}</option>
                ))}
              </select>
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.collection' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.collectionPh' })}
                value={collectionFilter} onChange={e => setCollectionFilter(e.target.value)} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label">{t({ id: 'catalog.filters.place' })}</label>
              <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.placePh' })}
                value={placeFilter} onChange={e => setPlaceFilter(e.target.value)} />
            </div>
          </div>
        )}
        </>)}

        {/* Chips + view controls */}
        <div className="ab-toolbar-meta">
          {hasActiveFilters && (
            <div className="ab-active-filters">
              {dSearch && <span className="ab-filter-chip">{t({ id: 'catalog.chip.search' })}: <strong>{dSearch}</strong> <button onClick={() => setSearch('')}>✕</button></span>}
              {dAuthor && <span className="ab-filter-chip">{t({ id: 'catalog.chip.author' })}: <strong>{dAuthor}</strong> <button onClick={() => { setAuthorFilter(''); setAuthorIdFilter(''); }}>✕</button></span>}
              {alphaFilter && <span className="ab-filter-chip">{t({ id: 'catalog.browse.alpha' })}: <strong>{alphaFilter}</strong> <button onClick={() => setAlphaFilter('')}>✕</button></span>}
              {subjectFilter && <span className="ab-filter-chip">{t({ id: 'book.meta.subjects' })}: <strong>{subjectLabel || subjectFilter}</strong> <button onClick={() => setSubjectFilter('')}>✕</button></span>}
              {dPublisher && <span className="ab-filter-chip">{t({ id: 'catalog.chip.publisher' })}: <strong>{dPublisher}</strong> <button onClick={() => setPublisherFilter('')}>✕</button></span>}
              {dYear && <span className="ab-filter-chip">{t({ id: 'catalog.chip.year' })}: <strong>{dYear}</strong> <button onClick={() => setYearFilter('')}>✕</button></span>}
              {availabilityFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.avail' })}: <strong>{availabilityOptions.find(o => o.value === availabilityFilter)?.label}</strong> <button onClick={() => setAvailabilityFilter('__all__')}>✕</button></span>}
              {libraryFilter.map(slug => <span key={slug} className="ab-filter-chip">{t({ id: 'catalog.chip.library' })}: <strong>{libraryOptions.find(o => o.value === slug)?.label || slug}</strong> <button onClick={() => setLibraryFilter(prev => prev.filter(v => v !== slug))}>✕</button></span>)}
              {dIsbn && <span className="ab-filter-chip">{t({ id: 'catalog.chip.isbn' })}: <strong>{dIsbn}</strong> <button onClick={() => setIsbnFilter('')}>✕</button></span>}
              {dLanguage && <span className="ab-filter-chip">{t({ id: 'catalog.chip.language' })}: <strong>{dLanguage}</strong> <button onClick={() => setLanguageFilter('')}>✕</button></span>}
              {dCdd && <span className="ab-filter-chip">{t({ id: 'catalog.chip.cdd' })}: <strong>{dCdd}</strong> <button onClick={() => setCddFilter('')}>✕</button></span>}
              {dSubjects && <span className="ab-filter-chip">{t({ id: 'catalog.chip.subjects' })}: <strong>{dSubjects}</strong> <button onClick={() => setSubjectsFilter('')}>✕</button></span>}
              {materialFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.material' })}: <strong>{t({ id: `catalogacao.material.${materialFilter}` })}</strong> <button onClick={() => setMaterialFilter('__all__')}>✕</button></span>}
              {dCollection && <span className="ab-filter-chip">{t({ id: 'catalog.chip.collection' })}: <strong>{dCollection}</strong> <button onClick={() => setCollectionFilter('')}>✕</button></span>}
              {dPlace && <span className="ab-filter-chip">{t({ id: 'catalog.chip.place' })}: <strong>{dPlace}</strong> <button onClick={() => setPlaceFilter('')}>✕</button></span>}
            </div>
          )}
          {subjectFilter && relatedSubjects.length > 0 && (
            <div className="ab-related-subjects">
              <span className="ab-related-subjects__label">{t({ id: 'catalog.related.subjects' })}</span>
              {relatedSubjects.map((r) => (
                <button key={r.id} type="button" className="ab-facet-chip"
                  onClick={() => pickSubject({ slug: r.slug, label_i18n: r.label_i18n })}>
                  {localizedSubjectLabel(r.label_i18n, locale)}
                </button>
              ))}
            </div>
          )}
          <div className="ab-view-controls">
            <button className="ab-mini-action" onClick={copySearchLink}>{t({ id: 'catalog.actions.copyLink' })}</button>
            <button className="ab-mini-action" onClick={emailSearchLink}>{t({ id: 'catalog.actions.emailLink' })}</button>
            <button className="ab-mini-action" onClick={() => setCompact(!compact)} aria-pressed={compact}>
              {compact ? t({ id: 'catalog.actions.compactOn' }) : t({ id: 'catalog.actions.compactOff' })}
            </button>
          </div>
        </div>
      </section>

      {/* ══ Exploration — modes + facettes (escamotable) ═════ */}
      <div className="ab-explore-toggle">
        <button type="button" className="ab-collapse-header" onClick={() => setExploreOpen(o => !o)} aria-expanded={exploreOpen}>
          {t({ id: 'catalog.section.explore' })} <span className="ab-collapse-chevron">{exploreOpen ? '▾' : '▸'}</span>
        </button>
      </div>
      {exploreOpen && (<div className="ab-explore-panel">
      {/* ══ #OPAC10 — Parcourir : modes + alphabet ═══════════ */}
      <section className="ab-explore-sec">
        <span className="ab-facets__title">{t({ id: 'catalog.browse.label' })}</span>
        <div className="ab-chip-row">
          <button
            type="button"
            className={`ab-facet-chip ${sortValue === 'created_at.desc' ? 'is-active' : ''}`}
            aria-pressed={sortValue === 'created_at.desc'}
            onClick={() => setSortValue(sortValue === 'created_at.desc' ? '__relevance__' : 'created_at.desc')}
          >
            {t({ id: 'catalog.browse.newest' })}
          </button>
          <button
            type="button"
            className={`ab-facet-chip ${collapseEditions ? 'is-active' : ''}`}
            aria-pressed={collapseEditions}
            onClick={() => setCollapseEditions(v => !v)}
          >
            {t({ id: 'catalog.collapseEditions' })}
          </button>
        </div>
        <div className="ab-explore-sub">
          <span className="ab-explore-sub__label">{t({ id: 'catalog.browse.alpha' })}</span>
          <div className="ab-browse-alpha">
            {ALPHABET.map(letter => (
              <button
                key={letter}
                type="button"
                className={`ab-alpha-btn ${alphaFilter === letter ? 'is-active' : ''}`}
                onClick={() => {
                  const next = alphaFilter === letter ? '' : letter;
                  setAlphaFilter(next);
                  if (next) { setAuthorFilter(''); setAuthorIdFilter(''); }
                }}
              >
                {letter}
              </button>
            ))}
          </div>
        </div>
      </section>

      {/* ══ v3-C — Parcourir par sujet (arbre hiérarchique) ══════════════════ */}
      {subjectTree && subjectTree.length > 0 && (() => {
        const roots = subjectTree.filter(s => s.parent_id == null);
        const childrenOf = (pid) => subjectTree.filter(s => s.parent_id === pid);
        const SubjectNode = (node, isChild) => (
          <li key={node.id} className="ab-tree__node">
            <div className="ab-tree__row">
              {(!isChild && childrenOf(node.id).length > 0) ? (
                <button type="button" className="ab-tree__toggle"
                  aria-expanded={!!openTreeNodes[node.id]}
                  onClick={() => setOpenTreeNodes(s => ({ ...s, [node.id]: !s[node.id] }))}>
                  {openTreeNodes[node.id] ? '▾' : '▸'}
                </button>
              ) : <span className="ab-tree__toggle ab-tree__toggle--leaf" aria-hidden="true" />}
              <button type="button"
                className={`ab-tree__label ${subjectFilter === node.slug ? 'is-active' : ''}`}
                onClick={() => pickSubject({ slug: node.slug, label_i18n: node.label_i18n })}>
                {localizedSubjectLabel(node.label_i18n, locale)}
                {node.book_count > 0 && <span className="ab-tree__count">{node.book_count}</span>}
              </button>
            </div>
            {!isChild && openTreeNodes[node.id] && childrenOf(node.id).length > 0 && (
              <ul className="ab-tree ab-tree--child">
                {childrenOf(node.id).map(kid => SubjectNode(kid, true))}
              </ul>
            )}
          </li>
        );
        return (
          <section className="ab-explore-sec ab-subject-tree">
            <span className="ab-facets__title">{t({ id: 'catalog.tree.title' })}</span>
            <ul className="ab-tree">{roots.map(node => SubjectNode(node, false))}</ul>
            <div className="ab-tree__export">
              {t({ id: 'catalog.tree.export' })}
              <button type="button" className="ab-mini-action" onClick={() => downloadThesaurus('ttl')}>SKOS/Turtle</button>
              <button type="button" className="ab-mini-action" onClick={() => downloadThesaurus('jsonld')}>JSON-LD</button>
            </div>
          </section>
        );
      })()}

      {/* ══ #OPAC7 — Facettes de découverte (CDD / auteur·rice / décennie) ══ */}
      {facets && ((facets.cdd?.length || 0) + (facets.author?.length || 0) + (facets.decade?.length || 0) + (facets.subjects?.length || 0) > 0) && (
        <section className="ab-explore-sec ab-facets">
          <span className="ab-facets__title">{t({ id: 'catalog.facets.title' })}</span>
          {facets.cdd?.length > 0 && (
            <div className="ab-facet-group">
              <span className="ab-facet-group__label">{t({ id: 'catalog.facets.cdd' })}</span>
              <div className="ab-facet-chips">
                {(showAllCdd ? facets.cdd : facets.cdd.slice(0, 12)).map(f => (
                  <button key={f.code} type="button"
                    className={`ab-facet-chip ${dCdd === f.code ? 'is-active' : ''}`}
                    onClick={() => pickCdd(f.code)}
                    title={cddLabel(f.code)}>
                    <strong>{f.code}</strong>
                    <span className="ab-facet-chip__sub">{cddLabel(f.code)}</span>
                    <span className="ab-facet-chip__count">{f.count}</span>
                  </button>
                ))}
                {facets.cdd.length > 12 && (
                  <button type="button" className="ab-facet-more" onClick={() => setShowAllCdd(s => !s)}>
                    {showAllCdd ? t({ id: 'catalog.facets.less' }) : t({ id: 'catalog.facets.more' })}
                  </button>
                )}
              </div>
            </div>
          )}
          {facets.author?.length > 0 && (
            <div className="ab-facet-group">
              <span className="ab-facet-group__label">{t({ id: 'catalog.facets.author' })}</span>
              <div className="ab-facet-chips">
                {facets.author.map(f => (
                  <button key={f.label} type="button" className="ab-facet-chip" onClick={() => pickAuthorFacet(f)}>
                    {f.label}
                    <span className="ab-facet-chip__count">{f.count}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
          {facets.decade?.length > 0 && (
            <div className="ab-facet-group">
              <span className="ab-facet-group__label">{t({ id: 'catalog.facets.decade' })}</span>
              <div className="ab-facet-chips">
                {facets.decade.map(f => (
                  <button key={f.decade} type="button" className="ab-facet-chip" onClick={() => pickDecade(f.decade)}>
                    {f.decade}
                    <span className="ab-facet-chip__count">{f.count}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
          {facets.subjects?.length > 0 && (
            <div className="ab-facet-group">
              <span className="ab-facet-group__label">{t({ id: 'book.meta.subjects' })}</span>
              <div className="ab-facet-chips">
                {facets.subjects.map(f => (
                  <button key={f.subject_id} type="button"
                    className={`ab-facet-chip ${subjectFilter === f.slug ? 'is-active' : ''}`}
                    onClick={() => pickSubject(f)}>
                    {localizedSubjectLabel(f.label_i18n, locale)}
                    <span className="ab-facet-chip__count">{f.count}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </section>
      )}
      </div>)}

      {/* ══ STATS PILLS ═══════════════════════════════════════ */}
      <div className="ab-stats">
        <Pill>Total: {totalCount ?? '…'}</Pill>
        <Pill>{t({ id: 'catalog.stats.displayed' }, { count: loading && books.length === 0 ? '…' : books.length })}{loading && books.length === 0 ? ` / ${totalCount ?? '…'}` : hasMore ? ` / ${totalCount ?? '…'}` : totalCount ? ` / ${totalCount}` : ''}</Pill>
        <Pill variant={isAuth && serverAvailableCount > 0 ? 'ok' : 'default'}>
          {t({ id: 'catalog.stats.localAvailable' }, { count: isAuth ? (serverAvailableCount ?? '…') : '—' })}
        </Pill>
        <Pill variant={hasActiveFilters ? 'warn' : 'default'}>
          {hasActiveFilters ? t({ id: 'catalog.stats.filtersActive' }) : t({ id: 'catalog.stats.noFilters' })}
        </Pill>
        <Pill>{t({ id: 'catalog.stats.sort' }, { label: sortLabel(sortValue, SORT_OPTIONS) })}</Pill>
      </div>

      {/* ══ TABLE ═════════════════════════════════════════════ */}
      {loading ? (
        <div className="ab-catalog-loading" role="status" aria-live="polite">
          <div className="ab-catalog-loading__message">
            <Spinner size={20} />
            <span>{t({ id: 'catalog.loading.message' })}</span>
          </div>
          <div className="ab-catalog-loading__skeleton" aria-hidden="true">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="ab-catalog-loading__row">
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--ref" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--title" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--author" />
                <span className="ab-catalog-loading__cell ab-catalog-loading__cell--year" />
              </div>
            ))}
          </div>
        </div>
      ) : books.length === 0 ? (
        <EmptyState message={t({ id: 'catalog.results.empty' })} />
      ) : (
        <div className="ab-sheet">
          <div className="ab-sheet__head">
            <div>
              <span className="ab-sheet__title">{t({ id: 'catalog.table.title' })}</span>
              <span className="ab-sheet__hint">{t({ id: 'catalog.table.sortHint' })}</span>
            </div>
            <div className="ab-table-jump">
              <button onClick={() => scrollTable('top')} title={t({ id: 'catalog.table.jumpTop' })}>↑</button>
              <button onClick={() => scrollTable('bottom')} title={t({ id: 'catalog.table.jumpBottom' })}>↓</button>
            </div>
          </div>
          <div className="ab-table-wrap" ref={tableRef}>
            <table className={`ab-table ab-table--cards ${compact ? 'ab-table--compact' : ''}`}>
              <thead>
                <tr>
                  <th onClick={() => handleHeaderSort('bib_ref')}>{t({ id: 'catalog.table.ref' })}{si('bib_ref')}</th>
                  <th onClick={() => handleHeaderSort('autor')}>{t({ id: 'catalog.table.author' })}{si('autor')}</th>
                  <th onClick={() => handleHeaderSort('titulo')}>{t({ id: 'catalog.table.bookTitle' })}{si('titulo')}</th>
                  <th onClick={() => handleHeaderSort('ano')}>{t({ id: 'catalog.table.year' })}{si('ano')}</th>
                  <th onClick={() => handleHeaderSort('editora')}>{t({ id: 'catalog.table.publisher' })}{si('editora')}</th>
                  <th>{t({ id: 'catalog.table.libraries' })}</th>
                  <th>{t({ id: 'catalog.table.availability' })}</th>
                  {isAuth && (
                    <th className="ab-table__actions-col">{t({ id: 'catalog.table.actions' })}</th>
                  )}
                </tr>
              </thead>
              <tbody>
                {displayBooks.map((book, idx) => {
                  const status = getStatusInfo(book, isAuth, t);
                  const icon = TIPO_ICONS[book.tipo_material] || '';
                  const libsRaw = parseLibraryNames(book);
                  const libs = libsRaw
                    ? libsRaw.split(', ').map(nm => cityByLib[nm] ? `${nm} (${cityByLib[nm]})` : nm).join(', ')
                    : '';
                  return (
                    <tr key={`${book.book_id}-${book.library_slug}-${idx}`}>
                      <td data-label={t({ id: 'catalog.table.ref' })}><Link to={`/livro/${book.book_id}`}>{book.bib_ref || '—'}</Link></td>
                      <td data-label={t({ id: 'catalog.table.author' })}><AuthorLinks book={book} /></td>
                      <td data-label={t({ id: 'catalog.table.bookTitle' })}>
                        <div className="ab-cat-title">
                          <Link to={`/livro/${book.book_id}`} className="ab-cat-thumb" tabIndex={-1} aria-hidden="true">
                            {book.cover_object_path
                              ? <img src={coverThumb(book.cover_object_path)} alt="" loading="lazy" decoding="async" width="30" height="42" />
                              : <span className="ab-cat-thumb__ph">{icon || '📖'}</span>}
                          </Link>
                          <span className="ab-cat-title__text">
                            <Link to={`/livro/${book.book_id}`}>
                              {book.titulo}
                              {book.subtitulo && <span className="ab-subtitulo"> — {book.subtitulo}</span>}
                            </Link>
                            {book.has_online_reading && <span className="ab-online-badge">{t({ id: 'catalog.actions.readOnline' })}</span>}
                            {book._editionCount > 1 && (
                              <Link to={`/obra/${book.work_id}`} className="ab-online-badge">
                                {t({ id: 'work.page.editions' }, { count: book._editionCount })} · {t({ id: 'book.work.view' })}
                              </Link>
                            )}
                          </span>
                        </div>
                      </td>
                      <td data-label={t({ id: 'catalog.table.year' })}>{book.ano || '—'}</td>
                      <td data-label={t({ id: 'catalog.table.publisher' })}>
                        {book.publisher_display ? (<>
                          {book.tipo_material === 'audiovisual' && <span title={t({ id: 'catalogacao.field.distribuidora' })}>🎬 </span>}
                          {book.tipo_material === 'audio' && <span title={t({ id: 'catalogacao.field.gravadora' })}>💿 </span>}
                          {book.publisher_display}
                        </>) : '—'}
                      </td>
                      <td data-label={t({ id: 'catalog.table.libraries' })}>{libs || '—'}</td>
                      <td data-label={t({ id: 'catalog.table.availability' })}><span className={`ab-status-dot ab-status-dot--${status.cls}`}>{status.label}</span></td>
                      {isAuth && (
                        <td className="ab-table__actions-cell">
                          {(() => {
                            // Bouton visible uniquement si :
                            //  - garde-fous globaux OK (service mode, non restreint)
                            //  - statut du livre = 'ok' (= disponible dans MA biblio, count > 0)
                            //  - livre prêtable (sinon c'est consultation, autre flux)
                            if (!quickReserveAvailable) return null;
                            if (status.cls !== 'ok') return null;
                            if (book.session_loanable === false) return null;

                            const key = String(book.book_id || book.bib_ref || '');
                            const refLow = String(book.bib_ref || '').trim().toLowerCase();
                            const localDone = reservedBibRefs.has(refLow);
                            const st = reserveState[key] || (localDone ? 'done' : 'idle');

                            if (st === 'done') {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.quickReserve.doneHint' })}>
                                  ✓ {t({ id: 'catalog.quickReserve.done' })}
                                </span>
                              );
                            }
                            if (st === 'reserving') {
                              return (
                                <button className="ab-quick-reserve ab-quick-reserve--loading" disabled>
                                  <Spinner size="sm" /> {t({ id: 'catalog.quickReserve.loading' })}
                                </button>
                              );
                            }
                            if (typeof st === 'string' && st.startsWith('error:')) {
                              const msg = st.slice(6);
                              return (
                                <div className="ab-quick-reserve-error">
                                  <span className="ab-quick-reserve-error__msg" title={msg}>{msg}</span>
                                  <button
                                    type="button"
                                    className="ab-quick-reserve ab-quick-reserve--retry"
                                    onClick={() => handleQuickReserve(book)}
                                  >
                                    {t({ id: 'catalog.quickReserve.retry' })}
                                  </button>
                                </div>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve"
                                onClick={() => handleQuickReserve(book)}
                                title={t({ id: 'catalog.quickReserve.hint' })}
                              >
                                {t({ id: 'catalog.quickReserve.label' })}
                              </button>
                            );
                          })()}
                          {/* Bouton "Agendar consulta" (#consulta-loanable,
                              24/05/2026). Tout ouvrage en circulation est
                              consultable, qu'il soit empruntable ou non, et
                              que ses exemplaires soient ou non disponibles a
                              l'emprunt. quickConsultaAvailable porte deja la
                              garde de service (pausada -> non). La
                              disponibilite reelle d'un exemplaire est tranchee
                              cote base (fn_v2_resolve_consulta_exemplar,
                              #MODEL-item-grain). */}
                          {(() => {
                            if (!quickConsultaAvailable) return null;
                            // Bug fix 30/05/2026 — garde par livre manquante.
                            // Sans ce check, le bouton apparaissait sur les
                            // livres hors périmètre lecteur (typique BTL vu
                            // depuis compte BLMF, hint=indisponivel_para_voce,
                            // status.cls='bad'). Le backend bloque déjà côté
                            // RPC mais montrer le bouton est trompeur.
                            if (status.cls === 'bad') return null;

                            const key = String(book.book_id || book.bib_ref || '');
                            const refLow = String(book.bib_ref || '').trim().toLowerCase();
                            const localDone = consultedBibRefs.has(refLow);
                            const st = consultaState[key] || (localDone ? 'done' : 'idle');

                            if (st === 'done') {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.quickConsulta.doneHint' })}>
                                  ✓ {t({ id: 'catalog.quickConsulta.done' })}
                                </span>
                              );
                            }
                            if (st === 'reserving') {
                              return (
                                <button className="ab-quick-reserve ab-quick-reserve--loading" disabled>
                                  <Spinner size="sm" /> {t({ id: 'catalog.quickConsulta.loading' })}
                                </button>
                              );
                            }
                            if (typeof st === 'string' && st.startsWith('error:')) {
                              const msg = st.slice(6);
                              return (
                                <div className="ab-quick-reserve-error">
                                  <span className="ab-quick-reserve-error__msg" title={msg}>{msg}</span>
                                  <button
                                    type="button"
                                    className="ab-quick-reserve ab-quick-reserve--retry"
                                    onClick={() => handleQuickConsulta(book)}
                                  >
                                    {t({ id: 'catalog.quickReserve.retry' })}
                                  </button>
                                </div>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve"
                                onClick={() => handleQuickConsulta(book)}
                                title={t({ id: 'catalog.quickConsulta.hint' })}
                              >
                                {t({ id: 'catalog.quickConsulta.label' })}
                              </button>
                            );
                          })()}
                          {/* #OPAC9 — Favoritar */}
                          {(() => {
                            const bid = book.book_id || book.id;
                            if (wishlistedIds.has(bid)) {
                              return (
                                <span className="ab-quick-reserve ab-quick-reserve--done" title={t({ id: 'catalog.wishlist.saved' })}>
                                  ★ {t({ id: 'catalog.wishlist.saved' })}
                                </span>
                              );
                            }
                            return (
                              <button
                                type="button"
                                className="ab-quick-reserve ab-wishlist-btn"
                                disabled={wishlistBusy === bid}
                                onClick={() => handleWishlist(book)}
                                title={t({ id: 'catalog.wishlist.add' })}
                              >
                                ☆ {t({ id: 'catalog.wishlist.add' })}
                              </button>
                            );
                          })()}
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Charger plus */}
      {hasMore && !loading && (
        <div className="ab-load-more">
          <Button variant="secondary" onClick={() => fetchBooks(totalFetched, true)} loading={loadingMore}>
            {t({ id: 'catalog.actions.loadMore' }, { loaded: totalFetched, total: totalCount ?? '…' })}
          </Button>
        </div>
      )}

      <Footer />
    </PageShell>
  );
}

// ── Composant liens auteurs ────────────────────────────────

function AuthorLinks({ book }) {
  // author_chips est un JSON array [{ author_id, label }]
  let chips = book.author_chips;
  if (typeof chips === 'string') {
    try { chips = JSON.parse(chips); } catch { chips = null; }
  }

  if (Array.isArray(chips) && chips.length > 0) {
    return chips.map((chip, i) => (
      <span key={chip.author_id || `unlinked-${i}`}>
        {i > 0 && ' ; '}
        {chip.author_id ? (
          <Link to={`/autor/${chip.author_id}`} className="ab-author-link">
            {chip.label || chip.preferred_name || '?'}
          </Link>
        ) : (
          <span>{chip.label || '?'}</span>
        )}
      </span>
    ));
  }

  // Fallback : author_id unique
  if (book.author_id) {
    return (
      <Link to={`/autor/${book.author_id}`} className="ab-author-link">
        {book.author_display || book.autor || '—'}
      </Link>
    );
  }

  return <>{book.author_display || book.autor || '—'}</>;
}
