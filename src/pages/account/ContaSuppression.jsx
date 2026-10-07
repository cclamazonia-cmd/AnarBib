import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════
// AnarBib — la suppression du compte, zone destructive tout en bas, dans l'onglet « Données personnelles » de Mon
// compte. Sorti d'AccountPage.jsx tel quel (E6, AccountPage lot 7,
// 07/10/2026), lignes déplacées par script : le geste reste écrit en ligne, comme avant ; la saisie de confirmation et le sablier restent au parent.
// Les props portent les noms du parent. Garde : conta-decisions-sous-le-
// profil.test.js relit l'onglet en remettant ce fichier à sa place.
// ═══════════════════════════════════════════════════════════

export default function ContaSuppression({ deleteConfirm, setDeleteConfirm, deleting, setDeleting, navigate }) {
  const { formatMessage: t } = useIntl();
  return (
    <>
      <div style={{ marginTop: 40, padding: 22, borderRadius: 10, background: 'rgba(220,38,38,.04)', border: '1px solid rgba(220,38,38,.15)' }}>
          <h4 style={{ margin: '0 0 6px', fontSize: '.95rem', fontWeight: 700, color: '#f87171', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'account.deleteAccount.title' })}</h4>
          <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 12px' }}>{t({ id: 'account.deleteAccount.warning' })}</p>
          <div style={{ marginBottom: 10 }}>
            <label style={{ fontSize: '.85rem', fontWeight: 600, display: 'block', marginBottom: 4, color: 'var(--brand-muted)' }}>
              {t({ id: 'account.deleteAccount.confirmLabel' })}
            </label>
            <input type="text" value={deleteConfirm} onChange={e => setDeleteConfirm(e.target.value)}
              placeholder={t({ id: 'account.deleteAccount.confirmText' })} style={{ width: 200, padding: '8px 12px', borderRadius: 8, border: '1px solid rgba(220,38,38,.3)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' }} />
          </div>
          <button
            disabled={deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' }) || deleting}
            onClick={async () => {
              if (deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' })) return;
              if (!confirm(t({ id: 'account.deleteAccount.confirmDialog' }))) return;
              setDeleting(true);
              try {
                const { data, error } = await supabase.rpc('fn_delete_my_account');
                if (error) throw error;
                if (data?.ok === false) { alert(data.error || t({ id: 'account.reserve.deleteError' })); setDeleting(false); return; }
                await supabase.auth.signOut();
                sessionStorage.removeItem('anarbib.libraryContext');
                navigate('/');
              } catch (err) { alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)})); setDeleting(false); }
            }}
            style={{
              padding: '10px 20px', borderRadius: 8, fontSize: '.9rem', fontWeight: 700, cursor: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'pointer' : 'not-allowed',
              background: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'rgba(220,38,38,.8)' : 'rgba(220,38,38,.2)',
              color: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? '#fff' : 'rgba(255,255,255,.4)',
              border: '1px solid rgba(220,38,38,.4)', transition: 'all .15s',
            }}>
            {deleting ? t({ id: 'account.deleteAccount.deleting' }) : t({ id: 'account.deleteAccount.button' })}
          </button>
      </div>
    </>
  );
}
