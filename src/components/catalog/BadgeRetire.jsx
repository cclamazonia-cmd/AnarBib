// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 7 (09/10/2026, IMP-26 d) : le badge d'un exemplaire
// « sorti du catalogue d'origine » (exemplares.retire_at) — là où le staff de
// sa bibliothèque le voit encore (catalogage, fiche, récolement). Rien ne
// s'affiche pour un exemplaire qui n'est pas retiré.
// ═══════════════════════════════════════════════════════════
import { useIntl } from 'react-intl';
import AppIcon from '@/components/ui/AppIcon';
import { estRetire } from '@/lib/importRetraits.js';

export default function BadgeRetire({ exemplaire, style }) {
  const { formatMessage: t, formatDate } = useIntl();
  if (!estRetire(exemplaire)) return null;
  const quand = formatDate(exemplaire.retire_at, { dateStyle: 'medium' });
  return (
    <span data-testid="badge-retire" title={t({ id: 'catalog.retire.badgeTitle' }, { date: quand })}
      style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: '.66rem', fontWeight: 600,
               color: 'var(--brand-warning, #9a6700)', border: '1px solid currentColor', borderRadius: 4,
               padding: '0 5px', whiteSpace: 'nowrap', ...style }}>
      <AppIcon name="archive" size={11} />
      {t({ id: 'catalog.retire.badge' })}
    </span>
  );
}
