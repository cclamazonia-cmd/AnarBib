# AnarBib Backlog v10 — 2026-05-14 (fin de session)

> **Version précédente** : v9 du 13/05/2026
> **Évolution v9 → v10** : items résolus retirés, nouveaux items issus session 14/05 ajoutés, items consultations sortis vers prompt de reprise séparé
> **Hors périmètre** : finition spec consultations + 3 annexes UI → `Prompt-Reprise-Consultations-Finition.md`

---

## 📊 Synthèse

| Type | Nombre |
|---|---|
| Items résolus depuis v9 | 8 |
| Items ouverts dans v10 | 17 |
| Total cumulé items v1-v10 | ~120 |

---

## ✅ RÉSOLUS depuis v9 (à retirer du backlog vivant)

| # v9 | Résolu par | Date |
|---|---|---|
| Paquet 26 L3+L4 (events consultas) | Commit c92b608 | 2026-05-14 |
| Paquet 26 L5 (UI consultations lecteur, 5 bugs) | Commit 1a1547d (#293) | 2026-05-14 |
| Libellés stages consultas i18n | Commit suivant | 2026-05-14 |
| #114.A spec | docs/specs/spec-implementation-114a-network-cooptation.md | 2026-05-14 |
| #114.A code | par toi en parallèle | 2026-05-14 |
| Rotation `WEBHOOK_SECRET_NOTIFY_EVENT` | vault.update_secret + redeploy | 2026-05-14 10:29 UTC |
| Fix mojibake `env.ts` ligne 13 | Au fil d'eau | 2026-05-14 |
| `.broken*` ajouté au `.gitignore` | Au fil d'eau | 2026-05-14 |

---

## 🔥 OUVERTS PRIORITÉ HAUTE (score ≥ 15)

### #98 — Chantier profils d'adoption (score 20)

**Spec** : `docs/specs/spec-profils-bibliotheque.md` v0.3 (934 lignes, livrée 13/05)
**État** : prérequis paquet F admin réseau ✅ clos depuis 13/05 → **chantier débloqué, démarrable maintenant**
**Volumétrie** : 7 paquets A-G, ~16j de dev cumulé
**4 axes orthogonaux** :
- `catalog_mode` : `local_only` | `network_published`
- `circulation_mode` : `off` | `informal` | `full_sigb`
- `network_mode` : `isolated` | `observer` | `federated`
- `governance_mode` : `informal` | `staff_roles` | `full_governance`
**3 profils-types** : A/C, B, D
**Doctrine transitions** : 1-4 selon type

### #110 — Migration mail Brevo → Resend (score 15)

**Spec** : `docs/specs/spec-migration-mail-resend.md` (161 KB, rédigée 13/05)
**Raison politique** : cohérence anti-tracking militant (Brevo trackait via sendibt3.com inaccessible aux usagers VPN/anti-tracker). Resend ne tracke pas par défaut.
**Prérequis** : `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN` fait 07/05 ✅
**Implémentation** : en cours de spec, code à écrire
**Indépendance** : pas de séquencement par rapport aux autres chantiers

### #61 — UX (score 15, à clarifier)

Item v9 reporté. À ressortir la description précise.

---

## 🔥 OUVERTS PRIORITÉ MOYENNE (score 10-14)

### #78 — Edge Function `notify-cross-library-digest` (score 12)

**Spec** : digest hebdomadaire des actions cross-library admins réseau
**État** : EF + cron créés mais inactifs jusqu'à activation
**Prérequis** : #79 ci-dessous

### #79 — Activation cron + secret vault pour #78 (score 12)

**Action** :
- Activer le job pg_cron `weekly_network_admin_digest`
- Stocker URL EF dans vault.secrets sous le nom convenu
- Tester déclenchement manuel d'abord

### #114.B — Sous-paquet network.cooptation_rejected + completed + reminder (score 12)

**Prérequis** : #114.A ✅ (fait aujourd'hui)
**Plan** : sur le modèle de #114.A (cf. `_shared/domain/network.ts` créé par toi)
**Events à ajouter** :
- `network.cooptation_rejected` (destinataires : target + proposeur + autres admins, avec rationale lourd politiquement)
- `network.cooptation_completed` (destinataires : target + tous admins, symétrique)
- `network.cooptation_reminder` (cron J+14 et J+25, destinataires : proposeur + admins n'ayant pas voté)
**Estimation** : 2-3h

### #114.C — Sous-paquet network.collective_removal_* (score 12)

**Events** :
- `network.collective_removal_proposed` (autres admins, target NON encore notifié)
- `network.collective_removal_vote_cast` (autres admins)
- `network.collective_removal_unanimous` (target + tous admins, déclenche carence 7j)
- `network.collective_removal_cancelled` (tous admins + target si déjà notifié)
- `network.collective_removal_executed` (tous admins ex-membres + target, cron post-carence)
**Estimation** : 2-3h

### #33, #36 — Cotisations (scores 16, 15 selon v9)

À ressortir des descriptions précises. Probablement chantier UX cotisations / paiements / preuves de membership.

---

## 🛠 BUGS UI MINEURS (priorité basse)

### #115 — Code-split `AccountPage.jsx` (score 8)

**Constat** : 99 721 bytes, 1455 lignes après ajouts paquet 26 L5
**Symptôme** : warning Vite "chunk >500KB"
**Action** : lazy-load des sous-composants (sections perfil, reservas, consultas, historico, avisos, desejos en composants séparés)
**Estimation** : 3-4h

### #116 — `LanguagePicker` refacto (score 6)

**Action** : retirer drapeaux + ISO codes (ES/GB/FR), afficher noms langue native :
- Português, Français, Castellano, English, Italiano, Deutsch
- Codes DB inchangés : `pt-BR`, `fr`, `es`, `en`, `it`, `de`
**Raison** : doctrine stateless LanguagePicker (cohérent avec idéologie anti-frontières)
**Estimation** : 30 min

---

## 🧹 HYGIÈNE / MAINTENANCE

### #117 — Supprimer `C:\Users\accat\AnarBib-functions\` (5 min)

**Constat** : vestige non-git de l'ancienne organisation EF. A causé 1h perdue le 12/05 (fichier édité au mauvais endroit).
**Décision** : delete (pas rename) — option confirmée par toi 14/05.
**Action** : `Remove-Item -Recurse -Force "C:\Users\accat\AnarBib-functions"`

### #118 — Automatiser déploiement EF dans Woodpecker (~1h)

**Action** :
- Modifier `.woodpecker.yml` pour ajouter étape `deploy-edge-functions`
- Secret `SUPABASE_ACCESS_TOKEN` (déjà disponible côté Woodpecker)
- Trigger : seulement si `supabase/functions/**` a changé
- Commande : `supabase functions deploy notify-event register --project-ref uflwmikiyjfnikiphtcp --no-verify-jwt`
**Bénéfice** : plus besoin de `supabase functions deploy <name>` manuel après chaque modif EF

### #119 — Audit secrets hygiene (session cold dédiée, ~2-3h)

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

---

## 📦 ITEMS V9 REPORTÉS À TRIER

Items v9 dont je n'ai pas les descriptions précises sous la main, à ressortir et trier dans v11 :

- #61 UX (score 15)
- #33 cotisations (score 16)
- #36 cotisations (score 15)
- #102-109 (8 items linter, scores variés selon v9)

---

## 📝 MÉTA

### #120 — Note décision session 14/05 (~30 min)

**Action** : créer `docs/decisions/SESSION_2026-05-14_recovery_paquet26_UI_spec114A.md`
**Contenu** :
- Catastrophe 09:35 : 5 fichiers écrasés par auto-revert IDE
- Recovery 5h (mail-strings.ts + events.ts + library-notification-context.ts + policies.ts + dispatch.ts)
- FK PostgREST consulta_workflow → linhas
- Tests scénarios 1-5 paquet 26 L3+L4
- Bugs UI consultations #1-5 (paquet 26 L5)
- Spec #114.A
- #114.A code (fait en parallèle)
- Rotation WEBHOOK_SECRET_NOTIFY_EVENT
- Audit chantier consultations vs état réel (constat : 70% du chantier était fait sans annotation)

### #121 — Mettre à jour spec consultations v2 → v2.1 quand chantier clos (~15 min)

À faire après finition Phases 4-7 (cf. Prompt-Reprise-Consultations-Finition.md) :
- Section 2.7 / 2.8 : marquer Phase 0 / 1 / 2 / 3 comme ✅ clos
- Section 9 : annoter chaque phase avec son commit de référence
- Changelog v2 → v2.1 : "Phases 0-3 closes par paquets 24-26"

---

## 🎯 ORDRE D'ATTAQUE SUGGÉRÉ POUR LES PROCHAINES SESSIONS

**Si 1h** : #117 (delete AnarBib-functions, 5 min) + #116 (LanguagePicker, 30 min) + #120 (note décision, 30 min)

**Si 4h** : finition consultations (cf. Prompt-Reprise-Consultations-Finition.md)

**Si 6h** : finition consultations COMPLET (Phases 4+5+6+7 + annexes A+B+C)

**Si 1 journée** : #114.B (cooptation_rejected/completed/reminder) — sur le modèle de #114.A

**Si 2 journées** : #114.B + #114.C (collective_removal_*)

**Sessions futures** :
- #98 Chantier profils d'adoption (16j cumulés) — chantier au long cours
- #110 Migration Brevo → Resend (indépendant, ~3-4j)
- #78/#79 Digest hebdo (~1j)
- #118 Automate EF deploy (~1h)
- #119 Audit secrets (~2-3h)

---

## 📎 RAPPEL CONTEXTES UTILES

- **Project Supabase** : `uflwmikiyjfnikiphtcp` (sa-east-1)
- **Repo principal** : `C:\Users\accat\Claude's AnarBib\anarbib-app\`
- **Deploiement** : Codeberg Pages via Woodpecker CI, GitHub = mirror
- **Mail backend actuel** : Brevo (jusqu'à migration Resend item #110)
- **Lívia user_id** (test) : `366cdc4e-10e0-44ad-8554-a444bcf9607a`
- **Xavier user_id** : `d6710372-e5e5-4608-800b-99a26817c677`

---

**Item retiré v9 → v10** : "Disable GitHub Pages" — décision conservatrice prise 12/05 (le DNS de app.anarbib.org pointe vers Codeberg, GitHub Pages tourne dans le vide mais sans impact). À ne pas désactiver.
