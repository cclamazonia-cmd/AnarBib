// ═══════════════════════════════════════════════════════════════════════════
// InvitationsPanel — onglet « Invitations » de RedePage (admins réseau seuls).
//
// Réf : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
//
// Émettre une invitation à rejoindre le réseau, la révoquer, suivre celles qui
// sont en cours. Trois choses valent d'être sues avant de toucher à ce fichier.
//
// 1. L'ÉMISSION PASSE PAR L'EDGE FUNCTION, PAS PAR LA RPC. `fn_create_library_
//    request_invitation` rend le jeton en clair une seule fois ; si on l'appelait
//    ici, ce jeton vivrait dans le navigateur. `notify-library-invitation` émet
//    ET envoie côté serveur : le jeton n'existe que dans le mail. La liste et la
//    révocation, elles, passent bien par RPC — elles ne manipulent aucun jeton.
//
// 2. LES DEUX NOTES NE VONT PAS AU MÊME ENDROIT, et c'est tout l'objet de la
//    décision A4. `mot_accompagnement` part dans le mail, sous les yeux de la
//    personne invitée. `note_interne` ne sort jamais d'ici. Les libellés le
//    disent, et la note interne est affichée sur fond distinct dans la liste :
//    quelqu'un qui copie-colle doit voir ce qu'il copie.
//
// 3. CE N'EST PAS UN FICHIER DE PROSPECTION (§7 du cadrage). La liste montre des
//    gestes DÉJÀ POSÉS — qui a invité qui, quand, avec quelle issue — et non des
//    bibliothèques à conquérir. Pas de relance automatique, pas de taux de
//    réponse : une invitation sans suite expire, et c'est une réponse.
// ═══════════════════════════════════════════════════════════════════════════
import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { SUPPORTED_LOCALES } from '@/i18n';
import { Button } from '@/components/ui';

const VIDE = { email: '', libraryName: '', mot: '', noteInterne: '' };

