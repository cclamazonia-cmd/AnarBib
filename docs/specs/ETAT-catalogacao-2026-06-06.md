# État des travaux — page **Catalogação** (au 2026-06-06)

> Document de **passation** pour reprise en session neuve. Confronte
> l'implémentation actuelle aux prescriptions de la spec et de la maquette.
> Statuts : ✅ fait · 🟡 partiel · ⛔ à faire · ❓ à vérifier en session neuve.

## 0. Sources de vérité à relire au démarrage

- **Spec** : `docs/specs/spec-catalogacao-fiche-et-paliers.md` (architecture 8.E
  registre de champs, 3 paliers, champs par type, §7 lisibilité, §8 i18n).
- **Maquette idéale** : `maquette_fiche_catalogacao_v3.html` — ⚠️ **PAS dans le
  dépôt** (fournie en pièce jointe `@…` lors des sessions précédentes). Le
  dossier `docs/specs/maquettes/` ne contient que les maquettes *import* (v7,
  wizard). **À RE-ATTACHER par Xavier** en session neuve pour tout travail de
  fidélité visuelle.
- Specs connexes citées : `spec-exemplaires-circulation.md` (destination par
  exemplaire), `spec-acquisition-provenance-v0_1.md` (proveniência tier 3),
  `spec-module-capas.md` (capa), `spec-doublons-detection-fusion.md` (bandeau §7.4).
- Décisions actées : `docs/specs/REGISTRE_decisions.md` (chercher `CAT-…`).

## 1. Fichiers clés (carte pour la reprise)

| Fichier | Rôle |
|---|---|
| `src/pages/catalogacao/CatalogacaoPage.{jsx,css}` | Page conteneur, onglets, panneau sombre `.cat-panel.active` / `.ab-sheet` |
| `src/pages/catalogacao/fieldRegistry.js` | **Registre déclaratif** : groupes/champs, `mat` (gating type) + `tier` (palier), `MATERIAL_TYPE_KEYS`, `CDD_MAT`, `CIRCULATION_OPTS`, `EDITORA_MAT` |
| `src/pages/catalogacao/CatalogFieldRenderer.jsx` | `renderRegistryField`, `renderMaterialSection`, `isFieldVisible` |
| `src/pages/catalogacao/BookDraftForm.jsx` | Fiche notice : EMPTY_FORM, save/publish, aperçu live v3, sélecteur auteur préventif, encart admin-réseau reassign |
| `src/pages/catalogacao/AuthorDraftForm.jsx` | Fiche autorité : authority_lookup, notes bio multilingues, publish-seed bio |
| `src/pages/catalogacao/ExemplarDraftForm.jsx` | Exemplaire : circulation_default seed |
| `src/i18n/locales/*.json` | 10 locales, parité gardée (test CI) ; namespaces `catalogacao.*` |

## 2. État par section de spec

