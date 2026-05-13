# Workflow réservation v2 — Négociation symétrique

> **Statut** : proposition pour discussion collective au CCLA.
> **Auteur·rice** : AnarBib · Mai 2026.
> **À valider avant implémentation.**

---

## 1. Principe politique

Pour une bibliothèque anarchiste militante, la relation entre lecteur·rice et biblio n'est pas hiérarchique. Le créneau de retrait n'est pas dicté par l'institution puis simplement validé/refusé : il est **négocié symétriquement** entre les deux parties.

La spec v1 modélisait une relation descendante (la biblio propose, le lecteur valide ou refuse). La v2 introduit la symétrie : les deux parties peuvent **proposer**, **accepter**, **contre-proposer** ou **annuler** à tout moment.

Cette refonte n'est pas un changement de spec gratuit : c'est l'inscription dans le code d'un choix politique de prefigurative organizing. Le code reflète l'éthique du collectif.

## 2. Flux de négociation (mermaid)

​```mermaid
stateDiagram-v2
    [*] --> solicitada : Lecteur·rice crée la résa

    solicitada --> em_preparacao : Biblio prend en charge
    em_preparacao --> proposta_biblio : Biblio propose un créneau
    em_preparacao --> retirada_a_combinar : Biblio dit "viens quand tu peux\navant le X"

    state "proposta_biblio" as proposta_biblio
    note right of proposta_biblio
      Stage : retirada_agendada
      proposed_by : biblio
      Lecteur·rice voit boutons :
      - Accepter
      - Contre-proposer (si autorisé)
      - Annuler
    end note

    proposta_biblio --> creneau_confirme : Lecteur·rice accepte
    proposta_biblio --> proposta_leitor : Lecteur·rice contre-propose
    proposta_biblio --> [*] : Annulation (lecteur ou biblio)

    state "proposta_leitor" as proposta_leitor
    note left of proposta_leitor
      Stage : re-retirada_agendada
      proposed_by : leitor
      Biblio voit boutons :
      - Accepter
      - Contre-proposer
      - Annuler
    end note

    proposta_leitor --> creneau_confirme : Biblio accepte
    proposta_leitor --> proposta_biblio : Biblio contre-propose
    proposta_leitor --> [*] : Annulation

    state "creneau_confirme" as creneau_confirme
    note right of creneau_confirme
      Stage inchangé
      proposed_by : null
      Les deux parties d'accord
    end note

    creneau_confirme --> pronta_para_retirada : Jour J approche
    creneau_confirme --> [*] : Annulation

    retirada_a_combinar --> pronta_para_retirada : Lecteur·rice passe
    retirada_a_combinar --> proposta_biblio : Biblio fixe finalement un créneau
    retirada_a_combinar --> proposta_leitor : Lecteur·rice propose un créneau
    retirada_a_combinar --> [*] : Annulation ou expiration

    pronta_para_retirada --> retirada_efetivada : Lecteur·rice vient
    pronta_para_retirada --> retirada_no_show : Cron (no-show)
    pronta_para_retirada --> [*] : Annulation

    retirada_efetivada --> [*]
    retirada_no_show --> [*]
​```

## 3. Décisions politiques validées

### 3.1. Timeout global = 21 jours

Une réservation entrée en phase de négociation (`retirada_a_combinar`, `retirada_agendada`, `re-retirada_agendada`) qui n'aboutit pas au bout de **21 jours après création de la résa initiale** est automatiquement passée en `expirada` par cron, avec notification aux deux parties.

Ce timeout libère le livre pour quelqu'un d'autre quand la négociation s'enlise. C'est un garde-fou, pas une autorité : il ne bloque pas la conversation tant qu'elle progresse activement.

### 3.2. Possibilité de désactiver la contre-proposition côté lecteur

Certaines structures (créneaux fixes, ouverture rare) ne peuvent pas négocier. Un nouveau paramètre par bibliothèque autorisera la biblio à désactiver la fonction de contre-proposition côté lecteur. Dans ce cas, le lecteur·rice ne voit que les boutons « Accepter » et « Annuler ».

