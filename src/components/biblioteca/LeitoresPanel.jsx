import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * LeitoresPanel — liste des lectrices et lecteurs d'une bibliothèque.
 *
 * Affiche les membres ayant role='reader' et status='active' pour la biblio
 * courante. Permet aux coordenadores et administradores de promouvoir un
 * lecteur au rôle de bibliothécaire via la RPC fn_team_promote_to_librarian
 * (déclenche l'event team.promoted_to_librarian et son mail militant).
 *
 * Pourquoi un composant dédié plutôt que d'étendre TeamPanel :
 *   - TeamPanel a pour vocation politique de montrer "qui engage la biblio".
 *     Les lectrices et lecteurs ne sont pas l'équipe.
 *   - La promotion lecteur → bibliothécaire est une action de prise de
 *     responsabilité ; elle mérite son propre espace, distinct du panneau
 *     équipe où les rétrogradations et exclusions seront gérées.
 */
export default function LeitoresPanel({ libraryId }) {
  const { formatMessage: t, locale } = useIntl();
  const { role } = useLibrary();
  const canPromote = role === 'coordenador' || role === 'administrador';

  const [readers, setReaders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [busyUserId, setBusyUserId] = useState(null);

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('user_library_memberships')
        .select('user_id, role, status, is_primary, created_at, profiles:user_id(email, first_name, last_name, preferred_language)')
        .eq('library_id', libraryId)
        .eq('role', 'reader')
        .eq('status', 'active')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setReaders(data || []);
    } catch (err) {
      console.warn('LeitoresPanel load:', err);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  async function promoteToLibrarian(reader) {
    const name = `${reader.profiles?.first_name||''} ${reader.profiles?.last_name||''}`.trim() || reader.profiles?.email || '—';
    const confirmMsg = t({ id: 'biblioteca.leitores.promoteConfirm' }, { name });
    if (!window.confirm(confirmMsg)) return;
    setBusyUserId(reader.user_id);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('fn_team_promote_to_librarian', {
        p_user_id: reader.user_id,
        p_library_id: libraryId,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.leitores.promoteSuccess' }, { name }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setBusyUserId(null);
    }
  }

  const filtered = useMemo(() => {
    if (!search.trim()) return readers;
    const q = search.trim().toLowerCase();
    return readers.filter(r => {
      const p = r.profiles || {};
      return (
        (p.email||'').toLowerCase().includes(q) ||
        (p.first_name||'').toLowerCase().includes(q) ||
        (p.last_name||'').toLowerCase().includes(q)
      );
    });
  }, [readers, search]);

  // Styles cohérents avec le reste de BibliotecaPage / RedePage
  const fs = { width:'100%', padding:'8px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
  const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12, flexWrap:'wrap', gap:8 }}>
        <h3 style={{ margin:0 }}>
          {t({ id: 'biblioteca.leitores.title' })} ({readers.length})
        </h3>
        <div style={{ display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder={t({ id: 'biblioteca.leitores.searchPlaceholder' })}
            style={{ ...fs, width:240 }}
          />
          <button className="cat-btn secondary" onClick={load} disabled={loading}>
            {loading ? t({ id: 'rede.refreshing' }) : t({ id: 'rede.refresh' })}
          </button>
        </div>
      </div>

      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>
        {t({ id: 'biblioteca.leitores.hint' })}
      </div>

      {msg.text && (
        <div style={{ padding:'10px 14px', borderRadius:8, fontSize:'.9rem', marginBottom:14,
          background: msg.kind==='ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind==='ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {filtered.length === 0 ? (
        <div style={{ padding:24, textAlign:'center', color:'var(--brand-muted)', fontSize:'.9rem', ...lw }}>
          {loading
            ? t({ id: 'common.loading' })
            : search
              ? t({ id: 'biblioteca.leitores.emptySearch' })
              : t({ id: 'biblioteca.leitores.empty' })}
        </div>
      ) : (
        <div style={lw}>
          <div style={{ display:'grid', gridTemplateColumns:'2fr 2.5fr 1fr 1.2fr', gap:0, padding:'8px 12px', fontSize:'.75rem', fontWeight:700, color:'var(--brand-muted)', borderBottom:'1px solid rgba(255,255,255,.08)' }}>
            <div>{t({ id: 'biblioteca.leitores.name' })}</div>
            <div>{t({ id: 'biblioteca.leitores.email' })}</div>
            <div style={{ textAlign:'center' }}>{t({ id: 'biblioteca.leitores.since' })}</div>
            <div style={{ textAlign:'center' }}>{t({ id: 'common.actions' })}</div>
          </div>
          {filtered.map((r, i) => {
            const p = r.profiles || {};
            const fullName = `${p.first_name||''} ${p.last_name||''}`.trim() || '—';
            const isBusy = busyUserId === r.user_id;
            return (
              <div key={r.user_id} style={{ display:'grid', gridTemplateColumns:'2fr 2.5fr 1fr 1.2fr', gap:0, padding:'10px 12px', background: i%2===0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', alignItems:'center' }}>
                <div style={{ fontSize:'.9rem', fontWeight:600 }}>{fullName}</div>
                <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{p.email || '—'}</div>
                <div style={{ textAlign:'center', fontSize:'.82rem', color:'var(--brand-muted)' }}>
                  {r.created_at ? new Date(r.created_at).toLocaleDateString(locale) : '—'}
                </div>
                <div style={{ textAlign:'center' }}>
                  {canPromote ? (
                    <button
                      className="cat-btn primary"
                      style={{ fontSize:'.78rem', padding:'4px 10px' }}
                      onClick={() => promoteToLibrarian(r)}
                      disabled={isBusy}
                    >
                      {isBusy
                        ? t({ id: 'common.loading' })
                        : t({ id: 'biblioteca.leitores.promote' })}
                    </button>
                  ) : (
                    <span style={{ fontSize:'.75rem', color:'var(--brand-muted)' }}>—</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
