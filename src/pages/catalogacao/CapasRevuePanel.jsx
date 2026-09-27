// CapasRevuePanel — l'écran de revue des capas proposées par le lot (27/09/2026).
//
// POURQUOI. Au 27/09/2026, 2 384 notices « livro » n'avaient pas de capa, et la
// seule façon d'en poser une était de l'ouvrir, chercher, choisir, enregistrer,
// publier — notice par notice. L'Edge Function cover-batch cherche désormais
// seule, par petits lots (même recherche que le formulaire), et range ce
// qu'elle trouve dans `public.cover_proposals`. Ici, une personne tranche : un
// clic sur la bonne couverture la pose, « Aucune ne convient » écarte la
// proposition pour de bon (le lot ne la reproposera pas ; « Annuler » défait).
//
// CE QUE L'ÉCRAN NE FAIT PAS. Il ne contacte jamais Open Library ni Inventaire :
// la base ne garde que des adresses, et les vignettes sont rapatriées par le
// serveur (cover_lookup, action `apercus`, spec capas §4.3). La couverture
// choisie est rangée par le serveur aussi (action `store`), sous un nom NEUF
// (`capa-…`) : jamais par-dessus une capa qu'une autre personne viendrait de
// poser par le formulaire. La RPC d'acceptation refuse alors d'écrire
// (« perimee ») et le fichier rangé pour rien est retiré.
//
// PÉRIMÈTRE. Les notices que possède ou détient une bibliothèque de la
// personne (toutes pour l'administration du réseau) — gardé côté SQL.

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { COVER_BUCKET, removeCoverThumb, writeCoverThumb } from '@/lib/coverThumbs';
import { accordEdition, etiquetteCandidate, ordonnerCandidates, parIsbn } from '@/lib/coverSources';

const PAGE = 8;
/** Candidates montrées par notice : les meilleures, la galerie complète reste au formulaire. */
const PAR_NOTICE = 4;

const box = {
  border: '1px solid rgba(255,255,255,.10)', borderRadius: 10,
  padding: 12, marginBottom: 10, background: 'rgba(0,0,0,.15)',
};
const muted = { fontSize: '.74rem', color: 'var(--brand-muted, #999)' };

/** La notice, telle que la confrontation d'édition la lit. */
const noticeDe = (r) => ({ ano: r.ano, editora: r.editora, volume: r.volume });

