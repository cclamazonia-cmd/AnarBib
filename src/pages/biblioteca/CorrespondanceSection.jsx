// src/pages/biblioteca/CorrespondanceSection.jsx — G19 lot 2 (08/10/2026)
//
// L'onglet « Correspondance » de la page Bibliothèque : les fils entre
// bibliothèques, écrits par leurs coordinations (REGISTRE CORR-1 à CORR-6).
// La section charge ses propres données (quatre lectures sous RLS : mes
// participations, les autres participantes, les messages, mes lectures) et
// n'écrit que par les RPC du schéma api (ouvrir, envoyer, archiver, lue).
// Rien n'est supprimé : un fil s'archive, pour ma bibliothèque seulement, et
// un message nouveau le rend à toutes. Les noms affichés sont ceux des
// bibliothèques, jamais ceux des personnes.
import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { fs, ls, bx, lr, lw } from './styles';

// Les dix locales, nommées dans leur langue : ce ne sont pas des chaînes à traduire.
export const LANGUES = [
  ['pt-BR', 'Português (Brasil)'], ['fr', 'Français'], ['es', 'Español'], ['en', 'English'], ['it', 'Italiano'],
  ['de', 'Deutsch'], ['el', 'Ελληνικά'], ['ca', 'Català'], ['eo', 'Esperanto'], ['nl', 'Nederlands'],
];
const CODES = LANGUES.map(([c]) => c);
// Le nom d'une langue dans la langue de l'écran (Intl), repli sur l'endonyme.
function nomLangue(code, locale) {
  try { const n = new Intl.DisplayNames([locale], { type: 'language' }).of(code); if (n && n !== code) return n; } catch { /* repli */ }
  return (LANGUES.find(([c]) => c === code) || [code, code])[1];
}

