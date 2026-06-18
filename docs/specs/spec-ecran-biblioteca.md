---
Genre : référence (carte d'ensemble)
Statut : ✅ implémenté en prod (chantier-cadre clos 08/06/2026) — carte d'orientation consolidée a posteriori (18/06)
Décisions : incarne BIBLIO-CLOSE, BIBLIO-9, BIBLIO-10 (REGISTRE §19) ; carte vers les specs par domaine
Supersédé par : —
---

# Spec — Écran de gestion « Biblioteca » (`/biblioteca`)

**Statut** : v1.0 — **carte d'ensemble** (orientation), pas la doctrine détaillée de chaque domaine.
**Date** : 18/06/2026
**Origine** : audit 360° (P2 « specs », option 2). Le **chantier-cadre Biblioteca** (mise à parité doctrinale + fonctionnelle de l'écran de gestion d'une biblio, transports mail câblés) a été **clos le 08/06** mais n'avait qu'une **trace** ; ce document est une **carte d'orientation** pour les futur·es dev — il dit *où vit* la doctrine de chaque onglet, sans la recopier. Trace : `docs/journal/chantiers/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md`.
**Périmètre** : l'écran staff `/biblioteca` (`BibliotecaPage.jsx`) — sa structure (12 onglets), ses accès, et le **renvoi** vers la spec de référence de chaque domaine. **Hors périmètre** : la doctrine de chaque domaine (portée par sa propre spec, cf. carte §3).

> ⚠️ **Nature** : `BibliotecaPage` est un **gros écran agrégateur** (~12 onglets) qui *consomme* des fonctions documentées ailleurs. Cette spec **n'est pas** un foyer doctrinal de plus — c'est un **index** pour s'y retrouver. Ne pas y dupliquer la doctrine des domaines.

---

## 1. Objet

`/biblioteca` est le **poste de gestion** d'une bibliothèque par son staff (à distinguer de `/painel`, poste de circulation au comptoir). Le chantier-cadre (BIBLIO) avait pour mission d'amener cet écran à **parité doctrinale et fonctionnelle** avec l'ancien outil HTML, et de **câbler les transports mail**. **Clos le 08/06** (BIBLIO-CLOSE).

---

## 2. Clôture du chantier-cadre (REGISTRE §19)

- **BIBLIO-CLOSE** (08/06) : 12 onglets fonctionnels + parité doctrinale + mails câblés. Dernière réserve (étape 8, mails) levée par la clôture de #110 (Brevo→Resend) : **EA-13** (`fn_send_weekly_report_now` + bouton « Enviar relatório » → `notify-weekly-report`), **EA-14** (cron `anarbib-notify-weekly-report-weekly`), **EA-19** (`fn_task_invite`).
- **BIBLIO-9** : **EA-12** (parité fonctionnelle PEB, ~45 fn) = **différée/gelée**, conditionnée à un manque réel constaté BLMF↔BTL. Ticket dormant.
- **BIBLIO-10** : **EA-11** (réplique HTML radicale des échanges, ~118 fn) = **non retenue** par défaut (le panneau React est jugé suffisant). Réouvrable sur décision délibérée.

---

## 3. Carte des onglets → doctrine de référence

`BibliotecaPage` (route `/biblioteca`) expose 12 onglets. Pour chacun, la doctrine vit dans la spec / le § indiqué :

| Onglet (id) | Libellé | Accès | Doctrine de référence |
|---|---|---|---|
| `identity` | Identité et fonctionnement | coord | horaires/contact/état public → **PUBLIB** (`spec-fiche-publique-bibliotheque`) ; thème → assets Storage |
| `comms` | Communications | coord | politiques de notification, identité e-mail → **§6 NOTIF**, **§3 MAIL** (`library_notification_policies`, `library_commons`) |
| `regulation` | Règlement et circulation | coord | règles de circulation → **`spec-flux-emprunts`** (`resolve_circulation_rule`, policy sets) ; **cotisation** → **`spec-cotisation`** |
| `privacy` | Confidentialité | staff | RGPD → `REGISTRE_TRAITEMENTS`, `LibraryPrivacySection` |
| `documents` | Documents et relations externes | coord | partenariats → **§21 PARTNER** ; imports/sources → **§17 IMP** |
| `transicoes` | Transitions | coord + gouvernance | cycle de vie biblio → **`spec-profils-bibliotheque`**, **`spec-gouvernance-roles`** |
| `team` | Équipe | staff | rôles/cooptation → **`spec-gouvernance-roles`**, **§24 FED** (cooptation) |
| `leitores` | Lecteur·rices | staff | roster + identité locale → **`spec-identite-lecteur-locale`** (CARD-LOCAL, `get_reader_roster`) ; validation → **§9 VALID** |
| `exchanges` | Échanges interbibliothèques | staff | panneau React des échanges (EA-11 HTML non retenu, cf. §2) |
| `ill` | Prêt interbibliothèques (PEB) | staff | **§22 ILL** (`spec-flux-partage-numerique`), **`spec-cycle-vie-peb`** (EA-12 parité différée) |
| `reports` | Rapports et résumés | staff | rapport hebdo → `notify-weekly-report` (EA-13/14) |
| `tasks` | Tâches internes | staff | `fn_task_*` (EA-19), `notify-internal-task` |

---

## 4. Accès

Les onglets `coordOnly` (identity, comms, regulation, documents, transicoes) sont réservés au **coordenador** ; `transicoes` est en plus `governance_only` (profil de gouvernance actif). Le reste est ouvert au **staff** de la biblio (RLS par appartenance).

---

## 5. Annexe — artefacts

- **Frontend** : `src/pages/biblioteca/BibliotecaPage.jsx` (route `/biblioteca`, lazy). 12 onglets `{identity, comms, regulation, privacy, documents, transicoes, team, leitores, exchanges, ill, reports, tasks}` (ids réels du tableau de tabs).
- **Décisions REGISTRE** : §19 BIBLIO-CLOSE / BIBLIO-9 / BIBLIO-10. Domaines : cf. carte §3 (chaque onglet → sa spec).
- **À distinguer** de `/painel` (`PanelPage`, poste de circulation au comptoir) et de `/bibliotecas` (annuaire public, PUBLIB).

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »). C'est une **carte d'orientation** d'un écran agrégateur livré-clos le 08/06, destinée aux futur·es dev — la doctrine de chaque domaine reste dans sa spec dédiée (carte §3).*
