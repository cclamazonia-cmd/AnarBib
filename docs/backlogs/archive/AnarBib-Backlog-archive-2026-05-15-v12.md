# AnarBib — Backlog v12

**Date :** 15 mai 2026 (matin, post sprint hygiène)
**Version :** v12 (succède à v11 du 14/05 soir)
**Auteur :** Xavier (via Claude, session refonte 4 specs + sprint hygiène)

---

## Convention de scoring

Score = importance politique (1-10) + urgence technique (1-10).
- **Score ≥ 18** : priorité critique, à attaquer cette semaine
- **Score 15-17** : priorité haute, prochaine fenêtre disponible
- **Score 12-14** : priorité moyenne, dans le mois
- **Score 8-11** : hygiène et dette, à planifier en sprint dédié
- **Score ≤ 7** : nice-to-have, traité opportunistiquement

---

## I. Items clos depuis v11 (4 items)

| Item | Titre | Date clôture | Commits / refs |
|---|---|---|---|
| #121 | Spec consultas v2 → v2.1 (refonte post-implémentation) | 15/05/2026 | 1083 lignes, raffinements R1-R6 inscrits |
| #122 | Spec admin réseau v0.3 → v0.3.1 (raffinements R1-R7) | 15/05/2026 | 1037 lignes, doctrine notifications figée |
| #123 | **Spec gouvernance v1.0 → v1.1** (cohérence post admin réseau + mode `full_governance`) | 15/05/2026 | 1379 lignes, articulation avec profils v0.3 |
| #124 | **Spec onboarding v1.0 → v1.1** (workflow unanime + volet 0 profils) | 15/05/2026 | 823 lignes, 17 events, table votes |

**Trio admin réseau / consultas / gouvernance + onboarding** : 4322 lignes de spec, 281 KB. Forment un **socle cohérent** prêt pour les chantiers à venir.

---

## II. Items ouverts — Priorité critique et haute (score ≥ 15)

### #98 — Chantier profils d'adoption (score 20) 🟢 **DÉMARRABLE**

**Estimation :** ~16 jours de dev, 4 semaines calendaires

**Description :** 4 axes orthogonaux par bibliothèque :
- `catalog_mode` : `local_only` | `network_published`
- `circulation_mode` : `off` | `informal` | `full_sigb`
- `network_mode` : `isolated` | `observer` | `federated`
- `governance_mode` : `informal` | `staff_roles` | `full_governance`

3 profils-types A/C, B, D définis dans la spec. 7 paquets A-G (~16j cumulés). Doctrine transitions par type 1-4.

