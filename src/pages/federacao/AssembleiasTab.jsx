import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════════════════════
// AssembleiasTab — onglet « Assembleias » de la Fédération (présentation v0).
//
// Onglet purement présentatif (préfiguration de l'AG du réseau) : principe,
// fonctionnement technique (visio Jitsi en link-out vers vc.autistici.org via
// VITE_JITSI_DOMAIN — salle d'AG anarbib-assembleia-<uuid> ouverte dans un onglet),
// règles de décision PAR DÉFAUT (date = disponibilité + préférence ; quorum =
// collectifs + diversité ; décisions = consentement), proposition d'un point à
// l'ODJ (modèle « pas de gardien, l'assemblée adopte ») et premiers points
// pressentis. Aucune écriture, aucun backend : le dépôt en ligne d'un point
// relève d'un futur spec-assembleias (RPC-first).
// Design : docs/journal/cadrages/CADRAGE_assembleias_reseau_2026-06-16.md
// ═══════════════════════════════════════════════════════════════════════════

export default function AssembleiasTab() {
  const { formatMessage: t } = useIntl();

  return (
    <div className="ab-fed-assembleias">
      <div className="ab-fed-head">
        <div><div className="ab-fed-sub">{t({ id: 'federacao.assembleias.lead' })}</div></div>
        <span className="ab-fed-pill is-new">{t({ id: 'federacao.assembleias.badge' })}</span>
      </div>

      <div className="ab-fed-welcome">
        <h3>{t({ id: 'federacao.assembleias.principle.title' })}</h3>
        <p>{t({ id: 'federacao.assembleias.principle.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.how.title' })}</div>
        <p className="ab-fed-cdesc">{t({ id: 'federacao.assembleias.how.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.rules.title' })}</div>
        <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.rules.intro' })}</p>
        <ul className="ab-fed-rules">
          <li>{t({ id: 'federacao.assembleias.rules.date' })}</li>
          <li>{t({ id: 'federacao.assembleias.rules.quorum' })}</li>
          <li>{t({ id: 'federacao.assembleias.rules.consent' })}</li>
        </ul>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.agenda.title' })}</div>
        <p className="ab-fed-cdesc">{t({ id: 'federacao.assembleias.agenda.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.firstPoints.title' })}</div>
        <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.firstPoints.intro' })}</p>
        <ul className="ab-fed-rules">
          <li>{t({ id: 'federacao.assembleias.firstPoints.rules' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.subjects' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.terms' })}</li>
        </ul>
      </div>
    </div>
  );
}
