# AnarBib — Backlog v13

**Date :** 15 mai 2026 (soir, post QA consultations)
**Version :** v13 (succède à v12 du matin)
**Auteur :** Xavier (via Claude, session refonte specs + paquet A + QA)

---

## Convention de scoring

Score = importance politique (1-10) + urgence technique (1-10).
- **Score ≥ 18** : priorité critique
- **Score 15-17** : priorité haute
- **Score 12-14** : priorité moyenne
- **Score 8-11** : hygiène et dette
- **Score ≤ 7** : nice-to-have

---

## I. Items clos depuis v12 (5 items)

| Item | Titre | Date clôture | Notes |
|---|---|---|---|
| #98-A | Paquet A profils infrastructure | 15/05/2026 | Migration `20260515170000`, 10 helpers, 15/15 tests OK |
| #116 | LanguagePicker stateless | déjà fait avant la session 15/05 | Confirmé par Xavier en cours de session |
| #117 | Delete obsolete `AnarBib-functions\` | déjà fait avant la session 15/05 | Confirmé par Xavier en cours de session |
| #125 | Note décision session 15/05 | 15/05/2026 | `docs/decisions/SESSION_refonte-specs-paquetA-QA-15-05-2026.md` |
| #126 | QA manuelle consultations | 15/05/2026 | `docs/decisions/QA_MANUELLE_consultations-2026-05-15.md` — 7 bugs détectés |

**Bonus** : cleanup biblio test FRT (action ponctuelle DB, trace `CLEANUP_FRT_2026-05-15.md`).

---

## II. Nouveau chantier critique : patches consultas (~1 journée)

**Issu de la QA manuelle du 15/05 — 7 bugs détectés, à fixer en chantier dédié**

### #130 — B6 annulation biblio sans note obligatoire (score 18) 🔴

**Estimation :** 2-3 heures
**Description :** Quand un·e coordenador·a clique « Anular » sur une consulta, aucune modal ne s'affiche et aucune note n'est exigée. **Contradiction directe avec spec consultas v2.1 §6.2 et §8.1** qui exigent une note obligatoire.
**Doctrine politique :** trace écrite obligatoire de toute décision d'annulation par la biblio (préserve la mémoire collective et permet au lecteur de comprendre)
**Fix :** ajouter modal côté PanelPage + validation backend dans `api.advance_consulta` (raise si `p_target_stage='cancelada_biblioteca'` et `p_workflow_note` NULL ou < 1 char)

### #131 — B1 mail proposition créneau mal formaté (score 17) 🔴

**Estimation :** 30 min
**Description :** Le mail de proposition affiche `"16/05/2026, das às às às (UTC)"` au lieu du créneau formaté correctement. Placeholder cassé dans template i18n `mail.consulta.agendada.body`.
**Fix :** identifier le template dans `_shared/i18n/mail-strings.ts` (× 6 locales), corriger les placeholders, redéployer EF `notify-event`

### #132 — B7 dismiss côté lecteur ne fonctionne pas (score 17) 🔴

**Estimation :** 1 heure
**Description :** Bouton « Accuser réception » côté lecteur·rice ne fait rien : `dismissed_by_reader_at` reste `null` en DB après clic.
**Fix :** investiguer si la RPC `api.dismiss_consulta_cancelled` est appelée, vérifier le handler côté AccountPage, fixer la propagation

### #133 — B3 motif refus pas dans le mail biblio (score 14) 🟠

**Estimation :** 30 min
**Description :** Quand le lecteur·rice refuse un créneau avec un motif, le motif n'apparaît pas dans le corps du mail envoyé à la biblio.
**Fix :** vérifier le payload event `consulta.resposta_creneau`, ajouter le motif dans le template i18n correspondant

### #134 — B5 mail no-show non envoyé (score 13) 🟠

**Estimation :** 30 min
**Description :** Quand la biblio marque `nao_compareceu`, aucun mail n'est envoyé au lecteur·rice. Trigger ou handler manquant.
**Fix :** créer trigger / handler pour event `consulta.nao_compareceu`, clés i18n × 6 locales

