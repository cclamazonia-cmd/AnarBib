// src/pages/biblioteca/CommsSection.jsx — E6, BibliotecaPage lot 5 (12/10/2026)
// L'onglet « Comunicações » : identité d'envoi (library_commons), canal et
// destinataires (library_mail_channels, par upsert_library_mail_channel —
// la ligne entière, champs non édités compris), profil de contact, vitrine
// publique, types de notification et politique de négociation des retraits
// (library_notification_policies, délai 7..60 j). Les trois états arrivent du
// parent (loadCore les charge) ; l'enregistrement en cours vit ici.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import LibraryContactProfileSection from '@/components/library/LibraryContactProfileSection';
import LibraryPublicContactSection from '@/components/library/LibraryPublicContactSection';
import { fs, ls, bx } from './styles';

// NOTIFICATION_FLAGS keys — labels resolved via t() inside the component
const NOTIFICATION_FLAG_KEYS = [
  'reservation_created', 'reservation_status', 'reservation_workflow', 'local_consultation',
  'loan_lifecycle', 'loan_reminders', 'loan_overdue',
  'profile_restriction', 'cotisation_payment_mail',
  'admin_copy_reservations', 'admin_copy_loans', 'tech_alerts', 'task_alerts',
];

export default function CommsSection({ libraryId, isCoord, user, commons, setC, mailChannel, setMailChannel, notifPolicy, setNotifPolicy, setMsg }) {
  const { formatMessage: t } = useIntl();
  const [saving, setSaving] = useState(false);
  function setMC(k,v){ setMailChannel(p=>p?{...p,[k]:v}:p); }
  function setNP(k,v){ setNotifPolicy(p=>p?{...p,[k]:v}:p); }

  async function saveComms() {
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // INTERRUPTEUR-UNIQUE (30/08/2026) : `email_delivery_mode` (library_commons)
      // n'etait applique NULLE PART — ni par les fonctions notify-*, ni par register.
      // L'ecran affichait donc un selecteur « Modo de envio » qui ne coupait rien,
      // juste au-dessus des vrais champs du canal. Il est retire ; le seul
      // commutateur est desormais celui de library_mail_channels (`active` pour
      // couper, `delivery_mode` pour le transport), honore par transportDisabledReason
      // dans _shared/context/library-mail-routing.ts.
      if (commons) await supabase.from('library_commons').update({ display_name:commons.display_name, contact_email:commons.contact_email, reply_to_email:commons.reply_to_email }).eq('library_id', libraryId);
      // La RPC remplace la ligne ENTIERE : on lui repasse les champs que cet
      // ecran n edite pas (transport_state, transport_channel, last_tested_at),
      // sans quoi une sauvegarde des adresses effacerait le resultat du dernier
      // test de transport.
      if (mailChannel) {
        const { error: mcErr } = await supabase.rpc('upsert_library_mail_channel', {
          p_library_id: libraryId,
          p_channel: {
            delivery_mode: mailChannel.delivery_mode || 'platform_shared',
            admin_notification_email: mailChannel.admin_notification_email || null,
            weekly_report_email: mailChannel.weekly_report_email || null,
            severe_alert_email: mailChannel.severe_alert_email || null,
            transport_state: mailChannel.transport_state || 'not_tested',
            transport_channel: mailChannel.transport_channel || null,
            last_tested_at: mailChannel.last_tested_at || null,
            active: mailChannel.active !== false,
          },
        });
        if (mcErr) throw mcErr;
      }
      if (notifPolicy) {
        // PATCH 08/05/2026 paquet 3A : sauvegarde aussi les 2 paramètres de
        // négociation symétrique (toggle + timeout). Validation timeout côté
        // frontend (la DB a aussi un CHECK 7..60 en défense en profondeur).
        const timeoutDays = Number(notifPolicy.reservation_negotiation_timeout_days);
        if (Number.isFinite(timeoutDays) && (timeoutDays < 7 || timeoutDays > 60)) {
          throw new Error(t({ id: 'biblioteca.reservation.timeoutDays.outOfRange' }));
        }
        const flags = {}; NOTIFICATION_FLAG_KEYS.forEach(k => { flags[k + '_enabled'] = notifPolicy[k + '_enabled'] || false; });
        await supabase.from('library_notification_policies').update({
          ...flags,
          reservation_allow_reader_counter_proposal: notifPolicy.reservation_allow_reader_counter_proposal ?? true,
          reservation_negotiation_timeout_days: Number.isFinite(timeoutDays) ? timeoutDays : 21,
          updated_by: user?.id
        }).eq('library_id', libraryId);
      }
      setMsg({ text: t({ id: 'biblioteca.comms.savedOk' }), kind: 'ok' });
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  return (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.comms.title' })}</h3>
          {commons && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.emailIdentity' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.displayName' })}</label><input type="text" value={commons.display_name||''} onChange={e=>setC('display_name',e.target.value)} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.sendEmail' })}</label><input type="email" value={commons.contact_email||''} onChange={e=>setC('contact_email',e.target.value)} style={fs} /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.identity.replyEmail' })}</label><input type="email" value={commons.reply_to_email||''} onChange={e=>setC('reply_to_email',e.target.value)} style={fs} /></div>
            </div>
          </div>}
          {mailChannel && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.adminRecipients' })}</h4>
            <div className="cat-book-grid">
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.adminEmail' })}</label><input type="email" value={mailChannel.admin_notification_email||''} onChange={e=>setMC('admin_notification_email',e.target.value)} style={fs} placeholder="admin@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.weeklyEmail' })}</label><input type="email" value={mailChannel.weekly_report_email||''} onChange={e=>setMC('weekly_report_email',e.target.value)} style={fs} placeholder="equipe@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.alertEmail' })}</label><input type="email" value={mailChannel.severe_alert_email||''} onChange={e=>setMC('severe_alert_email',e.target.value)} style={fs} placeholder="urgente@biblioteca.org" /></div>
              <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.comms.transport' })}</label>
                <select value={mailChannel.delivery_mode||'platform_shared'} onChange={e=>setMC('delivery_mode',e.target.value)} style={fs}>
                  <option value="platform_shared">{t({ id: 'biblioteca.comms.transport.platform_shared' })}</option>
                  <option value="platform_shared_local_reply">{t({ id: 'biblioteca.comms.transport.platform_shared_local_reply' })}</option>
                  <option value="library_own_transport">{t({ id: 'biblioteca.comms.transport.library_own_transport' })}</option>
                </select>
              </div>
              <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={{...ls,display:'flex',gap:8,alignItems:'flex-start'}}><input type="checkbox" checked={mailChannel.active!==false} onChange={e=>setMC('active',e.target.checked)} style={{marginTop:3}} /> <span><span>{t({id:'biblioteca.comms.channelActive'})}</span><br/><span style={{fontSize:'.8rem',color:'var(--brand-muted)',fontWeight:400}}>{t({id:'biblioteca.comms.channelActive.hint'})}</span></span></label></div>
            </div>
          </div>}
          {/* EA-20 : editeur du profil de contact de la biblioteca
              (library_contact_profiles), dans le composant separe
              LibraryContactProfileSection. */}
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.contactProfile.title' })}</h4>
            <LibraryContactProfileSection libraryId={libraryId} canEdit={isCoord} />
          </div>
          {/* Vitrine publique de contact (chantier carte ma bibliotheque, etape 2) :
              coordonnees que la biblio choisit de montrer a SES lecteur-rices,
              distinct du contact confidentiel ci-dessus. Composant auto-encadre. */}
          <LibraryPublicContactSection libraryId={libraryId} canEdit={isCoord} />
          {notifPolicy && <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.comms.notifTypes' })}</h4>
            <div style={{ display:'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap:6 }}>
              {NOTIFICATION_FLAG_KEYS.map(k => (
                <label key={k} style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer', padding:'4px 0' }}>
                  <input type="checkbox" checked={notifPolicy[k+'_enabled']||false} onChange={e=>setNP(k+'_enabled',e.target.checked)} />
                  {t({ id: `notif.type.${k}`, defaultMessage: k.replace(/_/g, ' ') })}
                </label>
              ))}
            </div>
          </div>}
          {/* PATCH 08/05/2026 paquet 3A : politique de négociation symétrique
              des créneaux de retrait. Toggle pour autoriser/refuser les
              contre-propositions de leitor(o/a/e)s + champ timeout (7..60 j,
              padrão 21 j). Sauvegardés via saveComms() vers library_notification_policies. */}
          {notifPolicy && <div style={bx}>
            <h4 style={{ margin:'0 0 6px' }}>{t({ id: 'biblioteca.reservation.title' })}</h4>
            <p style={{ fontSize:'.85rem', color:'var(--brand-muted)', margin:'0 0 14px' }}>
              {t({ id: 'biblioteca.reservation.subtitle' })}
            </p>

            <label style={{ display:'flex', gap:10, alignItems:'flex-start', cursor:'pointer', padding:'4px 0' }}>
              <input
                type="checkbox"
                checked={notifPolicy.reservation_allow_reader_counter_proposal ?? true}
                onChange={e => setNP('reservation_allow_reader_counter_proposal', e.target.checked)}
                style={{ marginTop:3 }}
              />
              <span style={{ flex:1 }}>
                <span style={{ fontSize:'.92rem', fontWeight:600 }}>
                  {t({ id: 'biblioteca.reservation.allowCounterProposal' })}
                </span>
                <span style={{ display:'block', fontSize:'.82rem', color:'var(--brand-muted)', marginTop:3 }}>
                  {t({ id: 'biblioteca.reservation.allowCounterProposal.hint' })}
                </span>
              </span>
            </label>

            <div className="cat-field" style={{ marginTop:14, maxWidth:280 }}>
              <label style={ls}>{t({ id: 'biblioteca.reservation.timeoutDays' })}</label>
              <input
                type="number"
                min={7}
                max={60}
                step={1}
                value={notifPolicy.reservation_negotiation_timeout_days ?? 21}
                onChange={e => {
                  const n = parseInt(e.target.value, 10);
                  setNP('reservation_negotiation_timeout_days', Number.isFinite(n) ? n : '');
                }}
                style={fs}
              />
              <span style={{ display:'block', fontSize:'.82rem', color:'var(--brand-muted)', marginTop:5 }}>
                {t({ id: 'biblioteca.reservation.timeoutDays.hint' })}
              </span>
            </div>
          </div>}
          <button className="cat-btn primary" onClick={saveComms} disabled={saving}>{saving?t({id:'common.saving'}):t({id:'biblioteca.comms.save'})}</button>
  </div>);
}
