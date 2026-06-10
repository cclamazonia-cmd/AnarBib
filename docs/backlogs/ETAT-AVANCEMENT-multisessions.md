# AnarBib — État d'avancement multi-sessions

> **But.** Consolider en un seul endroit git-tracké les acquis de **toutes les
> sessions** (en parallèle, en cours et archivées), pour ne pas perdre la trace
> du travail accompli.
>
> **Statut des sources.** `REGISTRE_decisions.md` = **source de vérité normative**
> (décisions, préséance). Ce document = **photographie d'avancement** (qui a livré
> quoi, où ça en est) — il référence le REGISTRE, ne le remplace pas.
>
> **Contexte multi-sessions.** Plusieurs sessions Claude travaillent en parallèle
> sur un **worktree git partagé** (cf. 🥇 règle d'or CLAUDE.md). Chaque commit porte
> un trailer `Session: <nom>`. Ce document agrège leur travail par chantier à partir
> du `git log`.
>
> **Dernière mise à jour : 2026-06-10.** Backlog formel précédent : v28 (2026-06-08).
> Légende : ✅ livré & déployé · 🟢 quasi fini · 🟡 en cours · ⬜ décidé, non implémenté.

## Vue d'ensemble

| Chantier | Statut | Réf. REGISTRE |
|---|---|---|
| **MULTI** — multi-appartenance lectrice | ✅ livré & déployé | §20 |
| **VALID** — validation physique | ✅ livré & déployé | §9 |
| **#CL.10** — lecture agrégée | ✅ livré & déployé | §20 (B.3/D.1) |
| **Catalogação** — qualité, étiquettes, autorités | 🟡 en cours | CAT-* |
| **Importações / Exportações** — refonte | 🟡 en cours | IMP-*, §21-22 |
| **Login / Auth** — robustesse | 🟢 quasi fini | #LOGIN-FIX |
| **OPAC** — réseau intellectuel | ✅ livré | §18 |

---

## ✅ MULTI — Multi-appartenance lectrice (§20)
*Session : MULTI P5. Livré 08-10/06/2026.*

Une lectrice peut appartenir à plusieurs bibliothèques, chacune cloisonnée
(rôle, restrictions, cotisations, validation), sans agrégation de privilèges ni
confiance transitive (MULTI-γ.1).

- **Backend** — P1 modèle 8 statuts + validation par-appartenance + n° lectrice
  local + journal (`20260608145936`) ; P2 `fn_my_memberships_status`
  (`20260608151435`) ; P3 gate de circulation + triggers emprunt/consulta —
  MULTI-F.1 cond. 1-4 (`20260608153720`) ; P4 auto-inscription `request_membership`
  (garde β.1 anti-inscription-en-masse) + validation staff `validate_membership`
  (`20260608154320`).
- **Frontend (P5)** — onglet « Mes biblios » (statut/validation/cotisation par
  appartenance) ; bandeau de contexte « biblio courante » ≥2 appartenances
  (re-thème `--brand-*` + sessionStorage) ; auto-inscription lectrice ; UI
  validation staff (onglet `Validações`). Commits `ceea68c`, `0135a18`.
- **#CL.10 / B.3 / D.1** — lecture agrégée : tag biblio d'origine par ligne de
  circulation + signal « même titre dans 2 biblios » (frontend pur, `library_id`
  → biblio résolu côté client). Commit `49d464a`.
- **MULTI-F.1 cond. 5** (plafonds de circulation simultanée) ✅ livré par une session parallèle (`4b5934d`, 10/06) — les 5 conditions de la porte sont posées.

## ✅ VALID — Validation physique (§9)
*Session : MULTI P5. Livré 10/06/2026.*

Filtre anti-infiltration : validation **en présentiel par le staff** (canal humain
premier). Le logiciel met la demande sous les yeux d'un·e humain·e qui vette.

- Écran staff **unitaire** (onglet Validações, `list_pending_validations` +
  `validate_membership`).
- **C1** valider en lot · **C3** notification staff « compte en attente »
  (`membership_validation_requested` → e-mail biblio) · **C4** compteur (badge
  onglet + card « Inscrições pendentes » dans *Trabalho do dia*). Commits
  `174d24e`, `9e0ac43`, `11f19fd`, `d54d821`.
- **C2 sans code** : appartenances coordenador créées `active` par promotion
  d'équipe (confiance par rôle).
- **Notifs e-mail 10 langues** : `validation_confirmed` (lectrice) +
  `membership_validation_requested` (staff).

## 🟡 Importações / Exportações — refonte (IMP, §12 ; symétrie §8/21-22)
*Session : Import/Export. En cours (Lots 0→5).*

- **Lot 0** — API publique d'import : 8 RPC + colonne `library_id` (`25afc23`).
- **Lot 1** — refonte `ImportacoesPage` maquette v7 (`ce39028`) + fix rules-of-hooks.
- **Lot 2** — candidate lookup câblé au staging (`dcb3c54`) ; **2b** dépôt
  partenaire (bucket + RPC, format maison) (`e174af8`).
- **Lot 3a** — infrastructure OAI-PMH harvest (`57a2af1`).
- **Lot 4** — parser MARC/UNIMARC (XML + ISO 2709) dans
  `process-partner-catalog-import` (`d52abbe`).
- **Lot 5** — sérialiseur catalogue CSV/MARCXML/JSON + export de lote (RPC + EF)
  (`045b05c`, `4d09e76`, `e6d9822`) ; i18n export dédiée.
- **IMP-14** — durcissement : wrappers d'import en coordenador-only (`dbf0d64`).
- Pipeline cible create→dispatch(EF)→staging→review→promote (déjà câblé, IMP-9).

## 🟡 Catalogação — qualité, étiquettes, autorités (CAT-*)
*Session : Catalogação. En cours.*

- **Exemplaires** — édition inline des étiquettes publiées (`3647f44`) ; sélection
  de champs + wizard de découverte (`8d4ad45`) ; auto-tombo `fn_next_tombo` par
  biblio (`ce8209f`, `4bd188b`) ; guards de publication + auto-exemplaire +
  messages localisés (`5163650`).
- **Phase 2 visibilité** — catalogue public reflète la visibilité exemplaire
  (CAT-B8, `c3c22e6` ; graduation `f2a7f89`).
- **Qualité** — nettoyage lot A (langues/doublons/coquilles, `813d04c`),
  harmonisation editora lot C, similar_books scoring v4 (`01e95cc`), normalisation
  `tipo_material` (`b633c82`), audit ISBN/CDD (`ebdd0c6`).
- **Autorités** — socle ateliers d'autorités + notes bio multilingues (CAT-I1/I2,
  workflow de revue, fédération 8 sources de métadonnées CAT-D5c).
