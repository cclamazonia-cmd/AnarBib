// src/pages/catalogacao/ExemplaresPanel.jsx — C29, lot 1 (10/10/2026)
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
// Ce lot ne crée ni ne modifie rien ici : « Nouvel exemplaire » et « Modifier »
// remontent au parent (onNewCopy, onEditPublished, onEditDraft), qui ouvre
// l'éditeur existant pré-ciblé. Un exemplaire publié qui a déjà un brouillon de
// mise à jour propose « Reprendre la mise à jour » au lieu d'en ouvrir un second
// (create_exemplar_draft_from_exemplar n'est pas idempotent). Rien ici n'écrit
// le formulaire de la notice.
import { useEffect, useMemo, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';
import { useStaffLibraries } from '@/lib/useStaffLibraries';

const VIVANTS = ['draft', 'ready'];

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

export default function ExemplaresPanel({ publishedBookId, draftId, reloadKey, onNewCopy, onEditPublished, onEditDraft }) {
  const { formatMessage: t } = useIntl();
  const { isNetworkAdmin } = useLibrary();
  const { staffLibraryIds, loaded: staffConnu } = useStaffLibraries();
  const [libraries, setLibraries] = useState([]);
  const [exemplaires, setExemplaires] = useState([]);
  const [brouillons, setBrouillons] = useState([]);
  const [chargement, setChargement] = useState(false);
  const [erreur, setErreur] = useState('');

  useEffect(() => {
    let cancelled = false;
    supabase.from('libraries').select('id, name, short_name').eq('is_active', true).order('name')
      .then(({ data }) => { if (!cancelled && Array.isArray(data)) setLibraries(data); });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    const pubId = publishedBookId ? Number(publishedBookId) : null;
    const dId = draftId ? Number(draftId) : null;
    if (!pubId && !dId) { setExemplaires([]); setBrouillons([]); setErreur(''); return undefined; }
    let cancelled = false;
    (async () => {
      setChargement(true); setErreur('');
      try {
        let bibRef = null;
        let publies = [];
        if (pubId) {
          const { data: book, error: eBook } = await supabase.from('books').select('bib_ref').eq('id', pubId).maybeSingle();
          if (eBook) throw eBook;
          bibRef = book?.bib_ref || null;
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
  }, [publishedBookId, draftId, reloadKey]); // eslint-disable-line react-hooks/exhaustive-deps

  const groupes = useMemo(
    () => grouperParBibliotheque(exemplaires, brouillons, { staffLibraryIds: staffConnu ? staffLibraryIds : [], isNetworkAdmin, libraries }),
    [exemplaires, brouillons, staffLibraryIds, staffConnu, isNetworkAdmin, libraries],
  );
  const total = exemplaires.length + brouillons.length;
  const circulation = (p) => (p ? t({ id: `catalogacao.exemplar.circulationPolicy.${p}` }) : '');

  return (
    <div className="cat-material-section cat-dep" style={{ gridColumn: 'span 3' }} data-testid="copies-panel">
      <div className="cat-dep__head">
        <h4 style={{ margin: 0 }}>
          {t({ id: 'catalogacao.copies.title' })}
          {total > 0 && <span className="cat-pill ok" style={{ marginLeft: 8, fontSize: '.65rem' }}>{t({ id: 'catalogacao.copies.count' }, { n: total })}</span>}
        </h4>
        {publishedBookId && onNewCopy && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => onNewCopy(publishedBookId)}>
            {t({ id: 'catalogacao.copies.new' })}
          </button>
        )}
      </div>

      {!publishedBookId && (
        <div className="cat-dep__note" role="note" data-testid="copies-unpublished">{t({ id: 'catalogacao.copies.unpublished' })}</div>
      )}
      {erreur && <div className="cat-dep__note" role="alert">{t({ id: 'catalogacao.copies.loadError' }, { message: erreur })}</div>}
      {chargement && total === 0 && <div className="cat-dep__empty">{t({ id: 'catalogacao.ui.refreshing' })}</div>}
      {!chargement && !erreur && publishedBookId && total === 0 && (
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
    </div>
  );
}
