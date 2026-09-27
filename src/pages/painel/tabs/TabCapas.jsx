import { useState, useEffect, useCallback, useRef } from 'react';
import { Button, Spinner } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { COVER_BUCKET, removeCoverThumb, writeCoverThumb } from '@/lib/coverThumbs';
import { cheminPhoto, preparerPhoto } from '@/lib/photoCapa';
import CardScanner from './CardScanner';

// ═══════════════════════════════════════════════════════════
// TabCapas — photographier les couvertures, livre en main (27/09/2026)
// ───────────────────────────────────────────────────────────
// Le fonds brésilien n'existe pas dans les catalogues ouverts : la recherche
// automatique (cover-batch) n'y trouve presque rien. Ici, la personne qui est
// en rayon prend le livre, retrouve sa notice — par le titre, le tombo, ou en
// scannant l'étiquette de l'exemplaire ou le code-barres ISBN —, photographie
// la couverture avec le téléphone, et passe au suivant.
//
// La photo est préparée DANS le navigateur (lib/photoCapa.js) : redressée,
// réduite, réencodée — donc sans les métadonnées du téléphone (lieu, appareil).
// Elle est rangée sous un nom neuf (`photo-…`) dans le dossier de la notice,
// avec sa vignette dérivée, puis api.capas_photo_poser l'attache à la notice
// (provenance « photo »). Une couverture existante n'est remplacée que sur
// demande explicite ; une couverture posée entre-temps ne l'est jamais.
//
// Même périmètre que le reste du Painel : la bibliothèque courante, son staff.
// ═══════════════════════════════════════════════════════════

const PAGE = 20;
const FORMATS_SCAN = ['qr_code', 'ean_13', 'ean_8', 'code_128'];

