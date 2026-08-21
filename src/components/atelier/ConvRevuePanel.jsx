// ConvRevuePanel — file de vérification des conventions catalographiques.
// REGISTRE §37 `CONV`. Alimenté par public.catalog_review_queue via les RPC
// staff api.conv_revue_resume / _list / _decide (migration 09).
//
// POURQUOI CET ÉCRAN EXISTE. Les trois tables de revue nées du chantier du
// 20/08 étaient un plan de travail sans endroit où travailler : le registre
// les désignait comme celui de l'Atelier, et le seul accès réel était le SQL
// Editor. On ne demande pas à quelqu'un de trancher 294 cas de jugement
// documentaire dans un éditeur SQL.
//
// CE QU'IL NE FAIT PAS. Il n'écrit rien dans `books` ni `authors`. Il recueille
// des VERDICTS ; l'application aux données reste une migration (DOC-DEPLOY-1).
// Décider et écrire sont deux gestes, et la colonne `applique_le` les sépare.
//
// i18n : les 16 clés sont extraites dans les 10 locales. Le `defaultMessage`
// reste comme filet, pas comme dispense : un test de CI (« i18n coverage :
// code ↔ locales ») exige que toute clé STATIQUE citée par le code existe
// dans pt-BR et dans les neuf autres. L'en-tête de la page annonce encore une
// extraction différée — c'était vrai pour elle, ça ne l'est plus pour ici.

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { Button } from '@/components/ui';

// Libelles PAR CLE, jamais en dur : le test de couverture i18n ne voit que les
// appels `t({ id })`, donc une chaine litterale y echappe — c'est exactement
// ainsi que ces trois cartes sont restees en portugais dans une interface en
// francais, en production, sans que rien ne le signale.
const LOTS = [
  { id: 'autorite_patronyme', k: 'patronyme' },
  { id: 'autorite_casse',     k: 'casse' },
  { id: 'titre_casse',        k: 'titres' },
];

const ls = { display: 'block', fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginBottom: 4 };
const box = {
  border: '1px solid rgba(255,255,255,.10)', borderRadius: 10,
  padding: 12, marginBottom: 10, background: 'rgba(0,0,0,.15)',
};