- **RLS** — policies `staff_read` sur books + exemplares (`6dc8f48`).

## 🟢 Login / Auth — robustesse (#LOGIN-FIX)
*Session : Login-fix. Quasi fini.*

- Redirection post-login ne dépend plus de `themeReady` (404 manifests ~14s)
  (`f0e8aac`) ; spinner de transition dès le clic (`562549e`, `0daa62e`).
- Nettoyage thème : `useTheme` réduit à `settledSlug` ; manifests chargés depuis
  le bucket Storage (pas l'origin) — un aller-retour de revert sur le sujet
  (`a75cc96` puis `afcf8e3`).
- Robustesse login : dedup `loadProfile` + garde-fou forward (H4, `1e44a22`).
- CHECK constraints : chemins Storage relatifs, jamais d'URL complète (`5e46915`).

## ✅ OPAC — réseau intellectuel (§18)
- `shared_count` inclut les co-signatures dans le réseau intellectuel (`11e8c8b`).

---

## ⬜ Prochaines specs candidates (décidées, non implémentées)

| Spec | Réf. | Note |
|---|---|---|
| **PARTNER** — partenariat biblios | §21 | Partage inter-biblios **sur consentement** (opt-in par partenariat, réciproque). C'est le canal contrôlé du cross-biblio (vs MULTI-γ.1 non transitif). |
| **ILL** — prêt inter-bibliothèques | §22 | Périmètre `library_partnerships` ; dépendance CAT-B8 levée (visibilité exemplaire). |
| Finition import/export | §12 | Compléter la refonte (Lots en cours). |

---

*Maintenu collectivement. Toute session qui livre un chantier : ajouter/mettre à
jour sa ligne ici (avec commit + date), et le REGISTRE pour la décision normative.*
