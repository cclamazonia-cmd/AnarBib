# Spec refactor v3 — sémantique du workflow réservation

> ## ⚠️ Note de clôture — 31/05/2026
>
> **Statut actuel** : référence historique — décision actée et appliquée en production.
> Cette doctrine sémantique a été appliquée au **paquet 5b du 09/05/2026**, qui a aligné les labels des stages sur leur mécanique de négociation effective. La spec sert désormais à reconstituer le raisonnement d'origine.
>
> Source : résumé `docs/decisions/AnarBib_decisions_synthese_2026-05-29.docx`, section « Acquis », entrée Paquet 5b.
>
> Le bloc de métadonnées ci-dessous est celui de la rédaction d'origine, conservé pour traçabilité.

**Date** : 2026-05-09
**Statut** : décidé, non appliqué (paquet 5a en cours de rédaction)
**Origine** : session 2026-05-08, identification d'une incohérence sémantique entre le label des stages et leur mécanique de négociation.

## Résumé

Le workflow réservation v2 (paquets 1-4) traite `retirada_agendada` comme stage principal de négociation et `re-retirada_agendada` comme boucle de re-proposition. C'est sémantiquement faux :

- `agendar` = forme aboutie (créneau verrouillé)
- `combinar` = forme verbale en cours (négociation active)
- `re-agendar` = relance d'un créneau verrouillé, n'a aucune raison d'exister si la négociation se fait correctement dans `a_combinar`

Le refactor v3 inverse la sémantique :

- **`retirada_a_combinar`** devient le stage de négociation active (proposition + contre-proposition + confirmation)
- **`retirada_agendada`** devient le stage d'aboutissement (créneau verrouillé après accord mutuel)
- **`re-retirada_agendada`** est déprécié (matrice false partout, conservé comme fossile pour les résas historiques)

## Décisions politiques actées (session 2026-05-08)

### Q1 — Pas de chemin direct vers `retirada_agendada`

Le staff **ne peut plus** faire passer une résa directement de `solicitada` ou `em_preparacao` vers `retirada_agendada`. Le seul chemin vers `retirada_agendada` est la confirmation mutuelle depuis `retirada_a_combinar`.

**Rationale éthique** : un créneau imposé sans communication préalable contredit le modèle anarchiste de relation symétrique. La biblio doit toujours d'abord proposer dans `retirada_a_combinar`, et l'accord se matérialise par la transition vers `retirada_agendada`.

### Q2 — Cron timeout retiré de `retirada_agendada`

Le cron `fn_expire_negotiation_timeout` n'agit plus sur `retirada_agendada`. Une fois le créneau verrouillé, il a une date précise et `retirada_no_show` gère le cas où il n'est pas honoré. Sinon les deux mécanismes se recouvrent.

Le cron continue d'agir sur : `em_preparacao`, `retirada_a_combinar`. (Le `re-retirada_agendada` est retiré aussi puisque déprécié.)

### Q3 — `re-retirada_agendada` déprécié

Le stage est conservé dans la matrice avec `false` partout (aucune transition entrante ni sortante autorisée pour les nouveaux usages). Cela évite de casser les résas historiques qui pourraient avoir ce stage.

À supprimer définitivement au paquet 7 de polish, après vérification SQL qu'aucune ligne n'est plus en ce stage en prod :

```sql
SELECT COUNT(*) FROM public.reserva_item_workflow_v2
WHERE workflow_stage = 're-retirada_agendada';
-- Doit être 0 avant suppression du stage du code.
```

### Q4 — Tâche `toScheduleWithReader` conservée

L'approche A du paquet 4 (rendre visible la tâche `retirada_a_combinar` dans Trabalho do dia) est conservée même après le refactor v3. La tâche reste pertinente : elle alerte le staff qu'une négociation est ouverte et nécessite son attention.

### Q5 — Commit en deux paquets

- **Paquet 5a (DB only)** : matrice + wrappers + cron + tests SQL. Testable de manière isolée.
- **Paquet 5b (UI)** : refonte PanelPage + AccountPage + NegotiationStateBadge + i18n recalibration. À faire avec un cerveau frais après validation du 5a.

## Matrice de transitions cible

| De / Vers | em_preparacao | retirada_a_combinar | retirada_agendada | pronta_para_retirada | retirada_no_show | retirada_efetivada | cancelada_leitor | cancelada_biblioteca | expirada |
|---|---|---|---|---|---|---|---|---|---|
| solicitada | staff | staff | ❌ | ❌ | ❌ | ❌ | lecteur | coord | system |
| em_preparacao | — | staff | ❌ | ❌ | ❌ | ❌ | lecteur | coord | system |
| retirada_a_combinar | ❌ | staff/lecteur (négo) | staff/lecteur (confirm) | ❌ | ❌ | ❌ | lecteur | coord | system |
| retirada_agendada | ❌ | ❌ | — | staff | ❌ | ❌ | lecteur | coord | ❌ |
| pronta_para_retirada | ❌ | ❌ | ❌ | — | staff/system | staff (api.confirm_pickup_v1) | lecteur | coord | ❌ |

Stages terminaux : `retirada_efetivada`, `retirada_no_show`, `cancelada_leitor`, `cancelada_biblioteca`, `expirada`, `liberada_para_circulacao`.

`re-retirada_agendada` : aucune transition entrante ni sortante (déprécié).

## RPC concernés et changements

