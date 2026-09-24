// ============================================================================
// network-admins.ts — À QUI on écrit quand on écrit « aux admins du réseau »
// ============================================================================
// Backlog F15 (24/09/2026). Constat de départ : un courriel « Mise à jour d'une
// demande institutionnelle » n'est arrivé QUE sur la boîte personnelle de
// l'unique administrateur actif. Neuf endroits rechargeaient chacun
// `network_administrators` + `profiles` à leur façon, et la boîte collective
// du réseau (`admins@` du domaine — déjà destinataire des alertes de
// supervision depuis le 28/08, et des rapports DMARC) ne voyait rien passer.
//
// Ce module est LA résolution des destinataires d'administration du réseau :
//
//   destinataires = admins actif·ves (chacun·e dans SA langue)
//                 + la boîte collective (variable d'environnement, en pt-BR)
//                 + d'éventuels extras du contexte appelant
//   dédoublonnés par adresse, insensible à la casse.
//
// Deux règles héritées de health-probe (28/08/2026), qui restent vraies :
//   * NE PAS sortir quand la table est vide. « Aucun administrateur actif »
//     voulait dire « aucun courriel », en silence. La boîte collective est
//     précisément le filet de ce cas-là.
//   * L'adresse vient d'une VARIABLE, jamais du code. Le réseau a décidé le
//     16/09 de ne plus imprimer d'adresse `.org` dans un texte ; un secret se
//     change sans redéploiement, une constante non.
//
// Langue de la boîte collective : pt-BR, langue de référence d'AnarBib
// (décision Xavier 24/09/2026). Les personnes gardent leur langue de profil.
//
// Limite acceptée : le dédoublonnage ne peut pas voir qu'un alias réexpédie vers
// une adresse déjà présente. Si `admins@` renvoie chez un administrateur, il
// recevra deux copies — cela se règle en changeant la variable, pas le code.
//
// AJOUTER, PAS REMPLACER. L'éventail par personne et par langue est voulu ; la
// boîte reçoit une copie EN PLUS. Et tout ne mérite pas la boîte : les courriels
// de gouvernance ENTRE admins (cooptation, retrait collectif, votes, motifs
// parfois nominatifs — `_shared/domain/network.ts`), la facilitation d'assemblée,
// l'éditorial de la gazette et de l'atelier restent adressés aux personnes.
// L'INSTITUTIONNEL et la SUPERVISION passent ici : demandes de bibliothèques,
// permissions documentaires, gel global d'un·e membre, rapport hebdo du réseau,
// récapitulatif inter-bibliothèques, alertes de santé. La garde
// `src/tests/admins-reseau-destinataires.test.js` tient les deux listes.
//
// Sans effet de bord à l'import : le client est passé en paramètre (chaque
// fonction a le sien), l'environnement n'est lu qu'à l'appel.
// ============================================================================

export const LOCALE_BOITE_COLLECTIVE = "pt-BR";

// Variable lue par les fonctions institutionnelles. Repli sur HEALTH_ALERT_CC
// (posée en production le 28/08/2026, la boîte collective) tant que la variable
// propre n'est pas posée : la livraison est effective sans nouveau secret, et
// séparer les deux boîtes reste possible en posant NETWORK_ADMIN_CC.
// AUCUNE adresse dans ce fichier : la garde du banc le vérifie.
export const VARIABLE_BOITE_COLLECTIVE = "NETWORK_ADMIN_CC";
export const VARIABLE_BOITE_REPLI = "HEALTH_ALERT_CC";

export type DestinataireReseau = {
  email: string;
  name?: string;
  locale: string;
  /** admin = personne de la table ; boite = variable d'environnement ; extra = fourni par l'appelant */
  source: "admin" | "boite" | "extra";
  user_id?: string;
};

const LOCALES = new Set(["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"]);

