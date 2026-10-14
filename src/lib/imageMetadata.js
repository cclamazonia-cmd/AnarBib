/**
 * imageMetadata.js — le fichier image déposé, sans ses métadonnées.
 *
 * Le module de nettoyage vit côté edge functions
 * (`supabase/functions/_shared/capas/metadonnees.ts`) : une seule logique,
 * partagée par `cover_lookup` (image rapatriée côté serveur) et par le
 * navigateur (fichier choisi dans le formulaire). Voir son en-tête pour ce qui
 * est retiré et ce qui est gardé.
 */
import { retirerMetadonnees } from '../../supabase/functions/_shared/capas/metadonnees.ts';

/**
 * Rend un File sans EXIF/XMP/IPTC/commentaires, pixels inchangés. Le même
 * objet est rendu s'il n'y avait rien à retirer, ou si le format n'est pas
 * pris en charge : le dépôt ne doit jamais échouer pour ça.
 */
export async function fichierSansMetadonnees(fichier) {
  if (!fichier || typeof fichier.arrayBuffer !== 'function') return fichier;
  const { octets, retires, erreur } = retirerMetadonnees(await fichier.arrayBuffer());
  if (erreur) console.warn('[metadonnees] fichier laissé tel quel :', erreur);
  if (!retires.length) return fichier;
  return new File([octets], fichier.name || 'image', { type: fichier.type, lastModified: Date.now() });
}
