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
  const [form, setForm] = useState({ targetKind: 'author', targetId: '', mergeIntoId: '', rationale: '' });
  const [submitting, setSubmitting] = useState(false);

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

  async function propose(e) {
    e.preventDefault();
    setMsg({ text: '', kind: '' });
    const dup = parseInt(form.targetId, 10);
    const can = parseInt(form.mergeIntoId, 10);
    if (!Number.isInteger(dup) || !Number.isInteger(can)) {
      setMsg({ text: t({ id: 'atelier.form.error.ids', defaultMessage: 'Informe os dois identificadores (duplicata e canônica).' }), kind: 'error' }); return;
    }
    if (form.rationale.trim().length < 10) {
      setMsg({ text: t({ id: 'atelier.form.error.rationale', defaultMessage: 'Explique brevemente o motivo da proposta.' }), kind: 'error' }); return;
    }
    setSubmitting(true);
    const { error } = await supabase.schema('api').rpc('fn_authority_propose', {
      p_kind: 'fusion',
      p_target_kind: form.targetKind,
      p_target_id: dup,
      p_merge_into_id: can,
      p_payload: {},
      p_rationale: form.rationale.trim(),
    });
    setSubmitting(false);
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); return; }
    setMsg({ text: t({ id: 'atelier.form.success', defaultMessage: 'Proposta registrada. A discussão fica aberta até o prazo.' }), kind: 'ok' });
    setForm({ targetKind: 'author', targetId: '', mergeIntoId: '', rationale: '' });
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
              : t({ id: 'atelier.action.newFusion', defaultMessage: 'Propor uma fusão' })}
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
              {t({ id: 'atelier.form.title', defaultMessage: 'Propor a fusão de uma duplicata' })}
            </h2>
            <div style={{ marginBottom: 10 }}>
              <label style={ls}>{t({ id: 'atelier.form.targetKind', defaultMessage: 'Tipo de autoridade' })}</label>
              <select value={form.targetKind} onChange={e => setForm(f => ({ ...f, targetKind: e.target.value }))} style={fs}>
                <option value="author">{t({ id: 'atelier.kind.author', defaultMessage: 'Pessoa / coletividade (author)' })}</option>
                <option value="subject">{t({ id: 'atelier.kind.subject', defaultMessage: 'Matéria (subject)' })}</option>
              </select>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 10 }}>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.duplicate', defaultMessage: 'ID da duplicata (a remover)' })}</label>
                <input type="number" value={form.targetId} onChange={e => setForm(f => ({ ...f, targetId: e.target.value }))} style={fs} />
              </div>
              <div>
                <label style={ls}>{t({ id: 'atelier.form.canonical', defaultMessage: 'ID da canônica (a manter)' })}</label>
                <input type="number" value={form.mergeIntoId} onChange={e => setForm(f => ({ ...f, mergeIntoId: e.target.value }))} style={fs} />
              </div>
            </div>
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
                </div>
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
