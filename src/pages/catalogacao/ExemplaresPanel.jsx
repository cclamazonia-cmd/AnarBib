// src/pages/catalogacao/ExemplaresPanel.jsx — C29, lots 1 et 2 (10/10/2026)
//
// Les exemplaires d'une notice, DANS la notice — frère de DigitalResourcesPanel.
// Jusqu'ici la fiche ne montrait jamais ses exemplaires ensemble : l'onglet
// « Indexation » liste « mes cent derniers brouillons », et la carte « pour
// information » de l'aperçu ne connaît que la bibliothèque active. Ce panneau
// lit la table des exemplaires publiés (fonds de la notice, puis repli sur la
// référence) et les brouillons vivants rattachés (par référence, ou par la
// notice pour un exemplaire importé), puis les range par bibliothèque : les
// miennes d'abord, modifiables ; les autres en lecture seule.
//
// Lot 2 — créer un exemplaire sans quitter la fiche. Le formulaire court se
// remplit dans l'ordre, chaque temps s'ouvrant quand le précédent est fait :
//   1. Où ?          une liste FERMÉE des bibliothèques où l'on est staff (toutes
//                    pour l'administration du réseau) ; une seule → choisie
//                    d'avance, le temps ne se montre pas. Plus de texte libre
//                    « Biblioteca » reconnu de façon floue (B29 : l'exemplaire se
//                    range dans une bibliothèque où l'on est staff, la cible est
//                    écrite explicitement).
//   2. Rangement     le numéro d'inventaire proposé par la série de la
//                    bibliothèque (fn_next_tombo), modifiable ; sans série, il se
//                    saisit ; puis secteur, étagère, rayon (format shelfLocation).
//   3. Circulation   et visibilité, héritées de la fiche (circulation_default,
//                    sinon loanable) — on n'y touche que si l'exemplaire déroge.
//   4. Détails       repliés : acquisition, provenance, notes, et l'étiquette,
//                    dont l'état se DÉDUIT (prête dès qu'auteur et titre sont
//                    connus) au lieu d'un bouton « marquer prête ».
// « Enregistrer et publier » pose le brouillon (exemplar_drafts) puis appelle
// publish_exemplar_draft tel quel : toutes les gardes de la base s'appliquent
// (staff de la bibliothèque, tombo unique, fonds de la bibliothèque, lot). Si
// la publication échoue, le brouillon reste et la liste le montre, avec
// « Modifier » vers l'éditeur complet. « Garder en brouillon » s'arrête avant.
//
// « Modifier » un exemplaire existant remonte encore au parent (onEditPublished,
// onEditDraft → éditeur complet) : c'est le lot 3. Un exemplaire publié qui a
// déjà un brouillon de mise à jour propose « Reprendre la mise à jour » au lieu
// d'en ouvrir un second (create_exemplar_draft_from_exemplar n'est pas
// idempotent). Rien ici n'écrit le formulaire de la notice.
import { useEffect, useMemo, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useStaffLibraries, bibliothequesProposables } from '@/lib/useStaffLibraries';
import { formatShelfLocation } from '@/lib/shelfLocation';

const VIVANTS = ['draft', 'ready'];
const CIRCULATIONS = ['ambos', 'emprestavel', 'consulta'];

function parTombo(a, b) {
  return String(a.tombo || '').localeCompare(String(b.tombo || ''), undefined, { numeric: true, sensitivity: 'base' });
}

