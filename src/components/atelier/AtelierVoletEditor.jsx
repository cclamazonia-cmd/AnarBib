import AtelierVolet1Identite from './AtelierVolet1Identite';
import AtelierVolet2Horarios from './AtelierVolet2Horarios';
import AtelierVolet4Catalogacao from './AtelierVolet4Catalogacao';
import AtelierVolet6Adesao from './AtelierVolet6Adesao';
import AtelierVolet7Emails from './AtelierVolet7Emails';
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
// Reste non câblé : seulement le volet 8 « partenariats » (LibraryPartnershipsSection
// → nécessite la liste réseau) ; le volet 8 ne rend ici que DocumentGovernanceSection.
// ═══════════════════════════════════════════════════════════════════════════
export const WIRED_VOLETS = new Set([1, 2, 3, 4, 5, 6, 7, 8, 9]);

export default function AtelierVoletEditor({ voletN, libraryId, canEdit }) {
  if (!libraryId) return null;
  switch (voletN) {
    case 1:
      return <AtelierVolet1Identite libraryId={libraryId} canEdit={canEdit} />;
    case 2:
      return <AtelierVolet2Horarios libraryId={libraryId} canEdit={canEdit} />;
    case 4:
      // Catalogação — le catalog_mode est déjà choisi au volet 0 ; ici, notes
      // libres de politique de catalogage (libraries.cataloging_policy_notes).
      return <AtelierVolet4Catalogacao libraryId={libraryId} canEdit={canEdit} />;
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
    case 6:
      return <AtelierVolet6Adesao libraryId={libraryId} canEdit={canEdit} />;
    case 7:
      // E-mails — identité d'envoi (library_commons), lue via library_commons_staff_read
      // (sinon fn_library_visible_to_caller bloque le SELECT sur une biblio pré-active).
      return <AtelierVolet7Emails libraryId={libraryId} canEdit={canEdit} />;
    case 8:
      return <DocumentGovernanceSection libraryId={libraryId} canEdit={canEdit} />;
    case 9:
      return <RetentionPolicySection libraryId={libraryId} canEdit={canEdit} />;
    default:
      return null;
  }
}