**Spec :** `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lignes, livrée 13/05).

**Prérequis BLOQUANT :** ✅ Tous résolus :
- ✅ Paquet F admin réseau clos (13/05)
- ✅ Spec admin réseau v0.3.1 inscrite (15/05, #122)
- ✅ Spec gouvernance v1.1 inscrite (15/05, #123) — mode `full_governance` documenté
- ✅ Spec onboarding v1.1 inscrite (15/05, #124) — volet 0 wizard intégré

**Articulations spec → spec (v1.1) :**
- Spec gouvernance v1.1 §1.4 : décrit le mode `full_governance` (cette spec = doctrine intégrale)
- Spec gouvernance v1.1 §6.11 : RPCs `fn_team_*` conditionnées par `governance_mode` à activer au paquet F
- Spec onboarding v1.1 §6.2 : volet 0 du wizard demande les 4 choix avant les autres volets
- Spec consultas v2.1 §13 : compatibilité avec `circulation_mode` (off → pas d'onglet, informal → pas de cotisations, full_sigb → workflow complet)

**Impact débloqué :** Annexe A consultas (colonne `circulation_mode`), conditionne #110 migration Resend (cohérence anti-tracking).

**Démarrage Paquet A possible :** dès aujourd'hui (15/05 après-midi) ou prochaine session selon énergie.

---

### #33 — Cotisations (score 16)

**Description :** Description héritée de v9, à clarifier.
**Estimation :** À évaluer après clarification.

---

### #110 — Migration mail Brevo → Resend (score 15)

**Estimation :** ~3-4 jours (mode pragma) ou 10 semaines (spec complète)

**Description :** Migration anti-tracking militante. Brevo trackait via `sendibt3.com` (CDN inaccessible aux usagers VPN/anti-tracker). Resend ne tracke pas par défaut.

**Spec :** `docs/specs/spec-migration-mail-resend.md` (161 Ko, rédigée 13/05).

**Setup préalable :** `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN` fait le 07/05.

**Note d'ordonnancement :** Indépendant de #98 mais le séquencer après permet de bénéficier des handlers `notify-event` déjà alignés sur `_shared/transport/email.ts`.

---

### #36 — Cotisations (score 15)

**Description :** Description héritée de v9, à clarifier.
**Estimation :** À évaluer après clarification.

---

### #61 — UX (score 15)

**Description :** Description héritée de v9, à clarifier.
**Estimation :** À évaluer après clarification.

---

## III. Items ouverts — Priorité moyenne (score 12-14)

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Estimation :** ~1 jour
**Description :** EF qui consomme les events du log `network_admin_cross_library_actions_log` pour générer un digest hebdomadaire des actions transverses (cooptations, retraits, etc.) à destination des admins réseau.

---

### #79 — Activation cron + secret vault pour #78 (score 12)

**Estimation :** ~30 minutes
**Description :** Activer le job pg_cron qui appelle l'EF #78. Stocker le secret webhook dans Supabase Vault. Inactif depuis paquet C.5c-bis.

---

## IV. Items techniques et hygiène (score 6-11)

### #115 — Code-split AccountPage.jsx (score 8)

**Estimation :** ~2-3 heures
**Description :** AccountPage.jsx est passé à ~110 KB / ~1730 lignes après les patches du paquet 27. Contribue au warning Vite >500KB chunk. Découper en sub-composants lazy-loaded (onglets séparés).

---

### #119 — Audit secrets hygiene (score 8)

**Estimation :** ~2-3 heures (cold session dédiée)
**Description :**
- Audit/rotation Codeberg tokens (`codeberg.org/user/settings/applications`)
- Vérifier `.woodpecker.yml`
- Windows Credential Manager (`control.exe /name Microsoft.CredentialManager`)
- Local auth qui casse régulièrement

---

### #116 — LanguagePicker refacto stateless (score 6)

**Estimation :** ~30 minutes
**Description :** Retirer state flags et ISO codes (ES/GB/FR). Afficher noms de langues dans leur propre langue (Português, Français, Castellano, English, Italiano, Deutsch). Codes DB inchangés (`pt-BR`, `fr`, `es`, `en`, `it`, `de`).

---

### #117 — Delete obsolete `C:\Users\accat\AnarBib-functions\` (score 6)

**Estimation :** ~5 minutes
**Description :** Vestige non-git, source de confusion (1h perdue 12/05/2026 quand un fichier Edge Function a été copié dans ce dossier au lieu du repo).

---

### #118 — Automatiser déploiement Edge Functions dans `.woodpecker.yml` (score 6)

**Estimation :** ~1 heure
**Description :** Étape `deploy-edge-functions` dans `.woodpecker.yml` avec secret `SUPABASE_ACCESS_TOKEN`. Aujourd'hui push Codeberg = build frontend seulement, EF déployées manuellement (`supabase functions deploy <name>`).

---

## V. Items consultations (post-paquet 27)

### Phase 6 — Tests E2E consultas (score —)

**Estimation :** 6-8 heures sur 2-3 sessions

**Description :** 4 scénarios à couvrir selon spec v2.1 § 9 Phase 6 :
- Scénario 6 : lecteur refuse créneau, biblio re-propose, lecteur confirme
- Scénario 7 : no-show (créneau passé, lecteur ne vient pas)
- Scénario 8 : lecteur annule une consulta
- Scénario 9 : biblio annule + lecteur dismiss

**Décision documentée v2.1 §11.2 R6** : Phase 6 reportée au profit d'une **QA manuelle structurée (1h)** avec checklist 9 scénarios. Inscrite dans spec consultas v2.1.

**Action restante :** dérouler la checklist en prod, documenter dans `docs/decisions/QA_MANUELLE_consultations-2026-05-XX.md`.

---

### Annexe A consultas — Bug `(nulld, nullx)` (score —)

**Estimation :** 30-45 minutes après #98 paquet A

**Description :** Règles de circulation non-renouvelables affichent « nulld, nullx » dans BibliotecaPage Regimento. Conditionner l'affichage par `circulation_mode === 'full_sigb'` ET `renewable === true`.

**Dépend de :** #98 paquet A (la colonne `circulation_mode` n'existe pas encore sur `libraries`).

---

## VI. Items méta

### #120 — Note de décision session 14/05 (score —)

**Estimation :** ~15 minutes
**Description :** Inscrire dans `docs/decisions/SESSION_paquet-27-cloture-14-05-2026.md` : 7 commits, méthode binaire safe, leçons indentation et encoding, principe SIGB de notification.

**Statut :** ⏸️ À faire (déjà partiellement couvert par le compte-rendu 48h du 14/05).

---

### #125 *(nouveau v12)* — Note de décision session refonte 15/05 (score —)

**Estimation :** ~15 minutes
**Description :** Inscrire dans `docs/decisions/SESSION_refonte-specs-15-05-2026.md` : 4 specs refondues, méthode (lecture exhaustive avant rédaction, inventaire des modifications, refonte cohérence + ajouts doctrinaux), articulations inter-specs, prêt pour démarrer #98.

---

## VII. Décision de séquencement recommandée

Pour la suite des sessions :

1. **Sprint hygiène fin (15/05 après-midi)** : actualiser ce backlog en v12 ✅ (en cours), commit + push des specs ✅ (script exécuté), **optionnel** : #116 LanguagePicker (30 min), #117 delete vestige (5 min), #125 note décision (15 min).

2. **QA manuelle consultations (~1h)** : checklist des 9 scénarios spec v2.1 § Phase 6. Documenter.

3. **Décision politique** : démarrer **#98 profils d'adoption** (16j, 4 semaines, débloque annexe A et conditionne #110 Resend) **OU #110 migration Resend** (3-4j en mode pragma, indépendant).

   - **Si l'énergie est haute** (Xavier a dormi une nuit entière le 14/05) → attaquer #98 paquet A maintenant tant que la fenêtre se prête à un long chantier.
   - **Si la fatigue accumulée pèse** → #110 Resend en mode pragma (3-4j) pour un gain politique tangible à court terme.

**Recommandation Claude v12** : **#98 paquet A** dans la foulée du sprint hygiène, vu que toutes les conditions sont réunies (specs alignées, prérequis bloquants résolus, énergie disponible). Le paquet A est court (~1 jour) et pose les champs DB `catalog_mode`/`circulation_mode`/`network_mode`/`governance_mode` sur `libraries`, ce qui débloque #115 et permet de poser des landmarks dans le code.

---

## VIII. Récap chiffré v11 → v12

| Métrique | v11 (14/05 soir) | v12 (15/05 matin) | Delta |
|---|---|---|---|
| Items ouverts | 14 | 12 | -2 (#121, #122 clos ; #125 ajouté) |
| Items clos cumulés | 13 | 17 | +4 (#121, #122, #123, #124) |
| Score total des ouverts | ~135 | ~133 | -2 (légère décrue) |
| Chantiers majeurs en attente | 5 (#98, #110, #61, #33, #36) | 5 (idem, mais #98 débloqué) | 0 mais #98 = vert |
| Specs livrées | 1 (admin réseau v0.3.1 mentionnée pour inscription) | 4 (admin réseau v0.3.1 + consultas v2.1 + gouvernance v1.1 + onboarding v1.1) | +3 |
| Lignes de spec dans `docs/specs/` | ~5000 | ~9300 | +4322 (refonte) |

**État de santé du backlog au 15/05 matin** : excellent. Toutes les conditions sont réunies pour démarrer #98 profils d'adoption (le prochain gros morceau, 16j). Les 4 specs refondues forment un socle doctrinal cohérent, le code en prod est aligné avec les specs (chantier admin réseau + #114 mails + paquet 27 consultas tous livrés).

**Articulation des specs prêtes** :
- Spec admin réseau v0.3.1 : implémentation entièrement en prod
- Spec consultas v2.1 : implémentation entièrement en prod
- Spec gouvernance v1.1 : partiellement en prod (Lot 1 partiel, Lots 2-3 largement livrés, Lots 4-7 à faire)
- Spec onboarding v1.1 : en attente d'implémentation, prérequis paquet A profils
- Spec profils v0.3 : prête à implémenter, **chantier prochain (#98)**

---

*Backlog v12 — fin.*
