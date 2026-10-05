// ═══════════════════════════════════════════════════════════
// AnarBib — les réseaux constitués (G13, 05/10/2026).
//
// L'appartenance d'un lieu à un réseau (FICEDL, RebAL, NORLA…) est déclarée par
// sa fiche de carte, en texte : `cartography_entries.reseau`. La base en tient
// la lecture (`reseaux`, slugs du vocabulaire `public.networks`) avec la MÊME
// règle que ce module : jetons séparés par « ; » ou « , », reconnus par libellé
// ou alias sans égard à la casse, sans doublon, dans l'ordre du texte
// (public.fn_cartography_reseaux_de). Un jeton hors vocabulaire reste dans le
// texte ; l'écran le montre plutôt que de le perdre.
// ═══════════════════════════════════════════════════════════

const norm = (s) => String(s || '').trim().toLowerCase();

export function decouperReseau(texte) {
  return String(texte || '').split(/\s*[;,]\s*/).map((s) => s.trim()).filter(Boolean);
}

export function reseauDuJeton(jeton, reseaux) {
  const j = norm(jeton);
  if (!j) return null;
  return (reseaux || []).find((r) => norm(r.label) === j || (r.aliases || []).some((a) => norm(a) === j)) || null;
}

// Le texte d'une fiche : les réseaux reconnus (slugs) et les jetons hors vocabulaire.
export function lireReseau(texte, reseaux) {
  const connus = [];
  const inconnus = [];
  for (const tok of decouperReseau(texte)) {
    const r = reseauDuJeton(tok, reseaux);
    if (r) { if (!connus.includes(r.slug)) connus.push(r.slug); }
    else if (!inconnus.some((i) => norm(i) === norm(tok))) inconnus.push(tok);
  }
  return { connus, inconnus };
}

// Le texte réécrit : libellés du vocabulaire (dans son ordre), puis les jetons
// hors vocabulaire tels qu'ils étaient saisis.
export function ecrireReseau(slugs, inconnus, reseaux) {
  const choisis = new Set(slugs || []);
  const libelles = (reseaux || []).filter((r) => choisis.has(r.slug)).map((r) => r.label);
  return [...libelles, ...(inconnus || [])].join('; ');
}

// Catalogue public : les bibliothèques (slugs) des réseaux choisis, d'après
// api.fn_catalog_networks_v1 ([{ slug, label, libraries: [{ slug, short_name, name }] }]).
export function bibliothequesDesReseaux(choix, reseauxCatalogue) {
  const pris = new Set(choix || []);
  const out = new Set();
  for (const r of reseauxCatalogue || []) {
    if (pris.has(r.slug)) for (const l of r.libraries || []) out.add(l.slug);
  }
  return out;
}

// Ce que le filtre de bibliothèques envoie au catalogue (des sigles) quand un
// filtre de réseaux est posé : la sélection de bibliothèques prise DANS ces
// réseaux, ou à défaut toutes les bibliothèques de ces réseaux.
export function bibliothequesFiltrees(libraryFilter, reseauxChoisis, reseauxCatalogue) {
  if (!reseauxChoisis || reseauxChoisis.length === 0) return libraryFilter || [];
  const dans = bibliothequesDesReseaux(reseauxChoisis, reseauxCatalogue);
  const pris = (libraryFilter || []).filter((s) => dans.has(s));
  return pris.length ? pris : [...dans];
}