// Range exemplaires publiés et brouillons par bibliothèque. Un brouillon qui
// reprend un exemplaire publié présent se greffe sur sa ligne (retake) ; les
// autres brouillons font leur propre ligne. Les bibliothèques où l'on est staff
// (ou toutes, pour l'administration du réseau) viennent d'abord et sont
// modifiables ; les autres suivent, en lecture seule, triées par nom.
export function grouperParBibliotheque(exemplaires, brouillons, { staffLibraryIds = [], isNetworkAdmin = false, libraries = [] } = {}) {
  const nomDe = (id) => {
    const l = libraries.find((x) => x.id === id);
    return l ? (l.short_name || l.name || id) : null;
  };
  const editable = (id) => isNetworkAdmin || staffLibraryIds.includes(id);
  const reprises = new Map();
  const seuls = [];
  for (const d of brouillons || []) {
    if (d.published_exemplar_id != null && (exemplaires || []).some((e) => String(e.id) === String(d.published_exemplar_id))) {
      reprises.set(String(d.published_exemplar_id), d);
    } else {
      seuls.push(d);
    }
  }
  const groupes = new Map();
  const groupe = (libraryId) => {
    const key = libraryId || '';
    if (!groupes.has(key)) groupes.set(key, { library_id: libraryId || null, nom: nomDe(libraryId), editable: !!libraryId && editable(libraryId), lignes: [] });
    return groupes.get(key);
  };
  for (const e of exemplaires || []) {
    groupe(e.library_id).lignes.push({
      kind: 'published', id: e.id, tombo: e.tombo || '', shelf_location: e.shelf_location || '',
      circulation_policy: e.circulation_policy || '', visibility: e.visibility || 'public',
      retake: reprises.get(String(e.id)) || null,
    });
  }
  for (const d of seuls) {
    groupe(d.target_library_id).lignes.push({
      kind: 'draft', id: d.id, tombo: d.tombo || '', shelf_location: d.shelf_location || '',
      circulation_policy: d.circulation_policy || '', visibility: d.visibility || 'public',
      status: d.status || 'draft', retake: null,
    });
  }
  const liste = [...groupes.values()];
  for (const g of liste) g.lignes.sort(parTombo);
  liste.sort((a, b) => {
    if (a.editable !== b.editable) return a.editable ? -1 : 1;
    return String(a.nom || '').localeCompare(String(b.nom || ''), undefined, { sensitivity: 'base' });
  });
  return liste;
}

// La circulation héritée de la fiche (§5.6) : circulation_default (3 valeurs),
// sinon le booléen loanable (true → 'ambos', sinon 'consulta').
export function circulationHeritee(book) {
  if (!book) return 'consulta';
  if (CIRCULATIONS.includes(book.circulation_default)) return book.circulation_default;
  return book.loanable ? 'ambos' : 'consulta';
}

// L'étiquette est prête dès qu'auteur et titre sont connus (de la fiche ou saisis).
export function etatEtiquette(book, saisie) {
  const titre = (saisie?.title || book?.titulo || '').trim();
  const auteur = (saisie?.author || book?.autor || '').trim();
  return titre && auteur ? 'ready' : 'pending';
}

const FORMULAIRE_VIDE = {
  library_id: '', tombo: '', tomboPropose: '', serieAbsente: false,
  sector: '', shelfUnit: '', shelfLevel: '', locNote: '',
  circulation_policy: '', visibility: 'public',
  acquisition_mode: '', acquisition_date: '', provenance_note: '', source_library: '', notes: '',
  label_title: '', label_author: '', label_cdd: '', label_note: '',
};

