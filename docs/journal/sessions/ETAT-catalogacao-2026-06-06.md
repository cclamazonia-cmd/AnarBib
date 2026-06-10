# Etat des travaux — page **Catalogacao** (au 2026-06-06, fin de journee)

> Document de **passation** pour reprise en session neuve. Confronte
> l'implementation actuelle aux prescriptions de la spec et de la maquette.
> Statuts : ✅ fait · 🟡 partiel · ⛔ a faire · ❓ a verifier.
>
> **Mise a jour 06/06 soir** : tous les points 🟡/⛔/❓ de la version
> precedente ont ete resolus. La spec `spec-catalogacao-fiche-et-paliers v0.3`
> est **integralement implementee**. Voir la cloture :
> `docs/journal/arbitrages/CLOTURE_catalogacao_spec_2026-06-06.md`.

## 0. Sources de verite

- **Spec** : `docs/specs/spec-catalogacao-fiche-et-paliers.md` (architecture 8.E
  registre de champs, 3 paliers, champs par type, §7 lisibilite, §8 i18n).
- **Maquette ideale** : `maquette_fiche_catalogacao_v3.html` — ⚠️ **PAS dans le
  depot** (fournie en piece jointe lors des sessions precedentes). Revue visuelle
  realisee le 06/06 sans ecarts majeurs.
- Specs connexes citees : `spec-exemplaires-circulation.md`,
  `spec-acquisition-provenance-v0_1.md`, `spec-module-capas.md`,
  `spec-doublons-detection-fusion.md`.
- Decisions actees : `docs/specs/REGISTRE_decisions.md` (chercher `CAT-…`).

## 1. Fichiers cles

| Fichier | Role |
|---|---|
| `src/pages/catalogacao/CatalogacaoPage.{jsx,css}` | Page conteneur, onglets, panneau sombre |
| `src/pages/catalogacao/fieldRegistry.js` | **Registre declaratif** : groupes/champs, `mat`, `tier`, `tierOverride`, 36 langues (IDIOMA_OPTS), 3 valeurs circulation |
| `src/pages/catalogacao/CatalogFieldRenderer.jsx` | `renderRegistryField`, `renderMaterialSection`, `isFieldVisible` |
| `src/pages/catalogacao/BookDraftForm.jsx` | Fiche notice : EMPTY_FORM, save/publish, apercu live v3, rendu pilote par registre (Lot 2) |
| `src/pages/catalogacao/AuthorDraftForm.jsx` | Fiche autorite : authority_lookup, notes bio multilingues |
| `src/pages/catalogacao/ExemplarDraftForm.jsx` | Exemplaire : circulation_default seed, acquisition/provenance |
| `src/i18n/locales/*.json` | 10 locales, 3412 cles, parite gardee par CI |

## 2. Etat par section de spec

### §3 — Registre de champs (archi 8.E)
- ✅ Registre declaratif en place (`fieldRegistry.js`), descripteur `{id,label,mat,tier,…}`, regle de visibilite §3.3 via `isFieldVisible`.
- ✅ `.mode-complete-only` (CSS) retire au profit du registre JS.
- ✅ **Lot 2 livre** : rendu ad-hoc `inp()/sel()` remplace par `renderRegistryField()` pilote par le registre. Celui-ci est la source unique de verite pour les champs.

### §4 — Trois paliers (simple | advanced | complete)
- ✅ 3 marches fonctionnelles, persistance localStorage, sélecteur UI verifie.

### §5 — Types de materiel & champs par type
- ✅ **12 types** cables (`MATERIAL_TYPE_KEYS`).
- ✅ `books_tipo_material_check` elargi aux 12 types (migration `124642`).
- ✅ **§5.4 audit type-par-type** realise : alignement tier-par-tier des 12 types confronte a la spec. Ecarts corriges dans `fieldRegistry.js`.
- ✅ **Familles partagees** panfleto+cartaz : jeu commun confirme.
- ✅ **§5.5 contributeurs types** : selecteur auteur preventif ; typologie des roles complete vs spec.
- ✅ **§5.6 circulacao padrao** : 3 valeurs (`emprestavel`/`consulta`/`ambos`), synchro `loanable`.
- ✅ **§5.7 aquisicao & proveniencia (tier 3)** : arrimage `spec-acquisition-provenance` cable dans `ExemplarDraftForm.jsx`.
- ✅ Champs specifiques : distribuidora (AV), paginas (tese), tese/artigo/relatorio/zine colonnes DB + wiring, subjects (transversal).
- ✅ **CDD scope par type** (`CDD_MAT`).
- ✅ **Idioma** : select 36 langues (10 locales AnarBib + 26 langues courantes). Placeholder corrige.

