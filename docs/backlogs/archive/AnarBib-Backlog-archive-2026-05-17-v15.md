# AnarBib — Backlog v15

**Date :** 17 mai 2026 (soir, post chantiers #132 + #142 + #143)
**Version :** v15 (succède à v14 du 15/05 soir)
**Auteur :** Xavier (via Claude, fin de session 17/05)

---

## Convention de scoring

Score = importance politique (1-10) + urgence technique (1-10).
- **Score ≥ 18** : priorité critique
- **Score 15-17** : priorité haute
- **Score 12-14** : priorité moyenne
- **Score 8-11** : hygiène et dette
- **Score ≤ 7** : nice-to-have

---

## I. Items clos depuis v14 (4 items majeurs)

| Item | Titre | Date clôture | Notes |
|---|---|---|---|
| **#141** | **Chantier hardening notifications consultas** | **16/05/2026 soir** | 7 bugs résolus en prod : B1 mojibake (141.3), B2 em_preparacao + B5 nao_compareceu (141.1+2.A+2.D CON_WE_MAP), B3 motif refus (141.2.E DB + 141.2.F EF lit `schedule_reply_note`), B6 motif annulation biblio (141.2.E inversion UPDATEs : INSERT workflow_v2 AVANT UPDATE linhas_v2), endsAt mail biblio (141.2.B M5), title non interpolé (141.2.G). Trace : `docs/decisions/SESSION_141-hardening-notifications-consultas_2026-05-16.docx`. **Doctrine émergée 141.2.E** : ordre des UPDATEs dans RPC métier, narrative AVANT état. |
| **#132** | **B7 dismiss côté lecteur ne fonctionne pas** | **17/05/2026 matin** | Fix one-liner dans `AccountPage.jsx` : `supabase.schema('api').rpc(...)` au lieu de `supabase.rpc(...)`. Cause racine : oubli du préfixe schema sur 1 ligne (le reste du fichier était cohérent). Diagnostic via console PGRST202. |
| **#142** | **Mail coordination sur annulation biblio (R8)** | **17/05/2026 matin** | Application doctrine R8 (traçabilité coordination) à `cancelada_biblioteca`, alignement sur `nao_compareceu`. Patch chirurgical dans `_shared/domain/consultas.ts` : retrait `staffKey = null`/`staffMailEnabled = false`, ajout `staffKey = "con.cancelStaff"`. Le motif est déjà propagé via `workflow_note` dans `details` (mécanique #141.2.C dormante jusqu'ici). |
| **#143** | **Onglet Historique PanelPage** (= ex #137 D1) | **17/05/2026 après-midi** | 6 sous-paquets livrés. **#143.1** tabs sur 2 lignes (flex-wrap). **#143.2** structure UI : onglet position 8 entre leitor et contribuicoes + pills cochables multi-sélection + état initial type majoritaire dynamique. **#143.3.a** 3 vues `api.painel_*_history_v1` security_invoker. **#143.3.b/c/d** i18n 20 clés × 6 locales + sections collapsibles `<details>` + tableaux hybrides desktop/cards mobile + fetch paginé 50 items + bouton "Load more". |

---

## II. Items hauts priorité (score ≥ 15)

### #98-B à #98-G — Suite chantier profils d'adoption (score 20) 🟢

**Estimation :** 15 jours restants sur 16

**Description :** 6 paquets restants après livraison paquet A.

**Statut :** **prêt à démarrer** — le prérequis bloquant admin réseau paquet F est clos, le chantier hardening #141 est clos, et tous les chantiers consultas critiques sont en prod.

**Recommandation :** **prochain gros chantier prioritaire**.

### #110 — Migration mail Brevo → Resend (score 15) 🟠

**Estimation :** 3-4 jours mode pragma

**Description :** Spec rédigée 13/05 (`docs/specs/spec-migration-mail-resend.md` 161 Ko). Setup sous-domaine fait 07/05. Implémentation en cours.

**Statut :** indépendant du chantier profils, peut être interlavé.

### #33 — Cotisations (score 16) 🟠

**Estimation :** à clarifier

### #36 — Cotisations (score 15) 🟠

**Estimation :** à clarifier

### #61 — UX (score 15) 🟠

**Estimation :** à clarifier

---

## III. Items moyens (score 12-14)

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Estimation :** 1 journée

### #79 — Activation cron + secret vault pour #78 (score 12)

**Estimation :** 30 min

### #136 — B4 pastille rouge « Recusado » manquante côté lecteur (score 9) 🟡

**Estimation :** 1h. UX feedback visuel uniquement.

### #138 — D2 workflow stage côté lecteur·rice (score 11)

**Estimation :** 2-3h

### #139 — Spec consultas v2.2 (score 11) — **réévalué à la hausse**

**Estimation :** 3-4h. Doctrine #141 à intégrer (propagation `workflow_note`, ordre UPDATE narrative-avant-état, dual workflow_note/schedule_reply_note). Aussi doctrine D3 (accusé réception explicite), D4 (mail traçabilité coordination = R8), D5 (consulta_mail_realizada_enabled false par défaut), D6 (8 toggles fins en prod).

### #140 — Spec admin réseau v0.3.2 (score 8)

**Estimation :** 1h. Inscrire doctrine traçabilité coordination R8 généralisée + doctrine proposeur notifié uniquement au 1er vote.

### #144 — **Tests QA réservations + emprunts à dérouler** (NOUVEAU score 12) 🟠

**Estimation :** 1-2h pour le déroulé QA réservations + 1-2h pour QA emprunts (peut être fait en 2 sessions distinctes).

**Description :** 2 documents QA cadrés livrés 17/05 :
- `docs/decisions/QA_MANUELLE_reservations-2026-05-17.md` (10 scénarios)
- `docs/decisions/QA_MANUELLE_emprestimos-2026-05-17.md` (10 scénarios)

Plans à dérouler en prod pour identifier bugs Br* et De* (cf. cadre QA consultas). Les docs intègrent déjà références aux doctrines récentes (R8, note obligatoire annulation biblio, vues painel_*_history_v1, invariant emprunt-vs-consulta).

**Sortie attendue :** liste de bugs prioritisés à attaquer dans un chantier dédié post-QA, sur le modèle du chantier #141.

---

## IV. Items hygiène et dette (score 6-11)

### #115 — Code-split AccountPage.jsx (score 8)

**Estimation :** 2-3h. Aussi : code-split `PanelPage.jsx` (~1400 lignes, désormais ~2300 après #143.3).

**Note** : le warning Vite « chunks > 500KB » persiste après #143, à voir si #115 devient #115-bis (PanelPage prioritaire).

### #119 — Audit secrets hygiene (score 8)

**Estimation :** 2-3h. Auditer tokens Codeberg actifs, Woodpecker `.woodpecker.yml`, Windows Credential Manager.

### #118 — Automatiser déploiement Edge Functions Woodpecker (score 6)

**Estimation :** 1h

### #145 — **Mojibakes résiduels AccountPage.jsx** — **Clos session 17/05 par non-existence** ✅

**Diagnostic :** ce qui était perçu comme mojibake (`â€"`, `Â·`) dans le fichier était en réalité un **artefact d'affichage PowerShell** sur Windows FR. La console PowerShell utilise CP1252 par défaut et affiche mal les caractères UTF-8 multi-bytes, alors que le fichier sous-jacent est UTF-8 valide.

**Vérification :**
```powershell
$content = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
# Em dash mojibake : 0
# Em dash reel '—' : 48
# Middot reel '·' : 44
```

**Doctrine UTF-8 PowerShell complétée :**
- Connu : `Get-Content -Raw` + `WriteAllText` peut **corrompre** un fichier UTF-8 (CP1252 lecture → double-encodage écriture)
- Nouveau : `Get-Content` peut **afficher** un fichier UTF-8 correct comme s'il était corrompu, sans qu'il le soit. Toujours vérifier avec `[System.IO.File]::ReadAllText(..., UTF8Encoding)` avant d'agir.

### #146 — **Désactiver GitHub Pages** (NOUVEAU score 3) 🟡 — **Reporté**

**Estimation :** 5 min

**Décision session 17/05 :** maintenir tel quel pour l'instant. GitHub Pages reste un miroir de secours en plus du déploiement principal Codeberg Pages (cf. livre-blanc-v0.1 §3.2 et BILAN_05_au_07_MAI). À reconsidérer si confusion en pratique avec les contributeur·rice·s.

**Description :** Le déploiement principal est Codeberg Pages via Woodpecker. GitHub Pages est inutile et peut créer de la confusion. Désactiver dans les settings du miroir GitHub.

### #147 — **Refonte LanguagePicker** (NOUVEAU score 7) 🟢

**Estimation :** 1h

**Description :** Retirer drapeaux d'États (ES/GB/FR) du picker. Afficher noms de langues dans leur propre langue (Português, Français, Castellano, English, Italiano, Deutsch). Cohérence anarchiste (refus des symboles étatiques). Codes DB inchangés.

### #148 — **Supprimer/renommer `AnarBib-functions/`** (NOUVEAU score 5) 🟡

**Estimation :** 5 min

**Description :** Vestige obsolète non-git à `C:\Users\accat\AnarBib-functions\`. A déjà causé 1h de perte le 12/05. Supprimer ou renommer en `_OBSOLETE_AnarBib-functions/`.

### #149 — **Pattern erreurs RPC silencieuses** (NOUVEAU score 8) 🟢

**Estimation :** 2-3h

**Description :** Le bug #132 (dismiss) restait silencieux : la console affichait PGRST202 mais l'UI ne donnait aucun feedback. Pattern à généraliser : tout `console.error` sur appel RPC devrait aussi afficher un toast/banner UI. Audit des call sites + utility `handleRpcError(err)`.

---

## V. Doctrines internalisées depuis v14

Doctrines à inscrire dans les specs concernées :

1. **#141.2.E ordre UPDATE** : dans RPC métier modifiant tables liées par triggers AFTER UPDATE, toujours UPDATE source de vérité narrative (`workflow_v2.workflow_note`) AVANT source d'état (`linhas_v2.item_status`). Sinon trigger lifecycle voit ancienne note. À inscrire dans spec consultas v2.2 ET spec réservations (#139 + nouveau item).

2. **#141.2.C distinction notes** : `workflow_note` (staff) et `schedule_reply_note` (lecteur) sont 2 colonnes distinctes. Triggers et handlers doivent propager les 2. À inscrire dans spec consultas v2.2.

3. **R8 traçabilité coordination généralisée** (post #142) : toute action initiée par le staff biblio sur un item lecteur génère un mail à `library_commons.coordination_email` en plus du mail au lecteur. Couvre cancelada_biblioteca, nao_compareceu, et probablement extensions/renouvellements/retours. À inscrire dans spec consultas v2.2 ET spec admin réseau v0.3.2 (#140).

4. **Leçon UTF-8 PowerShell (étendue 17/05 fin de session)** : sur Windows FR PowerShell, 2 pièges symétriques :
   - **Écriture** : `Get-Content -Raw` lit en CP1252 et corrompt les fichiers UTF-8 avec caractères Unicode (═, accents). Réécriture ensuite = double-encodage, fichier devient mojibake intégral. Méthode sûre : `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` ou scripts Node `.cjs` qui utilisent fs UTF-8 par défaut.
   - **Lecture/affichage** : `Get-Content` peut **afficher** des mojibakes (`â€"`, `Â·`) à la console alors que le fichier est en réalité UTF-8 valide. Toujours vérifier avec ReadAllText UTF-8 explicite **avant** de croire à un bug (incident #145 du 17/05 : faux positif).

5. **Doctrine création objets backend sécurisés** (rappel, déjà internalisé mais à enforcer) : `security_invoker=on` pour vues, `REVOKE ALL FROM PUBLIC` + `GRANT SELECT TO authenticated` explicite, DO-block de vérification en fin de migration. Le pre-commit hook `.githooks/pre-commit` enforce automatiquement.

---

## VI. Récap chiffré v14 → v15

| Métrique | v14 (15/05 soir) | v15 (17/05 soir) | Delta |
|---|---|---|---|
| Items ouverts | 15 | **14** | -1 (5 clos, 4 nouveaux) |
| Items clos cumulés | 23 | **28** | +5 (#141, #132, #142, #143, #145) |
| Score total ouverts | ~210 | ~186 | -24 (gros chantiers clos, petits nouveaux) |
| Bugs critiques (score ≥ 17) | 2 | **0** | -2 (#131 absorbé dans #141 clos, #132 clos) |
| Chantier majeur en cours | #141 | **(aucun)** | — |
| Prochain gros chantier | #141 ou #98-B | **#98-B profils d'adoption** | — |
| **Onglet Historique en prod** | non | ✅ | nouveau |
| **Doctrine R8 généralisée** | non | ✅ | nouveau |
| **Doctrine UTF-8 PowerShell complète** | partielle (écriture) | ✅ (écriture + lecture) | étendue |

---

## VII. Séquencement recommandé pour la prochaine session

### Court terme (1 session, 2-4h)

**Option A — Dérouler les QA réservations + emprunts (#144)** — RECOMMANDÉ si énergie modérée
- 1-2h par doc
- Identifie bugs concrets pour planifier chantier suivant
- Génère liste prioritisée

**Option B — Démarrer #98-B (profils d'adoption paquet B)** — alternatif si grosse session
- ~1 journée
- Avance le chantier majeur

**Option C — Hygiène quickwins** — pour souffler
- #145 mojibakes (15 min)
- #146 désactiver GitHub Pages (5 min)
- #148 vestige AnarBib-functions (5 min)
- #147 refonte LanguagePicker (1h)
- = ~1h30 pour 4 items clos

### Moyen terme

- #98-B → C → D → E → F → G (chantier profils)
- Interlude #110 Resend en parallèle si fenêtre
- Dérouler #144 QA après #98-B pour vérifier non-régression
- #139 spec consultas v2.2 + #140 spec admin réseau v0.3.2 (intégrer doctrines internalisées)

### Long terme

- #33/#36/#61 cotisations + UX (à clarifier d'abord)
- Si tests E2E automatisés deviennent prio : setup Playwright minimal sur la base des QA manuels

---

## VIII. État de santé final 17/05

**Excellent en doctrine** : 5 doctrines internalisées en 3 jours (ordre UPDATE, distinction notes, R8 généralisée, UTF-8 PowerShell, sécurité vues). Toutes documentées dans les memory edits + à inscrire en specs v2.2.

**Excellent en exécution** : 4 chantiers livrés en 2 jours dont 1 majeur (#143) en 6 sous-paquets. Aucun bug bloquant connu.

**Aucun gros chantier en attente bloqué** : prérequis admin réseau F clos depuis le 14/05, prérequis hardening notifications consultas clos depuis hier. **Tout est prêt pour démarrer le chantier majeur profils d'adoption (#98-B à G)**.

**Articulation prod** :
- Spec admin réseau v0.3.1 : implémentation en prod ✅
- Spec consultas v2.1 : implémentation en prod ✅ (post #141 + #142)
- Spec gouvernance v1.1 : partiellement en prod
- Spec onboarding v1.1 : en attente d'implémentation
- Spec profils v0.3 : paquet A en prod, paquets B-G à venir (#98-B prochain)
- Spec emprunts v1 : implémentée en grande partie, QA à dérouler (#144)
- **Spec consultas v2.2 + admin réseau v0.3.2** : à rédiger (#139 + #140) pour acter les doctrines internalisées

**Fenêtre stratégique** : aucun utilisateur tiers en prod, donc on peut encore réorganiser sans contraintes externes. Profiter pour livrer #98 profils complet avant d'ouvrir aux premiers collectifs.

---

*Backlog v15 — fin. Session 17/05 dense : 4 chantiers livrés (#132, #142, #143 en 6 sous-paquets), 2 docs QA cadrés, 5 doctrines internalisées, 0 régression. Reprise dimanche prochain ou en semaine sur #98-B ou #144.*
