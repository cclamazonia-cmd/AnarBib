# Spec — Notifications lecteur·rice (canal in-app)

**Statut** : v1.0 — 31/05/2026
**Auteur** : session Xavier + Claude, dans la continuité des chantiers #CL.6 et #CL.7
**Périmètre** : la boîte aux lettres in-app côté `/conta` (table `user_notifications`, onglet `avisos`). Ne couvre pas le canal e-mail (gouverné par `library_notification_policies` et les outboxes par domaine), sauf pour expliciter l'articulation entre les deux canaux.

---

## Sommaire

- [1. Motivation](#1-motivation)
- [2. Cartographie de l'existant](#2-cartographie-de-lexistant)
- [3. Doctrine](#3-doctrine)
- [4. Taxonomie des catégories légitimes](#4-taxonomie-des-catégories-légitimes)
- [5. Configurabilité](#5-configurabilité)
- [6. Conséquences pratiques](#6-conséquences-pratiques)
- [7. Décisions ouvertes](#7-décisions-ouvertes)

---

## 1. Motivation

L'onglet `avisos` du compte lecteur·rice (`/conta`) existe depuis le paquet 10 (10/05/2026) et a reçu plusieurs raffinements depuis : compteur de non-lus, marquage individuel/global comme lu, intégration RGPD, et — le 31/05/2026 — archivage par ligne et vue archives (#CL.6).

Mais aucun document n'a jamais formalisé **par quels mécanismes l'onglet est alimenté**, ni **selon quels critères politiques** une notification mérite d'y figurer. La conséquence : l'onglet est techniquement opérationnel mais doctrinalement muet. Une lectrice peut s'y connecter sans pouvoir comprendre pourquoi elle voit telle notification, pourquoi elle n'en voit pas une autre qu'elle attendait, ou par quel canal elle est en réalité prévenue de quoi.

Cette spec comble ce manque en énonçant la doctrine, la taxonomie, et les invariants. Elle n'invente rien : elle rend explicite une logique déjà à l'œuvre dans le projet, et tranche les zones qui restaient ambiguës.

---

## 2. Cartographie de l'existant

État relevé en base de production le 31/05/2026, par requêtes directes sur `pg_proc`, `information_schema`, et `pg_trigger`.

### 2.1 Treize triggers de notification — un seul écrit dans `user_notifications`

L'inventaire des triggers actifs touchant à la notification donne treize résultats, répartis sur les domaines : circulation (consulta, réserva, peb), gouvernance (library profile proposals/votes/history, library requests, cross-library admin), tâches painel (invitation, notification, team), document permissions.

**Mais sur ces treize triggers, aucun n'écrit dans `public.user_notifications`.** Ils alimentent des tables d'events ou d'outboxes par domaine métier — toutes orientées émission e-mail.

La **seule** fonction backend qui écrit dans `user_notifications` est `fn_notify_users_before_purge` (RGPD), invoquée par scheduler et non par trigger métier. Elle insère trois catégories préventives : `rgpd_retention_loans`, `rgpd_retention_reservations`, `rgpd_retention_consultations`, dans une fenêtre de 30 jours avant purge, de manière idempotente (re-vérification sur 40 jours pour éviter les doublons).

### 2.2 Treize tables/vues dédiées à la notification — toutes orientées e-mail

L'écosystème backend des notifications est en réalité riche et structuré :

- **5 tables d'events par domaine métier** : `document_permission_request_notification_events`, `interlibrary_loan_notification_events`, `library_request_notification_events`, plus une table archivée du 08/04/2026, plus les events implicites portés par les outboxes painel.
- **3 outboxes painel** : `painel_internal_task_invitation_outbox`, `painel_internal_task_notification_outbox`, `team_notification_outbox`. Domaine staff/admin.
- **4 tables de configuration biblio** : `library_email_identity`, `library_mail_channels`, `library_notification_policies` (45 colonnes d'activation fine par étape de workflow), `library_notification_profiles`. Plus une vue `v_library_notification_context`.
- **1 table `user_notifications`** : 2 lignes en prod à la date de rédaction (1 `info`, 1 `sistema`), plus quelques traces de test du 31/05. **Quasi vide.**

L'écart entre la richesse de l'infrastructure e-mail et la quasi-vacuité de l'in-app n'est pas un bug — c'est l'expression non documentée d'un choix architectural cohérent que cette spec va expliciter en §3.

### 2.3 `library_notification_policies` : 45 colonnes, toutes orientées canal e-mail

Inspection détaillée du schéma : 15 colonnes `reservation_mail_<étape>_enabled` (une par étape du workflow réservation), 6 colonnes `consulta_mail_<étape>_enabled`, 5 colonnes `loan_*_enabled` (lifecycle, reminders, overdue, mid-loan message, recommendations), 3 colonnes `admin_copy_*_enabled` (copie staff des notifs lectrice), plus deux colonnes techniques (`tech_alerts_enabled`, `task_alerts_enabled`), plus quelques colonnes de paramétrage workflow (timeouts, négociation).

**Aucune colonne `_inapp_enabled`.** La configurabilité actuelle porte exclusivement sur l'émission e-mail. La canal in-app ne dispose d'aucun levier de politique au niveau biblio aujourd'hui.

### 2.4 Aucune table de préférences côté lectrice

Recherche en base : aucune table `user_notification_preferences` ni équivalent. La configurabilité, là où elle existe, est exclusivement au niveau biblio. Les lectrices subissent (ou bénéficient de) la politique de leur biblio courante, sans levier d'ajustement individuel à ce jour.

---

## 3. Doctrine

Trois principes directeurs, ordonnés du plus général au plus particulier.

### 3.1 Critère d'admission (Doctrine A)

> *Toute notification doit permettre au lecteur de prendre conscience d'un état qui nécessite une action de sa part ou l'avertit d'une décision qui l'impacte.*

Deux portes d'entrée donc : **action requise** ou **impact subi**. Tout événement qui n'ouvre ni l'une ni l'autre n'a pas vocation à être notifié. Cas typiques exclus par ce critère : information statistique, recommandation marketing, marqueur technique interne, événement administratif sans conséquence personnelle.

### 3.2 Canal primaire vs réplique (Doctrine B, **lecture restrictive**)

> *L'e-mail est la base. La notification dans l'app est une réplique sélective — uniquement quand l'in-app est utile et nécessaire.*

**Lecture explicite : restrictive.** L'in-app n'est pas un doublon systématique de l'e-mail. C'est un canal de **relais ciblé**, mobilisé quand au moins l'une de ces trois conditions est remplie :

- **(B1) L'e-mail ne suffit pas à garantir que la lectrice agira** dans le délai requis (typique RGPD : si la lectrice ne lit pas son mail dans 30 jours, ses données sont purgées sans recours).
- **(B2) L'action demandée se situe entièrement dans l'app** et un détour par e-mail n'apporte rien (typique : réservation prête à retirer — la lectrice doit venir chercher physiquement, l'in-app sert de mémo persistant à chaque connexion).
- **(B3) L'événement est une décision qui impacte les droits de la lectrice** et doit laisser une trace consultable en permanence dans son compte (typique : restriction, exclusion, modification de cotisation par décision collective).

**Sans aucune de ces trois conditions, pas de réplique in-app.** Le mail seul suffit, et `user_notifications` reste vide pour cet événement.

### 3.3 Périmètre lectrice exclusif (Doctrine C)

`user_notifications` est, par cette spec, **doctrinalement réservée au rôle reader**. Une lectrice qui est aussi staff voit :

- ses **notifs reader** dans `/conta/avisos`,
- ses **notifs staff** dans le painel, via les outboxes painel dédiées (`painel_internal_task_notification_outbox`, `team_notification_outbox`, etc.).

Aucune ligne `user_notifications` ne doit jamais être insérée pour notifier d'un événement qui s'adresse à la personne en tant que rôle staff. Si un événement la concerne aux deux titres (par exemple, une exclusion qui affecte aussi sa fonction staff), il génère deux notifications distinctes — une dans chaque surface — avec des contenus adaptés au rôle d'arrivée.

Cette doctrine confirme et formalise une situation **déjà de facto** : à la rédaction de cette spec, aucun trigger n'écrit dans `user_notifications` pour le compte d'un événement staff. L'inscrire en doctrine empêche les futurs développements de mélanger les rôles dans la même boîte.

---

## 4. Taxonomie des catégories légitimes

Application méthodique de la doctrine A et B aux événements émis aujourd'hui par les triggers/outboxes du projet, plus quelques catégories prospectives.

Pour chaque catégorie : *nom de catégorie* + *canal e-mail* + *réplique in-app (oui/non + condition B remplie)* + *configurabilité* + *justification politique*.

### 4.1 Circulation — réservations

**Catégorie `reserva_pronta_para_retirada`** (et équivalents en cours de workflow où la lectrice doit agir : `retirada_a_combinar`, `retirada_reagendada`).
- E-mail : **oui** (déjà géré par `library_notification_policies.reservation_mail_*_enabled`).
- In-app : **oui — B2**. La lectrice doit physiquement se rendre à la biblio ; le mémo persistant dans `/conta` est utile à chaque connexion.
- Configurable lectrice : **oui**, mais réduction seule (cf. §5 — Position 1 souveraineté biblio).
- Justification : trace utile, pas d'information sensible, action concrète attendue.

**Catégories d'étapes intermédiaires** (`solicitada`, `em_preparacao`, `liberada_para_circulacao`, `retirada_efetivada`, `expirada`, `cancelada_*`).
- E-mail : **selon politique biblio** (configurable au cas par cas).
- In-app : **non**. Ces étapes sont visibles via l'onglet `reservas` qui montre l'état courant. La notification serait redondante avec la consultation directe.

### 4.2 Circulation — consultations sur place

**Catégorie `consulta_pronta`** (consultation validée, lectrice attendue).
- E-mail : **oui** (existant).
- In-app : **oui — B2** (même raisonnement que réservations).
- Configurable lectrice : **oui**, réduction seule.

Autres étapes consulta : **non répliquées in-app**, visibles via onglet `reservas-et-consultas`.

### 4.3 Circulation — emprunts

**Catégorie `emprestimo_atrasado`** (prêt en retard, action immédiate requise pour éviter restriction).
- E-mail : **oui** (`loan_overdue_enabled`).
- In-app : **oui — B3**. Le retard a une conséquence directe sur les droits (restriction d'emprunt). La trace in-app est utile pour comprendre le statut du bandeau de compte (`fn_my_account_status`).
- Configurable lectrice : **non** (B3 = impact sur les droits = non désactivable).

**Catégorie `emprestimo_lembrete`** (rappel pré-échéance, J-3 par exemple).
- E-mail : **oui** (`loan_reminders_enabled`).
- In-app : **non**. La date d'échéance est visible dans l'onglet `curso`, le rappel mail suffit.

### 4.4 Cotisation

**Catégorie `cotisacao_expiracao_proche`** (échéance dans X jours).
- E-mail : **selon politique biblio** (à ajouter si pas déjà couvert par `library_notification_policies`).
- In-app : **non**. Le bandeau de compte (`fn_my_account_status`) signale déjà l'état `expired` / `expiring_soon`. La notification serait redondante.

**Catégorie `cotisacao_paiement_enregistre`** (paiement confirmé côté staff).
- E-mail : **oui** (acte administratif méritant trace écrite).
- In-app : **non**, le bandeau passe en `valid` automatiquement, et la mention figure dans `account.cotisation.history`.

### 4.5 Gouvernance impactant la lectrice

**Catégorie `decision_restriction`** (suspension/restriction prononcée par décision collective).
- E-mail : **oui, obligatoire**, avec motif de la décision (cf. paquet `decided_by` du 30/05).
- In-app : **oui — B3, obligatoire**. La décision modifie les droits ; la trace doit être consultable à chaque connexion. Le bandeau de compte signale l'état, mais la notification donne le motif détaillé.
- Configurable lectrice : **non, jamais**. Acte fort, indispensable, non désactivable par doctrine.

**Catégorie `decision_exclusion`** (exclusion d'une biblio).
- Idem `decision_restriction` mais sur événement terminal. **Obligatoire e-mail + in-app.**

**Catégorie `migration_compte_ou_appartenance`** (modification structurelle du rattachement, ajout/retrait d'une biblio).
- E-mail : **oui**, acte administratif.
- In-app : **oui — B3**. Modifie le périmètre des droits, mérite trace consultable.
- Configurable : **non**.

### 4.6 RGPD — invariants légaux

**Catégories `rgpd_retention_loans`, `rgpd_retention_reservations`, `rgpd_retention_consultations`** (préavis de purge à 30 jours).
- E-mail : **à clarifier** — la fonction `fn_notify_users_before_purge` ne s'accompagne d'aucune émission e-mail dans son corps. Soit l'e-mail est émis ailleurs, soit ce flux est in-app exclusif (auquel cas, anomalie de doctrine — un préavis légal devrait toujours doubler le canal). Voir §7.
- In-app : **oui — B1, obligatoire**. C'est précisément la condition B1 : si la lectrice ne lit pas son mail, sa donnée est purgée. L'in-app est le filet.
- Configurable : **non, jamais**. Acte légal.

**Catégorie `rgpd_export_pret`** (export de données personnelles prêt à télécharger, fonctionnalité future).
- E-mail + in-app **oui — B1**. Idem RGPD purge.

### 4.7 Modération de contenu (si applicable)

**Catégorie `contenu_signale_action_requise`** (un contenu posté par la lectrice — note, commentaire — fait l'objet d'une modération).
- E-mail : **oui**.
- In-app : **oui — B3**. Décision impactant son expression.
- Configurable : **non**.

### 4.8 Catégories *non* admises (exclues par la doctrine)

Pour mémoire, les catégories qui **ne** méritent **pas** de réplique in-app malgré leur présence éventuelle dans le système e-mail :

- Newsletters, recommandations de lecture, suggestions d'événements.
- Informations statistiques (« vous avez emprunté X livres ce trimestre »).
- Étapes intermédiaires de workflow sans action lectrice (cf. §4.1).
- Toute notification dont le destinataire est en réalité un rôle staff (cf. Doctrine C).

---

## 5. Configurabilité

### 5.1 Position 1 — Souveraineté biblio, ajustement lectrice à la baisse

**Doctrine** : la lectrice ne peut **que réduire** ce que la biblio envoie. Elle ne peut pas activer une catégorie que la biblio n'a pas activée. Cohérent avec le principe fédéraliste — chaque collectif décide pour son périmètre, l'individu ajuste à l'intérieur.

### 5.2 Catégories effectivement configurables côté lectrice

D'après §4, **trois catégories seulement** sont à la fois répliquées in-app et configurables :

- `reserva_pronta_para_retirada` (et équivalents workflow réserva « action lectrice »)
- `consulta_pronta`
- (Éventuellement, à arbitrer : étapes intermédiaires si la biblio les a activées en mail)

Tout le reste est soit non configurable (RGPD, décisions impactantes), soit non répliqué in-app (cf. §4 catégories exclues).

### 5.3 Implication pour #CL.7

L'écran de préférences notifications de la lectrice est donc **minimal** : deux ou trois toggles, plus un encadré pédagogique expliquant que certaines notifications sont obligatoires.

Maquette de contenu envisageable :

> **Tes notifications**
>
> Tu peux ajuster les notifications que tu reçois dans cette app, dans la limite de ce que ta bibliothèque transmet.
>
> - [✓] Réservation prête à retirer
> - [✓] Consultation validée
>
> **Toujours actives** : décisions collectives qui te concernent, alertes RGPD, restrictions et exclusions. Ces notifications ne sont pas désactivables car elles touchent à tes droits.

### 5.4 Stockage technique des préférences

Nouvelle table à créer (dans un chantier ultérieur, pas dans cette spec) :

```sql
CREATE TABLE public.user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Désactivations par catégorie (NULL = défaut biblio respecté)
  disable_reserva_pronta boolean NOT NULL DEFAULT false,
  disable_consulta_pronta boolean NOT NULL DEFAULT false,
  -- ...autres catégories configurables au fil de l'évolution
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

Une rangée par lectrice qui a modifié au moins une préférence. Absence de rangée = comportement par défaut (réplique in-app selon politique biblio).

---

## 6. Conséquences pratiques

### 6.1 Sur l'onglet `avisos` actuel

**Aucune modification immédiate du code n'est nécessaire** pour appliquer cette doctrine. L'onglet est techniquement prêt : il sait afficher, archiver, restaurer, marquer comme lu. Le travail à venir consiste à **câbler les triggers manquants** qui inséreront les catégories légitimes au moment opportun.

### 6.2 Câblages à faire (chantiers ultérieurs)

Par ordre de priorité décroissante, à inscrire au backlog :

**Priorité haute** :
- Trigger de réplique in-app sur `reserva_pronta_para_retirada` (B2 — action lectrice physique).
- Trigger sur `emprestimo_atrasado` (B3 — impact droits).
- Vérification que la RGPD purge est bien doublée d'un mail (cf. §7).

**Priorité moyenne** :
- Trigger sur `consulta_pronta`.
- Trigger sur `decision_restriction` / `decision_exclusion` quand le module gouvernance lectrice arrive.

**Priorité basse / à ouvrir plus tard** :
- Table `user_notification_preferences` + UI de préférences (résolution #CL.7).
- Catégorie modération de contenu si/quand la fonctionnalité existe.

### 6.3 Sur l'onglet `avisos` — explicabilité

Une affordance à considérer pour une version future : chaque catégorie devrait pouvoir être accompagnée d'une explication accessible (tooltip ou page d'aide) répondant à *« pourquoi je reçois ça ? »*. Cette explication ancre la légitimité doctrinale de chaque notification dans l'expérience de la lectrice.

À envisager comme prolongement de cette spec, pas comme exigence immédiate.

### 6.4 Sur les catégories RGPD existantes

Les trois catégories `rgpd_retention_*` actuellement émises sont conformes à la doctrine (B1 — l'in-app est filet de sécurité légal). À conserver telles quelles.

Une vérification reste à faire : s'assurer que `fn_notify_users_before_purge` est bien accompagnée d'une émission e-mail symétrique. Sinon, le préavis légal est in-app exclusif, ce qui violerait la doctrine B (e-mail = canal primaire). Voir §7.

---

## 7. Décisions ouvertes

### 7.1 Le préavis RGPD est-il doublé d'un e-mail ?

Action : vérifier dans le pipeline RGPD (probablement une edge function ou un job scheduler distinct) si chaque insertion dans `user_notifications` pour les catégories `rgpd_retention_*` est accompagnée d'un mail à la lectrice. Si non, à compléter — un préavis légal qui ne passe que par l'in-app est insuffisant.

### 7.2 Statut de `user_notifications.is_read` vs `archived_at`

Cette spec n'introduit pas de nouvelle sémantique sur ces deux champs déjà existants (`is_read`, ajouté avant) et `archived_at` (ajouté en #CL.6, 31/05/2026). À noter pour mémoire :

- `is_read = false` → la lectrice n'a pas encore *vu* la notification.
- `archived_at IS NOT NULL` → la lectrice a *traité* (consciemment écarté) la notification.

Pas de purge automatique à ce jour. Les notifications archivées restent en base indéfiniment, sauf intervention RGPD si elles dépassent la rétention configurée (à clarifier — la rétention `retention_notifications_days` figure dans la politique biblio mais l'application pratique reste à vérifier).

### 7.3 Limite frontend à 100 notifications par chargement

La requête actuelle dans `AccountPage.jsx` limite le chargement à 100 lignes. Pour la quasi-totalité des cas réels (peu de notifications légitimes par la doctrine restrictive), c'est largement suffisant. À revoir si certaines catégories à forte fréquence apparaissent — mais a priori la doctrine garantit qu'on n'y arrivera pas.

---

## Annexe — Référence rapide

| Catégorie | E-mail | In-app | Configurable | Condition B |
|-----------|--------|--------|--------------|-------------|
| `reserva_pronta_para_retirada` | ✓ | ✓ | Réduction seule | B2 |
| `consulta_pronta` | ✓ | ✓ | Réduction seule | B2 |
| `emprestimo_atrasado` | ✓ | ✓ | **Non** | B3 |
| `emprestimo_lembrete` | ✓ | ✗ | — | — |
| `cotisacao_*` | ✓ | ✗ | — | — |
| `decision_restriction` | ✓ | ✓ | **Non** | B3 |
| `decision_exclusion` | ✓ | ✓ | **Non** | B3 |
| `migration_compte` | ✓ | ✓ | **Non** | B3 |
| `rgpd_retention_*` | À vérifier | ✓ | **Non** | B1 |
| Newsletters, recommandations | ✓ (selon politique) | ✗ | — | — |
| Étapes intermédiaires workflow | ✓ (selon politique) | ✗ | — | — |
| Toute notif staff | (canal painel) | ✗ par doctrine C | — | — |

---

*Spec rédigée le 31/05/2026 dans la session Xavier + Claude qui a livré #CL.6 (archivage notifications) en début d'après-midi et a ouvert la question doctrinale qui a produit ce document. Doctrine A et B formulées par Xavier en deux phrases ; cette spec en déduit les conséquences cataloguées.*
