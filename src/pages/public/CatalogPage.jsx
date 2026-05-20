import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, EmptyState, Spinner } from '@/components/ui';
import UnifiedSearchCombobox from '@/components/UnifiedSearchCombobox';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import './CatalogPage.css';

const PAGE_SIZE = 100;

// URLs des manuels (stockes sur Supabase Storage, bucket library-ui-assets).
// Le manuel lecteur est un PDF multilingue unique (8 langues en interne).
const PUBLIC_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total','available_count',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json',
].join(',');

const SESSION_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json',
  'session_library_id','session_library_slug','session_library_name',
  'session_exemplares_total','session_has_holding','session_status_hint',
  'session_available_count','session_loanable',
].join(',');

// Sort options, availability options, and status labels are built inside the component using t()
// See useMemo blocks inside CatalogPage

const TIPO_ICONS = {
  livro:'📕', periodico:'📰', folheto:'📄', boletim:'📰',
  arquivo:'📂', zine:'✊', tract:'📜', cartaz:'🪧',
  audio:'🎧', audiovisual:'🎬', recurso_digital:'💻',
  dossie:'📁', outro:'📎',
};

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

function buildServerFilters({ search, authorFilter, publisherFilter, yearFilter, libraryFilter, availabilityFilter, isAuth, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter }) {
  const f = {};
  if (search.trim()) {
    const p = `%${search.trim()}%`;
    f['or'] = `(titulo.ilike.${p},autor.ilike.${p},editora.ilike.${p},bib_ref.ilike.${p},cdd.ilike.${p},assuntos.ilike.${p},subtitulo.ilike.${p},isbn.ilike.${p})`;
  }
  if (authorFilter.trim()) f['autor'] = `ilike.%${authorFilter.trim()}%`;
  if (publisherFilter.trim()) f['editora'] = `ilike.%${publisherFilter.trim()}%`;
  if (yearFilter.trim()) {
    const raw = yearFilter.trim();
    const m = raw.match(/^(\d{4})\s*[-–]\s*(\d{4})$/);
    if (m) f['and'] = `(ano.gte.${m[1]},ano.lte.${m[2]})`;
    else f['ano'] = `eq.${raw}`;
  }
  if (libraryFilter && libraryFilter !== '__all__') f['library_slug'] = `eq.${libraryFilter}`;
  // Advanced filters
  if (isbnFilter.trim()) f['isbn'] = `ilike.%${isbnFilter.trim().replace(/[-\s]/g, '')}%`;
  if (languageFilter.trim()) f['idioma'] = `ilike.%${languageFilter.trim()}%`;
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
  // Doctrine A1/A2/A3 : aucun filtre availabilityFilter ne s'applique pour l'anon
  // (branche consult && !isAuth retiree car AVAILABILITY_OPTIONS_ANON ne contient
  // plus que '__all__').
  return f;
}

function sortLabel(v, opts) { return opts.find(o => o.value === v)?.label || ''; }

function useDebounce(value, delay = 400) {
  const [d, setD] = useState(value);
  useEffect(() => { const t = setTimeout(() => setD(value), delay); return () => clearTimeout(t); }, [value, delay]);
  return d;
}

// ── Export helpers ──────────────────────────────────────────

