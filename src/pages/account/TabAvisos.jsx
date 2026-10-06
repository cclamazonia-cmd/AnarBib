import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui';
import AppIcon from '@/components/ui/AppIcon';
import ContaTabHeader from '@/pages/account/ContaTabHeader';

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Avis » de Mon compte (E6, AccountPage lot 2,
// 06/10/2026). Sorti d'AccountPage.jsx tel quel, lignes déplacées par script :
// les avis, leur tri actifs / archivés et le compte des non-lus restent au
// parent, qui les charge ; les gestes (lu, archiver, restaurer) rechargent par
// loadData. Les props portent les noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabAvisos({
  notifViewMode, setNotifViewMode, unreadCount, visibleNotifications, tNotifText, loadData,
}) {
  const { formatMessage: t } = useIntl();
  return (
    <div>
      <ContaTabHeader
        title={t({ id: 'account.notifications.title' })}
        onRefresh={() => loadData({ silent: true })}
        actions={(
          <>
            {/* #CL.6 — toggle vue active / archives */}
            <Button variant="mini" onClick={() => setNotifViewMode(m => m === 'active' ? 'archived' : 'active')}>
              {notifViewMode === 'active'
                ? t({ id: 'account.notifications.showArchives' })
                : t({ id: 'account.notifications.backToActive' })}
            </Button>
            {/* "Marquer tout comme lu" : actifs uniquement, et seulement
                s'il y a effectivement des non-lus à marquer */}
            {notifViewMode === 'active' && unreadCount > 0 && (
              <Button variant="mini" onClick={async () => {
                await supabase.rpc('fn_mark_notifications_read');
                loadData({ silent: true });
              }}>{t({ id: 'account.notifications.markAllRead' })}</Button>
            )}
          </>
        )}
      />
      <p className="ab-conta-hint">{t({ id: 'account.tab.notifications.hint' })}</p>
      {visibleNotifications.length === 0 ? (
        <p className="ab-conta-empty">{
          notifViewMode === 'active'
            ? t({ id: 'account.notifications.empty' })
            : t({ id: 'account.notifications.archivesEmpty' })
        }</p>
      ) : (
        <div className="ab-conta-items">
          {visibleNotifications.map((n) => (
            <div key={n.id} className="ab-conta-item" style={{
              borderLeft: `3px solid ${n.is_read ? 'rgba(255,255,255,.06)' : n.category === 'alerta' ? '#f87171' : n.category === 'reserva' ? '#60a5fa' : n.category === 'emprestimo' ? '#fbbf24' : '#4ade80'}`,
              opacity: n.is_read ? 0.6 : 1,
            }}>
              <div className="ab-conta-item__main" style={{ flex: 1 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 4 }}>
                  <span className="ab-conta-item__title" style={{ cursor: 'default' }}>{tNotifText(n.title)}</span>
                  {!n.is_read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#60a5fa', flexShrink: 0 }} />}
                </div>
                {n.body && <span className="ab-conta-item__meta">{tNotifText(n.body)}</span>}
                <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>
                  {new Date(n.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                  {n.category && <> · {n.category}</>}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                {n.link_type === 'livro' && n.link_id && <Link to={`/livro/${n.link_id}`}><Button variant="mini">{t({ id: 'account.notifications.seeBook' })}</Button></Link>}
                {(n.link_type || '').startsWith('rede_') && <Link to={n.link_type === 'rede_gazette' ? '/federacao/gazeta' : n.link_type === 'rede_circulo' ? '/federacao/circulos' : '/federacao/carta'}><Button variant="mini">{t({ id: 'account.notifications.openNetwork' })}</Button></Link>}
                {!n.is_read && (
                  <Button variant="mini" onClick={async () => {
                    await supabase.rpc('fn_mark_notifications_read', { p_ids: [n.id] });
                    loadData({ silent: true });
                  }}>✓</Button>
                )}
                {/* #CL.6 — archiver (vue active) ou restaurer (vue archives) */}
                {notifViewMode === 'active' ? (
                  <Button variant="mini" onClick={async () => {
                    const { error } = await supabase.rpc('fn_archive_notification', { p_notification_id: n.id });
                    if (!error) loadData({ silent: true });
                  }} title={t({ id: 'account.notifications.archive' })}><AppIcon name="archive" size={16} /></Button>
                ) : (
                  <Button variant="mini" onClick={async () => {
                    const { error } = await supabase.rpc('fn_unarchive_notification', { p_notification_id: n.id });
                    if (!error) loadData({ silent: true });
                  }} title={t({ id: 'account.notifications.unarchive' })}><AppIcon name="archiveRestore" size={16} /></Button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
