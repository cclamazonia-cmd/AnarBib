import { useState, useEffect, useCallback, useRef } from 'react';
import { Button, Spinner } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { COVER_BUCKET, cheminCapaNeuf, removeCoverThumb, writeCoverThumb } from '@/lib/coverThumbs';
import { SEAU_PDF_PUBLIC, canvasEnJpeg, rendrePage1, urlPdfPublic } from '@/lib/capaPdf';

// ═══════════════════════════════════════════════════════════
// CapasPdfLot — la page 1 des PDF comme couverture, en lot (20/10/2026)
// ───────────────────────────────────────────────────────────
// Une archive numérique (Anarchief.org : 1 002 notices, aucune couverture) n'a
// pas de livre à photographier en rayon, mais elle a ses PDF — et la page 1
// d'un PDF est sa couverture. Le bouton du formulaire de catalogage le faisait
// notice par notice ; ici, une passe pour toute la bibliothèque.
//
// Le rendu se fait DANS le navigateur (lib/capaPdf.js), notice après notice :
// page 1 -> JPEG rangé sous un nom neuf `capa-…` dans le dossier de la notice,
// vignette dérivée, puis api.capas_pdf_poser l'attache (provenance pdf_page1).
// Une couverture posée entre-temps n'est jamais remplacée : « deja_une_capa »,
// et le fichier rangé pour rien est retiré.
//
// Les PDF à diffusion restreinte sont rendus aussi (décision de Xavier,
// 20/10/2026), lus par URL signée ; l'écran annonce combien, parce que leur
// page 1 devient une image publique (`covers` est un seau public — voir la
// migration 20261020203753).
//
// Rien ne s'affiche pour une bibliothèque sans PDF : le bloc ne gêne pas la
// campagne photo des fonds physiques.
//
// L'administration du réseau choisit la bibliothèque traitée (20/10/2026) : le
// Painel ne se place que là où le compte a une adhésion, et le réseau, qui suit
// le fonds d'Anarchief, n'y est pas coordinateur. Les RPC l'acceptent déjà pour
// toute bibliothèque ; api.capas_pdf_bibliotheques dit lesquelles ont à faire.
// ═══════════════════════════════════════════════════════════

const LOT = 10;

