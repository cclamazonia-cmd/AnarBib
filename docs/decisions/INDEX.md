# 🗓️ INDEX des décisions — AnarBib

**Dernière mise à jour** : 20 mai 2026 (nettoyage du corpus)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier `decisions/` est la **mémoire chronologique** du projet AnarBib : sessions de travail, chantiers, bilans, bugs, audits, riflexions doctrinales, décisions de coordination des biblios.

Contrairement aux specs (qui décrivent un état cible) ou au backlog (qui liste des tâches), les fichiers de `decisions/` sont des **traces datées** : ils ne sont pas mis à jour après coup, ils témoignent de ce qui a été décidé ou fait à un moment précis.

---

## 📌 Document doctrinal central

Un fichier de ce dossier a un statut particulier — ce n'est pas une trace datée mais une **doctrine vivante** régulièrement mise à jour :

➡️ **[`CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`](./CHANTIER_doctrine_creation_objets_securises_2026-05-12.md)**
La doctrine de création d'objets PostgreSQL sécurisés. Partie I (templates de création, chantier linter L.*) + Partie II (audit et isolation des fonctions privées, chantier #150). **À consulter avant toute migration backend.**

---

## 🗓️ Index chronologique

### Mai 2026 — semaine du 5 au 11

| Date | Fichier | Type | Sujet |
|---|---|---|---|
| 05/05 | `DECISOES_COORDENACAO_BLMF_2026-05-05.md` | Coordination | Décisions de coordination biblio BLMF (pt-BR) |
| 05-07/05 | `BILAN_05_au_07_MAI_2026.md` | Bilan | Bilan de la période 5-7 mai |
| 06/05 | `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06.md` | Audit | Audit des fonctions de notification |
| 06/05 | `BUG_LOGOS_BREVO_TRACKER_2026-05-06.md` | Bug | Logos Brevo tracker (motivation migration Resend) |
| 06/05 | `DECISOES_COORDENACAO_BTL_2026-05-06.md` | Coordination | Décisions de coordination biblio BTL (pt-BR) |
| 06/05 | `MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md` | Module | Statut du module inter-bibliothèques |
| 06/05 | `REDEPLOY_NOTIFY_EVENT_NO_VERIFY_JWT_2026-05-06.md` | Ops | Redéploiement notify-event avec `--no-verify-jwt` |
| 06/05 | `REFACTOR_TRIGGERS_MEMBERSHIPS_2026-05-06.md` | Refactor | Refactor des triggers de memberships |
| 07/05 | `SESSION_2026-05-07.md` | Session | Compte-rendu de session |
| 07/05 | `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN_2026-05-07.md` | Setup | Configuration du sous-domaine Resend |

### Mai 2026 — semaine du 12 au 18

| Date | Fichier | Type | Sujet |
|---|---|---|---|
| 11-12/05 | `CHANTIER_LINTER_2026-05-11-12.docx` | Chantier | Chantier linter L.* (~90 alertes éradiquées) |
| 12/05 | `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` | **Doctrine** | **Doctrine création objets sécurisés (document central, voir ci-dessus)** |
| 12/05 | `CHANTIER_linter_security_definer_assume_2026-05-12.md` | Chantier | Décision : SECURITY DEFINER assumé sur `library_circulation_stats` |
| 12/05 | `SESSION_2026-05-12.docx` | Session | Compte-rendu de session |
| 15/05 | `CLEANUP_FRT_2026-05-15.md` | Cleanup | Nettoyage frontend |
| 15/05 | `CLOTURE_B6_et_B3_generalise-2026-05-15.md` | Clôture | Clôture des paquets B6 et B3 généralisé |
| 15/05 | `QA_MANUELLE_consultations-2026-05-15.md` | QA | Plan de QA manuelle consultations |
| 15/05 | `SESSION_refonte-specs-paquetA-QA-15-05-2026.md` | Session | Refonte des specs + paquet A + QA |
| 16/05 | `SESSION_141-hardening-notifications-consultas_2026-05-16.docx` | Session | Chantier #141 hardening notifications (7 bugs) |
| 17/05 | `CHANTIER_doctrine_transitions_profils_2026-05-17.md` | Chantier | Doctrine des transitions de profils |
| 17/05 | `QA_MANUELLE_emprestimos-2026-05-17.md` | QA | Plan de QA manuelle emprunts (10 scénarios) |
| 17/05 | `QA_MANUELLE_reservations-2026-05-17.md` | QA | Plan de QA manuelle réservations (10 scénarios) |
| 18/05 | `AUDIT_securite_fonctions_privees_2026-05-18.md` | Audit | Audit sécurité du chantier #150 (28 fonctions Cat 3 isolées) |

### Mai 2026 — semaine du 19 au 25

