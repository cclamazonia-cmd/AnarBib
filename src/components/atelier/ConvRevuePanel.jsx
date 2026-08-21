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
const CLE_DE_LOT = {
  autorite_patronyme: 'patronyme',
  autorite_casse:     'casse',
  titre_casse:        'titres',
};

// Les trois vues forment une PARTITION : chaque ligne est dans exactement une
// d'entre elles, jamais dans deux, et leur union est le tout. C'est ce qui
// permet au travail fini de sortir des vues de travail sans que rien ne
// devienne inatteignable — un « toutes » qui cacherait des lignes serait un
// nom qui ment, et une ligne tranchee qui disparait sans recours est
// exactement ce qui a rendu l'autorite 10079 introuvable (CONV-O6).
//
//   a revoir    : aucune decision posee
//   en attente  : decidee (valide|corrige), pas encore ecrite au catalogue
//   reglees     : ecrite au catalogue, OU ecartee — dans les deux cas, fini
const FILTRES = [
  { v: 'a_revoir',    k: 'pending' },
  { v: '__attente__', k: 'decided' },
  { v: '__regle__',   k: 'settled' },
];

const APPARTIENT = {
  a_revoir:    r => r.decision === 'a_revoir',
  __attente__: r => (r.decision === 'valide' || r.decision === 'corrige') && !r.applique_le,
  __regle__:   r => Boolean(r.applique_le) || r.decision === 'ecarte',
};

const ls = { display: 'block', fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginBottom: 4 };
const box = {
  border: '1px solid rgba(255,255,255,.10)', borderRadius: 10,
  padding: 12, marginBottom: 10, background: 'rgba(0,0,0,.15)',
};

/**
 * @param {string[]} lots   identifiants de lot a montrer, dans l'ordre
 * @param {string}   titleKey  cle i18n du titre de section
 * @param {string}   introKey  cle i18n du paragraphe d'introduction
 */
