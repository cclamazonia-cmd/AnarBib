# AUDIT — Backlog v29 vs réalité prod (2026-06-10)

> **Objet.** Repérer ce que le backlog v29 (10/06) présente comme « à faire »
> (🟢 PRÊT / 🟠 EN COURS / 🟡 CADRÉ / ⬜) alors que **c'est déjà livré et déployé
> en production**. Déclencheur : intuition du lead que « on a beaucoup avancé et
> que ça n'a pas été réellement inscrit ».
>
> **Méthode.** Backlog v29 (`docs/backlogs/AnarBib-Backlog-2026-06-10-v29.docx`)
> croisé avec : (1) la prod réelle = projet Supabase `uflwmikiyjfnikiphtcp`
> (2675 livros / 2719 exemplares — match exact de la capture du 10/06) ;
> (2) les migrations sur disque `supabase/migrations/` ; (3) le code frontend.
> Trace non-normative (préséance : REGISTRE > spec > backlog).

## Constat global

Le backlog v29 est **en retard sur sa propre réalité**, de deux façons :

1. **Incohérence interne** — l'intro, les fiches (section C) et les acquis
   (section E) déclarent « livré », mais le **tableau macro (B)**, l'**ordre de
   priorité (B.2)**, les **quick-wins (D.0)** et les **tableaux de sous-tickets
   (D)** gardent les vieux statuts « à faire ». Le doc se contredit lui-même.
2. **Retard sur la prod** — des items que *même la section E* ne mentionne pas
   sont déjà en prod (chaîne exemplares complète, OPAC facettes/sujets,
   circulation 3 valeurs).

Cause probable : v29 a été incrémenté en recopiant la structure du v27/v28 sans
réconcilier les tableaux d'état avec ce que les sessions parallèles ont déployé.

---

## A. #CATALOGACAO — Phase 1-2-3 ENTIÈREMENT en prod (déphasage majeur)

Le backlog (fiche C.5, tableau D) présente le chemin critique comme à peine
entamé : `#CATALOGACAO` 🟠 EN COURS, **P1.1 🟢 PRÊT « confirmer F.10 »**,
**P1.2-P1.6 ⬜ « après P1.1 »**, arbitrage **F.10 « 4 confirmations avant le push
de P1.1 »** encore ouvert. **Réalité : tout est déployé.**

