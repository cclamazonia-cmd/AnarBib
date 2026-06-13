import AtelierVolet1Identite from './AtelierVolet1Identite';
import AtelierVolet2Horarios from './AtelierVolet2Horarios';
import TeamPanel from '@/components/team/TeamPanel';
import RegimeStateBox from '@/components/library/RegimeStateBox';
import PolicySetManager from '@/components/library/PolicySetManager';
import DocumentGovernanceSection from '@/components/library/DocumentGovernanceSection';
import RetentionPolicySection from '@/components/library/RetentionPolicySection';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierVoletEditor — ONBO-Q2 Lot 2/3
// Mappe un volet de constitution vers ses VRAIS éditeurs, scopés à la biblio
// pré-active (is_active=false). Les volets absents de WIRED_VOLETS retombent sur le
// placeholder « reuse » côté page.
//
// Tous ces composants éditent leurs sous-tables via une RLS staff-based (audit
// 2026-06-13 : library_document_governance, library_retention_policies… ne gatent PAS
// la lecture sur is_active) → fonctionnent sur une biblio pré-active où la coordinatrice
// a une membership coordenador active.
//
// À câbler au lot suivant : v2 horaires (service_state, in-page), v3 pessoas (TeamPanel),
// v4 catalogação, v5 circulação (PolicySetManager/RegimeStateBox), v6 adhesão, v7 emails
// (in-page), v8 partenariats (LibraryPartnershipsSection → nécessite la liste réseau).
// ═══════════════════════════════════════════════════════════════════════════
export const WIRED_VOLETS = new Set([1, 2, 3, 5, 8, 9]);

export default function AtelierVoletEditor({ voletN, libraryId, canEdit }) {
  if (!libraryId) return null;
  switch (voletN) {
    case 1:
      return <AtelierVolet1Identite libraryId={libraryId} canEdit={canEdit} />;
    case 2:
      return <AtelierVolet2Horarios libraryId={libraryId} canEdit={canEdit} />;
    case 3:
      // Pessoas responsáveis — TeamPanel charge ses propres données (membships +
      // RPC fn_team_*, staff-based → OK pré-active). La coordinatrice y est seule
      // membre active au départ.
      return <TeamPanel scope="library" libraryId={libraryId} />;
    case 5:
      // Circulação — état de service + jeux de règles de circulation (RPC staff-based).
      // seedT/regulationDocs optionnels (fallbacks dans les composants).
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <RegimeStateBox libraryId={libraryId} />
          <PolicySetManager libraryId={libraryId} canEdit={canEdit} />
        </div>
      );
    case 8:
      return <DocumentGovernanceSection libraryId={libraryId} canEdit={canEdit} />;
    case 9:
      return <RetentionPolicySection libraryId={libraryId} canEdit={canEdit} />;
    default:
      return null;
  }
}