export default function TabCapas({ t, libraryId }) {
  const [resume, setResume] = useState(null);
  const [recherche, setRecherche] = useState('');
  const [lignes, setLignes] = useState([]);
  const [page, setPage] = useState(0);
  const [chargement, setChargement] = useState(false);
  const [choisie, setChoisie] = useState(null);      // la notice en cours
  const [photo, setPhoto] = useState(null);          // { fichier, blob, apercu }
  const [quarts, setQuarts] = useState(0);
  const [occupe, setOccupe] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [scan, setScan] = useState(false);
  const entree = useRef(null);

  const erreur = useCallback((err) => {
    setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
  }, [t]);

  const chargerResume = useCallback(async () => {
    if (!libraryId) return;
    const { data, error } = await supabase.schema('api').rpc('capas_photo_resume', { p_library_id: libraryId });
    if (!error) setResume(data);
  }, [libraryId]);

  const chargerListe = useCallback(async (p, q) => {
    if (!libraryId) return;
    setChargement(true);
    try {
      const { data, error } = await supabase.schema('api').rpc('capas_photo_liste', {
        p_library_id: libraryId, p_recherche: q || null, p_limite: PAGE, p_decalage: p * PAGE,
      });
      if (error) throw error;
      const rows = data || [];
      setLignes(rows);
      // Un scan ou une recherche qui désigne UNE notice : elle est prise tout de suite.
      if (q && rows.length === 1) setChoisie(rows[0]);
    } catch (err) {
      erreur(err);
    } finally {
      setChargement(false);
    }
  }, [libraryId, erreur]);

  useEffect(() => { chargerResume(); }, [chargerResume]);
  useEffect(() => {
    const h = setTimeout(() => chargerListe(page, recherche.trim()), recherche ? 300 : 0);
    return () => clearTimeout(h);
  }, [page, recherche, chargerListe]);

  // L'aperçu est une URL locale (blob:) : on la rend quand elle ne sert plus.
  useEffect(() => () => { if (photo?.apercu) URL.revokeObjectURL(photo.apercu); }, [photo]);

  function choisir(ligne) {
    setChoisie(ligne);
    setPhoto(null);
    setQuarts(0);
    setMsg({ text: '', kind: '' });
  }

  async function preparer(fichier, q) {
    setOccupe(true);
    try {
      const blob = await preparerPhoto(fichier, q);
      setPhoto({ fichier, blob, apercu: URL.createObjectURL(blob) });
    } catch (err) {
      erreur(err);
    } finally {
      setOccupe(false);
    }
  }

  async function surFichier(e) {
    const fichier = e.target.files?.[0];
    e.target.value = '';          // la même photo peut être reprise
    if (!fichier) return;
    setQuarts(0);
    await preparer(fichier, 0);
  }

  async function tourner(sens) {
    if (!photo) return;
    const q = (quarts + sens + 4) % 4;
    setQuarts(q);
    await preparer(photo.fichier, q);
  }

  // La notice suivante de la liste : la campagne avance livre après livre.
  function suivante(apres) {
    const i = lignes.findIndex((l) => l.book_id === apres.book_id);
    const reste = lignes.filter((l) => l.book_id !== apres.book_id);
    return reste[Math.max(0, i)] || null;
  }

  async function effacer(chemin) {
    try {
      await supabase.storage.from(COVER_BUCKET).remove([chemin]);
      await removeCoverThumb(chemin);
    } catch {
      // best-effort : un orphelin ne casse rien
    }
  }

  async function poser() {
    if (!choisie || !photo) return;
    const notice = choisie;
    const chemin = cheminPhoto(notice.bib_ref);
    setOccupe(true);
    setMsg({ text: '', kind: '' });
    let range = false;
    try {
      const { error: eUp } = await supabase.storage.from(COVER_BUCKET)
        .upload(chemin, photo.blob, { contentType: 'image/jpeg', upsert: false });
      if (eUp) throw eUp;
      range = true;
      await writeCoverThumb(chemin, photo.blob);
      const { data: statut, error } = await supabase.schema('api').rpc('capas_photo_poser', {
        p_book_id: notice.book_id, p_object_path: chemin, p_remplacer: Boolean(notice.a_une_capa),
      });
      if (error) throw error;
      if (statut === 'deja_une_capa') {
        await effacer(chemin);
        setMsg({ text: t({ id: 'catalogacao.capas.perimee' }, { titre: notice.titulo }), kind: 'info' });
      } else {
        setMsg({ text: t({ id: 'catalogacao.capas.acceptee' }, { titre: notice.titulo }), kind: 'ok' });
        setResume((r) => (r ? {
          ...r,
          sans_capa: Math.max(0, Number(r.sans_capa ?? 0) - (notice.a_une_capa ? 0 : 1)),
          photographiees: Number(r.photographiees ?? 0) + 1,
        } : r));
      }
      const prochaine = suivante(notice);
      setLignes((ls) => ls.filter((l) => l.book_id !== notice.book_id));
      setChoisie(prochaine);
      setPhoto(null);
      setQuarts(0);
    } catch (err) {
      if (range) await effacer(chemin);
      erreur(err);
    } finally {
      setOccupe(false);
    }
  }

  const couleur = msg.kind === 'error' ? 'var(--color-danger, #f87171)' : msg.kind === 'ok' ? 'var(--color-success, #4ade80)' : undefined;

  return (
    <div className="ab-capas-photo">
      <h2 className="ab-painel-section-title">{t({ id: 'capas.photo.titre' })}</h2>
      <p className="ab-painel-hint">{t({ id: 'capas.photo.intro' })}</p>

      {resume && (
        <p className="ab-painel-hint" data-capas-compte>
          {t({ id: 'capas.photo.compte' }, { sans: Number(resume.sans_capa ?? 0), faites: Number(resume.photographiees ?? 0) })}
        </p>
      )}

      {msg.text && <p className="ab-painel-msg" role="status" aria-live="polite" style={{ color: couleur }}>{msg.text}</p>}

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', marginBottom: 12 }}>
        <input type="search" value={recherche} onChange={(e) => { setRecherche(e.target.value); setPage(0); }}
          placeholder={t({ id: 'capas.photo.recherche' })} aria-label={t({ id: 'capas.photo.recherche' })}
          style={{ flex: '1 1 220px', minWidth: 0, fontSize: 16, padding: '8px 12px', borderRadius: 8,
                   border: '1px solid rgba(255,255,255,.16)', background: 'rgba(0,0,0,.30)', color: 'inherit' }} />
        <Button onClick={() => setScan((s) => !s)}>{t({ id: 'capas.photo.scanner' })}</Button>
      </div>

      {scan && (
        <CardScanner
          t={t}
          formats={FORMATS_SCAN}
          prompt={t({ id: 'capas.photo.scanPrompt' })}
          onScan={(code) => { setScan(false); setPage(0); setRecherche(String(code || '').trim()); }}
          onClose={() => setScan(false)}
        />
      )}

      {choisie && (
        <div className="ab-capas-photo__fiche" style={{ border: '1px solid rgba(255,255,255,.14)', borderRadius: 10, padding: 12, marginBottom: 14, background: 'rgba(0,0,0,.18)' }}>
          <div style={{ fontWeight: 600, wordBreak: 'break-word' }}>
            {choisie.titulo}{choisie.subtitulo ? ` — ${choisie.subtitulo}` : ''}
          </div>
          {choisie.autor && <div style={{ fontSize: '.86rem', wordBreak: 'break-word' }}>{choisie.autor}</div>}
          <div className="ab-painel-hint" style={{ wordBreak: 'break-word' }}>
            {[[choisie.editora, choisie.ano].filter(Boolean).join(', '),
              (choisie.tombos || []).join(', '), choisie.bib_ref].filter(Boolean).join(' · ')}
          </div>
          {choisie.a_une_capa && (
            <p role="alert" style={{ color: '#fbbf24', fontSize: '.82rem', margin: '6px 0' }}>{t({ id: 'capas.photo.dejaUneCapa' })}</p>
          )}

          <input ref={entree} type="file" accept="image/*" capture="environment" hidden onChange={surFichier} data-capas-entree />

          {photo ? (
            <div style={{ marginTop: 10 }}>
              {/* URL locale (blob:) de la photo préparée — rien de tiers. */}
              <img src={photo.apercu} alt={t({ id: 'catalogacao.ui.coverAlt' })}
                style={{ display: 'block', maxWidth: '100%', maxHeight: 360, borderRadius: 6, margin: '0 auto 10px' }} />
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center' }}>
                <Button variant="secondary" onClick={() => tourner(-1)} disabled={occupe} aria-label={t({ id: 'capas.photo.tournerGauche' })}>⟲</Button>
                <Button variant="secondary" onClick={() => tourner(1)} disabled={occupe} aria-label={t({ id: 'capas.photo.tournerDroite' })}>⟳</Button>
                <Button variant="secondary" onClick={() => entree.current?.click()} disabled={occupe}>{t({ id: 'capas.photo.reprendre' })}</Button>
                <Button onClick={poser} disabled={occupe}>
                  {occupe ? <Spinner /> : t({ id: choisie.a_une_capa ? 'capas.photo.remplacer' : 'capas.photo.poser' })}
                </Button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
              <Button onClick={() => entree.current?.click()} disabled={occupe}>
                {occupe ? <Spinner /> : <>📷 {t({ id: 'capas.photo.photographier' })}</>}
              </Button>
              <Button variant="secondary" onClick={() => choisir(suivante(choisie))} disabled={occupe}>
                {t({ id: 'capas.photo.passer' })}
              </Button>
            </div>
          )}
        </div>
      )}

      {chargement ? (
        <Spinner />
      ) : lignes.length === 0 ? (
        <p className="ab-painel-hint">{t({ id: 'capas.photo.vide' })}</p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'grid', gap: 6 }}>
          {lignes.map((l) => (
            <li key={l.book_id}>
              <button type="button" onClick={() => choisir(l)} aria-current={choisie?.book_id === l.book_id ? 'true' : undefined}
                style={{ width: '100%', textAlign: 'left', padding: '8px 10px', borderRadius: 8, cursor: 'pointer', color: 'inherit',
                         border: choisie?.book_id === l.book_id ? '1px solid var(--brand-accent, #60a5fa)' : '1px solid rgba(255,255,255,.10)',
                         background: 'rgba(0,0,0,.15)' }}>
                <span style={{ fontWeight: 600, wordBreak: 'break-word' }}>{l.titulo}</span>
                {l.autor ? <span style={{ fontSize: '.8rem' }}> — {l.autor}</span> : null}
                <span className="ab-painel-hint" style={{ display: 'block', margin: 0, wordBreak: 'break-word' }}>
                  {[(l.tombos || []).join(', '), l.bib_ref].filter(Boolean).join(' · ')}
                  {l.a_une_capa ? ' · ✓' : ''}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {(page > 0 || lignes.length === PAGE) && (
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <Button variant="secondary" onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={page === 0 || chargement}>
            {t({ id: 'common.previous' })}
          </Button>
          <Button variant="secondary" onClick={() => setPage((p) => p + 1)} disabled={lignes.length < PAGE || chargement}>
            {t({ id: 'common.next' })}
          </Button>
        </div>
      )}
    </div>
  );
}