export default function CapasRevuePanel() {
  const { formatMessage: t } = useIntl();
  const [ouvert, setOuvert] = useState(false);
  const [resume, setResume] = useState(null);
  const [lignes, setLignes] = useState([]);
  const [page, setPage] = useState(0);
  const [apercus, setApercus] = useState({});
  const [chargement, setChargement] = useState(false);
  const [occupe, setOccupe] = useState(null);        // book_id dont la capa se pose
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [ecartee, setEcartee] = useState(null);      // la dernière écartée, pour « Annuler »

  // Le résumé se charge replié : c'est lui qui dit s'il y a du travail. Hors du
  // staff, la RPC refuse — l'écran ne s'affiche pas.
  const chargerResume = useCallback(async () => {
    const { data, error } = await supabase.schema('api').rpc('capas_revue_resume');
    setResume(error ? null : data);
  }, []);

  useEffect(() => { chargerResume(); }, [chargerResume]);

  const chargerPage = useCallback(async (p) => {
    setChargement(true);
    try {
      const { data, error } = await supabase.schema('api').rpc('capas_revue_liste', { p_limite: PAGE, p_decalage: p * PAGE });
      if (error) throw error;
      const rows = (data || []).map((r) => ({
        ...r,
        candidates: ordonnerCandidates(r.candidates || [], noticeDe(r)).slice(0, PAR_NOTICE),
      }));
      setLignes(rows);
      // Les vignettes passent par le serveur, jamais par le navigateur (§4.3).
      const urls = [...new Set(rows.flatMap((r) => r.candidates.map((c) => c.thumbnailUrl)).filter(Boolean))];
      if (urls.length) {
        const { data: ap } = await supabase.functions.invoke('cover_lookup', { body: { action: 'apercus', urls } });
        setApercus(ap?.apercus || {});
      } else {
        setApercus({});
      }
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setChargement(false);
    }
  }, [t]);

  // Le lot remplit la file pendant qu'on travaille : le compte se relit à
  // chaque ouverture et à chaque page.
  useEffect(() => {
    if (!ouvert) return;
    chargerResume();
    chargerPage(page);
  }, [ouvert, page, chargerPage, chargerResume]);

  // Une ligne tranchée quitte la page ; la page vidée se recharge (les
  // suivantes ont glissé d'un cran). Les gestes sont un à un (boutons
  // désactivés pendant qu'une capa se pose) : `lignes` est à jour ici.
  function retirer(bookId) {
    const reste = lignes.filter((l) => l.book_id !== bookId);
    const total = Math.max(0, Number(resume?.a_revoir ?? 0) - 1);
    setLignes(reste);
    setResume((r) => (r ? { ...r, a_revoir: Math.max(0, Number(r.a_revoir ?? 0) - 1) } : r));
    if (!reste.length) {
      if (page > 0 && page * PAGE >= total) setPage(page - 1);
      else chargerPage(page);
    }
  }

  async function choisir(ligne, c) {
    setOccupe(ligne.book_id);
    setMsg({ text: '', kind: '' });
    setEcartee(null);
    let range = null;
    try {
      const { data, error } = await supabase.functions.invoke('cover_lookup', {
        body: {
          action: 'store', imageUrl: c.fullUrl, key: ligne.bib_ref,
          nom: `capa-${Date.now().toString(36)}`, source: c.source || null, license: c.license || null,
        },
      });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'store failed');
      range = data.storagePath;
      await writeCoverThumb(range);
      const { data: statut, error: e2 } = await supabase.schema('api').rpc('capas_revue_accepter', {
        p_book_id: ligne.book_id, p_full_url: c.fullUrl, p_object_path: range,
      });
      if (e2) throw e2;
      if (statut === 'perimee') {
        await effacer(range);
        setMsg({ text: t({ id: 'catalogacao.capas.perimee' }, { titre: ligne.titulo }), kind: 'info' });
      } else {
        setMsg({ text: t({ id: 'catalogacao.capas.acceptee' }, { titre: ligne.titulo }), kind: 'ok' });
      }
      retirer(ligne.book_id);
    } catch (err) {
      // Rangée pour rien : on ne laisse pas un fichier orphelin dans le bucket.
      if (range) await effacer(range);
      setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setOccupe(null);
    }
  }

  async function effacer(chemin) {
    try {
      await supabase.storage.from(COVER_BUCKET).remove([chemin]);
      await removeCoverThumb(chemin);
    } catch {
      // best-effort : un orphelin ne casse rien
    }
  }

  async function aucune(ligne) {
    setOccupe(ligne.book_id);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.schema('api').rpc('capas_revue_ecarter', { p_book_id: ligne.book_id });
      if (error) throw error;
      setEcartee({ book_id: ligne.book_id, titulo: ligne.titulo });
      setMsg({ text: t({ id: 'catalogacao.capas.ecartee' }, { titre: ligne.titulo }), kind: 'info' });
      retirer(ligne.book_id);
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setOccupe(null);
    }
  }

  async function annulerEcart() {
    const e = ecartee;
    if (!e) return;
    try {
      const { error } = await supabase.schema('api').rpc('capas_revue_rouvrir', { p_book_id: e.book_id });
      if (error) throw error;
      setEcartee(null);
      setMsg({ text: t({ id: 'catalogacao.capas.rouverte' }, { titre: e.titulo }), kind: 'ok' });
      await chargerResume();
      await chargerPage(page);
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  const aRevoir = Number(resume?.a_revoir ?? 0);
  const aChercher = Number(resume?.a_chercher ?? 0);
  // Rien à revoir et rien à chercher : l'écran se tait.
  if (!resume || (aRevoir === 0 && aChercher === 0 && !ecartee)) return null;

  const debut = page * PAGE;
  const couleurMsg = msg.kind === 'error' ? '#f87171' : msg.kind === 'ok' ? '#4ade80' : 'var(--brand-muted, #bbb)';

  return (
    <section style={{ marginTop: 20 }}>
      <button type="button" onClick={() => setOuvert((o) => !o)} aria-expanded={ouvert}
        style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%', textAlign: 'left',
                 background: 'none', border: 'none', color: 'inherit', cursor: 'pointer',
                 padding: '6px 0', fontSize: '1rem', fontWeight: 600 }}>
        <span aria-hidden="true" style={{ display: 'inline-block', transition: 'transform .15s',
              transform: ouvert ? 'rotate(90deg)' : 'none' }}>▸</span>
        <span style={{ minWidth: 0 }}>{t({ id: 'catalogacao.capas.titre' })}</span>
        <span style={{ fontSize: '.78rem', fontWeight: 400, color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'catalogacao.capas.aRevoir' }, { n: aRevoir })}
        </span>
      </button>

      {ouvert && (
        <>
          <p style={{ ...muted, fontSize: '.78rem', margin: '8px 0 6px', maxWidth: 720 }}>
            {t({ id: 'catalogacao.capas.intro' })}
          </p>
          {aChercher > 0 && (
            <p style={{ ...muted, margin: '0 0 12px' }}>
              {t({ id: 'catalogacao.capas.aChercher' }, { n: aChercher })}
            </p>
          )}

          {msg.text && (
            <div role="status" aria-live="polite" style={{ marginBottom: 10, fontSize: '.8rem', color: couleurMsg, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <span style={{ minWidth: 0 }}>{msg.text}</span>
              {ecartee && (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={annulerEcart}>
                  {t({ id: 'catalogacao.capas.annuler' })}
                </button>
              )}
            </div>
          )}

          {chargement ? (
            <p style={muted}>{t({ id: 'common.loading' })}</p>
          ) : lignes.length === 0 ? (
            <p style={muted}>{t({ id: 'catalogacao.capas.vide' })}</p>
          ) : lignes.map((r) => {
            const notice = noticeDe(r);
            const accords = r.candidates.map((c) => accordEdition(c, notice));
            // Comme au formulaire : l'avertissement d'en-tête ne parle que des candidates trouvées par l'ISBN.
            const ecart = accords.find((a, i) => parIsbn(r.candidates[i]) && a?.statut === 'ecart') || null;
            const volume = ecart ? null : (accords.find((a, i) => parIsbn(r.candidates[i]) && a?.statut === 'volume') || null);
            const pris = occupe === r.book_id;
            return (
              <div key={r.book_id} style={box}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(260px, 100%), 1fr))', gap: 12 }}>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: '.92rem', fontWeight: 600, wordBreak: 'break-word' }}>
                      {r.titulo}{r.subtitulo ? ` — ${r.subtitulo}` : ''}
                    </div>
                    {r.autor && <div style={{ fontSize: '.82rem', marginTop: 2, wordBreak: 'break-word' }}>{r.autor}</div>}
                    <div style={{ ...muted, marginTop: 4, wordBreak: 'break-word' }}>
                      {[
                        [r.editora, r.ano].filter(Boolean).join(', '),
                        r.volume ? `${t({ id: 'catalogacao.field.volume' })} ${r.volume}` : '',
                        r.isbn ? `${t({ id: 'catalogacao.field.isbn' })} ${r.isbn}` : '',
                        r.bib_ref,
                      ].filter(Boolean).join(' · ')}
                    </div>
                    {ecart && (
                      <div role="alert" style={{ fontSize: '.72rem', lineHeight: 1.4, color: '#fbbf24', marginTop: 8 }}>
                        {t({ id: 'catalogacao.ui.coverIsbnEcart' }, { trouvee: ecart.trouvee || '?', notice: ecart.notice || '?' })}
                      </div>
                    )}
                    {volume && (
                      <div role="alert" style={{ fontSize: '.72rem', lineHeight: 1.4, color: '#fbbf24', marginTop: 8 }}>
                        {t({ id: 'catalogacao.ui.coverIsbnVolume' }, { volume: volume.volume })}
                      </div>
                    )}
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ marginTop: 10 }}
                      onClick={() => aucune(r)} disabled={occupe !== null}>
                      {t({ id: 'catalogacao.capas.aucune' })}
                    </button>
                  </div>

                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignContent: 'flex-start', minWidth: 0 }}>
                    {r.candidates.map((c, i) => {
                      const e = etiquetteCandidate(c, accords[i]);
                      const apercu = apercus[c.thumbnailUrl];
                      return (
                        <button key={c.fullUrl} type="button" onClick={() => choisir(r, c)} disabled={occupe !== null}
                          title={[t({ id: 'catalogacao.capas.choisir' }), c.label, c.source].filter(Boolean).join(' · ')}
                          aria-label={[t({ id: 'catalogacao.capas.choisir' }), c.label].filter(Boolean).join(' · ')}
                          style={{ padding: 0, width: 84, borderRadius: 6, background: 'rgba(0,0,0,.3)', color: 'inherit',
                                   border: e?.ton === 'attention' ? '1px solid #fbbf24' : '1px solid rgba(255,255,255,.15)',
                                   cursor: occupe !== null ? 'default' : 'pointer', opacity: occupe !== null && !pris ? 0.45 : 1 }}>
                          {/* data: URI rapatriée par le serveur — jamais `c.thumbnailUrl` dans un src (§4.3). */}
                          {apercu
                            ? <img src={apercu} alt="" style={{ width: '100%', height: 112, objectFit: 'cover', borderRadius: '6px 6px 0 0', display: 'block' }} />
                            : <div aria-hidden="true" style={{ width: '100%', height: 112, borderRadius: '6px 6px 0 0', background: 'rgba(255,255,255,.05)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.4rem', opacity: .35 }}>📖</div>}
                          {e && (
                            <div style={{ fontSize: '.58rem', fontWeight: 700, padding: '2px 3px 0', textAlign: 'center', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                              color: e.ton === 'attention' ? '#fbbf24' : e.ton === 'ok' ? '#4ade80' : 'var(--brand-muted, #aaa)' }}>
                              {e.code === 'oeuvre' ? t({ id: 'catalogacao.ui.coverOeuvre' })
                                : e.code === 'verifier' ? t({ id: 'catalogacao.ui.coverIsbnVerifier' })
                                : e.code === 'isbnConcordant' ? t({ id: 'catalogacao.ui.coverIsbnConcordant' })
                                : e.code === 'titreProbable' ? t({ id: 'catalogacao.ui.coverTitreProbable' })
                                : e.code === 'titreSeul' ? t({ id: 'catalogacao.ui.coverTitreSeul' })
                                : t({ id: 'catalogacao.ui.coverIsbnSeul' })}
                            </div>
                          )}
                          <div style={{ fontSize: '.6rem', color: 'var(--brand-muted, #aaa)', padding: '2px 3px 3px', textAlign: 'center', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {pris ? t({ id: 'catalogacao.capas.pose' }) : (c.label || c.source)}
                          </div>
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>
            );
          })}

          {aRevoir > PAGE && (
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginTop: 4 }}>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={page === 0 || chargement || occupe !== null}>
                {t({ id: 'common.previous' })}
              </button>
              <span style={muted}>
                {t({ id: 'catalogacao.capas.page' }, { debut: debut + 1, fin: Math.min(debut + PAGE, aRevoir), total: aRevoir })}
              </span>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={() => setPage((p) => p + 1)} disabled={debut + PAGE >= aRevoir || chargement || occupe !== null}>
                {t({ id: 'common.next' })}
              </button>
            </div>
          )}
        </>
      )}
    </section>
  );
}