### #135 — B2 mail `em_preparacao` non envoyé (score 12) 🟠

**Estimation :** 30 min
**Description :** Mail au lecteur·rice manquant à la transition `solicitada → em_preparacao`. Trigger ou handler manquant.
**Fix :** symétrique à #134

### #136 — B4 pastille rouge « Recusado » manquante côté lecteur (score 9) 🟡

**Estimation :** 1 heure
**Description :** Après refus de créneau par le lecteur, le bloc bleu disparaît mais aucune pastille rouge « Recusado » ne le remplace. Feedback visuel persistant manquant.
**Fix :** ajouter le composant Pastille dans AccountPage selon `schedule_reply_status === 'recusado_leitor'`

**Total chantier patches consultas :** ~6-7 heures, 1 journée. À enchaîner ou prochaine session.

---

## III. Items hauts priorité (score ≥ 15) à choisir pour les sessions suivantes

### #98-B à #98-G — Suite chantier profils d'adoption (score 20) 🟢

**Estimation :** 15 jours restants (sur 16 initiaux)

**Description :** 6 paquets restants après livraison du paquet A.
- **Paquet B** : fonctions de transition + carences + crons (3j)
- **Paquet C** : UI choix profil dans `/painel/configuracoes` (2j)
- **Paquet D** : conditionnalités RLS et RPC selon `governance_mode` (3j)
- **Paquet E** : intégration au wizard onboarding (volet 0) (3j)
- **Paquet F** : activation conditionnelle `governance_mode` sur les RPC gouvernance (2j)
- **Paquet G** : tests d'acceptation finaux + docs utilisateur (2j)

