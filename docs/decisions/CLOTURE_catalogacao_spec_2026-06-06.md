# CLOTURE — spec-catalogacao-fiche-et-paliers v0.3

**Date** : 2026-06-06
**Spec** : `docs/specs/spec-catalogacao-fiche-et-paliers.md`
**Etat** : `docs/specs/ETAT-catalogacao-2026-06-06.md`

---

## Verdict

La spec `spec-catalogacao-fiche-et-paliers v0.3` est **integralement implementee**.
Les 9 sections (§3–§9) sont couvertes, les 8 decisions d'interpretation (D1–D8)
sont toutes au statut RESOLU, et aucun point 🟡/⛔ ne subsiste dans le document
d'etat.

## Perimetres livres

### Architecture (§3/§4)
- **Registre declaratif** (`fieldRegistry.js`) : source unique de verite pour les
  champs, groupes, paliers, gating materiel, tierOverride.
- **3 paliers** (simple/avance/complet) avec persistance localStorage.
- **Lot 2 — rendu pilote** : `inp()/sel()` supprimes, remplacers par
  `renderRegistryField()` qui lit le registre. Les blocs speciaux (contributeurs,
  capa, ISBD/MARC) restent en rendu dedie.

### Types de materiel (§5)
- **12 types** operationnels (livro, periodico, tract, cartaz, audio, audiovisual,
  recurso_digital, dossie, tese, artigo, relatorio, zine).
- `books_tipo_material_check` elargi (migration `124642`).
- Audit type-par-type §5.4 realise : chaque champ aligne tier/mat sur la spec.
- Familles partagees (panfleto+cartaz) confirmees.

### Champs specifiques (§5.1–§5.7)
- **idioma** : select 36 langues (10 locales AnarBib + 26 langues courantes).
- **circulacao** : 3 valeurs (emprestavel/consulta/ambos).
- **distribuidora** (audiovisuel), **paginas** (tese).
- **14 colonnes** tese/artigo/relatorio/zine/subjects ajoutees en DB.
- **viaf/isni/wikidata** (§5.2) : DB + front + RPC + trigger.
- **Contributeurs types** (§5.5) : selecteur auteur preventif, roles complets.
- **Aquisicao/proveniencia** (§5.7) : cable dans ExemplarDraftForm.
- **publish_book_draft** consolide (18 colonnes ex-trigger en RPC directe).

### Lisibilite & UX (§7)
- Kit `.ab-*` adopte (relief §7.1, labels §7.2).
- Surface fresque panneau sombre tous onglets (§7.3).
- Emplacements reserves capa et bandeau doublon (§7.4).
- Apercu live v3 (TRA-v3).

### i18n (§8)
- 3412 cles x 10 locales, parite CI.
- Aucune chaine en dur dans les composants catalogacao.

## Migrations DB livrees le 06/06

| Migration | Objet |
|---|---|
| `20260606114851` | circulation_default 3 valeurs + trigger |
| `20260606124642` | books_tipo_material_check 12 types |
| `20260606130227` | distribuidora (AV) + propagation |
| `20260606173502` | 14 colonnes tese/artigo/relatorio/zine/subjects |
| `20260606183824` | viaf/isni/wikidata |
| `20260606184914` | consolidation publish_book_draft 18 colonnes |

## Decisions d'interpretation (D1–D8)

Toutes RESOLUES. Documentees dans le header de `fieldRegistry.js`.

| # | Objet | Resolution |
|---|---|---|
| D1 | editora.mat | 6 types (maquette normative) |
| D2 | Blocs speciaux | Marques `special` dans le registre |
| D3 | Selects/segments | Opts verbatim du render existant |
| D4 | idioma | Select 36 langues (endonyms) |
| D5 | circulacao | 3 valeurs (emprestavel/consulta/ambos) |
| D6 | viaf/isni/wikidata | DB + front + RPC + trigger |
| D7 | Tiers | Alignes spec §5.4 + tierOverride |
| D8 | Spans | Registre autoritatif (titulo span 2 = spec) |

## Points renvoyes (hors perimetre spec, non bloquants)

- **Module capas** : emplacement reserve, implementation → `spec-module-capas.md`.
- **Bandeau doublon** : emplacement reserve → `spec-doublons-detection-fusion.md`.
- **Normalisation donnees idioma** : les fiches anterieures ont du texte libre ;
  le select affiche « — » jusqu'a re-selection. Normalisation en lot a planifier
  si volume significatif.
- **Maquette v3** non versionnee dans le depot.

## Lecons apprises

1. **Le registre declaratif est le bon pattern.** Centraliser les champs dans un
   fichier unique (`fieldRegistry.js`) avec gating materiel + tier a permis de
   refactoriser le rendu (Lot 2) sans toucher au modele de donnees.
2. **Belt-and-suspenders DB** : consolider les colonnes dans la RPC `publish_book_draft`
   ET les garder dans le trigger evite les regressions silencieuses.
3. **Horodatage migrations en sessions paralleles** : la regle « UTC exact, > max »
   est critique quand 2+ sessions travaillent sur le meme dossier. Collision =
   pipeline rouge.
4. **Endonyms pour les langues** : stocker le nom natif (identique dans toutes les
   locales) simplifie enormement la maintenance i18n — 1 cle = 1 valeur universelle.