export default function ConvRevuePanel({ lots, titleKey, introKey, collapsible = false }) {
  const { formatMessage: t } = useIntl();

  // Replie par defaut quand la file s'insere dans une page qui a deja son
  // contenu : 211 propositions poussaient le catalogue de Catalogacao si bas
  // qu'on ne l'atteignait plus qu'au prix d'un tres long defilement.
  const [ouvert, setOuvert] = useState(!collapsible);

  const [resume, setResume] = useState([]);
  const [lot, setLot] = useState(lots[0]);
  const [filtre, setFiltre] = useState('a_revoir');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [editing, setEditing] = useState(null);   // { id, valeur }

  // Le RESUME se charge toujours, meme replie : c'est lui qui alimente le
  // compteur de l'en-tete, et un compteur a zero ferait croire qu'il n'y a
  // rien derriere la fleche. Il ne coute qu'un group by.
  const chargerResume = useCallback(async () => {
    const { data, error } = await supabase.schema('api').rpc('conv_revue_resume');
    if (error) setMsg({ text: localizeError(t, error), kind: 'err' });
    else setResume(data || []);
  }, [t]);

  useEffect(() => { chargerResume(); }, [chargerResume]);

  // Les LIGNES, elles, ne se chargent que si on les regarde : jusqu'a 200
  // propositions par lot, ce n'est pas ce qu'on demande a une page repliee.
  const charger = useCallback(async () => {
    if (!ouvert) return;
    setLoading(true);
    const [r1, r2] = await Promise.all([
      supabase.schema('api').rpc('conv_revue_resume'),
      // `p_decision: null` = toutes les decisions. « Tranches non appliques »
      // se filtre cote client, faute d'un parametre dedie cote RPC.
      supabase.schema('api').rpc('conv_revue_list', {
        p_lot: lot,
        p_decision: filtre === 'a_revoir' ? 'a_revoir' : null,
        p_max: 200,
      }),
    ]);
    if (r1.error || r2.error) {
      setMsg({ text: localizeError(t, r1.error || r2.error), kind: 'err' });
    } else {
      setResume(r1.data || []);
      const brut = r2.data || [];
      // Une seule regle d'appartenance, celle de la partition. « Ecarte » est
      // un etat TERMINAL : la ligne est reglee, rien ne l'appliquera jamais.
      setRows(brut.filter(APPARTIENT[filtre] || (() => true)));
    }
    setLoading(false);
  }, [lot, filtre, ouvert, t]);

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
    // Sous les autres filtres elle a vocation a rester visible — on recharge.
    if (filtre === 'a_revoir') setRows(rs => rs.filter(r => r.id !== id));
    else charger();
    setResume(rs => rs.map(r => r.lot === lot ? { ...r, a_revoir: Number(r.a_revoir) - 1 } : r));
    setEditing(null);
  }

  async function appliquer() {
    setBusyId('__apply__');
    setMsg({ text: '', kind: '' });
    const { data, error } = await supabase.schema('api').rpc('conv_revue_appliquer', { p_lot: lot });
    setBusyId(null);
    if (error) { setMsg({ text: localizeError(t, error), kind: 'err' }); return; }
    const r = (data && data[0]) || {};
    setMsg({
      text: t({ id: 'atelier.revue.applyDone' },
               { n: Number(r.applique ?? 0), r: Number(r.refuse ?? 0) }),
      kind: 'ok',
    });
    charger();
  }

  const compteurs = Object.fromEntries(resume.map(r => [r.lot, r]));
  const cLot = compteurs[lot] || {};
  // Ce qui attend une ECRITURE : les verdicts poses moins ceux deja ecrits.
  // « Ecarte » n'y figure pas — il ne sera jamais applique.
  const enAttente = Math.max(
    0,
    Number(cLot.valide ?? 0) + Number(cLot.corrige ?? 0) - Number(cLot.applique ?? 0));

  return (
    <section style={{ marginTop: 28 }}>
      <h2 style={{ fontSize: '1rem', margin: '0 0 4px' }}>
        {t({ id: titleKey })}
      </h2>
      <p style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)', margin: '0 0 12px', maxWidth: 720 }}>
        {t({ id: introKey })}
      </p>

      {/* Lots. minmax(0, …) sur chaque piste — MOB-1. */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(220px, 100%), 1fr))', gap: 8, marginBottom: 14 }}>
        {lots.map(id => {
          const k = CLE_DE_LOT[id];
          const c = compteurs[id] || {};
          const actif = lot === id;
          return (
            <button key={id} type="button" onClick={() => setLot(id)}
              style={{
                textAlign: 'left', cursor: 'pointer', padding: '10px 12px', borderRadius: 10,
                border: actif ? '1px solid var(--brand-accent, #60a5fa)' : '1px solid rgba(255,255,255,.10)',
                background: actif ? 'rgba(96,165,250,.10)' : 'rgba(0,0,0,.15)', color: 'inherit',
              }}>
              <div style={{ fontSize: '.86rem', fontWeight: 600 }}>
                {t({ id: `atelier.revue.lot.${k}` })}
              </div>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginTop: 2 }}>
                {t({ id: `atelier.revue.lot.${k}.hint` })}
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

      {/* Filtre de decision. Sans « tranches, non appliques », une ligne
          disparait de l'ecran des qu'on la tranche — meme si elle n'a jamais
          ete ecrite en base. C'est ce qui a rendu l'autorite 10079
          inatteignable apres un verdict pose par erreur (CONV-O6). */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12, flexWrap: 'wrap' }}>
        <span style={{ fontSize: '.74rem', color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'atelier.revue.filter.label' })}
        </span>
        <select value={filtre} onChange={e => setFiltre(e.target.value)}
          style={{ fontSize: 16, minWidth: 0, maxWidth: '100%', padding: '6px 10px', borderRadius: 8,
                   border: '1px solid rgba(255,255,255,.16)', background: 'rgba(0,0,0,.30)', color: 'inherit' }}>
          {FILTRES.map(f => (
            <option key={f.v} value={f.v}>{t({ id: `atelier.revue.filter.${f.k}` })}</option>
          ))}
        </select>

        {/* Appliquer au catalogue. Ecriture de donnees par le staff, comme une
            fusion d'autorites — pas une migration (cf. migration 14). Les
            gardes vivent cote SQL : une fiche modifiee depuis l'instantane
            n'est pas ecrasee, et la RPC dit combien elle a refuse. */}
        {enAttente > 0 && (
          <Button variant="primary" disabled={busyId === '__apply__'}
            onClick={appliquer}>
            {t({ id: 'atelier.revue.apply' }, { n: enAttente })}
          </Button>
        )}
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
              {/* CONV-O6 : `avant` est un instantane. Quand il ne decrit plus
                  l'entite, on montre ce qui EST, et on le dit. */}
              <div style={{ fontSize: '.9rem', wordBreak: 'break-word',
                            textDecoration: r.perime ? 'line-through' : 'none',
                            opacity: r.perime ? 0.55 : 1 }}>{r.avant}</div>
              {r.perime && (
                <div style={{ fontSize: '.9rem', wordBreak: 'break-word', marginTop: 4 }}>{r.actuel}</div>
              )}
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

          {r.perime && (
            <div style={{ fontSize: '.74rem', color: '#f87171', marginTop: 8 }}>
              ⚠ {t({ id: 'atelier.revue.stale' })}
            </div>
          )}
          {r.note && (
            <div style={{ fontSize: '.74rem', color: '#fbbf24', marginTop: 8 }}>⚠ {r.note}</div>
          )}
          {filtre === '__regle__' && (
            <div style={{ fontSize: '.74rem', color: '#4ade80', marginTop: 8 }}>
              {r.applique_le
                ? t({ id: 'atelier.revue.state.applied' })
                : t({ id: 'atelier.revue.state.discarded' })}
            </div>
          )}
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #777)', marginTop: 6 }}>
            {r.entity_kind === 'book'
              ? t({ id: 'atelier.revue.entity.book' })
              : t({ id: 'atelier.revue.entity.author' })} #{r.entity_id}
            {r.contexte ? ` · ${r.contexte}` : ''}
          </div>

          {filtre === '__regle__' ? null : editing?.id === r.id ? (
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
              {/* Une proposition batie sur un instantane perime ne peut pas etre
                  acceptee : l'appliquer deferait le travail d'un autre lot. */}
              <Button variant="primary" disabled={busyId === r.id || !r.apres_propose || r.perime}
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