| Date | Fichier | Type | Sujet |
|---|---|---|---|
| 19/05 | `BILAN_session_19_mai_2026_paquets_C_D.md` | Bilan | Bilan session paquets C et D du chantier profils |
| 19/05 | `CHANTIER_consulta_button_2026-05-19.md` | Chantier | Chantier bouton consulta |
| 19/05 | `CHANTIER_harmonisation_heros_2026-05-19.md` | Chantier | Harmonisation des composants Hero |
| 19/05 | `CHANTIER_peb_frontend_diagnostic_2026-05-19.md` | Chantier | Diagnostic frontend PEB (prêt inter-biblios) |
| 19-20/05 | `SESSION_2026-05-19_au_20_chantier_profils_cloture.docx` | Session | Clôture marathon du chantier profils d'adoption |
| 20/05 | `RIFLEXION_articulation_onboarding_profils_2026-05-20.md` | **Riflexion** | **Doctrine anti-méga-machine (origine des specs v2.0/v0.4)** |
| 21/05 | `CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md` | Chantier | Chantier-cadre Biblioteca — audit parité doctrinale |

---

## 🏷️ Index thématique

### Doctrine et sécurité backend
- `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` — doctrine centrale (création + audit)
- `CHANTIER_linter_security_definer_assume_2026-05-12.md` — exception SECURITY DEFINER assumée
- `CHANTIER_LINTER_2026-05-11-12.docx` — chantier linter L.*
- `AUDIT_securite_fonctions_privees_2026-05-18.md` — audit #150
- `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06.md` — audit fonctions notification

### Notifications et mail
- `BUG_LOGOS_BREVO_TRACKER_2026-05-06.md` — bug tracker Brevo
- `SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN_2026-05-07.md` — setup Resend
- `REDEPLOY_NOTIFY_EVENT_NO_VERIFY_JWT_2026-05-06.md` — redéploiement notify-event
- `SESSION_141-hardening-notifications-consultas_2026-05-16.docx` — hardening #141

### Chantier profils d'adoption (#98)
- `CHANTIER_doctrine_transitions_profils_2026-05-17.md` — doctrine des transitions
- `BILAN_session_19_mai_2026_paquets_C_D.md` — bilan paquets C/D
- `SESSION_2026-05-19_au_20_chantier_profils_cloture.docx` — clôture marathon
- `RIFLEXION_articulation_onboarding_profils_2026-05-20.md` — doctrine anti-méga-machine

### QA manuelle
- `QA_MANUELLE_consultations-2026-05-15.md`
- `QA_MANUELLE_emprestimos-2026-05-17.md`
- `QA_MANUELLE_reservations-2026-05-17.md`

### Coordination des biblios
- `DECISOES_COORDENACAO_BLMF_2026-05-05.md` — BLMF
- `DECISOES_COORDENACAO_BTL_2026-05-06.md` — BTL

### Chantiers frontend
- `CHANTIER_consulta_button_2026-05-19.md`
- `CHANTIER_harmonisation_heros_2026-05-19.md`
- `CHANTIER_peb_frontend_diagnostic_2026-05-19.md`
- `CLEANUP_FRT_2026-05-15.md`

### Modules et infrastructure
- `MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md`
- `REFACTOR_TRIGGERS_MEMBERSHIPS_2026-05-06.md`
- `CLOTURE_B6_et_B3_generalise-2026-05-15.md`

### Chantier-cadre Biblioteca (ouvert 21/05)
- `CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md`

---

## 📦 Contenu archivé

Le sous-dossier `archive/` contient les fichiers de `decisions/` devenus obsolètes :

- **`archive/prompts-reprise/`** — les 4 « Prompt-Reprise » des chantiers #98, #114, #150. Ces mémentos servaient à reprendre un chantier d'une session à l'autre. Tous les chantiers visés étant clos, ils n'ont plus de valeur opérationnelle (conservés pour traçabilité historique).
- **`archive/CHANTIER_doctrine_creation_objets_securises_2026-05-12.docx`** — ancien format `.docx` de la doctrine, doublon du `.md`.
- **`archive/CHANTIER_doctrine_creation_objets_securises_v2_2026-05-18.md`** — l'ancienne note « v2 » séparée, désormais fusionnée dans le document `.md` du 12/05 (Partie II).

---

## 🔧 Maintenance

Cet index doit être mis à jour à chaque nouveau fichier ajouté dans `decisions/`. Les fichiers de `decisions/` ne sont **pas** modifiés après leur création (ce sont des traces datées) — à l'exception du document doctrinal central `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` qui est vivant.

Quand un « Prompt-Reprise » devient obsolète (chantier clos), le déplacer dans `archive/prompts-reprise/`.

---

*Fin de l'index des décisions. Pour la navigation générale, voir `../INDEX.md`.*