Par défaut, la fonction est **activée** (cohérence avec l'éthique anarchiste). Les bibliothèques peuvent la désactiver explicitement.

### 3.3. Limite de 3 itérations

Pour éviter l'enlisement, la négociation est plafonnée à **3 contre-propositions** par cycle (initial + 2 contres). Au-delà, le système recommande explicitement à la biblio et au lecteur·rice de poursuivre **par téléphone, par mail, ou de visu** plutôt que via le SIGB.

Cette limite reconnaît que tout n'a pas vocation à être médié par un outil informatique. Quand la négociation devient compliquée, l'humain prend le relais.

UI : après la 3e itération, l'option « contre-proposer » disparaît et un message s'affiche :

> *« La négociation s'est étendue. Pour finaliser, contactez directement [biblio/lecteur·rice] : [coordonnées]. »*

### 3.4. Notifications immédiates pour les contre-propositions du lecteur

Quand un·e lecteur·rice propose un créneau (`pickup_proposed_by = 'leitor'`), la biblio reçoit une notification **immédiate** (mail + Matrix si configuré). Pas de regroupement nocturne.

Justification : la négociation doit fluider. Un délai de 12-24h entre chaque échange briserait la dynamique. Les bénévoles peuvent désactiver les notifications email pour leur propre confort, mais le déclenchement reste immédiat.

## 4. Modifications du schéma DB

### 4.1. Nouvelle colonne `pickup_proposed_by`

​```sql
ALTER TABLE public.reserva_item_workflow_v2
  ADD COLUMN pickup_proposed_by text 
    CHECK (pickup_proposed_by IN ('biblio', 'leitor') OR pickup_proposed_by IS NULL);
​```

Sémantique :
- `'biblio'` : la dernière proposition vient de la biblio, en attente de réponse du lecteur·rice
- `'leitor'` : la dernière proposition vient du lecteur·rice, en attente de réponse de la biblio
- `NULL` : créneau confirmé (les deux parties d'accord) ou pas de proposition en cours

### 4.2. Nouvelle colonne `negotiation_iteration_count`

​```sql
ALTER TABLE public.reserva_item_workflow_v2
  ADD COLUMN negotiation_iteration_count int NOT NULL DEFAULT 0,
  ADD CONSTRAINT chk_negotiation_iteration_max 
    CHECK (negotiation_iteration_count <= 3);
​```

Compteur qui s'incrémente à chaque contre-proposition. La contrainte CHECK empêche un dépassement même par bug applicatif.

### 4.3. Nouveau paramètre par bibliothèque

​```sql
ALTER TABLE public.library_notification_policies
  ADD COLUMN reservation_allow_reader_counter_proposal boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_negotiation_timeout_days int NOT NULL DEFAULT 21,
  ADD CONSTRAINT chk_negotiation_timeout 
    CHECK (reservation_negotiation_timeout_days BETWEEN 7 AND 60);
​```

## 5. Modifications de la matrice de transitions

Une seule transition est ajoutée dans `fn_check_workflow_transition` :

​```
Depuis retirada_agendada :
  Lecteur·rice peut transitionner vers re-retirada_agendada 
  (= contre-proposition du lecteur)
  → uniquement si reservation_allow_reader_counter_proposal = true 
    pour la bibliothèque concernée
  → uniquement si negotiation_iteration_count < 3
​```

Toutes les autres transitions de la matrice v1 restent inchangées.

## 6. Conséquences UI

### 6.1. Côté lecteur·rice (`/conta`)

**Quand `pickup_proposed_by = 'biblio'`** (la biblio propose un créneau) :
- Affichage : « La biblio te propose : [date]. Tu peux : »
- Bouton « Confirmer ce créneau »
- Bouton « Proposer un autre créneau » *(visible uniquement si la biblio l'autorise et si itération < 3)*
- Bouton « Annuler ma résa »

**Quand `pickup_proposed_by = 'leitor'`** (le lecteur a contre-proposé) :
- Affichage : « Tu as proposé : [date]. En attente de la biblio. »
- Bouton « Modifier ma proposition »
- Bouton « Annuler ma résa »

**Quand `pickup_proposed_by = NULL` et créneau confirmé** :
- Affichage : « Créneau confirmé : [date]. Retire à la biblio le jour prévu. »
- Bouton « Annuler ma résa » (jusqu'à `pronta_para_retirada`)

**Après 3 itérations atteintes** :
- Affichage : « La négociation a atteint sa limite. Contacte directement la biblio par téléphone ou mail : [coordonnées]. »
- Bouton « Annuler ma résa »

### 6.2. Côté biblio (`/painel`)

**Quand `pickup_proposed_by = 'biblio'`** :
- Tâche normale dans la liste : « En attente de réponse de [lecteur·rice] sur [date proposée] »
- Pas de bouton de modification (la balle est dans le camp du lecteur·rice)

**Quand `pickup_proposed_by = 'leitor'`** :
- Tâche **prioritaire** (notification immédiate) : « [lecteur·rice] propose [date]. À traiter. »
- Boutons « Confirmer », « Contre-proposer » *(si itération < 3)*, « Annuler avec raison »

## 7. Templates mails à ajouter

- `mail_pickup_proposed_by_biblio_to_reader.html` (la biblio propose au lecteur)
- `mail_pickup_proposed_by_reader_to_biblio.html` (le lecteur propose à la biblio)
- `mail_pickup_confirmed_to_both.html` (créneau confirmé par les deux)
- `mail_negotiation_max_iterations.html` (limite des 3 itérations atteinte)
- `mail_negotiation_timeout_to_both.html` (timeout global de 21 jours atteint)

## 8. Plan d'implémentation par paquets testables

**Paquet 1 — Schéma DB** (migration unique idempotente)
- Nouvelles colonnes `pickup_proposed_by`, `negotiation_iteration_count`
- Nouveaux paramètres `reservation_allow_reader_counter_proposal`, `reservation_negotiation_timeout_days`
- Mise à jour de la matrice de transitions

**Paquet 2 — Edge Functions et triggers**
- Edge function `fn_propose_pickup_slot_as_reader` (RPC pour la contre-proposition lecteur)
- Edge function `fn_propose_pickup_slot_as_library` (côté biblio)
- Trigger pour incrémenter `negotiation_iteration_count`
- Cron pour le timeout global de 21 jours

**Paquet 3 — UI lecteur·rice**
- Refonte de `AccountPage.jsx`/`ReservationCard` pour gérer les 4 états
- Date-picker pour la contre-proposition
- Affichage du compteur d'itérations (subtle, pas anxiogène)

**Paquet 4 — UI staff**
- Refonte de `PanelPage.jsx` pour distinguer les tâches normales/prioritaires
- Notification Matrix immédiate côté staff
- Réglage de `reservation_allow_reader_counter_proposal` dans `BibliotecaPage`

**Paquet 5 — Templates mails et i18n**
- 5 nouveaux templates (FR/PT-BR/EN/DE/IT/ES)
- Clés i18n pour les nouveaux libellés

**Paquet 6 — Tests**
- Tests unitaires sur la matrice de transitions étendue
- Tests d'intégration end-to-end (cycle complet de négociation)
- Vérification du compteur d'itérations
- Vérification du timeout global

## 9. Compatibilité ascendante

Cette spec étend la v1 sans la casser :

- Les résas existantes en `retirada_agendada` fonctionneront comme avant (le `pickup_reply_status` v1 reste opérationnel)
- Les nouvelles colonnes `pickup_proposed_by` et `negotiation_iteration_count` sont nullable/zéro par défaut
- La désactivation de `reservation_allow_reader_counter_proposal` rend le système indistinguable de la v1 du point de vue lecteur·rice

## 10. Points encore ouverts pour discussion collective

- [ ] La désactivation côté biblio doit-elle être visible aux lecteur·rices (« cette biblio n'autorise pas les contre-propositions ») ? Transparence vs simplicité ?
- [ ] Quand la limite de 3 itérations est atteinte, faut-il afficher au lecteur les coordonnées **personnelles** des bénévoles, ou juste celles de la biblio ?
- [ ] La séparation `pickup_reply_status` (v1) vs `pickup_proposed_by` (v2) crée deux mécanismes parallèles. Faut-il dépréciér `pickup_reply_status` à terme ?
- [ ] Sur Matrix, quel niveau de notification (silencieux, sonore, alerte) pour les contre-propositions lecteur·rice ?