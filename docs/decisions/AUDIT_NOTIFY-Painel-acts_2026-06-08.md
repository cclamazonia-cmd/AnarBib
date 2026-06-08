# Audit préalable — #NOTIFY-Painel-acts (mails manquants sur actes du Painel)

**Date** : 2026-06-08
**Auteur** : Xavier (lead AnarBib) en session avec Claude
**Session** : Audit #NOTIFY-Painel-acts
**Statut** : ✅ audit livré + **4 arbitrages tranchés le 08/06/2026** (validés Xavier) — prêt pour l'ouverture du chantier
**Foyer normatif** : à graduer au REGISTRE (`BIBLIO`/`NOTIF`) à l'ouverture du câblage
**Débloqué par** : clôture de #110 (Brevo → Resend) le 05-08/06/2026 — la couche d'envoi est stabilisée

---

## 1. Objet

Le backlog (#NOTIFY-Painel-acts, fiche C.8) constate l'**absence de mail de notification système** sur trois familles d'actes du Painel qui modifient l'état du **compte (conta)** d'un membre. Le membre concerné n'est jamais prévenu. Cet audit préalable (obligatoire avant câblage) établit, **sur le code et la base réels** (sondage `pg_proc` / `information_schema` / frontend, 08/06/2026), le point exact de déclenchement de chaque acte, l'état réel de notification, et le mapping sur le pattern d'implémentation existant.

## 2. Méthode

État relevé en base de production le 08/06/2026 par requêtes directes (`execute_sql`, lecture seule) sur `pg_proc.prosrc`, `information_schema.columns`, et lecture du frontend Painel (`src/pages/painel/`). Aucune modification.

## 3. Constat — les 3 familles

| Famille | Déclencheur réel | Écrit dans | Notif aujourd'hui |
|---|---|---|---|
| **Paiement cotisation** | `public.fn_record_membership_payment(...)` (Painel, `PanelPage.jsx:1388`) | tables cotisation + validité | ❌ **aucune** |
| **Restriction locale** (EA-10, chantier D) | `api.restrict_member(p_user_id, p_library_id, p_reason)` / `api.unrestrict_member` (`TabLeitor.jsx`) | `user_library_memberships.is_restricted` (+ `restricted_at/by/reason`) | ❌ **aucune** |
| **Gel global** (EA-10, admin réseau) | `api.freeze_account(p_user_id, p_reason)` / `api.unfreeze_account` (`TabLeitor.jsx`, bloc admin réseau) | `profiles.is_restricted` (+ `restricted_by/reason/since`) | ❌ **aucune** |

**Vérification d'émission** (regex `notify|dispatch|outbox|http_post|notify_event|user_notifications|net.http` sur le corps des fonctions) : **`false` pour les six fonctions** (les trois actes ET leurs levées). Les actes sont muets de bout en bout.

Précisions :
- **Deux niveaux de restriction distincts** : `user_library_memberships.is_restricted` = **locale** (périmètre d'une biblio) ; `profiles.is_restricted` = **globale / gel** (périmètre profil = tout le réseau, réservé à l'admin réseau).
- `fn_team_suspend_member` notifie, **mais** c'est la suspension d'un **rôle staff** (équipe), hors périmètre de cet audit (acte staff, pas acte conta).

## 4. Infrastructure existante (réutilisable — rien à reconstruire)

- **Pattern dispatch** (précurseur : `spec-notify-prorrogacao-granulaire`) : `fn_dispatch_notify_event`, `fn_network_notify_event`, `fn_reader_message_dispatch` → outbox/Edge Function → `mail-strings.ts` (`tMail`, i18n). Le câblage de chaque famille suit ce moule : **dispatch (fn/trigger) + handler EF + clés i18n mail**.
- **In-app reader** : table `user_notifications` (`/conta/avisos`) pour les répliques B3 (restriction/gel).
- **Amorce de configuration** : `library_notification_policies.profile_restriction_enabled` (boolean) **existe déjà** (1 consommateur en base) mais **n'est branché à aucun émetteur**. Aucune colonne de politique pour la cotisation ni la restriction locale.

## 5. Doctrine applicable (`spec-notifications-lecteur` v1.0)

| Famille | Destinataire | E-mail | In-app | Configurable | Réf. |
|---|---|---|---|---|---|
| Paiement cotisation | le membre (conta) | ✅ oui (acte admin, trace) | non (bandeau `fn_my_account_status` suffit) | cf. arbitrage 2 | §4.4 |
| Restriction locale | le membre (conta) | ✅ **obligatoire + motif** | ✅ **B3 obligatoire** | **non** (impact droits) | §4.5 `decision_restriction` |
| Gel global | le membre (conta) | ✅ **obligatoire + motif** | ✅ **B3 obligatoire** | **non** (impact droits) | §4.5 (analogue, portée réseau) |

Invariants transverses :
- **DOC-NOTIF-1** : on notifie **le membre impacté**, jamais le staff qui a agi.
- **Doctrine C** : ces actes s'adressent à la personne en tant que **reader** → canal reader (e-mail + `user_notifications`), pas le painel.
- **Doctrine A** : les trois familles passent le critère d'admission (impact subi sur les droits / acte administratif personnel).

## 6. Plan de câblage proposé (le chantier, post-audit)

Pour chaque acte : ajouter un appel **dispatch** dans la fonction (ou un trigger `AFTER`) → branche **reader** d'un EF notify → **mail i18n**, + insertion `user_notifications` pour restriction/gel (réplique B3). Events proposés :

- `cotisation_payment_recorded`
- `member_restricted_local` / `member_unrestricted_local`
- `member_frozen_global` / `member_unfrozen_global`

Robustesse : le dispatch est **best-effort** (un échec pg_net/secret ne casse pas l'acte métier — pattern déjà en place dans la circulation) ; gérer le cas **membre sans e-mail** (skip + log, l'in-app reste posée pour restriction/gel).

## 7. Arbitrages — ✅ tranchés le 08/06/2026 (validés Xavier)

1. **Notifier les levées (unrestrict / unfreeze) ?**
   - ✅ *Tranché* : **OUI**. Une levée rétablit des droits — symétrie et transparence avec la notification de restriction. E-mail + courte réplique in-app.
2. **E-mail cotisation : toujours actif ou configurable par biblio ?**
   - ✅ *Tranché* : **configurable, défaut ON** (souveraineté biblio, Position 1). Nouvelle colonne `cotisation_payment_mail_enabled`. Une biblio en gestion informelle peut couper.
3. **`profile_restriction_enabled` (toggle existant) vs « obligatoire/non configurable » de la doctrine.**
   - ✅ *Tranché* : le mail **au membre** reste **obligatoire** (plancher éthique : pas de restriction en silence) ; **réinterpréter ce toggle en « copie staff »** (le collectif reçoit une copie/log, optionnelle — cohérent avec les colonnes `admin_copy_*_enabled`). Sinon : vestige documenté, inutilisé.
4. **Contenu des mails.**
   - ✅ *Tranché* : restriction/gel = **motif obligatoire + portée** (biblio locale vs réseau) + date ; pour le « qui », nommer **le collectif / la biblio** plutôt que l'individu (doctrine anti-méga-machine). Cotisation = **montant + période de validité (nouvelle échéance) + méthode** (un vrai reçu).

## 8. Dépendances & séquencement

- **#110 (Resend)** : clos → transport e-mail stabilisé, plus aucun blocage.
- **Pattern prorrogação** : précurseur disponible, à dupliquer côté reader.
- **Suite** : une fois les 4 arbitrages validés → ouverture du chantier (REGISTRE + backlog), puis câblage par famille (dispatch + EF + i18n + in-app), en respectant l'ordre de déploiement **EF → migration**.

---

*Audit livré le 08/06/2026. Constats factuels établis en base réelle ; les 4 arbitrages ont été tranchés le 08/06/2026 (validés Xavier). Chantier ouvert au REGISTRE (§6 `NOTIF-PA*`) et au backlog (#NOTIFY-Painel-acts). Câblage à suivre, par famille, en blocs vérifiés.*
