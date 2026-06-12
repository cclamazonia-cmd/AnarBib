import { useIntl } from 'react-intl';
import './HumanChannelInlineCallout.css';

// ═══════════════════════════════════════════════════════════════════════════
// HumanChannelInlineCallout — encadré canal humain (ONBO-D1, spec §6.5)
//
// Doctrine anti-méga-machine §1.4.2 : à CHAQUE décision configurante (= chaque
// volet du wizard de constitution), un canal humain VISIBLE, en TÊTE du volet,
// NON-FERMABLE, jamais positionné comme accessoire.
//
// Accroche contextuelle par volet (§6.5.2). Les volets fortement configurants
// (0, 4, 5, 9, 10) reçoivent un ton « fort » (accent rouge anarchiste).
//
// Bouton « Demander un échange » : en attendant la RPC api.fn_propose_request_exchange
// + table library_request_invitations (sous-paquet différé), c'est un mailto
// pré-rempli avec le nom du volet — dégradé gracieux, sans rien casser.
// ═══════════════════════════════════════════════════════════════════════════

const NET_EMAIL = 'anarbib@proton.me';
const NET_MATRIX = '#anarbib:libreflux.fr';
const STRONG_VOLETS = new Set([0, 4, 5, 9, 10]);

export default function HumanChannelInlineCallout({ volet, subjectLabel }) {
  const { formatMessage: t } = useIntl();
  const strong = STRONG_VOLETS.has(volet);
  const subject = subjectLabel
    ? `[AnarBib] ${subjectLabel}`
    : t({ id: 'atelier.human.mailSubject' });
  const ctaHref = `mailto:${NET_EMAIL}?subject=${encodeURIComponent(subject)}`;

  return (
    <aside className={`ab-hcc${strong ? ' is-strong' : ''}`} role="note">
      <div className="ab-hcc-tag">{t({ id: 'atelier.human.tag' })}</div>
      <p className="ab-hcc-text">{t({ id: `atelier.human.volet${volet}` })}</p>
      <div className="ab-hcc-links">
        <a className="ab-hcc-chan" href={`mailto:${NET_EMAIL}`}>✉ {NET_EMAIL}</a>
        <a className="ab-hcc-chan" href={`https://matrix.to/#/${NET_MATRIX}`} target="_blank" rel="noreferrer">⌗ {NET_MATRIX}</a>
        <a className="ab-hcc-cta" href={ctaHref}>{t({ id: 'atelier.human.requestExchange' })}</a>
      </div>
    </aside>
  );
}
