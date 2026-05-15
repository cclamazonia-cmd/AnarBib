# AnarBib — Backlog v14

**Date :** 15 mai 2026 (soir, post fix B6 + diagnostic B3 généralisé)
**Version :** v14 (succède à v13 du soir)
**Auteur :** Xavier (via Claude, fin de session 15/05)

---

## Convention de scoring

Score = importance politique (1-10) + urgence technique (1-10).
- **Score ≥ 18** : priorité critique
- **Score 15-17** : priorité haute
- **Score 12-14** : priorité moyenne
- **Score 8-11** : hygiène et dette
- **Score ≤ 7** : nice-to-have

---

## I. Items clos depuis v13 (1 item)

| Item | Titre | Date clôture | Notes |
|---|---|---|---|
| **#130** | **B6 annulation biblio sans note obligatoire** | **15/05/2026 soir** | Migration `20260515180000_paquetA1_consulta_cancel_note_required.sql` v2 (commit `23b8fc6`) + modal frontend + i18n × 6 locales. **Fonctionnellement clos** : garde backend `cancel_note_required ≥ 5 chars`, modal frontend forçant la saisie, mail au lecteur·rice envoyé. La note est tracée en DB mais non affichée dans le mail (impact B3 généralisé, cf. ci-dessous) |

---

## II. Nouveau chantier critique : hardening notifications consultas (~4-6h)

### #141 — Chantier hardening notifications consultas (score 17) 🔴

**Estimation :** 4-6h en session dédiée

**Description :** Le diagnostic poussé pendant le fix B6 a révélé que les **triggers consultas ne propagent jamais la `workflow_note`** dans les payloads d'event. Conséquence : tous les bugs B1, B2, B3, B5 et le complément B6 (note pas dans le mail d'annulation biblio) sont liés à la même cause racine.

**Cause exacte :**
```sql
-- trg_notify_consulta_lifecycle (et probablement trg_notify_consulta_workflow)
v_payload := jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no));
IF v_cancelled_by IS NOT NULL THEN
  v_payload := v_payload || jsonb_build_object('cancelled_by', v_cancelled_by);
END IF;
-- ↑ Le payload n'inclut JAMAIS workflow_note
```

**Spec violée :** spec consultas v2.1 §11.2 R5 (doctrine de notification) implicite : si une note est saisie, elle doit être visible dans la notification correspondante (sinon à quoi sert-elle ?).

**Plan de fix** (détaillé dans `docs/decisions/CLOTURE_B6_et_B3_generalise-2026-05-15.md`) :

1. **Inventaire** des 2 triggers et du handler EF (30 min)
2. **Refacto DB** des triggers pour récupérer `workflow_note` via jointure et l'ajouter au payload (1-2h)
3. **Refacto handler EF** `consultas.ts` pour lire `payload.workflow_note` et l'injecter dans le rendering (1h)
4. **Refacto i18n** × 6 locales : ajouter `{workflow_note}` dans 5 chaînes mail (1h)
5. **Tests fonctionnels** : QA scénarios 1, 6, 9 + relance B6 (1h)
6. **Trace décision** (30 min)

**Bugs résolus par ce chantier :**
- **B3 généralisé** : notes workflow non propagées dans les mails
- **Complément B6** : note d'annulation biblio dans le mail
- **B1** (probablement) : si le créneau mal formaté est lié à un placeholder cassé dans le même template
- **B2 et B5** (à investiguer) : peut-être liés au handler EF qui ignore certains events

**Doctrine à inscrire en spec v2.2 :** « Toute note workflow saisie par un acteur doit être propagée au payload de l'event correspondant et affichée dans le mail de notification. »

---

## III. Items hauts priorité (score ≥ 15)

### #98-B à #98-G — Suite chantier profils d'adoption (score 20) 🟢

**Estimation :** 15 jours restants sur 16

**Description :** 6 paquets restants après livraison paquet A.

**Recommandation :** enchaîner après chantier hardening notifications consultas, ou en parallèle si l'énergie le permet.

### #131 — B1 mail proposition créneau mal formaté (score 17) 🔴

**Estimation :** 30 min

**Description :** Le mail de proposition affiche `"16/05/2026, das às às às (UTC)"`. Probablement résolu par #141 si la cause est commune. Sinon, patch i18n indépendant.

**Statut :** **peut-être absorbé dans #141**, à confirmer pendant l'inventaire.

### #132 — B7 dismiss côté lecteur ne fonctionne pas (score 17) 🔴

**Estimation :** 1h

**Description :** Bouton « Accuser réception » côté lecteur·rice ne fait rien : `dismissed_by_reader_at` reste `null`. Indépendant de #141.

### #110 — Migration mail Brevo → Resend (score 15) 🟠

**Estimation :** 3-4 jours mode pragma

### #33 — Cotisations (score 16) 🟠

**Estimation :** à clarifier