export default function CorrespondanceSection({ libraryId, allLibraries = [], setMsg }) {
  const { formatMessage: t, locale } = useIntl();
  const langueParDefaut = CODES.includes(locale) ? locale : 'pt-BR';
  const [fils, setFils] = useState([]);           // { id, subject, last_message_at, archived_at, autres: [libraryId], dernier, nonLus }
  const [messages, setMessages] = useState({});   // conversation_id -> [messages]
  const [chargement, setChargement] = useState(true);
  const [filtre, setFiltre] = useState('actifs'); // 'actifs' | 'archives'
  const [ouvert, setOuvert] = useState(null);     // conversation_id
  const [ecrire, setEcrire] = useState(false);
  const [brouillon, setBrouillon] = useState({ dest: '', sujet: '', corps: '', lang: langueParDefaut });
  const [reponse, setReponse] = useState({ corps: '', lang: langueParDefaut });
  const [occupe, setOccupe] = useState(false);
  const [localeDe, setLocaleDe] = useState({});   // library_id -> default_locale (la langue de la bibliothèque, lot 4 affinera)

  const nomBiblio = useCallback((id) => {
    const l = allLibraries.find((x) => x.id === id);
    return l ? (l.short_name || l.name) : t({ id: 'biblioteca.correspondance.unknownLibrary' });
  }, [allLibraries, t]);

  const charger = useCallback(async () => {
    if (!libraryId) return;
    setChargement(true);
    try {
      const { data: part, error: e1 } = await supabase.from('library_conversation_participants')
        .select('conversation_id, archived_at, library_conversations!inner(id, subject, last_message_at, created_at)')
        .eq('library_id', libraryId).order('conversation_id', { ascending: false }).limit(200);
      if (e1) throw e1;
      const ids = (part || []).map((p) => p.conversation_id);
      const { data: locs } = await supabase.from('libraries').select('id, default_locale');
      setLocaleDe(Object.fromEntries((locs || []).map((l) => [l.id, l.default_locale])));
      let autres = [], msgs = [], lus = [];
      if (ids.length) {
        const [a, m, r] = await Promise.all([
          supabase.from('library_conversation_participants').select('conversation_id, library_id').in('conversation_id', ids),
          supabase.from('library_messages').select('id, conversation_id, library_id, body, lang, created_at').in('conversation_id', ids).order('id', { ascending: true }),
          supabase.from('library_conversation_reads').select('conversation_id, last_read_message_id').in('conversation_id', ids),
        ]);
        if (a.error) throw a.error; if (m.error) throw m.error; if (r.error) throw r.error;
        autres = a.data || []; msgs = m.data || []; lus = r.data || [];
      }
      const parFil = {};
      for (const x of msgs) (parFil[x.conversation_id] ||= []).push(x);
      const luJusque = Object.fromEntries(lus.map((x) => [x.conversation_id, x.last_read_message_id]));
      const liste = (part || []).map((p) => {
        const c = p.library_conversations;
        const mm = parFil[p.conversation_id] || [];
        const dernierLu = luJusque[p.conversation_id] || 0;
        return {
          id: p.conversation_id, subject: c?.subject, last_message_at: c?.last_message_at, archived_at: p.archived_at,
          autres: autres.filter((x) => x.conversation_id === p.conversation_id && x.library_id !== libraryId).map((x) => x.library_id),
          dernier: mm[mm.length - 1] || null,
          nonLus: mm.filter((x) => x.id > dernierLu).length,
        };
      }).sort((x, y) => String(y.last_message_at).localeCompare(String(x.last_message_at)));
      setFils(liste); setMessages(parFil);
    } catch (err) {
      setMsg?.({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setChargement(false);
    }
  }, [libraryId, t, setMsg]);

  useEffect(() => { charger(); }, [charger]);

  const marquerLu = useCallback(async (id) => {
    const { error } = await supabase.schema('api').rpc('fn_correspondance_lue', { p_conversation_id: id });
    if (!error) setFils((f) => f.map((x) => (x.id === id ? { ...x, nonLus: 0 } : x)));
  }, []);

  function ouvrir(id) { setOuvert(id); setEcrire(false); setReponse({ corps: '', lang: langueParDefaut }); marquerLu(id); }

  async function envoyerNouveau(e) {
    e.preventDefault();
    setOccupe(true);
    try {
      const { data, error } = await supabase.schema('api').rpc('fn_correspondance_ouvrir', {
        p_library_id: libraryId, p_destinataire_id: brouillon.dest, p_sujet: brouillon.sujet, p_corps: brouillon.corps, p_lang: brouillon.lang,
      });
      if (error) throw error;
      setMsg?.({ text: t({ id: 'biblioteca.correspondance.sent' }), kind: 'ok' });
      setBrouillon({ dest: '', sujet: '', corps: '', lang: langueParDefaut }); setEcrire(false);
      await charger(); setOuvert(data);
    } catch (err) {
      setMsg?.({ text: localizeError(err, t), kind: 'error' });
    } finally { setOccupe(false); }
  }

  async function repondre(e) {
    e.preventDefault();
    setOccupe(true);
    try {
      const { error } = await supabase.schema('api').rpc('fn_correspondance_envoyer', {
        p_conversation_id: ouvert, p_library_id: libraryId, p_corps: reponse.corps, p_lang: reponse.lang,
      });
      if (error) throw error;
      setMsg?.({ text: t({ id: 'biblioteca.correspondance.sent' }), kind: 'ok' });
      setReponse({ corps: '', lang: reponse.lang });
      await charger();
    } catch (err) {
      setMsg?.({ text: localizeError(err, t), kind: 'error' });
    } finally { setOccupe(false); }
  }

  async function archiver(id, archive) {
    setOccupe(true);
    try {
      const { error } = await supabase.schema('api').rpc('fn_correspondance_archiver', { p_conversation_id: id, p_library_id: libraryId, p_archiver: archive });
      if (error) throw error;
      setMsg?.({ text: t({ id: archive ? 'biblioteca.correspondance.archived' : 'biblioteca.correspondance.unarchived' }), kind: 'ok' });
      await charger(); if (archive) setOuvert(null);
    } catch (err) {
      setMsg?.({ text: localizeError(err, t), kind: 'error' });
    } finally { setOccupe(false); }
  }

  const visibles = useMemo(() => fils.filter((f) => (filtre === 'archives' ? !!f.archived_at : !f.archived_at)), [fils, filtre]);
  // Les autres bibliothèques actives qui participent au réseau (une bibliothèque « isolée » ne correspond pas).
  const destinataires = useMemo(() => allLibraries.filter((l) => l.id !== libraryId && l.is_active !== false && l.network_mode !== 'isolated'), [allLibraries, libraryId]);
  const fil = ouvert ? fils.find((f) => f.id === ouvert) : null;
  const date = (d) => (d ? new Date(d).toLocaleString(locale, { dateStyle: 'medium', timeStyle: 'short' }) : '');
  const selectLangue = (val, onChange) => (
    <select value={val} onChange={(e) => onChange(e.target.value)} style={{ ...fs, width: 'auto' }} aria-label={t({ id: 'biblioteca.correspondance.lang' })}>
      {LANGUES.map(([c]) => <option key={c} value={c}>{nomLangue(c, locale)}</option>)}
    </select>
  );

  // ── Un fil ouvert ──
  if (fil) {
    const mm = messages[fil.id] || [];
    return (
      <div className="ab-correspondance">
        <button type="button" className="cat-btn secondary" onClick={() => setOuvert(null)} style={{ marginBottom: 10 }}>← {t({ id: 'biblioteca.correspondance.back' })}</button>
        <div style={bx}>
          <h3 style={{ margin: '0 0 4px' }}>{fil.subject}</h3>
          <div style={{ fontSize: '.85rem', opacity: .8 }}>
            {t({ id: 'biblioteca.correspondance.participants' })} : {[nomBiblio(libraryId), ...fil.autres.map(nomBiblio)].join(' · ')}
          </div>
          <div style={{ marginTop: 8 }}>
            {fil.archived_at
              ? <button type="button" className="cat-btn secondary" disabled={occupe} onClick={() => archiver(fil.id, false)}>{t({ id: 'biblioteca.correspondance.unarchive' })}</button>
              : <button type="button" className="cat-btn secondary" disabled={occupe} onClick={() => archiver(fil.id, true)}>{t({ id: 'biblioteca.correspondance.archive' })}</button>}
          </div>
        </div>
        <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 16px', ...lw }}>
          {mm.map((m, i) => (
            <li key={m.id} style={{ ...lr(i), display: 'block' }}>
              <div style={{ fontSize: '.8rem', opacity: .75, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <strong>{nomBiblio(m.library_id)}</strong>
                <span>{date(m.created_at)}</span>
                <span className="ab-correspondance__lang" title={t({ id: 'biblioteca.correspondance.writtenIn' }, { lang: nomLangue(m.lang, locale) })}>{m.lang}</span>
              </div>
              <div lang={m.lang} style={{ whiteSpace: 'pre-wrap', marginTop: 4 }}>{m.body}</div>
            </li>
          ))}
        </ul>
        <form onSubmit={repondre} style={bx}>
          <label style={ls} htmlFor="corr-reponse">{t({ id: 'biblioteca.correspondance.reply' })}</label>
          <textarea id="corr-reponse" value={reponse.corps} onChange={(e) => setReponse({ ...reponse, corps: e.target.value })} rows={4} maxLength={4000} required style={fs} />
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 8, flexWrap: 'wrap' }}>
            {selectLangue(reponse.lang, (v) => setReponse({ ...reponse, lang: v }))}
            <button type="submit" className="cat-btn" disabled={occupe || !reponse.corps.trim()}>{t({ id: 'biblioteca.correspondance.send' })}</button>
          </div>
        </form>
      </div>
    );
  }

  // ── La liste ──
  return (
    <div className="ab-correspondance">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
        <h3 style={{ margin: 0 }}>{t({ id: 'biblioteca.correspondance.title' })}</h3>
        <button type="button" className="cat-btn" onClick={() => setEcrire((v) => !v)}>{t({ id: 'biblioteca.correspondance.write' })}</button>
      </div>
      <p style={{ fontSize: '.9rem', opacity: .85 }}>{t({ id: 'biblioteca.correspondance.intro' })}</p>

      {ecrire && (
        <form onSubmit={envoyerNouveau} style={bx}>
          <div className="cat-field">
            <label style={ls} htmlFor="corr-dest">{t({ id: 'biblioteca.correspondance.to' })}</label>
            <select id="corr-dest" value={brouillon.dest} onChange={(e) => setBrouillon({ ...brouillon, dest: e.target.value })} required style={fs}>
              <option value="">—</option>
              {destinataires.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
            {brouillon.dest && localeDe[brouillon.dest] && (
              <div style={{ fontSize: '.85rem', opacity: .8, marginTop: 4 }}>{t({ id: 'biblioteca.correspondance.libraryLocale' }, { lang: nomLangue(localeDe[brouillon.dest], locale) })}</div>
            )}
          </div>
          <div className="cat-field">
            <label style={ls} htmlFor="corr-sujet">{t({ id: 'biblioteca.correspondance.subject' })}</label>
            <input id="corr-sujet" type="text" value={brouillon.sujet} onChange={(e) => setBrouillon({ ...brouillon, sujet: e.target.value })} maxLength={200} required style={fs} />
          </div>
          <div className="cat-field">
            <label style={ls} htmlFor="corr-corps">{t({ id: 'biblioteca.correspondance.body' })}</label>
            <textarea id="corr-corps" value={brouillon.corps} onChange={(e) => setBrouillon({ ...brouillon, corps: e.target.value })} rows={6} maxLength={4000} required style={fs} />
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            {selectLangue(brouillon.lang, (v) => setBrouillon({ ...brouillon, lang: v }))}
            <button type="submit" className="cat-btn" disabled={occupe}>{t({ id: 'biblioteca.correspondance.send' })}</button>
            <button type="button" className="cat-btn secondary" onClick={() => setEcrire(false)}>{t({ id: 'common.cancel' })}</button>
          </div>
        </form>
      )}

      <div role="tablist" style={{ display: 'flex', gap: 6, margin: '8px 0' }}>
        <button type="button" role="tab" aria-selected={filtre === 'actifs'} className={`cat-btn ${filtre === 'actifs' ? '' : 'secondary'}`} onClick={() => setFiltre('actifs')}>{t({ id: 'biblioteca.correspondance.filterActive' })}</button>
        <button type="button" role="tab" aria-selected={filtre === 'archives'} className={`cat-btn ${filtre === 'archives' ? '' : 'secondary'}`} onClick={() => setFiltre('archives')}>{t({ id: 'biblioteca.correspondance.filterArchived' })}</button>
      </div>

      {chargement ? <p>{t({ id: 'common.loading' })}</p> : visibles.length === 0 ? (
        <p style={{ opacity: .8 }}>{t({ id: filtre === 'archives' ? 'biblioteca.correspondance.emptyArchived' : 'biblioteca.correspondance.empty' })}</p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, ...lw }}>
          {visibles.map((f, i) => (
            <li key={f.id} style={{ ...lr(i), cursor: 'pointer' }} onClick={() => ouvrir(f.id)}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: f.nonLus > 0 ? 700 : 500 }}>
                  {f.subject}
                  {f.nonLus > 0 && <span className="ab-correspondance__nonlus" style={{ marginLeft: 8, fontSize: '.8rem' }}>{t({ id: 'biblioteca.correspondance.unread' }, { n: f.nonLus })}</span>}
                </div>
                <div style={{ fontSize: '.8rem', opacity: .75 }}>
                  {t({ id: 'biblioteca.correspondance.withLibraries' }, { libraries: f.autres.map(nomBiblio).join(', ') })}
                  {f.dernier && <> · {nomBiblio(f.dernier.library_id)} · {date(f.last_message_at)}</>}
                </div>
                {f.dernier && <div style={{ fontSize: '.85rem', opacity: .85, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.dernier.body}</div>}
              </div>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.8rem', padding: '4px 10px' }} onClick={(e) => { e.stopPropagation(); ouvrir(f.id); }}>{t({ id: 'biblioteca.correspondance.open' })}</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