export default function ExemplaresPanel({ publishedBookId, draftId, reloadKey, onNewCopy, onEditPublished, onEditDraft }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const { isNetworkAdmin } = useLibrary();
  const { staffLibraryIds, loaded: staffConnu } = useStaffLibraries();
  const [libraries, setLibraries] = useState([]);
  const [book, setBook] = useState(null);           // { bib_ref, titulo, autor, cdd, circulation_default, loanable }
  const [exemplaires, setExemplaires] = useState([]);
  const [brouillons, setBrouillons] = useState([]);
  const [chargement, setChargement] = useState(false);
  const [erreur, setErreur] = useState('');
  const [rechargement, setRechargement] = useState(0);
  // Lot 2 : le formulaire court (null = fermé).
  const [nf, setNf] = useState(null);
  const [acqModes, setAcqModes] = useState([]);
  const [envoi, setEnvoi] = useState(''); // '' | 'draft' | 'publish'
  const [message, setMessage] = useState({ text: '', kind: '' });

  useEffect(() => {
    let cancelled = false;
    supabase.from('libraries').select('id, name, short_name').eq('is_active', true).order('name')
      .then(({ data }) => { if (!cancelled && Array.isArray(data)) setLibraries(data); });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    const pubId = publishedBookId ? Number(publishedBookId) : null;
    const dId = draftId ? Number(draftId) : null;
    if (!pubId && !dId) { setExemplaires([]); setBrouillons([]); setBook(null); setErreur(''); return undefined; }
    let cancelled = false;
    (async () => {
      setChargement(true); setErreur('');
      try {
        let bibRef = null;
        let publies = [];
        if (pubId) {
          const { data: livre, error: eBook } = await supabase.from('books')
            .select('bib_ref, titulo, autor, cdd, circulation_default, loanable').eq('id', pubId).maybeSingle();
          if (eBook) throw eBook;
          if (!cancelled) setBook(livre || null);
          bibRef = livre?.bib_ref || null;
          const { data: holdings, error: eH } = await supabase.from('book_holdings').select('id').eq('book_id', pubId);
          if (eH) throw eH;
          const cols = 'id, library_id, holding_id, bib_ref, tombo, shelf_location, circulation_policy, visibility';
          const vus = new Map();
          if (holdings && holdings.length) {
            const { data, error } = await supabase.from('exemplares').select(cols).in('holding_id', holdings.map((h) => h.id));
            if (error) throw error;
            for (const e of data || []) vus.set(String(e.id), e);
          }
          if (bibRef) {
            // Repli : un exemplaire publié sans fonds résolu garde la référence.
            const { data, error } = await supabase.from('exemplares').select(cols).eq('bib_ref', bibRef);
            if (error) throw error;
            for (const e of data || []) vus.set(String(e.id), e);
          }
          publies = [...vus.values()];
        } else if (!cancelled) {
          setBook(null);
        }
        const dcols = 'id, target_library_id, tombo, shelf_location, status, published_exemplar_id, circulation_policy, visibility';
        const vivants = new Map();
        if (bibRef) {
          const { data, error } = await supabase.from('exemplar_drafts').select(dcols)
            .in('status', VIVANTS).eq('retake_untouched', false).eq('target_bib_ref', bibRef);
          if (error) throw error;
          for (const d of data || []) vivants.set(String(d.id), d);
        }
        if (dId) {
          // Exemplaires importés : rattachés à la notice elle-même (H19).
          const { data, error } = await supabase.from('exemplar_drafts').select(dcols)
            .in('status', VIVANTS).eq('retake_untouched', false).eq('book_draft_id', dId);
          if (error) throw error;
          for (const d of data || []) vivants.set(String(d.id), d);
        }
        if (cancelled) return;
        setExemplaires(publies);
        setBrouillons([...vivants.values()]);
      } catch (e) {
        if (!cancelled) setErreur(localizeError(e, t));
      } finally {
        if (!cancelled) setChargement(false);
      }
    })();
    return () => { cancelled = true; };
  }, [publishedBookId, draftId, reloadKey, rechargement]); // eslint-disable-line react-hooks/exhaustive-deps

  // La fiche change : un formulaire ouvert ne la concerne plus.
  useEffect(() => { setNf(null); setMessage({ text: '', kind: '' }); }, [publishedBookId]);

  const groupes = useMemo(
    () => grouperParBibliotheque(exemplaires, brouillons, { staffLibraryIds: staffConnu ? staffLibraryIds : [], isNetworkAdmin, libraries }),
    [exemplaires, brouillons, staffLibraryIds, staffConnu, isNetworkAdmin, libraries],
  );
  const total = exemplaires.length + brouillons.length;
  const circulation = (p) => (p ? t({ id: `catalogacao.exemplar.circulationPolicy.${p}` }) : '');

  // ── Lot 2 : les bibliothèques où l'exemplaire peut se ranger ──────────────
  const rangeables = useMemo(
    () => (staffConnu || isNetworkAdmin ? bibliothequesProposables(libraries, { isNetworkAdmin, staffLibraryIds }) : []),
    [libraries, isNetworkAdmin, staffLibraryIds, staffConnu],
  );
  const nomBiblio = (id) => { const l = libraries.find((x) => x.id === id); return l ? (l.short_name || l.name) : id; };

  function ouvrirFormulaire() {
    setMessage({ text: '', kind: '' });
    const seule = rangeables.length === 1 ? rangeables[0].id : '';
    setNf({ ...FORMULAIRE_VIDE, library_id: seule, circulation_policy: circulationHeritee(book) });
    if (seule) proposerTombo(seule);
    if (acqModes.length === 0) {
      supabase.from('catalog_ref_acquisition_modes').select('code, label').eq('is_active', true).order('sort_order')
        .then(({ data }) => { if (Array.isArray(data)) setAcqModes(data); });
    }
  }
  function set(k, v) { setNf((p) => (p ? { ...p, [k]: v } : p)); }

  // 1 → 2 : la bibliothèque choisie propose le prochain numéro de sa série.
  function choisirBibliotheque(id) {
    setNf((p) => (p ? { ...p, library_id: id, tombo: '', tomboPropose: '', serieAbsente: false } : p));
    if (id) proposerTombo(id);
  }
  async function proposerTombo(libraryId) {
    try {
      const { data, error } = await supabase.rpc('fn_next_tombo', { p_library_id: libraryId });
      if (error) throw error;
      setNf((p) => (p && p.library_id === libraryId ? { ...p, tombo: p.tombo || data || '', tomboPropose: data || '', serieAbsente: !data } : p));
    } catch {
      // Pas de série configurée (tombo_pattern_not_configured) : saisie manuelle.
      setNf((p) => (p && p.library_id === libraryId ? { ...p, tomboPropose: '', serieAbsente: true } : p));
    }
  }

  const etape2 = !!nf?.library_id;
  const pretAEnvoyer = etape2 && (!!nf.tombo.trim() || !nf.serieAbsente) && !!book?.bib_ref;

  async function enregistrer(publier) {
    if (!nf || !pretAEnvoyer || envoi) return;
    setEnvoi(publier ? 'publish' : 'draft'); setMessage({ text: '', kind: '' });
    try {
      const payload = {
        action: 'create', status: 'draft',
        label_status: etatEtiquette(book, { title: nf.label_title, author: nf.label_author }),
        target_bib_ref: book.bib_ref,
        target_library_id: nf.library_id,
        tombo: nf.tombo.trim() || null,
        shelf_location: formatShelfLocation({ sector: nf.sector, shelfUnit: nf.shelfUnit, shelfLevel: nf.shelfLevel, note: nf.locNote }) || null,
        label_title_override: nf.label_title.trim() || null,
        label_author_override: nf.label_author.trim() || null,
        label_cdd_override: nf.label_cdd.trim() || null,
        label_note: nf.label_note.trim() || null,
        notes: nf.notes.trim() || null,
        circulation_policy: nf.circulation_policy || null,
        visibility: nf.visibility || 'public',
        acquisition_mode: nf.acquisition_mode || null,
        acquisition_date: nf.acquisition_date || null,
        provenance_note: nf.provenance_note.trim() || null,
        source_library: nf.source_library.trim() || null,
        created_by: user?.id || null, updated_by: user?.id || null,
      };
      const { data: brouillon, error } = await supabase.from('exemplar_drafts').insert(payload).select('id, tombo').single();
      if (error) throw error;
      if (!publier) {
        setNf(null); setRechargement((n) => n + 1);
        setMessage({ text: t({ id: 'catalogacao.copies.form.draftKept' }), kind: 'ok' });
        return;
      }
      try {
        const { error: ePub } = await supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(brouillon.id) });
        if (ePub) throw ePub;
      } catch (ePub) {
        // Le brouillon existe : la liste le montre, « Modifier » mène à l'éditeur complet.
        setNf(null); setRechargement((n) => n + 1);
        setMessage({ text: t({ id: 'catalogacao.copies.form.publishFailed' }, { message: localizeError(ePub, t) }), kind: 'error' });
        return;
      }
      const { data: pose } = await supabase.from('exemplar_drafts').select('tombo').eq('id', Number(brouillon.id)).maybeSingle();
      setNf(null); setRechargement((n) => n + 1);
      setMessage({ text: t({ id: 'catalogacao.copies.form.created' }, { tombo: pose?.tombo || nf.tombo.trim() || '—', library: nomBiblio(nf.library_id) }), kind: 'ok' });
    } catch (e) {
      setMessage({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setEnvoi('');
    }
  }

  const champ = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };

  return (
    <div className="cat-material-section cat-dep" style={{ gridColumn: 'span 3' }} data-testid="copies-panel">
      <div className="cat-dep__head">
        <h4 style={{ margin: 0 }}>
          {t({ id: 'catalogacao.copies.title' })}
          {total > 0 && <span className="cat-pill ok" style={{ marginLeft: 8, fontSize: '.65rem' }}>{t({ id: 'catalogacao.copies.count' }, { n: total })}</span>}
        </h4>
        {publishedBookId && !nf && (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={ouvrirFormulaire}
              disabled={staffConnu && rangeables.length === 0} data-testid="copies-new">
              {t({ id: 'catalogacao.copies.new' })}
            </button>
            {onNewCopy && (
              <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => onNewCopy(publishedBookId)}
                title={t({ id: 'catalogacao.copies.form.fullEditorHint' })}>
                {t({ id: 'catalogacao.copies.form.fullEditor' })}
              </button>
            )}
          </div>
        )}
      </div>

      {!publishedBookId && (
        <div className="cat-dep__note" role="note" data-testid="copies-unpublished">{t({ id: 'catalogacao.copies.unpublished' })}</div>
      )}
      {publishedBookId && staffConnu && rangeables.length === 0 && !isNetworkAdmin && (
        <div className="cat-dep__note" role="note">{t({ id: 'catalogacao.copies.form.noLibrary' })}</div>
      )}
      {erreur && <div className="cat-dep__note" role="alert">{t({ id: 'catalogacao.copies.loadError' }, { message: erreur })}</div>}
      {message.text && (
        <div className={`cat-dep__note ${message.kind === 'error' ? 'is-error' : ''}`} role="status" data-testid="copies-message"
          style={message.kind === 'error' ? { color: '#f87171' } : { color: '#7fd18f' }}>{message.text}</div>
      )}
      {chargement && total === 0 && <div className="cat-dep__empty">{t({ id: 'catalogacao.ui.refreshing' })}</div>}
      {!chargement && !erreur && publishedBookId && total === 0 && !nf && (
        <div className="cat-dep__empty" data-testid="copies-empty">{t({ id: 'catalogacao.copies.empty' })}</div>
      )}

      {groupes.map((g) => (
        <div key={g.library_id || 'sans'} data-testid="copies-group" data-library={g.library_id || ''} data-editable={g.editable ? '1' : '0'} style={{ marginBottom: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', fontSize: '.8rem', fontWeight: 700, margin: '6px 0 4px' }}>
            <span>{g.nom || t({ id: 'catalogacao.copies.libraryUnknown' })}</span>
            <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.copies.count' }, { n: g.lignes.length })}</span>
            {!g.editable && <span className="cat-pill" style={{ fontSize: '.6rem' }}>{t({ id: 'catalogacao.copies.otherLibrary' })}</span>}
          </div>
          <ul className="cat-dep__list">
            {g.lignes.map((l) => {
              const meta = [l.shelf_location, circulation(l.circulation_policy),
                l.visibility === 'staff_only' ? t({ id: 'catalogacao.exemplar.visibility.staff_only' }) : ''].filter(Boolean);
              return (
                <li key={`${l.kind}-${l.id}`} className="cat-dep__item" data-testid="copies-row" data-kind={l.kind} data-retake={l.retake ? '1' : '0'}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="cat-dep__item-title" style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
                      <span>{l.tombo || t({ id: 'catalogacao.queue.noTombo' })}</span>
                      {l.kind === 'draft' && (
                        <span className={`cat-pill ${l.status === 'ready' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                          {t({ id: l.status === 'ready' ? 'catalogacao.status.ready' : 'catalogacao.status.draft' })}
                        </span>
                      )}
                      {l.retake && <span className="cat-pill warn" style={{ fontSize: '.6rem' }}>{t({ id: 'catalogacao.copies.updatePending' })}</span>}
                    </div>
                    {meta.length > 0 && <div className="cat-dep__item-meta">{meta.join(' · ')}</div>}
                  </div>
                  {g.editable && (
                    <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                      {l.kind === 'draft' && onEditDraft && (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => onEditDraft(l.id)}>{t({ id: 'common.edit' })}</button>
                      )}
                      {l.kind === 'published' && l.retake && onEditDraft && (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => onEditDraft(l.retake.id)}>{t({ id: 'catalogacao.copies.resumeUpdate' })}</button>
                      )}
                      {l.kind === 'published' && !l.retake && onEditPublished && (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => onEditPublished(l.id)}>{t({ id: 'common.edit' })}</button>
                      )}
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      ))}

      {nf && (
        <div className="cat-dep__form" data-testid="copies-form">
          <h4 style={{ margin: '0 0 12px', fontSize: '.9rem' }}>{t({ id: 'catalogacao.copies.form.title' })}</h4>

          {/* 1. Où ? — une seule bibliothèque possible : choisie d'avance, rien à montrer */}
          {rangeables.length > 1 && (
            <fieldset className="cat-dep__step" data-testid="copies-step-where">
              <legend>{t({ id: 'catalogacao.copies.form.where' })}</legend>
              {rangeables.length <= 4 ? (
                <div className="cat-dep__choices">
                  {rangeables.map((l) => (
                    <label key={l.id} className={`cat-dep__choice${nf.library_id === l.id ? ' is-on' : ''}`}>
                      <input type="radio" name="copies-library" checked={nf.library_id === l.id} onChange={() => choisirBibliotheque(l.id)} />
                      <span>{l.short_name || l.name}{l.short_name && l.name !== l.short_name && <small>{l.name}</small>}</span>
                    </label>
                  ))}
                </div>
              ) : (
                <select value={nf.library_id} onChange={(e) => choisirBibliotheque(e.target.value)} style={champ}>
                  <option value="">—</option>
                  {rangeables.map((l) => <option key={l.id} value={l.id}>{l.short_name ? `${l.short_name} — ${l.name}` : l.name}</option>)}
                </select>
              )}
            </fieldset>
          )}
          {rangeables.length === 1 && (
            <div className="cat-dep__note" data-testid="copies-where-one">{t({ id: 'catalogacao.copies.form.whereOne' }, { library: nomBiblio(nf.library_id) })}</div>
          )}

          {/* 2. Rangement */}
          {etape2 && (
            <fieldset className="cat-dep__step" data-testid="copies-step-shelf">
              <legend>{t({ id: 'catalogacao.copies.form.shelf' })}</legend>
              <div className="cat-book-grid">
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.tombo' })}</label>
                  <input type="text" value={nf.tombo} onChange={(e) => set('tombo', e.target.value)} style={champ} data-testid="copies-tombo" />
                  <div style={{ fontSize: '.7rem', color: 'var(--brand-muted,#888)', marginTop: 2 }}>
                    {nf.serieAbsente ? t({ id: 'catalogacao.copies.form.tomboManual' }) : t({ id: 'catalogacao.copies.form.tomboHint' })}
                  </div>
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.sectorRoom' })}</label>
                  <input type="text" value={nf.sector} onChange={(e) => set('sector', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.sectorRoom.ph' })} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.shelfUnit' })}</label>
                  <input type="text" value={nf.shelfUnit} onChange={(e) => set('shelfUnit', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.shelfUnit.ph' })} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.shelfLevel' })}</label>
                  <input type="text" value={nf.shelfLevel} onChange={(e) => set('shelfLevel', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.shelfLevel.ph' })} style={champ} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label>{t({ id: 'catalogacao.exemplar.locNote' })}</label>
                  <input type="text" value={nf.locNote} onChange={(e) => set('locNote', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.locNote.ph' })} style={champ} />
                </div>
              </div>
            </fieldset>
          )}

          {/* 3. Circulation et visibilité, héritées de la fiche */}
          {etape2 && (
            <fieldset className="cat-dep__step" data-testid="copies-step-circulation">
              <legend>{t({ id: 'catalogacao.copies.form.circulation' })}</legend>
              <div className="cat-dep__note" style={{ marginTop: 0, marginBottom: 8 }}>{t({ id: 'catalogacao.copies.form.circulationInherited' })}</div>
              <div className="cat-dep__choices">
                {CIRCULATIONS.map((c) => (
                  <label key={c} className={`cat-dep__choice${nf.circulation_policy === c ? ' is-on' : ''}`}>
                    <input type="radio" name="copies-circulation" checked={nf.circulation_policy === c} onChange={() => set('circulation_policy', c)} />
                    <span>{t({ id: `catalogacao.exemplar.circulationPolicy.${c}` })}</span>
                  </label>
                ))}
              </div>
              <label className="cat-dep__check" style={{ marginTop: 8 }}>
                <input type="checkbox" checked={nf.visibility === 'staff_only'} onChange={(e) => set('visibility', e.target.checked ? 'staff_only' : 'public')} />
                {t({ id: 'catalogacao.exemplar.visibility.staff_only' })}
              </label>
            </fieldset>
          )}

          {/* 4. Détails, repliés */}
          {etape2 && (
            <details className="cat-dep__step" data-testid="copies-step-details">
              <summary style={{ fontWeight: 700, fontSize: '.86rem', cursor: 'pointer', marginBottom: 8 }}>{t({ id: 'catalogacao.copies.form.details' })}</summary>
              <div className="cat-book-grid">
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.acquisitionMode' })}</label>
                  <select value={nf.acquisition_mode} onChange={(e) => set('acquisition_mode', e.target.value)} style={champ}>
                    <option value="">{t({ id: 'catalogacao.exemplar.acquisitionModeDefault' })}</option>
                    {acqModes.map((m) => <option key={m.code} value={m.code}>{m.label}</option>)}
                  </select>
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.acquisitionDate' })}</label>
                  <input type="date" value={nf.acquisition_date} onChange={(e) => set('acquisition_date', e.target.value)} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.sourceLibrary' })}</label>
                  <input type="text" value={nf.source_library} onChange={(e) => set('source_library', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.sourceLibrary.ph' })} style={champ} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                  <label>{t({ id: 'catalogacao.exemplar.provenanceNote' })}</label>
                  <input type="text" value={nf.provenance_note} onChange={(e) => set('provenance_note', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.provenanceNote.ph' })} style={champ} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                  <label>{t({ id: 'catalogacao.exemplar.notes' })}</label>
                  <input type="text" value={nf.notes} onChange={(e) => set('notes', e.target.value)} placeholder={t({ id: 'catalogacao.exemplar.notes.ph' })} style={champ} />
                </div>
              </div>
              <div className="cat-dep__note" data-testid="copies-label-state">
                {t({ id: 'catalogacao.copies.form.labelDeduced' }, { author: nf.label_author || book?.autor || '—', title: nf.label_title || book?.titulo || '—' })}
              </div>
              <div className="cat-book-grid">
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.labelTitle' })}</label>
                  <input type="text" value={nf.label_title} onChange={(e) => set('label_title', e.target.value)} placeholder={book?.titulo || ''} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.labelAuthor' })}</label>
                  <input type="text" value={nf.label_author} onChange={(e) => set('label_author', e.target.value)} placeholder={book?.autor || ''} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.exemplar.labelCdd' })}</label>
                  <input type="text" value={nf.label_cdd} onChange={(e) => set('label_cdd', e.target.value)} placeholder={book?.cdd || ''} style={champ} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                  <label>{t({ id: 'catalogacao.exemplar.labelNote' })}</label>
                  <input type="text" value={nf.label_note} onChange={(e) => set('label_note', e.target.value)} style={champ} />
                </div>
              </div>
            </details>
          )}

          <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
            <button type="button" className="ab-button ab-button--sm" onClick={() => enregistrer(true)} disabled={!pretAEnvoyer || !!envoi} data-testid="copies-submit-publish">
              {envoi === 'publish' ? t({ id: 'catalogacao.author.publishing' }) : t({ id: 'catalogacao.copies.form.submitPublish' })}
            </button>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => enregistrer(false)} disabled={!pretAEnvoyer || !!envoi} data-testid="copies-submit-draft">
              {envoi === 'draft' ? t({ id: 'catalogacao.saving' }) : t({ id: 'catalogacao.copies.form.submitDraft' })}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => setNf(null)} disabled={!!envoi}>{t({ id: 'common.cancel' })}</button>
          </div>
        </div>
      )}
    </div>
  );
}