export default function CapasPdfLot({ t, libraryId, isNetworkAdmin = false, onPosees }) {
  const [cible, setCible] = useState(libraryId);   // la bibliothèque traitée
  const [choix, setChoix] = useState([]);          // admin réseau : où il y a à faire
  const [resume, setResume] = useState(null);
  const [enCours, setEnCours] = useState(false);
  const [courante, setCourante] = useState('');
  const [bilan, setBilan] = useState(null);       // { posees, echecs: [{ titre }] }
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const arret = useRef(false);

  useEffect(() => { setCible(libraryId); }, [libraryId]);

  const chargerChoix = useCallback(async () => {
    if (!isNetworkAdmin) return;
    const { data, error } = await supabase.schema('api').rpc('capas_pdf_bibliotheques');
    if (!error) setChoix(data || []);
  }, [isNetworkAdmin]);

  const chargerResume = useCallback(async () => {
    if (!cible) return;
    const { data, error } = await supabase.schema('api').rpc('capas_pdf_resume', { p_library_id: cible });
    if (!error) setResume(data);
  }, [cible]);

  useEffect(() => { chargerChoix(); }, [chargerChoix]);
  useEffect(() => { chargerResume(); }, [chargerResume]);
  // Quitter l'onglet arrête la passe à la notice suivante.
  useEffect(() => () => { arret.current = true; }, []);

  async function effacer(chemin) {
    try {
      await supabase.storage.from(COVER_BUCKET).remove([chemin]);
      await removeCoverThumb(chemin);
    } catch {
      // best-effort : un orphelin ne casse rien (scripts/purge-orphelins-covers.py)
    }
  }

  // La page 1, d'où que vienne le PDF. Seau public : son adresse publique, lue
  // par plages. Seau restreint : une URL signée de courte durée, lue de même —
  // et, si elle ne passe pas, le fichier entier par l'API Storage, comme le
  // bouton du formulaire.
  async function page1(n) {
    if (n.storage_bucket === SEAU_PDF_PUBLIC) return rendrePage1({ url: urlPdfPublic(n.storage_path) });
    const seau = supabase.storage.from(n.storage_bucket);
    const { data: signee } = await seau.createSignedUrl(n.storage_path, 600);
    if (signee?.signedUrl) {
      try {
        return await rendrePage1({ url: signee.signedUrl });
      } catch (err) {
        console.warn('[capas pdf] URL signée illisible, repli sur le fichier entier :', err?.message || err);
      }
    }
    const { data: fichier, error } = await seau.download(n.storage_path);
    if (error) throw error;
    return rendrePage1(await fichier.arrayBuffer());
  }

  // Une notice : rendre, ranger, attacher. Renvoie le statut de la RPC.
  async function traiter(n) {
    const canvas = await page1(n);
    const blob = await canvasEnJpeg(canvas);
    const chemin = cheminCapaNeuf(n.bib_ref || n.book_id, 'jpg');
    const { error: eUp } = await supabase.storage.from(COVER_BUCKET)
      .upload(chemin, blob, { contentType: 'image/jpeg', upsert: false });
    if (eUp) throw eUp;
    try {
      await writeCoverThumb(chemin, canvas);
      const { data: statut, error } = await supabase.schema('api').rpc('capas_pdf_poser', {
        p_book_id: n.book_id, p_object_path: chemin,
      });
      if (error) throw error;
      if (statut !== 'posee') await effacer(chemin);
      return statut;
    } catch (err) {
      await effacer(chemin);
      throw err;
    } finally {
      canvas.width = 0;           // rend la mémoire de la toile tout de suite
      canvas.height = 0;
    }
  }

  async function lancer() {
    arret.current = false;
    setEnCours(true);
    setMsg({ text: '', kind: '' });
    const echecs = [];
    let posees = 0;
    setBilan({ posees, echecs: [] });
    try {
      for (;;) {
        if (arret.current) break;
        const { data, error } = await supabase.schema('api').rpc('capas_pdf_liste', {
          p_library_id: cible, p_limite: LOT, p_exclure: echecs.map((e) => e.book_id),
        });
        if (error) throw error;
        const lot = data || [];
        if (!lot.length) break;
        for (const n of lot) {
          if (arret.current) break;
          setCourante(n.titulo || n.bib_ref || String(n.book_id));
          try {
            const statut = await traiter(n);
            if (statut === 'posee') posees += 1;
            // « deja_une_capa » : une couverture est arrivée d'ailleurs, la
            // notice sort d'elle-même de la liste — rien à compter.
          } catch (err) {
            echecs.push({ book_id: n.book_id, titre: n.titulo || n.bib_ref || String(n.book_id) });
            console.warn('[capas pdf] page 1 non rendue pour', n.book_id, '-', err?.message || err);
          }
          setBilan({ posees, echecs: [...echecs] });
        }
      }
      setMsg({
        text: t({ id: arret.current ? 'capas.pdf.arretee' : 'capas.pdf.fini' }, { posees, echecs: echecs.length }),
        kind: echecs.length ? 'info' : 'ok',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.capas.erreur' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setEnCours(false);
      setCourante('');
      await chargerResume();
      await chargerChoix();
      if (posees > 0 && cible === libraryId) onPosees?.();
    }
  }

  if (!resume) return null;
  const faisables = Number(resume.faisables ?? 0);
  const restreintes = Number(resume.restreintes ?? 0);
  const deja = Number(resume.posees ?? 0);
  const ailleurs = choix.filter((c) => c.library_id !== libraryId);
  if (!faisables && !restreintes && !deja && !bilan && !ailleurs.length) return null;

  const couleur = msg.kind === 'error' ? 'var(--color-danger, #f87171)' : msg.kind === 'ok' ? 'var(--color-success, #4ade80)' : undefined;

  return (
    <section className="ab-capas-pdf" data-capas-pdf
      style={{ border: '1px solid rgba(255,255,255,.14)', borderRadius: 10, padding: 12, marginBottom: 18, background: 'rgba(0,0,0,.18)' }}>
      <h2 className="ab-painel-section-title" style={{ marginTop: 0 }}>{t({ id: 'capas.pdf.titre' })}</h2>
      {ailleurs.length > 0 && (
        <label className="ab-painel-hint" style={{ display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
          {t({ id: 'capas.pdf.choix' })}
          <select value={cible || ''} disabled={enCours} data-capas-pdf-choix
            onChange={(e) => { setCible(e.target.value); setResume(null); setBilan(null); setMsg({ text: '', kind: '' }); }}
            style={{ minWidth: 0, maxWidth: '100%', fontSize: 16, padding: '6px 10px', borderRadius: 8,
                     border: '1px solid rgba(255,255,255,.16)', background: 'rgba(0,0,0,.30)', color: 'inherit' }}>
            {!choix.some((c) => c.library_id === libraryId) && (
              <option value={libraryId}>{t({ id: 'capas.pdf.bibCourante' })}</option>
            )}
            {choix.map((c) => (
              <option key={c.library_id} value={c.library_id}>{t({ id: 'capas.pdf.option' }, { nom: c.nom, n: Number(c.faisables) })}</option>
            ))}
          </select>
        </label>
      )}
      <p className="ab-painel-hint">{t({ id: 'capas.pdf.intro' }, { n: faisables })}</p>
      {deja > 0 && <p className="ab-painel-hint">{t({ id: 'capas.pdf.deja' }, { n: deja })}</p>}
      {restreintes > 0 && <p className="ab-painel-hint" data-capas-pdf-restreintes>{t({ id: 'capas.pdf.restreintes' }, { n: restreintes })}</p>}

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        {enCours ? (
          <Button variant="secondary" onClick={() => { arret.current = true; }}>{t({ id: 'capas.pdf.arreter' })}</Button>
        ) : (
          <Button onClick={lancer} disabled={!faisables}>{t({ id: 'capas.pdf.lancer' }, { n: faisables })}</Button>
        )}
        {enCours && <Spinner />}
      </div>

      {bilan && (
        <p className="ab-painel-hint" role="status" aria-live="polite" data-capas-pdf-bilan>
          {t({ id: 'capas.pdf.progression' }, { posees: bilan.posees, echecs: bilan.echecs.length })}
          {courante ? <span style={{ display: 'block', wordBreak: 'break-word' }}>{t({ id: 'capas.pdf.courante' }, { titre: courante })}</span> : null}
        </p>
      )}
      {msg.text && <p className="ab-painel-msg" role="status" aria-live="polite" style={{ color: couleur }}>{msg.text}</p>}

      {!enCours && bilan?.echecs.length > 0 && (
        <details style={{ marginTop: 6 }}>
          <summary className="ab-painel-hint" style={{ cursor: 'pointer' }}>{t({ id: 'capas.pdf.echecs' }, { n: bilan.echecs.length })}</summary>
          <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: '.82rem' }}>
            {bilan.echecs.map((e) => <li key={e.book_id} style={{ wordBreak: 'break-word' }}>{e.titre}</li>)}
          </ul>
        </details>
      )}
    </section>
  );
}