| Item backlog | Statut backlog | Réalité prod | Preuve |
|---|---|---|---|
| P1.1 migration mutualisée exemplares (provenance + destination) | 🟢 PRÊT, F.10 à confirmer | **LIVRÉ** | `20260603073556_exemplares_provenance_destination.sql` appliqué ; colonnes `circulation_policy`, `visibility`, `source_library` présentes ; **2719/2719 exemplares ont `circulation_policy` rempli** (backfill fait) |
| P1.2 seed padrão → exemplaire + RPC édition policy/visibility | ⬜ après P1.1 | **LIVRÉ** | `20260603075434_p1_2_publish_exemplar_draft_destination_seed.sql` ; `publish_exemplar_draft` en prod |
| P1.3 doublon fédéré + `api.attach_exemplar` (CAT-B5) | ⬜ après P1.1 | **LIVRÉ** | `20260603140222_p1_3b_api_attach_exemplar.sql` ; **`api.attach_exemplar` existe en prod** |
| P1.4 filtre public `visibility` + matrice d'actions | ⬜ après P1.1-P1.2 | **LIVRÉ** | `20260603142749_p1_4a_filtre_public_visibility.sql` + `20260608143145_catalog_exemplar_visibility_filter.sql` |
| P1.6 frontend onglet Exemplaires | ⬜ dernier de la vague | **LIVRÉ** | `ExemplarDraftForm.jsx` en prod (saisie biblio intuitive + dernier tombo, #UX-CAT 10/06) |
| F.10 « 4 confirmations avant push P1.1 » | arbitrage ouvert | **CADUC** | la migration est poussée et tourne ; l'arbitrage n'a plus d'objet |
| TRA-v3 maquette v3 (aperçu live, jauge essenciais 3/3, hints, validations) | 🟢 PRÊT « référence de design » | **LIVRÉ** | visible sur la capture prod du 10/06 (« Pré-visualização · ESSENCIAIS 3/3 », hints, aperçu live) |
| TRA-2c / TRA-3 / TRA-4 / TRA-5 (Track A Lots 2c→5) | 🟠/🟡/🟡/✅ (mélangés) | **LIVRÉ** | section E elle-même (CAT-E8) dit « Track A COMPLET, solde TRA-2c/3/4/5 » — les lignes du tableau D n'ont pas suivi |
| CAPAS-P1 (fix chemin capa) | 🟢 PRÊT (quick-win #5) | **LIVRÉ** | section E (CAT-C5) « module capas P1-P3 livré » |
| CAT-E6 « circulation 3 valeurs » | 🟡 DIFFÉRÉ | **LIVRÉ** | `20260606114851_circulation_default_three_values.sql` |

➡️ **#CATALOGACAO devrait être ✅ BOUCLÉ (Phase 1-3 + Track A + capas), pas
🟠 EN COURS.** Reste réellement ouvert : Track C résiduel éventuel (à confirmer),
les items OPAC aval (section B ci-dessous, dont certains aussi livrés).

---

## B. OPAC / découverte — partiellement livré (marqué « à faire »)

`#CATALOG-EXT` 🟡 PARTIEL « aval de #CATALOGACAO ». Or plusieurs items sont déjà
en prod :

| Item | Statut backlog | Réalité | Preuve |
|---|---|---|---|
| #OPAC7 facettes latérales (`api.catalog_facets_v1`) | 🟡 « aval filtre visibility » | **LIVRÉ** | `20260607225547_opac_catalog_facets_v1.sql` ; `api.catalog_facets_v1` existe en prod |
| #OPAC8 nuage « Sugestões de assuntos » | 🟡 RebAL | **LIVRÉ (backend)** | `20260608074214_opac_subjects_cataloging.sql` |

➡️ À reverser en ✅ (au moins le socle backend) ; vérifier le câblage UI avant
de clore définitivement.

---

## C. Hygiène / sécurité — déjà fait, encore listé

| Item | Statut backlog | Réalité | Preuve |
|---|---|---|---|
| #HYG-ui-assets — déployer migration `20260605170000` | 🟢 PRÊT « à déployer » (quick-win **#1**, B.2 **rang 1**) | **DÉPLOYÉE** | `20260605170000_scope_library_ui_assets_policies` présente dans `schema_migrations` prod (+ correctifs `20260608002842`, `20260608161818`) |
| #HYG-REG-1 — réinscrire §17-26 au REGISTRE | 🟢 PRÊT « préalable doctrinal » (D.0 #4, B.2 rang 2, tableau #HYG) | **SOLDÉ** | l'**intro du v29 et la section E** le disent explicitement (« #HYG-REG-1 soldé, foyer normatif complet ») — seuls les tableaux d'état n'ont pas suivi |

---

## D. Incohérences internes du document (fiche dit fait / tableau dit à-faire)

Ces items sont déclarés clos **ailleurs dans le même backlog** mais gardent un
statut « actif » dans le tableau macro B et/ou les annexes :

| Item | Dit clos en… | Mais marqué « actif » en… |
|---|---|---|
| **#BIBLIO** | C.1 « ✅ CLOS 08/06 » | tableau B ligne 1 « 🟠 EN COURS (étape 8) » |
| **#NOTIFY-Painel-acts** | C.8 « ✅ LIVRÉ 08/06 » | tableau B ligne 8 « 🟡 CADRÉ » |
| **#110 R.6 / R.7** | C.6 « ✅ CLOS 05/06, R.6+R.7 exécutés » | D.0 #8 « 🟡 À PLANIFIER » ; B.2 rang 8 « à faire » |
| **#CL.10 / #CL** | C.4 « ✅ BOUCLÉ 10/10 » | cohérent (OK) — cité pour mémoire |
| **spec-multi-appartenance** | C.12 « ✅ implémentée 10/06 » | tableau D #MODEL « 🟡 FIGÉE v0.3 » |

---

## E. Index & statuts de specs périmés (effet de bord)

- **`docs/backlogs/INDEX.md`** annonce encore **« Version courante v26 »** alors
  que v27, v28 (archive/) et **v29** (racine) existent. À réaligner sur v29 +
  pointer la source vivante `journal/sessions/ETAT-AVANCEMENT-multisessions.md`.
- **`docs/specs/INDEX.md`** garde des statuts périmés :
  - `spec-multi-appartenance-lecteur` 🟡 → **implémentée** (10/06).
  - `spec-validation-physique` 🟡 → **livrée** (VALID C1-C4, §9 bouclée).
  - `spec-migration-mail-resend` 🟠 « R.6 le 05/06 » → **#110 CLOS** (Brevo
    entièrement retiré).
  - `spec-sources-externes-autorites` 🟠 « reste VIAF/ISNI/Wikidata +
    authority_lookup » → backlog section E (CAT-D5a-d COMPLET) +
    EF `authority_lookup` / `catalog_metadata_lookup` présentes → **à requalifier**.

---

## Recommandations

1. **Réconcilier le backlog (priorité).** Passer en section E / ✅ : tout le bloc
   #CATALOGACAO Phase 1-3 (P1.1→P1.6), TRA-2c/3/4/5, TRA-v3, CAPAS-P1, CAT-E6,
   #OPAC7/#OPAC8 (socle), #HYG-ui-assets, #HYG-REG-1 ; et **mettre à jour les
   tableaux B, B.2, D.0 et D** pour qu'ils cessent de contredire les fiches.
   Clore les arbitrages caducs (**F.10**, et **F.6** étape 8 déjà débloquée).
2. **Recalculer #CATALOGACAO** : 🟠 EN COURS → ✅ BOUCLÉ (sous réserve d'un
   reliquat Track C / OPAC UI à confirmer).
3. **Réaligner `docs/backlogs/INDEX.md`** sur v29.
4. **Rafraîchir `docs/specs/INDEX.md`** (4 statuts ci-dessus) et **archiver les
   specs achevées** (chantier séparé — cf. liste proposée au lead).

---

*Audit produit le 2026-06-10. Trace non-normative. Vérifications DB faites sur
le projet prod `uflwmikiyjfnikiphtcp` ; migrations constatées sur disque.*
