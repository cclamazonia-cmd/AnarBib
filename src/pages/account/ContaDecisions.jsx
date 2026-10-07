import { useIntl } from 'react-intl';
import { supabase, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { Button } from '@/components/ui';
import DataExportButton from '@/components/account/DataExportButton';

// ═══════════════════════════════════════════════════════════
// AnarBib — les trois décisions de l'onglet « Données personnelles » de Mon
// compte : exporter mes données, mes notifications, la lettre de la fédération
// (E19 : une grille de trois cartes, juste sous le profil). Sorti
// d'AccountPage.jsx tel quel (E6, AccountPage lot 6, 07/10/2026), lignes
// déplacées par script : les gestes restent écrits en ligne, comme avant ;
// l'état (préférences, consentement, sabliers, messages) reste au parent, qui
// le charge, et passe en props sous ses noms. Garde : conta-decisions-sous-le-
// profil.test.js relit l'onglet en remettant ce fichier à sa place.
// ═══════════════════════════════════════════════════════════

export default function ContaDecisions({
  notifPrefs, setNotifPrefs, notifPrefsSaving, setNotifPrefsSaving, notifPrefsMsg, setNotifPrefsMsg,
  lettreConsent, setLettreConsent, lettreSaving, setLettreSaving, lettreMsg, setLettreMsg,
}) {
  const { formatMessage: t } = useIntl();
  return (
      <section className="ab-conta-decisions-bloc" aria-labelledby="ab-conta-decisions-title">
        <h3 id="ab-conta-decisions-title" className="ab-conta-subsection">{t({ id: 'account.rgpd.title' })}</h3>
        <div className="ab-conta-decisions">
          {/* Export des données — droit à la portabilité (RGPD art. 20, LGPD art. 18) */}
          <div className="ab-conta-decision">
            <h4>{t({ id: 'account.export.title' })}</h4>
            <p className="ab-conta-hint">{t({ id: 'account.export.description' })}</p>
            <DataExportButton />
            <p className="ab-conta-hint ab-conta-decision-note">{t({ id: 'account.rgpd.subtitle' })}</p>
          </div>

          {/* #CL.7 — Préférences de notification (31/05/2026) */}
          {/* Cf. docs/specs/spec-notifications-lecteur.md §5. Position 1 :    */}
          {/* la lectrice peut réduire ce que la biblio envoie, pas l'inverse.*/}
          <div className="ab-conta-decision ab-conta-decision--notif">
            <h4>
              {t({ id: 'account.notifPrefs.title' })}
            </h4>
            <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
              {t({ id: 'account.notifPrefs.intro' })}
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 12 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={notifPrefs.disable_reserva_pronta}
                  onChange={(e) => setNotifPrefs(p => ({ ...p, disable_reserva_pronta: e.target.checked }))}
                />
                <span>{t({ id: 'account.notifPrefs.disableReservaPronta' })}</span>
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={notifPrefs.disable_consulta_pronta}
                  onChange={(e) => setNotifPrefs(p => ({ ...p, disable_consulta_pronta: e.target.checked }))}
                />
                <span>{t({ id: 'account.notifPrefs.disableConsultaPronta' })}</span>
              </label>
              {/* Phase 1 actus réseau : un seul toggle gouverne Lettre/Gazette/cercles */}
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={notifPrefs.disable_rede_news}
                  onChange={(e) => setNotifPrefs(p => ({ ...p, disable_rede_news: e.target.checked }))}
                />
                <span>{t({ id: 'account.notifPrefs.disableRedeNews' })}</span>
              </label>
              {/* Événements de bibliothèque (avis « nouvel événement ») */}
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={notifPrefs.disable_library_events}
                  onChange={(e) => setNotifPrefs(p => ({ ...p, disable_library_events: e.target.checked }))}
                />
                <span>{t({ id: 'account.notifPrefs.disableLibraryEvents' })}</span>
              </label>
            </div>

            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <Button
                variant="secondary"
                onClick={async () => {
                  setNotifPrefsSaving(true);
                  setNotifPrefsMsg('');
                  try {
                    const { error } = await supabase.rpc('fn_set_my_notification_preferences', {
                      p_disable_reserva_pronta: notifPrefs.disable_reserva_pronta,
                      p_disable_consulta_pronta: notifPrefs.disable_consulta_pronta,
                      p_disable_rede_news: notifPrefs.disable_rede_news,
                      p_disable_library_events: notifPrefs.disable_library_events,
                    });
                    if (error) throw error;
                    setNotifPrefsMsg(t({ id: 'account.notifPrefs.saved' }));
                  } catch (err) {
                    setNotifPrefsMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
                  } finally {
                    setNotifPrefsSaving(false);
                  }
                }}
                disabled={notifPrefsSaving}
              >
                {notifPrefsSaving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
              </Button>
              {notifPrefsMsg && (
                <span className="ab-conta-msg" style={{ fontSize: '.85rem' }}>{notifPrefsMsg}</span>
              )}
            </div>

            <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
              {t({ id: 'account.notifPrefs.alwaysActive' })}
            </p>
          </div>

          {/* Lettre de la fédération — abonnement opt-in (Lot 2, GAZ-5). Double opt-in :
              cocher déclenche un e-mail de confirmation ; rien n'est envoyé sans le clic de validation. */}
          <div className="ab-conta-decision ab-conta-decision--lettre">
            <h4>
              {t({ id: 'account.lettre.title' })}
            </h4>
            <p className="ab-conta-hint" style={{ marginTop: 0, marginBottom: 12 }}>
              {t({ id: 'account.lettre.intro' })}
            </p>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: lettreSaving ? 'wait' : 'pointer' }}>
              <input
                type="checkbox"
                checked={lettreConsent.consent_lettre || lettreConsent.pending}
                disabled={lettreSaving}
                onChange={async (e) => {
                  const want = e.target.checked;
                  setLettreSaving(true);
                  setLettreMsg('');
                  try {
                    if (want) {
                      const { data, error } = await apiRpc('fn_lettre_request_optin');
                      if (error) throw error;
                      if (data === 'already_subscribed') {
                        setLettreConsent({ consent_lettre: true, pending: false });
                      } else {
                        setLettreConsent((c) => ({ ...c, pending: true }));
                        setLettreMsg(t({ id: 'account.lettre.confirmationSent' }));
                      }
                    } else {
                      const { error } = await apiRpc('fn_lettre_cancel');
                      if (error) throw error;
                      setLettreConsent({ consent_lettre: false, pending: false });
                      setLettreMsg(t({ id: 'account.lettre.unsubscribed' }));
                    }
                  } catch (err) {
                    setLettreMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
                  } finally {
                    setLettreSaving(false);
                  }
                }}
              />
              <span>{t({ id: 'account.lettre.toggle' })}</span>
            </label>
            {lettreConsent.pending && (
              <p className="ab-conta-hint" style={{ marginTop: 10, marginBottom: 0, fontSize: '.82rem' }}>
                {t({ id: 'account.lettre.pending' })}
              </p>
            )}
            {lettreConsent.consent_lettre && !lettreConsent.pending && (
              <p className="ab-conta-hint" style={{ marginTop: 10, marginBottom: 0, fontSize: '.82rem' }}>
                {t({ id: 'account.lettre.subscribed' })}
              </p>
            )}
            {lettreMsg && (
              <p className="ab-conta-msg" style={{ marginTop: 10, marginBottom: 0, fontSize: '.85rem' }}>{lettreMsg}</p>
            )}
            <p className="ab-conta-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
              {t({ id: 'account.lettre.note' })}
            </p>
          </div>
        </div>
      </section>
  );
}