export default function ConvRevuePanel() {
  const { formatMessage: t } = useIntl();

  const [resume, setResume] = useState([]);
  const [lot, setLot] = useState('autorite_patronyme');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [editing, setEditing] = useState(null);   // { id, valeur }

  const charger = useCallback(async () => {
    setLoading(true);
    const [r1, r2] = await Promise.all([
      supabase.schema('api').rpc('conv_revue_resume'),
      supabase.schema('api').rpc('conv_revue_list', { p_lot: lot, p_decision: 'a_revoir', p_max: 50 }),
    ]);
    if (r1.error || r2.error) {
      setMsg({ text: localizeError(t, r1.error || r2.error), kind: 'err' });
    } else {
      setResume(r1.data || []);
      setRows(r2.data || []);
    }
    setLoading(false);
  }, [lot, t]);

  useEffect(() => { charger(); }, [charger]);

  async function decider(id, decision, valeur) {
    setBusyId(id);
    setMsg({ text: '', kind: '' });
    const { error } = await supabase.schema('api').rpc('conv_revue_decide', {
      p_id: id, p_decision: decision, p_valeur: valeur ?? null, p_note: null,
    });
    setBusyId(null);
    if (error) { setMsg({ text: localizeError(t, error), kind: 'err' }); return; }
    // La ligne quitte la file « à revoir » : on la retire sans recharger la page.
    setRows(rs => rs.filter(r => r.id !== id));
    setResume(rs => rs.map(r => r.lot === lot ? { ...r, a_revoir: Number(r.a_revoir) - 1 } : r));
    setEditing(null);
  }

  const compteurs = Object.fromEntries(resume.map(r => [r.lot, r]));

  return (
    <section style={{ marginTop: 28 }}>
      <h2 style={{ fontSize: '1rem', margin: '0 0 4px' }}>
        {t({ id: 'atelier.revue.title', defaultMessage: 'Fila de verificação — convenções' })}
      </h2>
      <p style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)', margin: '0 0 12px', maxWidth: 720 }}>
        {t({ id: 'atelier.revue.intro', defaultMessage:
          'Cada linha é uma PROPOSTA, nunca uma decisão tomada. A ferramenta retira um artefato de importação ; ela não sabe se uma palavra é um nome próprio. Nada é escrito no catálogo aqui : os veredictos são aplicados depois, por migração.' })}
      </p>

      {/* Lots. minmax(0, …) sur chaque piste — MOB-1. */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(220px, 100%), 1fr))', gap: 8, marginBottom: 14 }}>
        {LOTS.map(L => {
          const c = compteurs[L.id] || {};
          const actif = lot === L.id;
          return (
            <button key={L.id} type="button" onClick={() => setLot(L.id)}
              style={{
                textAlign: 'left', cursor: 'pointer', padding: '10px 12px', borderRadius: 10,
                border: actif ? '1px solid var(--brand-accent, #60a5fa)' : '1px solid rgba(255,255,255,.10)',
                background: actif ? 'rgba(96,165,250,.10)' : 'rgba(0,0,0,.15)', color: 'inherit',
              }}>
              <div style={{ fontSize: '.86rem', fontWeight: 600 }}>
                {t({ id: `atelier.revue.lot.${L.k}` })}
              </div>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginTop: 2 }}>
                {t({ id: `atelier.revue.lot.${L.k}.hint` })}
              </div>
              <div style={{ fontSize: '.78rem', marginTop: 6 }}>
                <strong>{c.a_revoir ?? 0}</strong>{' '}
                {t({ id: 'atelier.revue.pending', defaultMessage: 'a revisar' })}
                {Number(c.applique ?? 0) > 0 && (
                  <span style={{ color: 'var(--brand-muted, #999)' }}>
                    {' · '}{c.applique} {t({ id: 'atelier.revue.applied', defaultMessage: 'aplicadas' })}
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>

      {msg.text && (
        <div style={{ marginBottom: 10, fontSize: '.8rem', color: msg.kind === 'err' ? '#f87171' : '#4ade80' }}>
          {msg.text}
        </div>
      )}

      {loading ? (
        <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'atelier.revue.loading', defaultMessage: 'Carregando…' })}
        </p>
      ) : rows.length === 0 ? (
        <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'atelier.revue.empty', defaultMessage: 'Nada a revisar neste lote.' })}
        </p>
      ) : rows.map(r => (
        <div key={r.id} style={box}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(260px, 100%), 1fr))', gap: 10 }}>
            <div style={{ minWidth: 0 }}>
              <span style={ls}>{t({ id: 'atelier.revue.before', defaultMessage: 'Atual' })}</span>
              <div style={{ fontSize: '.9rem', wordBreak: 'break-word' }}>{r.avant}</div>
            </div>
            <div style={{ minWidth: 0 }}>
              <span style={ls}>{t({ id: 'atelier.revue.after', defaultMessage: 'Proposta' })}</span>
              <div style={{ fontSize: '.9rem', wordBreak: 'break-word', color: '#4ade80' }}>
                {r.apres_propose || <em style={{ color: 'var(--brand-muted, #999)' }}>
                  {t({ id: 'atelier.revue.noProposal', defaultMessage: 'nenhuma proposta' })}
                </em>}
              </div>
            </div>
          </div>

          {r.note && (
            <div style={{ fontSize: '.74rem', color: '#fbbf24', marginTop: 8 }}>⚠ {r.note}</div>
          )}
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #777)', marginTop: 6 }}>
            {r.entity_kind === 'book'
              ? t({ id: 'atelier.revue.entity.book' })
              : t({ id: 'atelier.revue.entity.author' })} #{r.entity_id}
            {r.contexte ? ` · ${r.contexte}` : ''}
          </div>

          {editing?.id === r.id ? (
            <div style={{ marginTop: 10 }}>
              <label style={ls}>{t({ id: 'atelier.revue.ownValue', defaultMessage: 'Valor correto' })}</label>
              <input type="text" value={editing.valeur} autoFocus
                onChange={e => setEditing(s => ({ ...s, valeur: e.target.value }))}
                style={{ width: '100%', minWidth: 0, maxWidth: '100%', fontSize: 16, padding: '8px 10px',
                         borderRadius: 8, border: '1px solid rgba(255,255,255,.16)',
                         background: 'rgba(0,0,0,.30)', color: 'inherit' }} />
              <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                <Button variant="primary" disabled={busyId === r.id || !editing.valeur.trim()}
                  onClick={() => decider(r.id, 'corrige', editing.valeur.trim())}>
                  {t({ id: 'atelier.revue.saveOwn', defaultMessage: 'Registrar esta correção' })}
                </Button>
                <Button variant="secondary" onClick={() => setEditing(null)}>
                  {t({ id: 'atelier.revue.cancel', defaultMessage: 'Cancelar' })}
                </Button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
              <Button variant="primary" disabled={busyId === r.id || !r.apres_propose}
                onClick={() => decider(r.id, 'valide')}>
                {t({ id: 'atelier.revue.accept', defaultMessage: 'Aceitar a proposta' })}
              </Button>
              <Button variant="secondary" disabled={busyId === r.id}
                onClick={() => decider(r.id, 'ecarte')}>
                {t({ id: 'atelier.revue.reject', defaultMessage: 'Descartar — deixar como está' })}
              </Button>
              <Button variant="secondary" disabled={busyId === r.id}
                onClick={() => setEditing({ id: r.id, valeur: r.apres_propose || r.avant })}>
                {t({ id: 'atelier.revue.own', defaultMessage: 'Corrigir manualmente' })}
              </Button>
            </div>
          )}
        </div>
      ))}
    </section>
  );
}