export default function InvitationsPanel() {
  const { formatMessage: t, locale } = useIntl();
  const [form, setForm] = useState(VIDE);
  const [langue, setLangue] = useState(locale || 'pt-BR');
  const [liste, setListe] = useState([]);
  const [mentions, setMentions] = useState([]);
  const [closes, setCloses] = useState(false);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  const charger = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_list_library_request_invitations', {
        p_inclure_closes: closes,
      });
      if (error) throw error;
      setListe(data || []);
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [closes, t]);
  useEffect(() => { charger(); }, [charger]);

  // Décision C — bibliothèques nommées par des lecteur·rices orphelines, et qui
  // ont consenti à ce que la coordination les contacte. La fonction lit
  // `profiles` en direct : si quelqu'un efface sa mention dans /conta, elle
  // disparaît d'ici au prochain chargement, sans rien à synchroniser.
  const chargerMentions = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_list_orphan_library_mentions');
      if (error) throw error;
      setMentions(data || []);
    } catch {
      // Silencieux : c'est une aide au repérage, pas le cœur de l'onglet. La
      // faire échouer bruyamment masquerait la liste des invitations, qui, elle,
      // compte.
      setMentions([]);
    }
  }, []);
  useEffect(() => { chargerMentions(); }, [chargerMentions]);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }

  async function emettre(e) {
    e.preventDefault();
    if (!form.email.trim() || !form.libraryName.trim()) {
      setMsg({ text: t({ id: 'rede.invitations.form.required' }), kind: 'error' });
      return;
    }
    setBusy('emettre');
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.functions.invoke('notify-library-invitation', {
        body: {
          email: form.email.trim(),
          library_name: form.libraryName.trim(),
          mot_accompagnement: form.mot.trim(),
          note_interne: form.noteInterne.trim(),
          locale: langue,
        },
      });
      if (error) {
        // supabase-js v2 : sur un non-2xx, error.context est la Response, pas le
        // corps. Sans cette lecture, un 409 « déjà invitée » retombe sur un
        // message générique et l'admin réémet en boucle.
        let corps = data;
        try {
          if (error.context && typeof error.context.clone === 'function') {
            corps = await error.context.clone().json();
          }
        } catch { /* corps illisible : on garde le repli */ }
        const code = corps?.code || corps?.error || '';
        if (code === '23505') {
          setMsg({ text: t({ id: 'rede.invitations.error.alreadyPending' }), kind: 'error' });
        } else if (code === '42501') {
          setMsg({ text: t({ id: 'rede.invitations.error.notAdmin' }), kind: 'error' });
        } else {
          setMsg({ text: localizeError(error, t), kind: 'error' });
        }
        return;
      }
      // L'invitation peut exister sans que le mail soit parti : on ne dit pas
      // « envoyée » dans ce cas — l'admin doit pouvoir renvoyer le lien
      // autrement plutôt que de croire la bibliothèque prévenue.
      setMsg({
        text: data?.email_envoye
          ? t({ id: 'rede.invitations.sent' })
          : t({ id: 'rede.invitations.createdNoMail' }),
        kind: data?.email_envoye ? 'ok' : 'warn',
      });
      setForm(VIDE);
      charger();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  async function revoquer(inv) {
    const motif = window.prompt(t({ id: 'rede.invitations.list.revokeReason' }));
    // null = annulé ; chaîne vide = motif refusé côté base, autant le dire ici.
    if (motif === null) return;
    if (!motif.trim()) {
      setMsg({ text: t({ id: 'rede.invitations.list.revokeReasonRequired' }), kind: 'error' });
      return;
    }
    setBusy(inv.claim_id);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('fn_revoke_library_request_invitation', {
        p_claim_id: inv.claim_id,
        p_motif: motif.trim(),
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'rede.invitations.list.revoked' }), kind: 'ok' });
      charger();
    } catch (e) {
      setMsg({ text: localizeError(e, t), kind: 'error' });
    } finally {
      setBusy(null);
    }
  }

  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const hs = { fontSize: '.78rem', color: 'var(--brand-muted, #999)', marginTop: 4 };
  const req = <span style={{ color: '#f87171' }}>*</span>;

  const dateCourte = (v) => (v ? new Date(v).toLocaleDateString(locale) : '—');

  return (
    <div>
      <h3 style={{ marginBottom: 6 }}>{t({ id: 'rede.invitations.title' })}</h3>
      <p style={{ ...hs, marginTop: 0, marginBottom: 16, maxWidth: 720 }}>
        {t({ id: 'rede.invitations.intro' })}
      </p>

      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {/* ── Émettre ─────────────────────────────────────────────────── */}
      <form onSubmit={emettre} style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 24, maxWidth: 720 }}>
        <strong style={{ display: 'block', marginBottom: 10, fontSize: '.92rem' }}>
          {t({ id: 'rede.invitations.form.title' })}
        </strong>

        <div style={{ marginBottom: 12 }}>
          <label style={ls}>{t({ id: 'rede.invitations.form.libraryName' })} {req}</label>
          <input type="text" value={form.libraryName} maxLength={200} required style={fs}
            onChange={e => set('libraryName', e.target.value)} />
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={ls}>{t({ id: 'rede.invitations.form.email' })} {req}</label>
          <input type="email" value={form.email} maxLength={200} required style={fs}
            onChange={e => set('email', e.target.value)} />
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={ls}>{t({ id: 'rede.invitations.form.locale' })}</label>
          <select value={langue} onChange={e => setLangue(e.target.value)} style={fs}>
            {SUPPORTED_LOCALES.map(l => <option key={l.code} value={l.code}>{l.label}</option>)}
          </select>
          <div style={hs}>{t({ id: 'rede.invitations.form.localeHint' })}</div>
        </div>

        {/* Ce que la bibliothèque LIRA. */}
        <div style={{ marginBottom: 12 }}>
          <label style={ls}>{t({ id: 'rede.invitations.form.mot' })}</label>
          <textarea value={form.mot} maxLength={2000} rows={3}
            style={{ ...fs, resize: 'vertical', fontFamily: 'inherit' }}
            onChange={e => set('mot', e.target.value)} />
          <div style={hs}>{t({ id: 'rede.invitations.form.motHint' })}</div>
        </div>

        {/* Ce qu'elle NE LIRA PAS. Fond distinct : on doit voir la différence
            sans lire le libellé, parce que c'est là qu'on se trompe. */}
        <div style={{ marginBottom: 14, padding: 10, borderRadius: 8, background: 'rgba(180,83,9,.08)', border: '1px solid rgba(180,83,9,.25)' }}>
          <label style={ls}>{t({ id: 'rede.invitations.form.noteInterne' })}</label>
          <textarea value={form.noteInterne} maxLength={2000} rows={2}
            style={{ ...fs, resize: 'vertical', fontFamily: 'inherit' }}
            onChange={e => set('noteInterne', e.target.value)} />
          <div style={hs}>{t({ id: 'rede.invitations.form.noteInterneHint' })}</div>
        </div>

        <Button type="submit" variant="primary" loading={busy === 'emettre'}>
          {t({ id: 'rede.invitations.form.submit' })}
        </Button>
      </form>

      {/* ── Bibliothèques nommées (décision C) ──────────────────────── */}
      {mentions.length > 0 && (
        <div style={{ marginBottom: 24, maxWidth: 720 }}>
          <h3 style={{ marginBottom: 6 }}>{t({ id: 'rede.invitations.mentions.title' })}</h3>
          <p style={{ ...hs, marginTop: 0, marginBottom: 12 }}>
            {t({ id: 'rede.invitations.mentions.intro' })}
          </p>
          {mentions.map(m => (
            <div key={m.library_name} style={{ padding: 12, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'baseline' }}>
                <strong style={{ fontSize: '.95rem' }}>{m.library_name}</strong>
                <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)' }}>
                  {t({ id: 'rede.invitations.mentions.count' }, { n: m.mentions })}
                </span>
              </div>
              <div style={{ ...hs, marginTop: 4 }}>
                {t({ id: 'rede.invitations.mentions.last' })} {dateCourte(m.derniere_mention)}
              </div>
              {/* Les personnes ne sont nommées que si elles l'ont accepté ; les
                  autres restent comptées sans nom. Le dire explicitement évite
                  de lire une liste vide comme « personne n'a mentionné ». */}
              <div style={{ ...hs, marginTop: 6 }}>
                {(m.personnes || []).length > 0
                  ? <>
                      <b>{t({ id: 'rede.invitations.mentions.reachable' })}</b>{' '}
                      {(m.personnes || []).map(x => `${x.prenom || ''} (${x.public_id || '—'})`).join(', ')}
                    </>
                  : t({ id: 'rede.invitations.mentions.anonymous' })}
              </div>
              <div style={{ marginTop: 10 }}>
                <Button type="button" variant="secondary"
                  onClick={() => set('libraryName', m.library_name)}>
                  {t({ id: 'rede.invitations.mentions.prefill' })}
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ── Suivre ──────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10, flexWrap: 'wrap' }}>
        <h3 style={{ margin: 0 }}>{t({ id: 'rede.invitations.list.title' })}</h3>
        <label style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <input type="checkbox" checked={closes} onChange={e => setCloses(e.target.checked)} />
          {t({ id: 'rede.invitations.list.includeClosed' })}
        </label>
      </div>

      {loading && <p style={hs}>{t({ id: 'common.loading' })}</p>}
      {!loading && liste.length === 0 && <p style={hs}>{t({ id: 'rede.invitations.list.empty' })}</p>}

      {liste.map(inv => (
        <div key={inv.claim_id} style={{ padding: 12, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 10, maxWidth: 720 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'baseline' }}>
            <strong style={{ fontSize: '.95rem' }}>{inv.library_name || '—'}</strong>
            <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)' }}>
              {t({ id: `rede.invitations.etat.${inv.etat}` })}
            </span>
          </div>
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', marginTop: 4 }}>
            {/* Après la purge (45 j), l'e-mail a disparu : on le dit plutôt que
                d'afficher un vide qui ressemblerait à une donnée manquante. */}
            {inv.purged_at ? <em>{t({ id: 'rede.invitations.list.purged' })}</em> : inv.email_snapshot}
          </div>
          <div style={{ ...hs, marginTop: 6 }}>
            {t({ id: 'rede.invitations.list.expires' })} {dateCourte(inv.expires_at)}
          </div>
          {inv.mot_accompagnement && (
            <div style={{ ...hs, marginTop: 6 }}>
              <b>{t({ id: 'rede.invitations.list.motLabel' })}</b> {inv.mot_accompagnement}
            </div>
          )}
          {inv.note_interne && (
            <div style={{ marginTop: 6, padding: '6px 10px', borderRadius: 6, background: 'rgba(180,83,9,.08)', border: '1px solid rgba(180,83,9,.25)', fontSize: '.78rem', color: 'var(--brand-muted, #ccc)' }}>
              <b>{t({ id: 'rede.invitations.list.noteInterneLabel' })}</b> {inv.note_interne}
            </div>
          )}
          {inv.revoked_reason && (
            <div style={{ ...hs, marginTop: 6 }}>
              <b>{t({ id: 'rede.invitations.list.revokedReason' })}</b> {inv.revoked_reason}
            </div>
          )}
          {inv.etat === 'en_attente' || inv.etat === 'compte_cree' ? (
            <div style={{ marginTop: 10 }}>
              <Button type="button" variant="danger" loading={busy === inv.claim_id}
                onClick={() => revoquer(inv)}>
                {t({ id: 'rede.invitations.list.revoke' })}
              </Button>
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}
