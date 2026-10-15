// ═══════════════════════════════════════════════════════════
// La page de la source d'une ressource numérique (D17, NUMDIF-3)
//
// On enregistre deux adresses : celle du FICHIER trouvé ailleurs
// (source_url, provenance, jamais montrée pour une copie restreinte)
// et celle de la PAGE qui le présente (source_page_url). Seule la page
// est montrée à qui peut lire la copie (« aussi en ligne »). Le choix
// de ce qui sort se fait côté serveur (get_accessible_digital_asset_by_id_v2,
// read-digital-asset) ; ce module ne fait que deux aides d'affichage
// et de saisie.
// ═══════════════════════════════════════════════════════════

// archive.org/details/<id>, archive.org/download/<id>/…,
// <nœud>.archive.org/<n>/items/<id>/… — même motif que la migration
// 20261015180042 qui a rempli les ressources existantes.
const ARCHIVE_ORG = /^https?:\/\/(?:[a-z0-9-]+\.)*archive\.org\/(?:details|download|\d+\/items)\/([a-z0-9._-]+)/i;

// La page Archive.org d'un fichier Archive.org, ou null.
export function archiveOrgPage(fileUrl) {
  const m = ARCHIVE_ORG.exec(String(fileUrl || '').trim());
  return m ? `https://archive.org/details/${m[1]}` : null;
}

// Le nom à montrer pour la source : celui saisi, sinon l'hôte de la page
// (trois des sept ressources restreintes du 15/10 n'ont pas de nom).
export function sourceLabel(sourceName, pageUrl) {
  const nom = String(sourceName || '').trim();
  if (nom) return nom;
  try {
    return new URL(pageUrl).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}