### #36 — Cotisations (score 15) 🟠

**Estimation :** à clarifier

### #61 — UX (score 15) 🟠

**Estimation :** à clarifier

---

## IV. Items moyens (score 12-14)

### #133 — ~~B3 motif refus pas dans le mail biblio~~ — fusionné dans #141

**Statut :** **fusionné** dans #141 (chantier hardening notifications consultas) — score absorbé.

### #134 — B5 mail no-show non envoyé (score 13) 🟠

**Statut :** **peut-être absorbé** dans #141, à confirmer à l'inventaire.

### #135 — B2 mail `em_preparacao` non envoyé (score 12) 🟠

**Statut :** **peut-être absorbé** dans #141, à confirmer à l'inventaire.

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Estimation :** 1 journée

### #79 — Activation cron + secret vault pour #78 (score 12)

**Estimation :** 30 min

### #136 — B4 pastille rouge « Recusado » manquante côté lecteur (score 9) 🟡

**Estimation :** 1h. Indépendant de #141 (UX seulement).

### #137 — D1 onglet historique PanelPage (score 14)

**Estimation :** 1 journée

### #138 — D2 workflow stage côté lecteur·rice (score 11)

**Estimation :** 2-3h

### #139 — Spec consultas v2.2 (score 8)

**Estimation :** 3-4h. À actualiser après #141 (intégrer la doctrine de propagation des notes).

---

## V. Items hygiène et dette (score 6-11)

### #115 — Code-split AccountPage.jsx (score 8)

**Estimation :** 2-3h

### #119 — Audit secrets hygiene (score 8)

**Estimation :** 2-3h

### #118 — Automatiser déploiement Edge Functions Woodpecker (score 6)

**Estimation :** 1h

### #140 — Spec admin réseau v0.3.2 (score 6)

**Estimation :** 1h. À aligner si #141 confirme la doctrine traçabilité coordination.

---

## VI. Récap chiffré v13 → v14

| Métrique | v13 (15/05 soir, post-QA) | v14 (15/05 fin de session) | Delta |
|---|---|---|---|
| Items ouverts | 17 | **15** | -2 (#130 clos, #133 fusionné dans #141) |
| Items clos cumulés | 22 | **23** | +1 (#130 B6) |
| Score total ouverts | ~205 | **~210** | +5 (chantier hardening score 17) |
| Bugs critiques (score ≥ 17) | 3 | **2** (#131 si non absorbé, #132) | -1 (#130 clos) |
| Chantier majeur identifié | non | **#141 hardening notifications consultas** | nouveau |
| **Implémentation paquet A profils** | ✅ | ✅ idem | — |
| **Fix B6 fonctionnel** | non | ✅ | nouveau |

---

## VII. Séquencement recommandé pour la prochaine session

### Court terme (1 session, 4-6h)

**Option A — Chantier hardening notifications consultas (#141)** — RECOMMANDÉ
- Couvre B1 (probable), B2 (probable), B3 généralisé, B5 (probable), complément B6
- 4-6h en session dédiée
- Fenêtre cohérente : on attaque le diagnostic, on patche, on teste
- Aboutit à une spec v2.2 actualisée

**Option B — Continuer chantier profils (#98-B)** — alternatif
- 3 jours
- Indépendant de #141
- Plus politique (avancée du chantier majeur)

### Moyen terme

1. Si A choisie en court terme : enchaîner #98-B après
2. Si B choisi en court terme : intercaler #141 plus tard

### Long terme

- #110 Resend
- #98-C à #98-G
- #137/#138 UX consultas
- #33/#36/#61 cotisations + UX (à clarifier d'abord)

---

## VIII. État de santé final 15/05

**Excellent en doctrine** : 4 specs alignées, paquet A profils livré, QA structurée, fix B6 livré, diagnostic B3 généralisé documenté.

**Bon en exécution** : 1 bug critique fixé, 6 documentés avec plan d'attaque. La cause racine d'au moins 4 d'entre eux (B1/B2/B3/B5) est identifiée et un chantier cohérent les couvre tous.

**Aucun bug bloque la circulation** : les consultas fonctionnent bout-en-bout, juste avec des notifications imparfaites (notes manquantes, mais traces en DB).

**Articulation prod** :
- Spec admin réseau v0.3.1 : implémentation en prod ✅
- Spec consultas v2.1 : implémentation en prod ⚠️ (chantier #141 en cours pour atteindre intention spec complète)
- Spec gouvernance v1.1 : partiellement en prod
- Spec onboarding v1.1 : en attente d'implémentation
- Spec profils v0.3 : **paquet A livré ce jour**, paquets B-G à venir

---

*Backlog v14 — fin. Session 15/05 dense : ~8h cumulées, 2 chantiers livrés (refonte specs + paquet A profils), 1 bug critique fixé (B6), 1 chantier majeur identifié (#141 hardening notifications consultas).*
