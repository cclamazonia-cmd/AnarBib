import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui';
import BookAvailability from '@/components/BookAvailability';

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Liste de souhaits » de Mon compte (E6, AccountPage lot 2,
// 06/10/2026). Sorti d'AccountPage.jsx tel quel, lignes déplacées par script :
// la liste et la disponibilité des livres restent au parent, qui les
// charge ; réserver et retirer rechargent par loadData. Les props portent les
// noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabDesejos({ wishlist, availabilityMap, user, loadData }) {
  const { formatMessage: t } = useIntl();
  return (
    <div>
      <h2 className="ab-conta-section-title">{t({ id: 'account.wishlist.title' })}</h2>
      <p className="ab-conta-hint">{t({ id: 'account.tab.wishlist.hint' })}</p>
      {wishlist.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.wishlist.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {wishlist.map((w) => {
            const b = w.books || {};
            const wAvail = w.book_id ? availabilityMap.get(Number(w.book_id)) : null;
            const canReserveFromWishlist =
              wAvail?.session_holding_id &&
              wAvail?.session_loanable &&
              (wAvail?.session_available_count || 0) > 0;
            return (
              <div key={w.id} className="ab-conta-item" style={{ display: 'flex', gap: 10 }}>
                <div className="ab-conta-item__main" style={{ flex: 1 }}>
                  <Link to={`/livro/${w.book_id}`} className="ab-conta-item__title">{b.titulo || '—'}</Link>
                  <span className="ab-conta-item__meta">{b.autor || '—'}{b.editora && ` · ${b.editora}`}{b.ano && ` (${b.ano})`}</span>
                  <span className="ab-conta-item__meta">ref: {b.bib_ref || '—'}{w.note && ` · ${w.note}`}</span>
                  <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>{t({id:'account.wishlist.addedOn2'},{date: new Date(w.created_at).toLocaleDateString()})}</span>
                  {/* #CL.9 — dispo courante du livre dans la biblio par défaut (31/05/2026) */}
                  {wAvail && (
                    <span className="ab-conta-item__meta" style={{ marginTop: 4 }}>
                      <BookAvailability availability={wAvail} variant="compact" />
                    </span>
                  )}
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                  <Link to={`/livro/${w.book_id}`}><Button variant="mini">{t({ id: 'account.wishlist.seeRecord' })}</Button></Link>
                  {/* #CL.9 — réserver depuis la wishlist quand le livre est dispo et prêtable (31/05/2026) */}
                  {canReserveFromWishlist && (
                    <Button variant="mini" onClick={async () => {
                      const { error } = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
                        p_user_id: user.id,
                        p_holding_ids: [wAvail.session_holding_id],
                      });
                      if (!error) loadData();
                    }}>{t({ id: 'account.wishlist.reserveNow' })}</Button>
                  )}
                  <Button variant="mini" onClick={async () => {
                    await supabase.from('user_wishlist').delete().eq('id', w.id);
                    loadData();
                  }} style={{ color: '#f87171' }}>{t({ id: 'common.remove' })}</Button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