function exportCSV(books) {
  const header = ['ref','autor','titulo','ano','editora','biblioteca'];
  const rows = books.map(b => [b.bib_ref||'', (b.author_display||b.autor||'').replace(/"/g,'""'), (b.titulo||'').replace(/"/g,'""'), b.ano||'', (b.editora||'').replace(/"/g,'""'), parseLibraryNames(b).replace(/"/g,'""')]);
  const csv = [header.join(','), ...rows.map(r => r.map(c => `"${c}"`).join(','))].join('\n');
  const blob = new Blob(['\uFEFF'+csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = 'anarbib-catalogo.csv'; a.click();
  URL.revokeObjectURL(url);
}

function exportPDF(books, t) {
  const now = new Date().toLocaleDateString('pt-BR');
  const rows = books.map(b =>
    `<tr><td>${b.bib_ref||'—'}</td><td>${b.author_display||b.autor||'—'}</td><td>${b.titulo||'—'}${b.subtitulo?` — ${b.subtitulo}`:''}</td><td>${b.ano||'—'}</td><td>${b.editora||'—'}</td><td>${parseLibraryNames(b)||'—'}</td></tr>`
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
  const { formatMessage: t } = useIntl();
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
  const [publisherFilter, setPublisherFilter] = useState(filterState.publisherFilter || '');
  const [yearFilter, setYearFilter] = useState(filterState.yearFilter || '');
  const [availabilityFilter, setAvailabilityFilter] = useState(filterState.availabilityFilter || '__all__');
  const [libraryFilter, setLibraryFilter] = useState(filterState.libraryFilter || '__all__');
  const [sortValue, setSortValue] = useState(filterState.sortValue || '__relevance__');
  const [compact, setCompact] = useState(filterState.compact || false);
  const [filtersOpen, setFiltersOpen] = useState(true);
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [isbnFilter, setIsbnFilter] = useState(filterState.isbnFilter || '');
  const [languageFilter, setLanguageFilter] = useState(filterState.languageFilter || '');
  const [cddFilter, setCddFilter] = useState(filterState.cddFilter || '');
  const [subjectsFilter, setSubjectsFilter] = useState(filterState.subjectsFilter || '');
  const [materialFilter, setMaterialFilter] = useState(filterState.materialFilter || '__all__');
  const [collectionFilter, setCollectionFilter] = useState(filterState.collectionFilter || '');
  const [placeFilter, setPlaceFilter] = useState(filterState.placeFilter || '');

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
    saveFilters({ search, authorFilter, publisherFilter, yearFilter, availabilityFilter, libraryFilter, sortValue, compact, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter });
  }, [search, authorFilter, publisherFilter, yearFilter, availabilityFilter, libraryFilter, sortValue, compact, isbnFilter, languageFilter, cddFilter, subjectsFilter, materialFilter, collectionFilter, placeFilter]);

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
      || urlSearchParams.has('editora') || urlSearchParams.has('ano');
    if (!hasUrlIntent) return;

    // Filtre bibliothèque : URL prioritaire, sinon __all__.
    setLibraryFilter(libFromUrl || '__all__');
    // Autres filtres : valeur de l'URL si présente, sinon remise à zéro.
    setSearch(urlSearchParams.get('q') || '');
    setAuthorFilter(urlSearchParams.get('autor') || '');
    setPublisherFilter(urlSearchParams.get('editora') || '');
    setYearFilter(urlSearchParams.get('ano') || '');
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
        select: 'slug,name',
        order: 'name.asc',
      });
      if (data?.length) {
        setLibraryOptions([
          { value: '__all__', label: t({ id: 'catalog.avail.all' }) },
          ...data.map(l => ({ value: l.slug, label: l.name || l.slug })),
        ]);
      }
    })();
  }, []);

  // Fetch
  const fetchBooks = useCallback(async (offset = 0, append = false) => {
    if (offset === 0) setLoading(true); else setLoadingMore(true);
    try {
      const filters = buildServerFilters({ search:dSearch, authorFilter:dAuthor, publisherFilter:dPublisher, yearFilter:dYear, libraryFilter, availabilityFilter, isAuth, isbnFilter:dIsbn, languageFilter:dLanguage, cddFilter:dCdd, subjectsFilter:dSubjects, materialFilter, collectionFilter:dCollection, placeFilter:dPlace });
      const { data, error, totalCount: serverTotal } = await apiQuery(viewName, { select:selectCols, order:resolveOrder(), rangeFrom:offset, rangeTo:offset+PAGE_SIZE-1, filters });
      if (error) throw error;
      const result = data || [];
      if (append) setBooks(prev => [...prev, ...result]);
      else setBooks(result);
      setTotalFetched(offset + result.length);
      setHasMore(result.length === PAGE_SIZE);
      // Phase B.7 : utiliser le totalCount du Content-Range plutôt qu'un appel séparé à books_count_v1
      // (cohérent avec la grille, respecte automatiquement la visibility par matérialisée)
      if (serverTotal != null) setTotalCount(serverTotal);
    } catch (err) { console.error('Catalog fetch error:', err); if (!append) setBooks([]); }
    finally { setLoading(false); setLoadingMore(false); }
  }, [viewName, selectCols, sortValue, dSearch, dAuthor, dPublisher, dYear, libraryFilter, availabilityFilter, isAuth, dIsbn, dLanguage, dCdd, dSubjects, materialFilter, dCollection, dPlace]);

  useEffect(() => { fetchBooks(0); }, [fetchBooks]);

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
        p_notes: t({ id: 'catalog.quickReserve.note' }),
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
        p_notes: t({ id: 'catalog.quickConsulta.note' }),
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
  const hasActiveFilters = dSearch || dAuthor || dPublisher || dYear || availabilityFilter !== '__all__' || libraryFilter !== '__all__' || dIsbn || dLanguage || dCdd || dSubjects || materialFilter !== '__all__' || dCollection || dPlace;
  const availabilityOptions = isAuth ? AVAILABILITY_OPTIONS_AUTH : AVAILABILITY_OPTIONS_ANON;

  function handleHeaderSort(col) {
    setSortValue(prev => {
      const [pc,pd] = prev.split('.');
      return pc === col ? `${col}.${pd === 'asc' ? 'desc' : 'asc'}` : `${col}.asc`;
    });
  }
  function si(col) { const [c,d] = sortValue.split('.'); return c === col ? (d==='asc'?' ↑':' ↓') : ''; }

  function clearFilters() {
    setSearch(''); setAuthorFilter(''); setPublisherFilter(''); setYearFilter('');
    setAvailabilityFilter('__all__'); setLibraryFilter('__all__'); setSortValue('__relevance__');
    setIsbnFilter(''); setLanguageFilter(''); setCddFilter(''); setSubjectsFilter('');
    setMaterialFilter('__all__'); setCollectionFilter(''); setPlaceFilter('');
  }

  function copySearchLink() {
    // Forme propre alignée sur la route alias /catalogo/:slug.
    // La bibliothèque va dans le chemin ; les autres filtres en query params.
    const base = window.location.origin
      + (libraryFilter !== '__all__' ? `/catalogo/${libraryFilter}` : '/catalogo');
    const url = new URL(base);
    if (dSearch) url.searchParams.set('q', dSearch);
    if (dAuthor) url.searchParams.set('autor', dAuthor);
    if (dPublisher) url.searchParams.set('editora', dPublisher);
    if (dYear) url.searchParams.set('ano', dYear);
    navigator.clipboard.writeText(url.toString()).catch(() => {});
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
            // Filtre la grille par auteur (point 7 des décisions B.7) : on alimente
            // simplement le champ authorFilter texte. Le système de filtres existant
            // s'occupe du reste (debouncing, requête PostgREST, persistance localStorage).
            setAuthorFilter(author.filterValue || author.label);
            setSearch('');
            setFiltersOpen(true);
          }}
        />
      </section>

      {/* ══ FILTRES ═══════════════════════════════════════════ */}
      <section className="ab-toolbar">
        <div className="ab-filters-grid">
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.searchLabel' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.searchPlaceholder' })}
              value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalog.filters.author' })}</label>
            <input className="ab-input" type="search" placeholder={t({ id: 'catalog.filters.authorPlaceholder' })}
              value={authorFilter} onChange={e => setAuthorFilter(e.target.value)} />
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
            <select className="ab-select" value={libraryFilter} onChange={e => setLibraryFilter(e.target.value)}>
              {libraryOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div className="ab-field ab-field--action">
            <label className="ab-field__label">{t({ id: 'catalog.filters.clearAll' })}</label>
            <button className="ab-button ab-button--secondary" onClick={clearFilters}>{t({ id: 'catalog.filters.clearButton' })}</button>
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

        {/* Chips + view controls */}
        <div className="ab-toolbar-meta">
          {hasActiveFilters && (
            <div className="ab-active-filters">
              {dSearch && <span className="ab-filter-chip">{t({ id: 'catalog.chip.search' })}: <strong>{dSearch}</strong> <button onClick={() => setSearch('')}>✕</button></span>}
              {dAuthor && <span className="ab-filter-chip">{t({ id: 'catalog.chip.author' })}: <strong>{dAuthor}</strong> <button onClick={() => setAuthorFilter('')}>✕</button></span>}
              {dPublisher && <span className="ab-filter-chip">{t({ id: 'catalog.chip.publisher' })}: <strong>{dPublisher}</strong> <button onClick={() => setPublisherFilter('')}>✕</button></span>}
              {dYear && <span className="ab-filter-chip">{t({ id: 'catalog.chip.year' })}: <strong>{dYear}</strong> <button onClick={() => setYearFilter('')}>✕</button></span>}
              {availabilityFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.avail' })}: <strong>{availabilityOptions.find(o => o.value === availabilityFilter)?.label}</strong> <button onClick={() => setAvailabilityFilter('__all__')}>✕</button></span>}
              {libraryFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.library' })}: <strong>{libraryOptions.find(o => o.value === libraryFilter)?.label}</strong> <button onClick={() => setLibraryFilter('__all__')}>✕</button></span>}
              {dIsbn && <span className="ab-filter-chip">{t({ id: 'catalog.chip.isbn' })}: <strong>{dIsbn}</strong> <button onClick={() => setIsbnFilter('')}>✕</button></span>}
              {dLanguage && <span className="ab-filter-chip">{t({ id: 'catalog.chip.language' })}: <strong>{dLanguage}</strong> <button onClick={() => setLanguageFilter('')}>✕</button></span>}
              {dCdd && <span className="ab-filter-chip">{t({ id: 'catalog.chip.cdd' })}: <strong>{dCdd}</strong> <button onClick={() => setCddFilter('')}>✕</button></span>}
              {dSubjects && <span className="ab-filter-chip">{t({ id: 'catalog.chip.subjects' })}: <strong>{dSubjects}</strong> <button onClick={() => setSubjectsFilter('')}>✕</button></span>}
              {materialFilter !== '__all__' && <span className="ab-filter-chip">{t({ id: 'catalog.chip.material' })}: <strong>{t({ id: `catalogacao.material.${materialFilter}` })}</strong> <button onClick={() => setMaterialFilter('__all__')}>✕</button></span>}
              {dCollection && <span className="ab-filter-chip">{t({ id: 'catalog.chip.collection' })}: <strong>{dCollection}</strong> <button onClick={() => setCollectionFilter('')}>✕</button></span>}
              {dPlace && <span className="ab-filter-chip">{t({ id: 'catalog.chip.place' })}: <strong>{dPlace}</strong> <button onClick={() => setPlaceFilter('')}>✕</button></span>}
            </div>
          )}
          <div className="ab-view-controls">
            <button className="ab-mini-action" onClick={copySearchLink}>{t({ id: 'catalog.actions.copyLink' })}</button>
            <button className="ab-mini-action" onClick={() => setCompact(!compact)} aria-pressed={compact}>
              {compact ? t({ id: 'catalog.actions.compactOn' }) : t({ id: 'catalog.actions.compactOff' })}
            </button>
          </div>
        </div>
      </section>

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
              <button onClick={() => scrollTable('top')} title="Ir para o topo">↑</button>
              <button onClick={() => scrollTable('bottom')} title="Ir para o fim">↓</button>
            </div>
          </div>
          <div className="ab-table-wrap" ref={tableRef}>
            <table className={`ab-table ${compact ? 'ab-table--compact' : ''}`}>
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
                {books.map((book, idx) => {
                  const status = getStatusInfo(book, isAuth, t);
                  const icon = TIPO_ICONS[book.tipo_material] || '';
                  const libs = parseLibraryNames(book);
                  return (
                    <tr key={`${book.book_id}-${book.library_slug}-${idx}`}>
                      <td><Link to={`/livro/${book.book_id}`}>{book.bib_ref || '—'}</Link></td>
                      <td><AuthorLinks book={book} /></td>
                      <td>
                        <Link to={`/livro/${book.book_id}`}>
                          {icon && <span className="ab-tipo-icon">{icon} </span>}
                          {book.titulo}
                          {book.subtitulo && <span className="ab-subtitulo"> — {book.subtitulo}</span>}
                        </Link>
                        {book.has_online_reading && <span className="ab-online-badge">{t({ id: 'catalog.actions.readOnline' })}</span>}
                      </td>
                      <td>{book.ano || '—'}</td>
                      <td>{book.editora || '—'}</td>
                      <td>{libs || '—'}</td>
                      <td><span className={`ab-status-dot ab-status-dot--${status.cls}`}>{status.label}</span></td>
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
                          {/* Paquet B.2 : bouton "Agendar consulta", miroir du Reservar.
                              Doctrine §8 : pausada -> aucun ; somente_consulta -> seul ce bouton ;
                              funcionamento_normal -> ce bouton sur non-loanable OU livre dispo. */}
                          {(() => {
                            if (!quickConsultaAvailable) return null;
                            const mode = serviceState?.service_mode || 'funcionamento_normal';
                            const showConsulta =
                              mode === 'somente_consulta' ||
                              (mode === 'funcionamento_normal' && (
                                book.session_loanable === false ||
                                (status.cls === 'ok' && book.session_loanable !== false)
                              ));
                            if (!showConsulta) return null;

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
      <span key={chip.author_id}>
        {i > 0 && ' ; '}
        <Link to={`/autor/${chip.author_id}`} className="ab-author-link">
          {chip.label || chip.preferred_name || '?'}
        </Link>
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