### §3 — Registre de champs (archi 8.E)
- ✅ Registre déclaratif en place (`fieldRegistry.js`), descripteur `{id,label,mat,tier,…}`, règle de visibilité §3.3 via `isFieldVisible` (gating type **et** palier en JS).
- ✅ `.mode-complete-only` (CSS) retiré au profit du registre JS (à reconfirmer qu'il ne reste aucun sélecteur CSS de mode résiduel — ❓ grep `mode-complete`).

### §4 — Trois paliers (simple | advanced | complete)
- ✅ Insertion de `advanced` au milieu sans remap localStorage (arbitrage A3) : `tierFromMode`.
- ❓ Vérifier que le sélecteur de palier UI propose bien les **3** marches et persiste.

### §5 — Types de matériel & champs par type
- ✅ **12 types** câblés (`MATERIAL_TYPE_KEYS`) : livro, periodico, tract, cartaz, audio, audiovisual, recurso_digital, dossie, tese, artigo, relatorio, zine.
- ✅ **BUG MAJEUR corrigé** : `books_tipo_material_check` ne tolérait que 6 types legacy → publication cassée pour 9/12 types (repro DVD « Batalha em Seattle »). Migration `20260606124642` élargit le CHECK aux 12 + legacy.
- ✅ Champs cœur `mat:'all'` (titre, autoria, ano, editora, idioma…).
- ✅ Dédup du champ **langue** (un seul `idioma` cœur ; suppression `audio_language`/`audiovisual_language`).
- ✅ **CDD scopé par type** (`CDD_MAT`) — exclu de l'audiovisuel/audio.
- ✅ Champ **`distribuidora`** (audiovisuel) : colonne books+book_drafts + propagation au publish (migration `20260606130227`).
- ✅ Champ **`páginas`** étendu aux **thèses** (`paginas` mat += tese).
- ✅ Fuite de champs périódico corrigée (chaque champ périódico a son `mat:['periodico']`).
- 🟡 **§5.4 jeux simple/complet par type** : les 12 sections existent, mais **l'alignement fin tier-par-tier** des champs propres (quel champ en tier 1/2/3 pour chaque type) **n'a pas été audité exhaustivement** contre §5.4. → ❓ **audit type-par-type à faire**.
- 🟡 **Familles partagées** panfleto+cartaz (§5.4 / P3) : à confirmer qu'elles partagent bien leur jeu.
- ✅ **§5.6 circulação padrão** : contrôle **3 valeurs** (`emprestavel`/`consulta`/`ambos`), additif + synchro `loanable`. Migration `20260606114851` (circulation_default + trigger `fn_propagate_circulation_default_on_publish`, étendu ensuite).
- ⛔ **§5.5 contributeurs typés (tier 2)** : sélecteur auteur préventif fait ; vérifier la **typologie des rôles** complète vs §5.5.
- ⛔ **§5.7 aquisição & proveniência (tier 3)** : arrimage `spec-acquisition-provenance` — **non traité ici**, à brancher.

### §6 — Visibilité (synthèse opérationnelle)
- ✅ Re-render depuis le registre à chaque changement type/palier.

### §7 — Lisibilité au niveau champ (8.G)
- ✅ **§7.3 surface « fresque »** : panneau sombre `.ab-sheet`/`.cat-panel.active` déployé sur **TOUS les onglets** de la page (demande explicite).
- ✅ Aperçu live **v3** (TRA-v3) : `renderLivePreview()`, carte `.ab-pv-*`, jauge, colonne sticky `.ab-work` 2-col.
- ✅ **§7.5 réduction de l'inline** : boutons migrés vers `.ab-button` (+ `--ghost`, `--sm`) ; styles inline → kit.
- 🟡 **§7.1 relief / §7.2 labels & hiérarchie** : kit `.ab-*` adopté ; ❓ **revue visuelle fine vs maquette v3** non faite (nécessite la maquette re-attachée).

### §7.4 — Réservations d'emplacements (hors périmètre, ancrées)
- ❓ Emplacement **capa** réservé (§5.3) — à vérifier.
- ❓ Emplacement **bandeau doublon** (`.ab-dup`) présent dans BookDraftForm — à vérifier le câblage logique (renvoi spec doublons, hors périmètre ici).

### §8 — i18n
- ✅ Externalisation massive des chaînes catalogação (`catalogacao.msg.*`,
  `.digital.*`, `.ui.*`, `.contributor.*`, `.ph.*`, `.shelf.*`, `.field.*`,
  `.material.*`, `.role.*`, `.reassign.*`).
- ✅ 10 locales à parité (test CI `i18n.test.js`, 76 tests).
- 🟡 **Coût i18n de la 3ᵉ marche (§8)** : labels des champs tier-3 nouveaux — ❓ vérifier qu'aucune clé `catalogacao.*` n'est manquante/en dur après l'audit type-par-type.

### §9 — Implémentation & rétro-compatibilité
- ✅ P1 (paliers) / P2 (registre) / **partie** P3 (12 types) / P4 (lisibilité `.ab-*`).
- 🟡 P3 reste : **alignement fin §5.4** (cf. §5 ci-dessus).

## 3. Livré cette session (réf. commits / migrations — prod vérifiée)

- Migration `20260606114851` — circulation_default (3 valeurs) + trigger publish.
- Migration `20260606124642` — fix `books_tipo_material_check` (12 types). **Débloque la publication.**
- Migration `20260606130227` — colonne `distribuidora` + propagation publish.
- Migration `20260606160309` — **admin réseau : attribuer notice + exemplaires à une bibliothèque** : RPC `list_catalog_libraries()` + `network_admin_reassign_book_to_library(book, library)` (transfert complet, journalisé). **RPC vérifiées live.** (REGISTRE `CAT-E14`.)
- Frontend : encart reassign en tête de fiche (admin réseau, notice publiée) ; champ distribuidora/páginas ; aperçu v3 ; surface sombre tous onglets ; boutons `.ab-*`.

## 4. Reste à faire — backlog priorisé (proposition)

1. **Audit type-par-type §5.4** (le plus structurant) : pour chacun des 12
   types, confronter les champs présents + leur tier au tableau §5.4 de la spec
   et à la maquette v3. Produire un tableau d'écarts, corriger `fieldRegistry.js`.
2. **§5.5 contributeurs typés** : compléter la typologie des rôles (tier 2) vs spec.
3. **§5.7 aquisição/proveniência (tier 3)** : brancher l'arrimage à
   `spec-acquisition-provenance-v0_1.md`.
4. **Revue visuelle fine §7.1/§7.2** contre la maquette v3 **re-attachée**
   (relief, hiérarchie des labels, espacements).
5. **§7.4** : confirmer emplacements capa + bandeau doublon.
6. **Test live de l'attribution réseau** : reprendre « Batalha em Seattle »
   (DVD, id `0000227`), l'attribuer à une biblio, vérifier déplacement des
   exemplaires + `network_admin_cross_library_actions_log`.
7. Nettoyage : ❓ grep résiduel `mode-complete` (CSS de mode) à supprimer si présent.

## 5. Garde-fous process (à respecter en session neuve)

- 🥇 **Règle d'or** (CLAUDE.md) : jamais deux push concurrents. **+ corollaire
  ajouté ce jour** : sérialiser ses **propres** push — ne jamais enchaîner un
  push tant que le pipeline Woodpecker du précédent n'est pas **vert**.
  *Cadence : l'agent est une fusée, Woodpecker un train à vapeur — coordonner,
  ne pas dépasser.*
- 🛑 **Horodatage migration** = UTC **exact** à la seconde, strictement > max du
  dossier ; si sessions parallèles, `max+1s`. Vérifier le max **juste avant** de
  nommer (une session parallèle peut avoir ajouté une migration).
- MCP `execute_sql` = **lecture seule** ; jamais `apply_migration` via MCP ni
  SQL Editor pour le schéma. Les migrations sont appliquées par **Woodpecker**.
- Sessions parallèles : `git fetch` + `git status` avant de committer/pousser —
  le working tree est **partagé** (vérifier qu'aucun travail non commité n'est
  emporté/écrasé).
- Build + `npm test` (parité i18n bloquante) avant tout push de code.
- Commits : Conventional Commits ASCII ; `[CI SKIP]` seulement sur commits
  doc-purs et **jamais** en tête d'un push contenant une migration.