**Spec :** `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lignes)

**Recommandation :** enchaîner après patches consultas pour bénéficier de la fenêtre cohérente

### #110 — Migration mail Brevo → Resend (score 15) 🟠

**Estimation :** 3-4 jours mode pragma

**Description :** Migration anti-tracking militante. Brevo trackait via `sendibt3.com` (CDN inaccessible aux usagers VPN/anti-tracker). Resend ne tracke pas par défaut.
**Setup préalable fait :** `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN` (07/05)
**Spec :** `docs/specs/spec-migration-mail-resend.md`
**Note :** indépendant de #98, peut s'intercaler

### #33 — Cotisations (score 16) 🟠

**Estimation :** à clarifier
**Description :** héritée v11/v12, description à préciser

### #36 — Cotisations (score 15) 🟠

**Estimation :** à clarifier
**Description :** héritée v11/v12

### #61 — UX (score 15) 🟠

**Estimation :** à clarifier
**Description :** héritée v11/v12

---

## IV. Chantier UX consultas v2 (score 11-14)

### #137 — D1 onglet historique PanelPage (score 14)

**Estimation :** 1 journée
**Description :** Ajouter un onglet « Historique » dans PanelPage qui regroupe les consultas terminales (`consultada`, `cancelada_*`, `nao_compareceu`, `expirada`). Permet de désencombrer le tab actif.

### #138 — D2 workflow stage côté lecteur·rice (score 11)

**Estimation :** 2-3 heures
**Description :** Afficher le workflow stage actuel côté AccountPage (« Aguardando análise », « Em preparação », etc.) pour que le lecteur·rice voie où en est sa demande.

### #139 — Spec consultas v2.2 (score 8)

**Estimation :** 3-4 heures
**Description :** Amender la spec consultas pour acter les décisions issues de la QA :
- §7.5 : passer de 3 toggles globaux à 8 toggles fins (correction de doc, conforme à la prod)
- §11.2 nouvelles doctrines :
  - **R7 (nouvelle)** : exception au principe SIGB R5 pour les accusés de réception explicites (consulta créée = mail lecteur·rice OK)
  - **R8 (nouvelle)** : doctrine traçabilité coordination distincte (mail à `library_commons.coordination_email` pour toute action initiée par staff biblio)
  - **R9 (nouvelle)** : `consulta_mail_realizada_enabled = false` par défaut, cohérent SIGB R5

---

## V. Items hygiène et dette (score 6-11)

### #115 — Code-split AccountPage.jsx (score 8)

**Estimation :** 2-3 heures
**Description :** AccountPage.jsx ~110KB / ~1730 lignes. Découper en sub-composants lazy-loaded.

### #119 — Audit secrets hygiene (score 8)

**Estimation :** 2-3 heures dédiées
**Description :** Audit/rotation tokens Codeberg, Windows Credential Manager, etc.

### #118 — Automatiser déploiement Edge Functions Woodpecker (score 6)

**Estimation :** 1 heure
**Description :** Étape `deploy-edge-functions` dans `.woodpecker.yml`

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Estimation :** 1 journée
**Description :** EF qui consomme `network_admin_cross_library_actions_log` pour digest hebdo aux admins réseau.

### #79 — Activation cron + secret vault pour #78 (score 12)

**Estimation :** 30 min après #78

### #140 — Spec admin réseau v0.3.2 (score 6)

**Estimation :** 1 heure
**Description :** Si la doctrine R8 (traçabilité coordination) est confirmée pour consultas v2.2, l'aligner aussi en spec admin réseau v0.3.2 pour cohérence inter-specs.

---

## VI. Récap chiffré v12 → v13

| Métrique | v12 (15/05 matin) | v13 (15/05 soir) | Delta |
|---|---|---|---|
| Items ouverts | 12 | **17** | +5 (7 patches consultas - 2 #116/#117 clos) |
| Items clos cumulés | 17 | **22** | +5 |
| Score total ouverts | ~133 | **~205** | +72 (chantier patches consultas) |
| Bugs critiques (score ≥ 17) | 0 | **3** (#130, #131, #132) | nouveaux |
| Specs alignées prod | 4 | 4 (idem) | stable |
| **Implémentation paquet A profils** | non | ✅ **livrée** | nouveau |

---

## VII. Séquencement recommandé pour la suite

### Court terme (1-2 sessions)

1. **Chantier patches consultas** (#130-#136, ~1 journée) — bugs frais identifiés, fenêtre de motivation bonne
2. **Spec consultas v2.2** (#139, ~3-4h) — clôt le chantier consultas avec doctrine actualisée

### Moyen terme (1-2 semaines)

3. **Paquet B profils** (#98-B, 3j) — enchaîne naturellement après le paquet A
4. **Migration Resend** (#110, 3-4j) — peut s'intercaler entre paquets profils

### Long terme

5. **Paquets C-G profils** (#98-C à #98-G, 12j)
6. **Chantier UX consultas v2** (#137, #138, ~1j+)
7. **Cotisations** (#33, #36) — à clarifier d'abord

---

## VIII. État de santé du backlog au 15/05 soir

**Excellent en doctrine** : 4 specs alignées sur la prod, paquet A profils livré, QA structurée déroulée.

**Mois bon en exécution** : 7 bugs détectés sur les consultations, dont 3 critiques. Mais c'est précisément la valeur d'une QA — détecter avant les utilisateur·rices.

**Pas de dette nouvelle introduite** : tous les nouveaux items proviennent soit de la QA (cahier des charges précis), soit de la suite naturelle du chantier profils.

**Articulation des chantiers prêts** :
- Spec admin réseau v0.3.1 : implémentation en prod ✅
- Spec consultas v2.1 : implémentation en prod ⚠️ (avec 7 bugs à fixer pour atteindre la pleine intention spec)
- Spec gouvernance v1.1 : partiellement en prod
- Spec onboarding v1.1 : en attente d'implémentation
- Spec profils v0.3 : **paquet A livré ce jour**, paquets B-G à venir

---

*Backlog v13 — fin. Session 15/05 dense et productive (~6h cumulées).*
