# AnarBib Backlog v11 — 2026-05-14 (nuit, fin de session marathon)

> **Version précédente** : v10 du 14/05/2026 (matin)
> **Évolution v10 → v11** : intégration de la session marathon du 14/05 (paquet 27 complet 7 commits + #114.B + #114.C). Items clos retirés du backlog vivant. Items v9 reportés ressortis avec descriptions précises.
> **Source compte-rendu** : `docs/decisions/AnarBib-CompteRendu-48h-2026-05-14.docx`

---

## 📊 Synthèse

| Type | Nombre |
|---|---|
| Items résolus depuis v10 | 12 |
| Items ouverts dans v11 | 24 |
| Total cumulé items v1-v11 | ~125 |

**Évolution v10 → v11** : 12 items passés de ouverts à résolus en une session marathon nuit du 14/05. Aucun nouvel item bloquant ouvert. Le chantier consultations (qui était la malédiction de 6 jours) est entièrement opérationnel bout-en-bout. Le chantier admin réseau v0.3 est entièrement actif côté DB + UI + mails militants.

---

## ✅ RÉSOLUS depuis v10 (à retirer du backlog vivant)

### Paquet 27 — Workflow consultations bout-en-bout (7 commits, nuit du 14/05)

| Item v10 / v9 | Sub-paquet | Résolu par |
|---|---|---|
| #91 Phase 3 consultations | 27.A.1 (migration RPC AccountPage) + handlers existants | commit en chaîne 27 |
| #92 Phase 4 frontend lecteur | 27.A.2 (bouton Annuler) + 27.A.5 (réponse créneau lecteur 4.3+4.4) | commits 27.A.2 + 27.A.5 |
| #93 Phase 5 frontend biblio | 27.A.3 (migration setConsultaWorkflow) + 27.A.4 (modal Agendar) + 27.A.6 (statuts + reproposition) + 27.A.7 (endsAt obligatoire hotfix) | commits 27.A.3 → 27.A.7 |
| Annexe B top books 90j | Bloc UI ajouté en session précédente | commit 6cd41e8 (à confirmer) |

### #114 entièrement clos (handler notify-event network.*)

| Item v10 | Description | Résolu par |
|---|---|---|
| #114.A | Sous-handlers cooptation_proposed/voted | commit 8e60718 (14/05 après-midi) |
| #114.B | Sous-handlers cooptation_rejected/completed/reminder | commit 114.B-3a (14/05 soir) |
| #114.C | Sous-handlers collective_removal_* (5 events) | commits 114.B-3b + hotfix 3c (14/05 soir) |

**Spec v0.3.1** : doctrines de notifications raffinées figées (proposeur notifié uniquement au 1er vote, rationale diffusé si disclose=true, reminder = 2 mails distincts intro vs proposer_intro, flag was_unanimous pour cancelled).

### Autres résolutions session 14/05

| Item | Description | Résolu par |
|---|---|---|
| Annexe C consultas (logo mail) | Logo AnarBib dans register/index.ts | déjà appliqué par paquet 25.10 |
| Spec v0.3.1 admin réseau | Doctrine notifs raffinée à inscrire | inscrite en mémoire 14/05 soir |

---

## 🔥 OUVERTS PRIORITÉ HAUTE (score ≥ 15)

### #98 — Chantier profils d'adoption (score 20)

**Spec** : `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lignes, livrée 13/05)
**État** : prérequis paquet F admin réseau ✅ clos depuis 13/05 → **chantier débloqué, démarrable maintenant**
**Volumétrie** : 7 paquets A-G, ~16j de dev cumulé, ~4 semaines calendaires

**4 axes orthogonaux** :
- `catalog_mode` : `local_only` | `network_published`
- `circulation_mode` : `off` | `informal` | `full_sigb`
- `network_mode` : `isolated` | `observer` | `federated`
- `governance_mode` : `informal` | `staff_roles` | `full_governance`

**3 profils-types** : A/C, B, D
**Doctrine transitions** : 1-4 selon type courant, gouvernance différenciée selon `governance_mode`
**Doctrine sœur D.6** : transitions type 4 en `full_governance` (unanimité + carence 48h + expiration 30j)

**Ordre de paquets recommandé** : A (infra DB, 1j) → C (RLS, 3-4j) → B (transitions, 3j) → D (archivage, 3j) → E (frontend, 3j) → F (onboarding, 2-3j) → G (déploiement, 1j)

**Synergies** :
- Catalogação refonte (axe `catalog_mode`)
- Cotisations #33/#36 (axe `circulation_mode`) — cf. note d'arbitrage #99
- Onboarding wizard #111 (axe `governance_mode`)
- Annexe A consultas (bug `nulld, nullx`) débloquée par axe `circulation_mode`

### #33 — Test scenario blocage emprunts par cotisation expirée (score 16)

**Description** : tester que les emprunts sont bloqués au RPC quand la cotisation du lecteur a expiré, vérifier la RLS et le message d'erreur côté UI.
**⚠️ Attention** : à attendre après paquet C profils (#98) car la RLS sera reprise pour conditionner sur `fn_library_has_full_sigb()` (cf. note d'arbitrage #99).
**Estimation** : ~1j

### #110 — Migration mail Brevo → Resend (score 15)

**Spec** : `docs/specs/spec-migration-mail-resend.md` (161 KB, rédigée 13/05)
**Raison politique** : cohérence anti-tracking militant (Brevo trackait via sendibt3.com, inaccessible aux usagers VPN/anti-tracker, link tracking non désactivable par toggle). Resend ne tracke pas par défaut.
**Prérequis** : `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN` fait 07/05 ✅
**Implémentation** : en cours de spec, code à écrire
**Impact** : tous les handlers de notification (notify-event, notify-library-request, register, notify-mid-loan, notify-weekly-report)
**Indépendance** : pas de séquencement par rapport aux autres chantiers
**Estimation** : ~3-4j en mode pragma (10 sem si paquet complet selon spec)

### #36 — Activation cotisations pour CIRA Marseille (score 15)

**Description** : activer la facturation de cotisations sur la biblio du CIRA Marseille.
**Dépend de** : #33 (test scenario expiration)
**⚠️ Attention** : à attendre après paquet C profils (#98) — cf. note d'arbitrage #99.
**Estimation** : ~30min hors prérequis

### #61 — Date limite de retrait dans les réservations (score 15)

**Description** : ajouter une date limite de retrait sur les réservations (au-delà, la réservation expire automatiquement et la file passe au suivant). Aujourd'hui les réservations `pronta_para_retirada` restent indéfiniment dans cet état.
**Dépend de** : #33/#36 (logique parallèle aux blocages cotisations)
**Estimation** : ~1-2j (DB + frontend + i18n)

---

## 🔥 OUVERTS PRIORITÉ MOYENNE (score 10-14)

### #2 — Audit complet SECURITY DEFINER non documentées (score 12)

**État** : 103/183 fonctions ont un `COMMENT ON FUNCTION`, 80 restantes
**Action** : auditer les 80 restantes, ajouter `COMMENT ON FUNCTION` documentant l'usage, l'auteur, et la raison du `SECURITY DEFINER`
**Estimation** : ~3j

### #32 — Test E2E parcours staff (score 12)

**Description** : test bout-en-bout du parcours staff (circulation, no-show, libera).
**Bloqué par** : absence de framework E2E (Playwright à installer).
**Recommandation Claude (CR 14/05)** : reporter, faire 1 session QA manuelle structurée à la place.
**Estimation** : 6-8h sur 2-3 sessions

### #40 — Performance vues `my_*_v2` sous concurrence (score 12)

**Description** : tester la performance des vues `my_reservations_active_v2`, `my_consultas_v2`, etc. quand plusieurs utilisateurs requêtent simultanément.
**État** : mitigé (`TOKEN_REFRESHED` filtré dans `AuthContext` depuis paquet 25.2)
**Estimation** : ~1j de profiling + optimisation

### #60 — Import CSV / OPF / JSON catalogues existants (score 12)

**État** : partiel — page `Importações` existe mais ne couvre pas tous les formats source
**Description** : faciliter la migration depuis catalogues legacy (Calibre OPF, BibTeX, exports Koha/Aleph CSV)
**Estimation** : ~3-4j (parser + UI + mapping)

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Spec** : digest hebdomadaire des actions cross-library logguées dans `network_admin_cross_library_actions_log`
**État** : EF + cron créés mais inactifs jusqu'à activation
**Différence vs #114** : #78 traite les actions transverses en batch hebdomadaire ; #114 traite les events temps réel du workflow cooptation/retrait (#114 désormais clos)
**Prérequis** : #79 (activation cron + vault)
**Estimation** : ~1j (compose mail i18n × 6 locales + handler Deno + regroupement par biblio)

### #79 — Activation cron + secret vault pour #78 (score 12)

**Action** :
- `UPDATE cron.job SET active=true` sur job `weekly_network_admin_digest`
- `SELECT vault.create_secret(...)` pour `WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST`
- Tester déclenchement manuel d'abord
**Estimation** : ~30min (étape manuelle hors pipeline)

### #111 — Wizard d'onboarding biblio post-validation (score 12, perspective Q3 2026)

**Description** : fait suite logique au paquet 25.11 signup-sans-biblio (#100). Aujourd'hui, après validation admin d'une demande de biblio, le coordenador arrive sur `BibliotecaPage` écrasante (dizaines de formulaires, choix techniques). Proposition :
- Wizard multi-étapes au premier login post-validation
- Regroupement thématique des décisions
- Valeurs par défaut anarchistes raisonnables
- Génération automatique d'un règlement intérieur exportable PDF et réutilisable comme "règlement type" partageable

**Séquencement** : postérieur au chantier profils #98 (synergie forte avec axe `governance_mode`)
**Idée alternative** : site statique pour le parcours d'inscription biblio (`anarbib.org` au lieu de `app.anarbib.org`), à reconsidérer au moment du chantier
**Estimation** : ~3-4j

---

## 🛠 BUGS UX & PERFORMANCE (priorité basse)

### #4 — Documenter chaque SECURITY DEFINER via COMMENT (score 9)

**État** : 56% audité, reste 80 fonctions
**Note** : sous-tâche de #2
**Estimation** : ~2j

### #6 — Affichage `(nulld, nullx)` pour règles non-renouvelables (score 8) — Annexe A consultas

**Description** : règles de circulation non-renouvelables affichent `(nulld, nullx)` dans BibliotecaPage Regimento
**Dépend de** : #98 (axe `circulation_mode`) car la colonne `circulation_mode` n'existe pas encore
**Estimation** : 30-45 min après #98

### #20 — `must_change_password` non enforced au login (score 8)

**Description** : `must_change_password=true` affiche bien PanelPage mais l'utilisateur peut quand même naviguer ailleurs sans changer son mot de passe.
**Action** : enforcement réel via guard de routage
**Estimation** : ~1-2h

### #25 — Notifications expiration cotisation (7j, 1j, jour J) (score 8)

**Description** : envoi automatique de mails à J-7, J-1 et jour J avant expiration de la cotisation lecteur
**Estimation** : ~1j (handler + cron + i18n × 6 locales)

### #102 — [L.M.1] Trigger BEFORE INSERT sur libraries pour accepts_public_signup (score 8)

**Description** : le paquet L.1.1 a ajouté `accepts_public_signup` avec DEFAULT false et backfill manuel (public+network → true, private → false). Pour les futures biblios créées, le DEFAULT reste false donc elles n'apparaîtront pas dans le dropdown signup tant qu'on ne le passe pas explicitement à true.
**Action** : ajouter un trigger BEFORE INSERT qui applique automatiquement la logique A3 aux futures biblios
**Estimation** : ~30min
**Réf** : `docs/decisions/CHANTIER_LINTER_2026-05-11-12.docx` §2.2

### #119 — Audit secrets hygiene (score 8)

**Périmètre** : audit + rotation préventive de tous les secrets vault non rotés depuis création
- `WEBHOOK_SECRET_NOTIFY_MID_LOAN` (créé 2026-05-06, jamais roté)
- `WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT` (créé 2026-05-06, jamais roté)
- `WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT` (créé 2026-05-06, jamais roté)
- `NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET` (créé 2026-04-10, jamais roté)
- `WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST` (créé 2026-04-07, jamais roté)
**Aussi** :
- Audit Codeberg tokens (`codeberg.org/user/settings/applications`)
- Audit `.woodpecker.yml` (secrets exposés ?)
- Audit Windows Credential Manager (`control.exe /name Microsoft.CredentialManager`)
**Pattern** : auth Codeberg casse régulièrement → suggère rotation/expiration tokens
**Estimation** : ~2-3h (cold session dédiée)

### #103 — [L.M.2] Panel coordenador pour modifier accepts_public_signup (score 7)

**Description** : le champ existe en base, la RLS staff permet déjà la modification, mais aucune interface frontend ne l'expose. Aujourd'hui, modifier ce champ nécessite une intervention SQL directe.
**Action** : toggle dans le panel coordenador (BibliotecaPage.jsx ou panel dédié)
**Estimation** : ~1-2h

### #13 / #115 — Code-split AccountPage.jsx (score 6/8)

**Constat** : ~110 KB après patches paquet 27, ~1730 lignes (vs ~1400 avant paquet 25)
**Symptôme** : warning Vite "chunk >500KB"
**Action** : lazy-load des sous-composants (sections perfil, reservas, consultas, historico, avisos, desejos en composants séparés)
**Estimation** : 2-3h

### #34 — Composant `ReaderMembershipBadge` (score 6)

**Description** : badge unifié affichant l'état de membership lecteur (cotisations actives/expirées, biblios rattachées)
**Bloqué par** : tables membership inexistantes au sens unifié (à ouvrir préalablement)
**Estimation** : ~1j

### #51 — ReaderPage i18n (score 6)

**Description** : 0 occurrence confirmée d'appels `t()` dans ReaderPage, tous les libellés sont hardcodés
**Estimation** : ~1j (audit + extraction + 6 locales)

### #62 — Filtres avancés catalogue (score 6)

**État** : partiel — recherche par titre/auteur/éditeur OK, manquent année intervalle, ISBN, assunto
**Estimation** : ~1j

### #104 — [L.M.3] Audit ressources numériques 'L'Homme et la Terre' (score 6)

**Description** : un seul `digital_asset` en base pour 'L'Homme et la Terre' (id=1, `bib_ref=BTL-TL-001303`), alors que le lecteur PDF affiche 6 volumes. Hypothèse : autres volumes via `book_digital_resources` (table parallèle).
**Action** : investigation + documentation du mécanisme dans le grand livre blanc
**Estimation** : ~1-2h
**Réf** : `docs/decisions/CHANTIER_LINTER_2026-05-11-12.docx` §2.2

### #116 — LanguagePicker refacto stateless (score 6)

**Action** : retirer drapeaux + ISO codes (ES/GB/FR), afficher noms en propre langue :
- Português, Français, Castellano, English, Italiano, Deutsch
- Codes DB inchangés : `pt-BR`, `fr`, `es`, `en`, `it`, `de`
**Raison** : doctrine stateless LanguagePicker (cohérent avec idéologie anti-frontières)
**Estimation** : ~30 min

### #117 — Supprimer `C:\Users\accat\AnarBib-functions\` (score 6)

**Constat** : vestige non-git, 1h perdue le 12/05 (fichier édité au mauvais endroit)
**Décision** : delete (confirmée 14/05)
**Action** : `Remove-Item -Recurse -Force "C:\Users\accat\AnarBib-functions"`
**Estimation** : ~5 min

### #118 — Automatiser déploiement EF dans Woodpecker (score 6)

**État partiel** : item v9 #112 marqué résolu mais en réalité partiel. Vérifier que le pipeline déploie bien les EF au push.
**Action** : si non-actif, modifier `.woodpecker.yml` pour ajouter étape `deploy-edge-functions` avec secret `SUPABASE_ACCESS_TOKEN` ; trigger seulement si `supabase/functions/**` a changé
**Estimation** : ~1h

### #94 — Phase 6 consultations : tests E2E (score 6)

**Description** : 9 scénarios end-to-end (création, agendamento, confirmation/refus, realização, no-show, annulations variées, dismiss).
**Recommandation Claude (CR 14/05)** : reporter, faire 1 session QA manuelle structurée à la place (cf. spec v2 § Phase 6, scénarios 6-7-8-9 prioritaires : refus + repropose, no-show, annulation lecteur, annulation biblio + dismiss).
**Estimation** : 6-8h sur 2-3 sessions

### Autres items linter et hygiène (scores ≤ 5)

| # | Description | Score | Estimation |
|---|---|---|---|
| #16 | Bundle index 947 KB à splitter (manualChunks Vite) | 4 | 1-2h |
| #49 | Phase 5 i18n : test CI orphelines + clés inutilisées | 4 | 1-2h |
| #105 | [L.T.1] Materialized views in API (mv_books_catalog_list_v1, v_network) — RLS non supportée sur MV | 5 | 2-4h |
| #106 | [L.T.2] Buckets storage public listables (library-privacy-public, library-ui-assets) | 4 | ~1h |
| #7 | Top books 90-day data charge mais bloc UI manquant (à confirmer commit 6cd41e8) | 3 | 30min vérif |
| #8 | Hardcoded PT-BR strings dans Rapports (description, email label) | 3 | ~30 min |
| #22 | `fn_submit_library_request_via_claim` : pas de COALESCE sur user_id | 3 | ~30 min |
| #43 | Notifications devolução tardive | 3 | ~3h |
| #70 | Manuel complet AnarBib : 6-8 versions traduites | 3 | ~10j cumulé |
| #87 | Pattern test RLS dans SQL Editor : `SET LOCAL ROLE authenticated` (leçon en mémoire) | 3 | doc 15min |
| #99 | Note d'arbitrage cotisations vs chantier profils (#33/#36 attendent paquet C de #98) | 3 | doc 30min |
| #107 | [L.B.1] Convention timestamps de migrations à clarifier | 3 | 15min doc |
| #17 | Tests CI orphelins i18n (566 clés inutilisées) | 2 | ~1j passe dédiée |
| #26 | 4 tables `_backup_*_20260408` toujours en prod | 2 | 30 min après validation |
| #108 | [L.B.2] Suppression cosmétique de `paquetL3_audit_security_definer.sql` | 2 | ~5 min |
| #57 | Warnings linter (`.linter.toml` non présent) | 1 | ~30 min |
| #71 | `Vollstaendiges` → `Vollständiges` dans `de.json` | 1 | 1 caractère |
| #109 | [L.T.3] 138 alertes authenticated_security_definer_function_executable (volontairement acceptées) | 1 | doc 15min |

---

## 📦 ITEMS MÉTA

### #120 — Note décision session 14/05 (~30 min)

**Action** : créer `docs/decisions/SESSION_2026-05-14_paquet27_consultas_+_114BC.md`
**Contenu** :
- Compte-rendu déjà rédigé dans `AnarBib-CompteRendu-48h-2026-05-14.docx` à committer
- 7 commits paquet 27 détaillés (27.A.1 → 27.A.7)
- Doctrines figées (notifs proposeur, rationale disclose, reminder × 2, was_unanimous)
- 3 pièges récurrents méthode binaire (indentation visuelle, encoding utf8 ancres, ordre étapes)
- Bug runtime `actionBox` `renderEmail` contrat
- Workflow consultations 7 étapes finalisé

### #121 — Mettre à jour spec consultations v2 → v2.1 quand chantier clos (~15 min)

**Action** :
- Section 2.7 / 2.8 : marquer Phase 0 / 1 / 2 / 3 / 4 / 5 comme ✅ closes
- Section 9 : annoter chaque phase avec son commit de référence (24, 25, 26, 27)
- Changelog v2 → v2.1 : "Phases 0-5 closes par paquets 24-27"

### #122 — Spec admin réseau v0.3 → v0.3.1 (~30 min)

**Action** :
- Inscrire les 4 doctrines raffinées 14/05 (notifs proposeur voteCount===1, rationale disclose, reminder × 2, was_unanimous)
- Inscrire patch DB 9d3ae6b (enrichissement `trg_check_cooptation_completion`)
- Inscrire spec implémentation #114.A référencée

---

## 🎯 ORDRE D'ATTAQUE SUGGÉRÉ POUR LES PROCHAINES SESSIONS

**Si 1h (sprint hygiène)** :
- #117 (delete AnarBib-functions, 5 min)
- #116 (LanguagePicker stateless, 30 min)
- #120/#122 (notes décision, 30 min cumulé)

**Si 2-3h (sprint hygiène + automatisation)** :
- Sprint 1h ci-dessus
- #118 (vérif automate EF deploy, 1h)
- #102 (trigger BEFORE INSERT accepts_public_signup, 30 min)
- #103 (toggle panel coordenador, 1-2h)

**Si 4h (QA consultations + petits items)** :
- QA manuelle consultations (1h) : checklist 9 scénarios spec v2 § Phase 6 en remplacement de l'E2E (#94)
- Sprint 1h
- #25 notifications expiration cotisation (peut commencer)

**Si 1 journée** :
- Démarrer #98 paquet A profils d'adoption (infra DB, 1j)

**Si 2-3 journées** :
- #110 Migration Brevo → Resend en mode pragma (3-4j)

**Sessions futures** :
- #98 paquets B-G chantier profils (15j cumulés au long cours)
- #78/#79 Digest hebdo (1j + 30min activation)
- #119 Audit secrets (2-3h cold session)
- #111 Wizard onboarding (3-4j, perspective Q3 2026)
- #61 Date limite retrait (1-2j, après chantier profils #98 paquet C)
- #94 QA manuelle consultations (1h structurée vs 6-8h E2E)

---

## 📌 DÉCISION POLITIQUE EN ATTENTE

**Question** : démarrer #98 (profils d'adoption, 16j, 4 sem, débloque annexe A et conditionne #110) **OU** #110 (migration Resend, 3-4j en mode pragma, indépendant) **OU** combinaison ?

**Recommandation Claude (CR 14/05)** : sprint hygiène en premier (3h), puis arbitrage à valider lundi. La voie est libre techniquement pour les deux chantiers.

---

## 📎 RAPPEL CONTEXTES UTILES

- **Project Supabase** : `uflwmikiyjfnikiphtcp` (sa-east-1)
- **Repo principal** : `C:\Users\accat\Claude's AnarBib\anarbib-app\`
- **Déploiement** : Codeberg Pages via Woodpecker CI, GitHub = mirror
- **Mail backend actuel** : Brevo (jusqu'à migration Resend item #110)
- **Lívia user_id** (test) : `366cdc4e-10e0-44ad-8554-a444bcf9607a`
- **Xavier user_id** : `d6710372-e5e5-4608-800b-99a26817c677`

**Spec FICEDL Bologna septembre 2026** : cadrage de la présentation pour public FICEDL (bibliothécaires militant·es CIRA, Centro Studi Libertari, Kate Sharpley, etc.). Format à finaliser (langue, durée, support). Item de séquencement à part, non scoré.

---

## 🏴 BILAN DES 48H (12-14 mai 2026)

5 chantiers clos en parallèle :
- **Linter Supabase** : 270 → 184 alertes, 18 → 0 ERRORs (1 documentée volontaire)
- **Admin réseau v0.3** : 7 paquets A-F + #114 10 sous-handlers network.*
- **Consultations paquet 27** : 7 commits bout-en-bout (lecteur + biblio)
- **Site vitrine 8 langues** : 16 fichiers HTML × 8 langues
- **Spec FICEDL Bologna** : cadrage rédigé

~30 commits prod cumulés, ~8000 lignes de code, ~1440 entrées i18n × 6 locales, 0 incident prod, 0 régression visible. Méthode binaire safe a tenu jusqu'au bout.

**Statut final v11** : 24 items ouverts (vs 17 dans v10 — la différence vient de la réintégration des items v9 reportés avec descriptions précises, pas d'une régression). Aucun item bloquant.

🏴