| RPC | Avant v3 | Après v3 |
|---|---|---|
| `api.fn_propose_pickup_slot_as_library` | source ∈ {solicitada, em_preparacao, retirada_a_combinar} → cible retirada_agendada<br>source ∈ {retirada_agendada, re-retirada_agendada} → cible re-retirada_agendada | source ∈ {solicitada, em_preparacao, retirada_a_combinar} → cible **retirada_a_combinar (toujours)** |
| `api.fn_propose_pickup_slot_as_reader` | source ∈ {retirada_agendada, re-retirada_agendada} → cible re-retirada_agendada | source ∈ {**retirada_a_combinar**} → cible **retirada_a_combinar** |
| `api.fn_confirm_pickup_slot_as_library` | source ∈ {retirada_agendada, re-retirada_agendada} ∧ pickup_proposed_by='leitor' → cible pronta_para_retirada | source ∈ {**retirada_a_combinar**} ∧ pickup_proposed_by='leitor' → cible **retirada_agendada** |
| `api.fn_confirm_pickup_slot_as_reader` | source ∈ {retirada_agendada, re-retirada_agendada} ∧ pickup_proposed_by='biblio' → cible pronta_para_retirada | source ∈ {**retirada_a_combinar**} ∧ pickup_proposed_by='biblio' → cible **retirada_agendada** |
| `api.advance_reservation` | cible ∈ {retirada_agendada, re-retirada_agendada} → set pickup_proposed_by='biblio' | cible = **retirada_a_combinar** → set pickup_proposed_by='biblio'<br>cible = retirada_agendada → **interdit depuis solicitada/em_preparacao**, set pickup_proposed_by=NULL si transition légitime |
| `public.fn_expire_negotiation_timeout` (cron) | source ∈ {em_preparacao, retirada_agendada, retirada_a_combinar, re-retirada_agendada} | source ∈ {**em_preparacao, retirada_a_combinar**} |

## Sémantique des notes d'audit

Les notes d'audit générées par les RPC `fn_confirm_*` (paquet 2 bis) restent inchangées :

- `[autoconf-by-library]` : la biblio a confirmé le créneau contre-proposé par le lecteur
- `[autoconf-by-reader]` : le lecteur a confirmé le créneau proposé par la biblio

Ces notes sont apposées au moment de la transition vers `retirada_agendada` (au lieu de `pronta_para_retirada` avant le refactor). Le contenu textuel est ajusté en conséquence.

## Migration de données

D'après l'inventaire en prod au 2026-05-08 (4 résas en DB, dont 3 en `pronta_para_retirada` et 1 en `liberada_para_circulacao`), aucune migration de données n'est nécessaire. Aucune résa n'est en `retirada_agendada` ou `re-retirada_agendada` actif.

Si à l'avenir des résas se retrouvent dans `re-retirada_agendada`, elles seront bloquées dans la matrice (pas de transition sortante) — il faudra les traiter manuellement avec un UPDATE SQL.

## Refactor UI à prévoir (paquet 5b)

**PanelPage** :
- `RES_STAGES` (menu déroulant « Aplicar etapa ») : retirer `re-retirada_agendada`, mettre `retirada_a_combinar` en option principale, retirer `retirada_agendada` (uniquement accessible via la confirmation des boutons inline)
- `canTransition` : aligner sur la nouvelle matrice DB
- `buildDailyTasks` : la tâche `readerCounterProposed` se déclenche désormais sur `retirada_a_combinar` au lieu des deux anciens stages
- Table réservations : `showStaffActions` et `isWaitingReader` se basent sur `retirada_a_combinar`
- Tâche `toScheduleWithReader` (paquet 4A) : conservée, déclenchée par `retirada_a_combinar` qui devient le stage actif principal

**AccountPage / ReservationCard** :
- `inNegotiationStage` se base sur `retirada_a_combinar` uniquement
- Logique des 4 états refondue selon la nouvelle matrice
- Affichage des transitions vers `retirada_agendada` après confirmation : « créneau confirmé, prêt à retirer bientôt »

**NegotiationStateBadge** :
- `NEGOTIATION_STAGES = ['retirada_a_combinar']` (au lieu des deux anciens)

## i18n à recalibrer

Aucune clé à supprimer. Quelques clés à reformuler pour refléter le nouveau sens :

- `reservation.stage.retirada_a_combinar` : le label peut être enrichi pour souligner « négociation active »
- `reservation.stage.retirada_agendada` : peut être enrichi pour souligner « créneau verrouillé »
- `reservation.nextStep.bibliotaProposed` : valable maintenant sur `retirada_a_combinar`
- `reservation.nextStep.leitorProposed` : idem

Détail des reformulations à faire au paquet 5b.

## Risques identifiés

1. **Matrice et code répliqué** : la fonction JS `canTransition` dans PanelPage est une réplication de `fn_check_workflow_transition`. Risque de divergence si on touche l'un sans l'autre. À synchroniser au paquet 5b.

2. **Réservations en cours d'expiration** : le changement du périmètre du cron peut affecter les résas qui étaient sur le point d'expirer. Vérifier au déploiement qu'aucune résa active n'est en `retirada_agendada` avec `created_at` > 21j.

3. **Tests d'intégration** : les tests existants des paquets 1-4 reposent sur l'ancienne matrice. Pas de tests automatisés actuellement (Vitest ne couvre pas les RPC), donc pas de régression mécanique attendue, mais à valider en SQL après application.

## Questions ouvertes pour le paquet 5b

- L'UX du staff doit-elle distinguer visuellement `retirada_a_combinar` (négo en cours) de `retirada_agendada` (verrouillé) ? Probablement oui, avec un badge vert pour ce dernier.
- Le bouton « Confirmar » côté staff/lecteur change de cible (`pronta_para_retirada` → `retirada_agendada`). Le label du bouton doit-il être ajusté (« Verrouiller le créneau » au lieu de « Confirmer ») ?
- Les notifications mail (paquet 5 d'origine, à venir) doivent intégrer les transitions vers `retirada_agendada`. À aligner.