/** Locale de courriel d'un profil : l'une des dix, sinon pt-BR. */
export function localeDeProfil(raw: unknown): string {
  const s = String(raw ?? "").trim();
  if (!s) return LOCALE_BOITE_COLLECTIVE;
  if (LOCALES.has(s)) return s;
  const bas = s.toLowerCase();
  if (bas === "pt" || bas.startsWith("pt-") || bas.startsWith("pt_")) return "pt-BR";
  const deux = bas.slice(0, 2);
  return LOCALES.has(deux) ? deux : LOCALE_BOITE_COLLECTIVE;
}

/** Séparateurs admis dans la variable : virgule, point-virgule, espace. */
export function adressesSupplementaires(brut: string | null | undefined): string[] {
  return String(brut ?? "")
    .split(/[,;\s]+/)
    .map((s) => s.trim())
    .filter((s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s));
}

/** La boîte collective telle que l'environnement la donne (brut, peut porter plusieurs adresses). */
export function boiteCollectiveReseau(): string {
  const propre = (Deno.env.get(VARIABLE_BOITE_COLLECTIVE) ?? "").trim();
  if (propre) return propre;
  return (Deno.env.get(VARIABLE_BOITE_REPLI) ?? "").trim();
}

export function fusionnerDestinataires<T extends { email: string }>(...listes: T[][]): T[] {
  const vus = new Set<string>();
  const out: T[] = [];
  for (const liste of listes) {
    for (const c of liste) {
      const cle = String(c?.email ?? "").trim().toLowerCase();
      if (!cle || vus.has(cle)) continue;
      vus.add(cle);
      out.push({ ...c, email: cle });
    }
  }
  return out;
}

/** Les admins actif·ves de la table, avec leur langue. Vide (jamais une erreur) si la lecture échoue. */
export async function adminsReseauActifs(client: any): Promise<DestinataireReseau[]> {
  const { data: rows, error } = await client
    .from("network_administrators")
    .select("user_id")
    .eq("status", "active");
  if (error || !rows?.length) return [];
  const ids = Array.from(new Set(rows.map((r: any) => r.user_id).filter(Boolean)));
  if (!ids.length) return [];
  const { data: profils } = await client
    .from("profiles")
    .select("id,email,first_name,preferred_language")
    .in("id", ids);
  return (profils ?? [])
    .filter((p: any) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(p?.email ?? "").trim()))
    .map((p: any) => ({
      email: String(p.email).trim().toLowerCase(),
      name: p.first_name || undefined,
      locale: localeDeProfil(p.preferred_language),
      source: "admin" as const,
      user_id: String(p.id),
    }));
}

/**
 * Les destinataires d'administration du réseau.
 *   client  : le client supabase de la fonction appelante (service role).
 *   cc      : la variable brute à lire à la place de la boîte collective par
 *             défaut (health-probe passe la sienne, HEALTH_ALERT_CC).
 *   extras  : adresses supplémentaires du contexte (ex. le destinataire
 *             historique du rapport hebdo), en pt-BR.
 * Jamais vide si une boîte est configurée, même sans admin actif.
 */
export async function destinatairesAdminsReseau(
  client: any,
  opts: { cc?: string | null; extras?: { email: string; name?: string }[] } = {},
): Promise<DestinataireReseau[]> {
  const admins = await adminsReseauActifs(client);
  const brut = opts.cc === undefined ? boiteCollectiveReseau() : (opts.cc ?? "");
  const boite = adressesSupplementaires(brut).map((email) => ({
    email,
    name: undefined as string | undefined,
    locale: LOCALE_BOITE_COLLECTIVE,
    source: "boite" as const,
  }));
  const extras = (opts.extras ?? [])
    .filter((e) => e && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e.email ?? "").trim()))
    .map((e) => ({
      email: String(e.email).trim(),
      name: e.name || undefined,
      locale: LOCALE_BOITE_COLLECTIVE,
      source: "extra" as const,
    }));
  return fusionnerDestinataires<DestinataireReseau>(admins, boite, extras);
}