### §5.2 — Identifiants d'autorite
- ✅ **viaf/isni/wikidata** : colonnes DB (book_drafts + books), champs actives dans le registre (groupe `autoridade`, tier 3), wiring EMPTY_FORM + save payload + publish_book_draft RPC + trigger de propagation.

### §6 — Visibilite
- ✅ Re-render depuis le registre a chaque changement type/palier.

### §7 — Lisibilite (8.G)
- ✅ **§7.1/§7.2** : revue visuelle fine vs maquette v3 realisee. Kit `.ab-*` adopte.
- ✅ **§7.3** : surface « fresque » panneau sombre tous onglets.
- ✅ **§7.4** : emplacement capa reserve (§5.3) + bandeau doublon (`.ab-dup`) cable.
- ✅ **§7.5** : boutons migres `.ab-button` ; styles inline reduits.
- ✅ Apercu live **v3** (TRA-v3).

### §8 — i18n
- ✅ Externalisation complete des chaines catalogacao.
- ✅ 10 locales a parite (3412 cles, test CI).
- ✅ 26 cles `language.XX` ajoutees (36 langues au total).
- ✅ Aucune cle `catalogacao.*` manquante ou en dur.

### §9 — Implementation & retro-compatibilite
- ✅ P1 (paliers) / P2 (registre) / P3 (12 types complets) / P4 (lisibilite `.ab-*`).

## 3. Decisions d'interpretation (D1–D8) — toutes RESOLUES

| Decision | Objet | Statut |
|---|---|---|
| D1 | editora.mat aligne sur maquette normative (6 types) | ✅ |
| D2 | Blocs speciaux (contrib/cover/ISBD) marques `special` | ✅ |
| D3 | Selects/segments opts verbatim | ✅ |
| D4 | idioma → select 36 langues (IDIOMA_OPTS) | ✅ |
| D5 | circulacao 3 valeurs (emprestavel/consulta/ambos) | ✅ |
| D6 | viaf/isni/wikidata DB + front + RPC | ✅ |
| D7/D7b | Tiers alignes spec + tierOverride | ✅ |
| D8 | Spans autoritatifs (registre = verite) | ✅ |

## 4. Migrations livrees le 06/06 (cette session)

| Horodatage | Objet |
|---|---|
| `114851` | circulation_default 3 valeurs + trigger publish |
| `124642` | `books_tipo_material_check` 12 types |
| `130227` | colonne `distribuidora` + propagation publish |
| `173502` | 14 colonnes tese/artigo/relatorio/zine/subjects |
| `183824` | colonnes viaf/isni/wikidata |
| `184914` | consolidation publish_book_draft (18 colonnes) |

## 5. Commits frontend cles (cette session, selection)

| Hash | Objet |
|---|---|
| `2491a7b` | **Lot 2** — remplacement inp()/sel() par registre |
| `6b150d9` | Audit §5.4 + revue visuelle §7.1/§7.2 |
| `3d0cbea` | idioma → select 10 locales (D4 initial) |
| `05701a3` | viaf/isni/wikidata frontend (D6) |
| `5dfe0fa` | consolidation publish_book_draft |
| `9c6ed37` | idioma → 36 langues |
| `8656a97` | cleanup ESLint + header docs |
| `63dd581` | D1–D8 toutes RESOLU |

## 6. Reste a faire — rien de bloquant

La spec `spec-catalogacao-fiche-et-paliers v0.3` est **integralement implementee**.

Points de maintenance/evolution future (hors perimetre spec) :
- **Maquette v3** non versionnee dans le depot — a versionner si revue visuelle
  fine recurrente souhaitee.
- **Capa (module capas)** : emplacement reserve, implementation renvoyee a
  `spec-module-capas.md`.
- **Bandeau doublon** : emplacement reserve, implementation renvoyee a
  `spec-doublons-detection-fusion.md`.
- **Donnees existantes idioma** : les fiches anterieures stockent du texte libre
  (ex. « Portugues »). La valeur affichee sera « — » jusqu'a re-selection.
  Normalisation en lot a envisager si le volume le justifie.

## 7. Garde-fous process

- 🥇 **Regle d'or** (CLAUDE.md) : jamais deux push concurrents + serialiser ses
  propres push (attendre pipeline vert).
- 🛑 **Horodatage migration** = UTC exact a la seconde, strictement > max du dossier.
- Build + `npm test` (parite i18n bloquante) avant tout push de code.
- Commits : Conventional Commits ASCII ; `[CI SKIP]` seulement sur commits doc-purs.
