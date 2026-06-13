import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';

// Atelier autorités — paquet 2, lot A : la file de propositions (vue 1re page).
// Lecture via api.fn_authority_list ; actions via fn_authority_propose / apply /
// withdraw. i18n en defaultMessage inline (pt-BR) — extraction 10 locales = suivi.
// Objection (besoin du contexte biblio utilisatrice) = itération suivante.

const STATUS = {
  open:              { color: '#60a5fa', label: 'Aberta' },
  contested:         { color: '#fbbf24', label: 'Contestada' },
  resolved_consent:  { color: '#4ade80', label: 'Consenso — pronta para aplicar' },
  applied:           { color: '#a3a3a3', label: 'Aplicada' },
  refused:           { color: '#f87171', label: 'Recusada' },
  withdrawn:         { color: '#a3a3a3', label: 'Retirada' },
};
const KIND = { creation: 'Criação', edition: 'Edição', fusion: 'Fusão', traduction: 'Tradução' };

export default function AtelierAutoridadesPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'atelier.page.title', defaultMessage: 'Oficina de autoridades' }));

  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [busyId, setBusyId] = useState(null);

  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ kind: 'fusion', targetKind: 'author', targetId: '', mergeIntoId: '', dupName: '', canName: '', authorName: '', lang: 'pt-BR', biography: '', rationale: '' });
  const [submitting, setSubmitting] = useState(false);

  const [myLibs, setMyLibs] = useState([]);
  const [objectingId, setObjectingId] = useState(null);
  const [objForm, setObjForm] = useState({ libraryId: '', reason: '' });

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.schema('api').rpc('fn_authority_list');
    if (error) {
      setMsg({ text: localizeError(error, t), kind: 'error' });
      setRows([]);
    } else {
      setRows(Array.isArray(data) ? data : []);
    }
    setLoading(false);
  }, [t]);

  useEffect(() => { load(); }, [load]);

  // Mes bibliothèques où je suis staff (pour objecter au nom d'une biblio utilisatrice).
  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('user_library_memberships')
        .select('library_id, role, libraries(name, short_name)')
        .eq('user_id', user.id).eq('status', 'active').in('role', ['librarian', 'coordenador']);
      if (!cancelled) setMyLibs(Array.isArray(data) ? data : []);
    })();
    return () => { cancelled = true; };
  }, [user]);

  async function propose(e) {
    e.preventDefault();
    setMsg({ text: '', kind: '' });
    if (form.rationale.trim().length < 10) {
      setMsg({ text: t({ id: 'atelier.form.error.rationale', defaultMessage: 'Explique brevemente o motivo da proposta.' }), kind: 'error' }); return;
    }
    let args;
    if (form.kind === 'traduction') {
      const aid = parseInt(form.targetId, 10);
      if (!Number.isInteger(aid)) {
        setMsg({ text: t({ id: 'atelier.form.error.authorId', defaultMessage: 'Informe o ID da autoridade (pessoa).' }), kind: 'error' }); return;
      }
      if (!form.authorName.trim()) {
        setMsg({ text: t({ id: 'atelier.form.error.names', defaultMessage: 'Informe o nome da autoridade.' }), kind: 'error' }); return;
      }
      if (form.biography.trim().length < 10) {
        setMsg({ text: t({ id: 'atelier.form.error.bio', defaultMessage: 'Escreva a biografia traduzida.' }), kind: 'error' }); return;
      }
      args = { p_kind: 'traduction', p_target_kind: 'author', p_target_id: aid, p_merge_into_id: null, p_payload: { lang: form.lang, biography: form.biography.trim(), author_name: form.authorName.trim() }, p_rationale: `« ${form.authorName.trim()} » (#${aid}, ${form.lang}). ${form.rationale.trim()}` };
    } else {
      const dup = parseInt(form.targetId, 10);
      const can = parseInt(form.mergeIntoId, 10);
      if (!Number.isInteger(dup) || !Number.isInteger(can)) {
        setMsg({ text: t({ id: 'atelier.form.error.ids', defaultMessage: 'Informe os dois identificadores (duplicata e canônica).' }), kind: 'error' }); return;
      }
      if (!form.dupName.trim() || !form.canName.trim()) {
        setMsg({ text: t({ id: 'atelier.form.error.names', defaultMessage: 'Informe o nome da autoridade.' }), kind: 'error' }); return;
      }
      args = { p_kind: 'fusion', p_target_kind: form.targetKind, p_target_id: dup, p_merge_into_id: can, p_payload: { duplicate_name: form.dupName.trim(), canonical_name: form.canName.trim() }, p_rationale: `« ${form.dupName.trim()} » (#${dup}) → « ${form.canName.trim()} » (#${can}). ${form.rationale.trim()}` };
    }
    setSubmitting(true);
    const { error } = await supabase.schema('api').rpc('fn_authority_propose', args);
    setSubmitting(false);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    setMsg({ text: t({ id: 'atelier.form.success', defaultMessage: 'Proposta registrada. A discussão fica aberta até o prazo.' }), kind: 'ok' });
    setForm({ kind: 'fusion', targetKind: 'author', targetId: '', mergeIntoId: '', dupName: '', canName: '', authorName: '', lang: 'pt-BR', biography: '', rationale: '' });
    setShowForm(false);
    load();
  }

  async function act(rpcName, args, id) {
    setBusyId(id); setMsg({ text: '', kind: '' });
    const { error } = await supabase.schema('api').rpc(rpcName, args);
    setBusyId(null);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    load();
  }

  async function objecter(proposalId) {
    if (!objForm.libraryId) {
      setMsg({ text: t({ id: 'atelier.obj.error.lib', defaultMessage: 'Selecione a biblioteca que objeta.' }), kind: 'error' }); return;
    }
    if (objForm.reason.trim().length < 20) {
      setMsg({ text: t({ id: 'atelier.obj.error.reason', defaultMessage: 'A objeção precisa de uma motivação (mín. 20 caracteres).' }), kind: 'error' }); return;
    }
    setBusyId(proposalId); setMsg({ text: '', kind: '' });
    const { data, error } = await supabase.schema('api').rpc('fn_authority_object', {
      p_proposal_id: proposalId, p_library_id: objForm.libraryId, p_reason: objForm.reason.trim(),
    });
    setBusyId(null);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    setMsg({
      text: data === 'refused'
        ? t({ id: 'atelier.obj.refused', defaultMessage: 'Objeção registrada — a proposta foi recusada (2+ bibliotecas usuárias).' })
        : t({ id: 'atelier.obj.contested', defaultMessage: 'Objeção registrada — a discussão está aberta.' }),
      kind: 'ok',
    });
    setObjectingId(null); setObjForm({ libraryId: '', reason: '' });
    load();
  }

  const card = { padding: 14, borderRadius: 10, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(255,255,255,.03)', marginBottom: 10 };
  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
          {t({ id: 'atelier.page.title', defaultMessage: 'Oficina de autoridades' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 16, fontSize: '.9rem', lineHeight: 1.6 }}>
          {t({ id: 'atelier.page.subtitle', defaultMessage: 'A fila de propostas de contribuição ao corpus compartilhado de autoridades (pessoas, coletividades, matérias). As decisões se dão por consentimento: sem objeção motivada até o prazo, a proposta é aplicada por um membro da equipe.' })}
        </p>

        <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
          <Button variant="primary" onClick={() => setShowForm(s => !s)}>
            {showForm
              ? t({ id: 'atelier.action.closeForm', defaultMessage: 'Fechar' })
              : t({ id: 'atelier.action.newProposal', defaultMessage: 'Fazer uma proposta' })}
          </Button>
          <Button variant="secondary" onClick={load} disabled={loading}>
            {t({ id: 'atelier.action.refresh', defaultMessage: 'Atualizar' })}
          </Button>
        </div>

        {msg.text && (
          <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14,
            background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
            color: msg.kind === 'ok' ? '#4ade80' : '#f87171',
            border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}` }}>
            {msg.text}
          </div>
        )}

        {showForm && (
          <form onSubmit={propose} style={{ ...card, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.2)', padding: 16, marginBottom: 18 }}>
            <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 10, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
              {t({ id: 'atelier.form.newTitle', defaultMessage: 'Nova proposta' })}
            </h2>
            <div style={{ marginBottom: 10 }}>
              <label style={ls}>{t({ id: 'atelier.form.kind', defaultMessage: 'Tipo de proposta' })}</label>
              <select value={form.kind} onChange={e => setForm(f => ({ ...f, kind: e.target.value }))} style={fs}>
                <option value="fusion">{t({ id: 'atelier.kindProp.fusion', defaultMessage: 'Fusão de duplicata' })}</option>
                <option value="traduction">{t({ id: 'atelier.kindProp.traduction', defaultMessage: 'Tradução de biografia (pessoa)' })}</option>
              </select>
            </div>

            {form.kind === 'fusion' && (<>
            <div style={{ marginBottom: 10 }}>
              <label style={ls}>{t({ id: 'atelier.form.targetKind', defaultMessage: 'Tipo de autoridade' })}</label>
              <select value={form.targetKind} onChange={e => setForm(f => ({ ...f, targetKind: e.target.value }))} style={fs}>
                <option value="author">{t({ id: 'atelier.kind.author', defaultMessage: 'Pessoa / coletividade (author)' })}</option>
                <option value="subject">{t({ id: 'atelier.kind.subject', defaultMessage: 'Matéria (subject)' })}</option>
              </select>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '90px 1fr', gap: 10, marginBottom: 10, alignItems: 'end' }}>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.duplicate', defaultMessage: 'ID da duplicata (a remover)' })}</label>
                <input type="number" value={form.targetId} onChange={e => setForm(f => ({ ...f, targetId: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.nameDup', defaultMessage: 'Nome da duplicata' })}</label>
                <input type="text" value={form.dupName} onChange={e => setForm(f => ({ ...f, dupName: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.canonical', defaultMessage: 'ID da canônica (a manter)' })}</label>
                <input type="number" value={form.mergeIntoId} onChange={e => setForm(f => ({ ...f, mergeIntoId: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.nameCan', defaultMessage: 'Nome da canônica' })}</label>
                <input type="text" value={form.canName} onChange={e => setForm(f => ({ ...f, canName: e.target.value }))} style={fs} />
              </div>
            </div>
            </>)}

            {form.kind === 'traduction' && (<>
            <div style={{ display: 'grid', gridTemplateColumns: '88px 1fr 104px', gap: 10, marginBottom: 10, alignItems: 'end' }}>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.authorId', defaultMessage: 'ID da autoridade (pessoa)' })}</label>
                <input type="number" value={form.targetId} onChange={e => setForm(f => ({ ...f, targetId: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.nameAuthor', defaultMessage: 'Nome da autoridade (pessoa/coletivo)' })}</label>
                <input type="text" value={form.authorName} onChange={e => setForm(f => ({ ...f, authorName: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.lang', defaultMessage: 'Idioma' })}</label>
                <select value={form.lang} onChange={e => setForm(f => ({ ...f, lang: e.target.value }))} style={fs}>
                  {['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'].map(L => <option key={L} value={L}>{L}</option>)}
                </select>
              </div>
            </div>
            <div style={{ marginBottom: 10 }}>
              <label style={ls}>{t({ id: 'atelier.form.bio', defaultMessage: 'Biografia traduzida' })}</label>
              <textarea value={form.biography} onChange={e => setForm(f => ({ ...f, biography: e.target.value }))} style={{ ...fs, resize: 'vertical', minHeight: 90 }} />
            </div>
            </>)}
            <div style={{ marginBottom: 12 }}>
              <label style={ls}>{t({ id: 'atelier.form.rationale', defaultMessage: 'Motivo' })}</label>
              <textarea value={form.rationale} onChange={e => setForm(f => ({ ...f, rationale: e.target.value }))} style={{ ...fs, resize: 'vertical', minHeight: 64 }} />
            </div>
            <Button variant="primary" type="submit" disabled={submitting}>
              {submitting ? t({ id: 'atelier.form.sending', defaultMessage: 'Enviando…' }) : t({ id: 'atelier.form.submit', defaultMessage: 'Registrar proposta' })}
            </Button>
          </form>
        )}

        {loading ? (
          <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem' }}>{t({ id: 'common.loading', defaultMessage: 'Carregando…' })}</p>
        ) : rows.length === 0 ? (
          <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem' }}>{t({ id: 'atelier.empty', defaultMessage: 'Nenhuma proposta no momento.' })}</p>
        ) : (
          rows.map(r => {
            const st = STATUS[r.status] || { color: '#a3a3a3', label: r.status };
            const mine = user && r.proposed_by === user.id;
            return (
              <div key={r.id} style={card}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap', alignItems: 'baseline' }}>
                  <div style={{ fontSize: '.92rem', fontWeight: 700 }}>
                    {KIND[r.kind] || r.kind}
                    {r.target_label ? ` · ${r.target_label}` : ''}
                    {r.merge_into_label ? ` → ${r.merge_into_label}` : ''}
                  </div>
                  <span style={{ fontSize: '.74rem', fontWeight: 700, color: st.color, border: `1px solid ${st.color}55`, borderRadius: 20, padding: '2px 10px' }}>
                    {st.label}
                  </span>
                </div>
                {r.rationale && <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', margin: '6px 0', lineHeight: 1.5 }}>{r.rationale}</p>}
                <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #999)', display: 'flex', gap: 14, flexWrap: 'wrap' }}>
                  {r.proposer_name && <span>{t({ id: 'atelier.row.by', defaultMessage: 'por {name}' }, { name: r.proposer_name })}</span>}
                  <span>{t({ id: 'atelier.row.deadline', defaultMessage: 'prazo: {date}' }, { date: new Date(r.deadline).toLocaleDateString() })}</span>
                  {r.objection_count > 0 && <span style={{ color: '#fbbf24' }}>{t({ id: 'atelier.row.objections', defaultMessage: '{n} objeção(ões)' }, { n: r.objection_count })}</span>}
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
                  {r.status === 'resolved_consent' && (
                    <Button variant="primary" disabled={busyId === r.id}
                      onClick={() => act('fn_authority_apply', { p_proposal_id: r.id }, r.id)}>
                      {t({ id: 'atelier.action.apply', defaultMessage: 'Aplicar' })}
                    </Button>
                  )}
                  {mine && (r.status === 'open' || r.status === 'contested') && (
                    <Button variant="secondary" disabled={busyId === r.id}
                      onClick={() => act('fn_authority_withdraw', { p_proposal_id: r.id }, r.id)}>
                      {t({ id: 'atelier.action.withdraw', defaultMessage: 'Retirar' })}
                    </Button>
                  )}
                  {myLibs.length > 0 && (r.status === 'open' || r.status === 'contested') && (
                    <Button variant="secondary" disabled={busyId === r.id}
                      onClick={() => { setObjectingId(objectingId === r.id ? null : r.id); setObjForm({ libraryId: myLibs.length === 1 ? myLibs[0].library_id : '', reason: '' }); setMsg({ text: '', kind: '' }); }}>
                      {t({ id: 'atelier.action.object', defaultMessage: 'Objetar' })}
                    </Button>
                  )}
                </div>
                {objectingId === r.id && (
                  <div style={{ marginTop: 10, padding: 12, borderRadius: 8, background: 'rgba(251,191,36,.06)', border: '1px solid rgba(251,191,36,.25)' }}>
                    <label style={ls}>{t({ id: 'atelier.obj.library', defaultMessage: 'Biblioteca que objeta' })}</label>
                    <select value={objForm.libraryId} onChange={e => setObjForm(f => ({ ...f, libraryId: e.target.value }))} style={{ ...fs, marginBottom: 8 }}>
                      <option value="">{t({ id: 'atelier.obj.libraryPh', defaultMessage: 'Escolha…' })}</option>
                      {myLibs.map(m => <option key={m.library_id} value={m.library_id}>{m.libraries?.short_name || m.libraries?.name || m.library_id}</option>)}
                    </select>
                    <label style={ls}>{t({ id: 'atelier.obj.reason', defaultMessage: 'Motivação (mín. 20 caracteres)' })}</label>
                    <textarea value={objForm.reason} onChange={e => setObjForm(f => ({ ...f, reason: e.target.value }))} style={{ ...fs, resize: 'vertical', minHeight: 56, marginBottom: 8 }} />
                    <Button variant="primary" disabled={busyId === r.id} onClick={() => objecter(r.id)}>
                      {t({ id: 'atelier.obj.submit', defaultMessage: 'Registrar objeção' })}
                    </Button>
                  </div>
                )}
              </div>
            );
          })
        )}

        <div style={{ marginTop: 20 }}>
          <Button variant="secondary" onClick={() => navigate(-1)}>{t({ id: 'common.back', defaultMessage: 'Voltar' })}</Button>
        </div>
      </div>
    <Footer /></PageShell>
  );
}
