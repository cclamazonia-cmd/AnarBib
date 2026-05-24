# Audit #153 — Contenus des mails AnarBib

> Document de constats. Cet audit **constate et liste**, il ne corrige rien.
> Les corrections feront l'objet de chantiers séparés, à prioriser après audit.

**Date d'ouverture :** 23 mai 2026
**Périmètre :** les 8 Edge Functions qui envoient effectivement des courriels.
**Méthode :** audit en 4 passes — A (inventaire), B (destinataires & doublons),
C (wording & cohérence), D (présentation & délivrabilité).

**État au 24/05/2026 :** passe A réalisée. Passe B en cours — sous-passes B.1
(TR-1, TR-2 ; voir §5) et B.2 (`team.ts`, `library_profile.ts`, TR-8 ; voir §6)
réalisées. Reste B.3 (`network.ts`). Passes C et D à venir.

---

## Avertissement de périmètre

Cet audit porte sur les **8 EF qui envoient réellement** des courriels.
L'EF `notify-interlibrary-loan` existe à l'état de *stub* (ne déclenche aucun
envoi à ce jour) : elle est **hors périmètre** et devra être auditée lorsque le
module de prêt inter-bibliothèques sera implémenté.

L'audit porte sur le **contenu** des mails (déclencheur, destinataire, type,
wording, présentation). Il ne traite **pas** la couche de transport, qui a fait
l'objet du chantier #110 (migration Brevo → Resend) et de son volet documentaire.

---

## 1. Cartographie générale

AnarBib envoie des courriels via deux types d'Edge Functions :

- **EF autonomes** — chacune gère son propre périmètre fonctionnel et envoie
  directement : `register`, `notify-weekly-report`,
  `notify-network-weekly-report`, `notify-mid-loan-reading`,
  `notify-library-request`, `notify-document-permission-request`,
  `notify-internal-task`.
- **EF orchestratrice** — `notify-event` est un point d'entrée unique (webhook)
  qui ne contient pas de logique propre : son `index.ts` (72 lignes) délègue
  tout à `_shared/core/dispatch.ts`, lequel route 9 familles d'événements vers
  10 handlers de domaine dans `_shared/domain/`.

Conséquence pour l'audit : `notify-event` n'est pas « un » mail mais une
**famille de mails**. L'inventaire la décompose handler par handler.

### Tableau de synthèse — les 8 EF

| EF | Rôle | Nature | Inventaire détaillé |
|---|---|---|---|
| `register` | Inscription d'un compte lecteur·rice | Autonome | §2.1 |
| `notify-event` | Orchestrateur d'événements de circulation et de gouvernance | Wrapper → dispatch → 10 handlers | §2.2 |
| `notify-weekly-report` | Rapport hebdomadaire d'une bibliothèque | Autonome | §2.3 |
| `notify-network-weekly-report` | Rapport hebdomadaire du réseau | Autonome | §2.4 |
| `notify-mid-loan-reading` | Message « comment va la lecture ? » à mi-emprunt | Autonome | §2.5 |
| `notify-library-request` | Workflow d'adhésion d'une bibliothèque au réseau | Autonome | §2.6 |
| `notify-document-permission-request` | Demande de troche documentaire inter-bibliothèques | Autonome | §2.7 |
| `notify-internal-task` | Notification de tâche interne au staff | Wrapper → handler `_shared/handlers/internal-task.ts` | §2.8 |

**Légende des destinataires** utilisée dans tout le document :
- **reader** — la lectrice ou le lecteur concerné·e (locale = `preferred_language`).
- **staff** — copie à la bibliothèque (locale = `default_locale` de la biblio,
  dite *libLocale*). Adresse résolue via `adminTarget(ctx)`.
- **admin réseau** — administrateur·rice du réseau.
- **institution** — contact d'une bibliothèque candidate à l'adhésion (non encore
  membre).

---

## 2. Inventaire détaillé par EF

### 2.1 — `register` (856 lignes)

Inscription d'un nouveau compte. Envoie selon deux scénarios :

| # | Déclencheur | Destinataire(s) | Type de mail | Sujet (observé) |
|---|---|---|---|---|
| R-1 | Inscription avec bibliothèque d'attache | reader + staff | confirmation lecteur·rice + rendu interne | `Novo cadastro — <nom> — <publicId>` (rendu interne) |
| R-2 | Inscription sans bibliothèque (`signupWithoutLibrary`) | reader | confirmation lecteur·rice | clé i18n `subject.initial` |

> **À verser passe C** — sous-constat n°3 : les rendus internes de `register`
> (le mail `Novo cadastro …` au staff) ne sont pas harmonisés sur le style du
> mail lecteur·rice. Sujet en dur, non passé par les clés i18n, format distinct.

### 2.2 — `notify-event` → 10 handlers de domaine

Point d'entrée webhook unique. `dispatch.ts` route l'événement reçu vers le
handler de domaine correspondant. Les 10 handlers :

#### 2.2.a — `domain/legacy.ts` (171 l) — circulation « ancienne génération »

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| L-1 | `reserva_criada` | reader | avis de réservation créée (legacy) |
| L-2 | `emprestimo_criado`, `emprestimo_prorrogado`, `emprestimo_devolvido`, `lembrete_devolucao_*`, `aviso_atraso_*` | reader | avis d'emprunt / rappel / retard (legacy) |

> **À verser passe B** — `legacy.ts` coexiste avec les handlers v2
> (`emprestimos.ts`, `reservas.ts`). Vérifier qu'aucun événement ne déclenche
> *à la fois* un handler legacy et un handler v2 (risque de double envoi).

#### 2.2.b — `domain/emprestimos.ts` (432 l) — emprunts v2

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| E-1 | `emprestimo_v2_criado` | reader | emprunt créé |
| E-2 | `emprestimo_v2_prorrogado` / `emprestimo_prorrogado` | reader | emprunt prorogé |
| E-3 | `emprestimo_v2_devolvido`, `emprestimo_v2_parcialmente_devolvido`, `emprestimo_v2_devolvido_apos_parcial` | reader | retour (total / partiel) |
| E-4 | `lembrete_v2_devolucao_5d / _3d / _hoje` | reader | rappels d'échéance |
| E-5 | `aviso_v2_atraso_1d / _7d / _30d` | reader | avis de retard |
| E-6 | `emprestimo_devolucao_agendada`, `emprestimo_devolucao_cancelada`, `emprestimo_devolucao_nao_realizada` | reader | workflow de retour planifié |

#### 2.2.c — `domain/reservas.ts` (564 l) — réservations v2

Trois handlers distincts :

| # | Déclencheur(s) | Destinataire(s) | Type | Note |
|---|---|---|---|---|
| RV-1 | `reserva_v2_criada` | reader + staff | réservation créée | `handleReservaCriadaV2` |
| RV-2 | `reserva_v2_recusada`, `reserva_cancelada_biblioteca`, `reserva_cancelada_leitor`, `reserva_expirada`, `reserva_convertida_em_emprestimo` | reader + staff | changement de statut | `handleReservaV2StatusChange` |
| RV-3 | workflow de retrait (`em_preparacao`, `retirada_a_combinar`, `retirada_agendada`, `pronta_para_retirada`, `retirada_no_show`, `liberada_para_circulacao`, etc.) | reader (+ staff selon étape) | étapes du workflow | `handleReservaV2WorkflowEvent` ; certaines étapes désactivent le mail staff (`staffMailEnabled=false`) |
| RV-4 | `retirada_confirmada_leitor`, `retirada_recusada_leitor` | reader + staff | réponse du lecteur sur créneau | `handleReservaPickupReplyEvent` |

> **À verser passe C** — sous-constat n°1 (annulation de réservation) :
> dans `handleReservaV2StatusChange`, la **même clé i18n** est utilisée pour les
> *deux* mails — celui du lecteur·rice ET celui du staff (commentaire du code,
> reservas.ts ~l.120 : « utilisée par les 2 mails lecteur ET biblio »). Pour
> `reserva_cancelada_biblioteca`, la clé est `res.cancelStaff`. Le constat
> n'est donc **pas** un mauvais routage (les deux mails partent bien aux deux
> bons destinataires), mais un constat de **wording** : le mail reçu par le
> lecteur·rice est rédigé à partir d'une clé pensée côté staff. À examiner :
> faut-il une clé lecteur·rice distincte ?

> **À verser passe B** — sous-constat n°2 (conversion réservation → emprunt) :
> `reserva_convertida_em_emprestimo` (clé `res.converted`) déclenche dans
> `handleReservaV2StatusChange` un **double envoi** reader + staff. Or la
> conversion crée aussi un emprunt, qui peut déclencher `emprestimo_v2_criado`
> (handler E-1, mail au reader). À vérifier en passe B : le lecteur·rice
> reçoit-il alors **deux** mails rapprochés (« réservation convertie » +
> « emprunt créé ») ? Si oui, lequel supprimer ou fusionner ?

#### 2.2.d — `domain/consultas.ts` (630 l) — consultations sur place v2

Trois handlers distincts :

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| C-1 | `consulta_v2_criada` | reader + staff | consultation créée |
| C-2 | `consulta_v2_realizada`, `consulta_v2_cancelada`, `consulta_v2_expirada` | reader + staff | cycle de vie de la consultation |
| C-3 | `consulta_v2_em_preparacao`, `consulta_v2_agendada`, `consulta_v2_nao_compareceu`, `consulta_v2_resposta_creneau` | reader + staff | workflow de la consultation |

#### 2.2.e — `domain/team.ts` (815 l) — gouvernance de la bibliothèque locale

Événements `team.*`. Le handler lit la table `team_notification_outbox` par
`recordId` et opère un fan-out vers plusieurs destinataires (`recipients`).

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| T-1 | événements `team.*` (cooptation, retrait, suspension, etc.) | reader concerné·e + staff (coordination) | notifications de gouvernance d'équipe |

> Le détail des sous-événements `team.*` (par transition T1–T9 du guide de
> gouvernance) sera décomposé en passe B — c'est un handler à fan-out
> multi-destinataires, qui mérite un inventaire fin.

#### 2.2.f — `domain/network.ts` (1305 l) — gouvernance du réseau

Événements `network.*`. Même mécanisme d'outbox que `team.*`. C'est le plus
gros handler du périmètre.

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| N-1 | événements `network.*` (cooptation/retrait d'admin réseau, etc.) | admin réseau concerné·e + autres admins réseau | notifications de gouvernance réseau |

> Décomposition fine des sous-événements `network.*` à faire en passe B.

#### 2.2.g — `domain/profiles.ts` (101 l) — avis de profil

| # | Déclencheur | Destinataire(s) | Type |
|---|---|---|---|
| P-1 | `profile_notice` | staff (locale biblio) | avis interne de modification de profil (`admin.profileNotice`) |

#### 2.2.h — `domain/library_profile.ts` (798 l) — profil de bibliothèque

Handler de notifications liées au profil d'une bibliothèque (transitions
d'équipe/réseau, changements de mode de circulation). Destinataire dominant :
**staff**. Inventaire fin des sous-événements à faire en passe B.

| # | Déclencheur(s) | Destinataire(s) | Type |
|---|---|---|---|
| LP-1 | sous-événements de profil de biblio (équipe / réseau / mode de circulation) | staff (+ reader pour le sous-événement « mode de circulation ») | notifications de profil de biblio |

### 2.3 — `notify-weekly-report` (554 lignes)

| # | Déclencheur | Destinataire(s) | Type | Sujet (observé) |
|---|---|---|---|---|
| WR-1 | exécution périodique (cron hebdomadaire) | staff | rapport hebdomadaire de la biblio | `<subjectTag> · Relatório semanal (<date>)` |

### 2.4 — `notify-network-weekly-report` (480 lignes)

| # | Déclencheur | Destinataire(s) | Type | Sujet (observé) |
|---|---|---|---|---|
| NWR-1 | exécution périodique (cron hebdomadaire) | admin réseau | rapport hebdomadaire du réseau | `<brandName> · Relatório semanal da rede (<date>)` |

### 2.5 — `notify-mid-loan-reading` (610 lignes)

| # | Déclencheur | Destinataire(s) | Type | Sujet (observé) |
|---|---|---|---|---|
| ML-1 | emprunt arrivé à mi-parcours (cron) | reader | message « comment va la lecture ? » + suggestions | `<libraryName> \| Como vai a leitura?` |

### 2.6 — `notify-library-request` (663 lignes)

Workflow d'adhésion d'une bibliothèque au réseau. Sept sujets identifiés.

| # | Déclencheur | Destinataire(s) | Type | Sujet (observé) |
|---|---|---|---|---|
| LR-1 | demande reçue | institution | accusé de réception | `[AnarBib] Solicitação recebida` |
| LR-2 | demande en analyse | institution | mise à jour de statut | `[AnarBib] Solicitação em análise` |
| LR-3 | informations complémentaires requises | institution | demande de complément | `[AnarBib] Precisamos de informações complementares` |
| LR-4 | demande approuvée | institution | décision | `[AnarBib] Solicitação aprovada` |
| LR-5 | demande refusée | institution | décision | `[AnarBib] Solicitação recusada` |
| LR-6 | nouvelle demande institutionnelle | admin réseau | alerte interne | `[AnarBib] Nova solicitação institucional` |
| LR-7 | mise à jour de demande institutionnelle | admin réseau | alerte interne | `[AnarBib] Atualização de solicitação institucional` |

> **À verser passe D** — les sujets de `notify-library-request` sont préfixés
> `[AnarBib]` en dur, contrairement à d'autres EF qui utilisent un `subjectTag`
> issu du contexte. Constat de cohérence de présentation des sujets.

### 2.7 — `notify-document-permission-request` (550 lignes)

Demande de troche documentaire inter-bibliothèques. Trois sujets identifiés.

| # | Déclencheur | Destinataire(s) | Type | Sujet (observé) |
|---|---|---|---|---|
| DP-1 | consultation de troche émise | staff (biblio destinataire) | demande | `[<BRAND>] Consulta de troca documental interbibliotecas` |
| DP-2 | consultation enregistrée | staff (biblio émettrice) | accusé | `[<BRAND>] Consulta de troca registrada — <…>` |
| DP-3 | réponse à la consultation | staff (biblio émettrice) | réponse | `[<BRAND>] Resposta à consulta de troca — <…>` |

### 2.8 — `notify-internal-task` (wrapper 7 lignes → `_shared/handlers/internal-task.ts`)

| # | Déclencheur | Destinataire(s) | Type |
|---|---|---|---|
| IT-1 | création / mise à jour d'une tâche interne | staff | notification de tâche interne |

> `index.ts` n'est qu'un ré-export ; le contenu réel est dans
> `_shared/handlers/internal-task.ts`. Inventaire fin du wording à faire en
> passe C.

---

## 3. Registre des constats

Ce registre rassemble tous les constats de l'audit. Les constats **TR-***
traversent le périmètre (relevés en passe A ou en cours d'instruction). Les
constats **TM-*** sont propres au handler `team.ts`, les **LP-*** au handler
`library_profile.ts` (tous deux instruits en passe B.2, voir §6).

### 3.1 — Constats transverses (TR-*)

| ID | Constat | Sévérité estimée | Passe de traitement |
|---|---|---|---|
| TR-1 | Coexistence des handlers `legacy.ts` et v2. **Instruit en B.1 :** double envoi via dispatch impossible (`if/return`). Mais anomalie de routage révélée — `emprestimo_prorrogado` capté par la branche legacy, la branche v2 (lignes 58/62 de `dispatch.ts`) est morte. Mail legacy non i18n au lieu du mail v2 multilingue. | À qualifier | B.1 — instruit, voir §5 |
| TR-2 | Conversion réservation → emprunt : **doublon confirmé en B.1.** Le passage du stage à `retirada_efetivada` émet `reserva_convertida_em_emprestimo` (mail `res.converted`), et l'INSERT de l'emprunt dans `emprestimos_v2` émet `emprestimo_v2_criado` (mail `loan.created`). Le lecteur·rice reçoit deux mails. Redondance de notification (mails distincts), non duplication stricte. Sous-constat n°2. | À qualifier | B.1 — instruit, voir §5 |
| TR-3 | Annulation de réservation : clé i18n unique partagée entre mail reader et mail staff (`res.cancelStaff`). Le mail reader est rédigé côté staff. Sous-constat n°1. | À qualifier | C |
| TR-4 | Rendus internes de `register` non harmonisés sur le style du mail lecteur·rice. Sous-constat n°3. | À qualifier | C |
| TR-5 | Incohérence des préfixes de sujet : `[AnarBib]` en dur dans `notify-library-request`, `subjectTag` contextuel ailleurs, `[<BRAND>]` dans `notify-document-permission-request`. | À qualifier | D |
| TR-6 | Logo `logo_url` null : l'affichage du logo dépend de la source que chaque EF interroge. Sous-constat n°4. | À qualifier | D |
| TR-7 | Délivrabilité : le sous-domaine `notifications.anarbib.org` a une réputation jeune ; risque de classement en spam (Gmail observé). Sous-constat n°5. | À qualifier | D |
| TR-8 | Cascade d'annulation. **Tranché en B.2 :** une annulation biblio (item → `cancelada_biblioteca`) déclenche le trigger `trg_auto_liberate_after_no_show_change`, qui fait un second `UPDATE` (stage → `liberada_para_circulacao`). Les deux changements de stage émettent chacun un événement : `reserva_cancelada_biblioteca` puis `liberada_para_circulacao`. Or le handler de `liberada_para_circulacao` (`reservas.ts` l.277-279) définit `readerKey='wf.closed'` → **mail lecteur·rice**. Résultat : deux mails au lecteur·rice pour une seule annulation, le second redondant et porteur de jargon interne (« libérée pour circulation »). | À qualifier | B.2 — tranché, voir §6.3 |

> Les sévérités sont laissées **à qualifier** : l'audit inventorie et instruit,
> il ne hiérarchise pas. La qualification se fera lorsque l'ensemble des constats
> sera instruit (fin de passe B, puis C et D).

### 3.2 — Constats sur `team.ts` (TM-*)

| ID | Constat | Sévérité estimée | Passe |
|---|---|---|---|
| TM-A | Écart code / spec sur la notification d'inactivité. La spec gouvernance (§9, lignes 654-656) prévoit que `inactive_warning_30d` **et** `inactive_warning_7d` notifient **la personne uniquement** ; seul `inactive_auto` (J-9 mois) ajoute la coordination. Le code de `team.ts` est conforme pour le 30j mais **non conforme pour le 7j** : `handleInactiveWarning` envoie une copie staff (`if (isShort)`, l.735) non prévue par la spec. Correction par défaut : aligner le code sur la spec (retrait de la copie staff au 7j). Une révision de spec resterait possible par le circuit d'amendement, si le réseau juge au contraire que la coordination doit être prévenue dès le 7j. | À qualifier | B.2 |
| TM-B | Mails de copie staff (`admin_copy`) entièrement **hors du système i18n** : titres et intros codés en dur en **pt-BR** (`"Admissão concertada"`, `"Pedido de retirada"`, etc.), libellés de détails codés en dur en **français** (`"Cible"`, `"Acteur·rice"`, `"Bibliothèque"`, `"Motif"`). Le mail lecteur·rice, lui, passe par `tMail(locale, …)`. Pour une biblio dont la `default_locale` n'est ni pt-BR ni fr, le mail de copie part dans la mauvaise langue. Même famille que TR-4 (sous-constat n°3). | À qualifier | B.2 / C |
| TM-C | Mot-valise FR/PT dans un libellé en dur : `team.ts` l.738, `"Aviso de inatividade — 7 dias antes do passage em inativo"` — « passage » est français au milieu d'un texte portugais. Coquille. | Faible | B.2 / C |
| TM-D | Divergence de nommage spec / code : la spec gouvernance nomme l'événement de sortie automatique `inactive_auto` (§9 l.656, §12) ; le code de `team.ts` traite `team.inactive_completed` (TM-13). Même rôle fonctionnel, nom différent. À confirmer : simple décalage de nommage sans incidence, ou risque qu'un événement émis sous un nom ne soit pas capté. | Faible — à confirmer | B.2 |

### 3.3 — Constats sur `library_profile.ts` (LP-*)

| ID | Constat | Sévérité estimée | Passe |
|---|---|---|---|
| LP-A | Doublon **volontaire et assumé** (doctrine B.7). Sur `executed` avec `axis = circulation_mode`, le handler envoie un mail aux lecteur·rices **en plus** du mail staff/admin, sans déduplication : une personne à la fois lectrice et staff reçoit deux mails (contenus distincts — l'un côté gestion, l'autre côté usage). Doctrine confirmée justifiée par l'auteur du projet le 24/05/2026. Signalé pour mémoire, **non considéré comme défaut**. | Néant (doctrine assumée) | B.2 |
| LP-B | Non-constat positif. Les six appels à `actionBox` de `library_profile.ts` respectent le contrat strict de `layout.ts` (`{kind, title, ctaUrl, ctaLabel}`). Le fichier est une **référence correcte** d'usage d'`actionBox` — utile pour la passe D. | Néant | D (référence) |
| LP-C | Lorsqu'un fan-out est vide (ex. : proposition dans une biblio à staff unique → seul destinataire exclu car proposeur), le handler journalise un `console.warn` « no recipients » et marque néanmoins l'outbox `status='sent'`. Comportement fonctionnellement correct (rien à envoyer), mais l'état `sent` sans envoi réel peut tromper une lecture ultérieure de la table outbox. | Faible | B.2 |

---

## 4. Bilan de la passe A

**Couverture.** 8 EF inventoriées. `notify-event` décomposée en 10 handlers de
domaine. Au total, l'inventaire recense **8 EF / 10 handlers de domaine** et de
l'ordre de **30+ déclencheurs distincts** de courriels (chaque ligne `*-n` des
tableaux du §2).

**Familles de destinataires.** Quatre : reader, staff, admin réseau, institution.
La majorité des mails de circulation (`emprestimos`, `reservas`, `consultas`)
suivent un schéma **reader + copie staff**. Les mails de gouvernance (`team`,
`network`) opèrent un fan-out multi-destinataires via une table outbox. Les
rapports et les mails institutionnels ont un destinataire unique.

**Cinq sous-constats connus** versés et localisés dans le code : n°1 → TR-3 ;
n°2 → TR-2 ; n°3 → TR-4 ; n°4 → TR-6 ; n°5 → TR-7. Deux constats supplémentaires
relevés en cours d'inventaire : TR-1 (coexistence legacy/v2) et TR-5
(incohérence des préfixes de sujet).

**Suite.** Trois passes restent à mener, en sessions dédiées :
- **Passe B — destinataires & doublons** : sous-passes B.1 (TR-1, TR-2 instruits ;
  TR-8 relevé — voir §5) et B.2 (`team.ts`, `library_profile.ts`, TR-8 tranché —
  voir §6) réalisées. Reste B.3 (`network.ts`).
- **Passe C — wording & cohérence** : instruire TR-3, TR-4 ; revue des clés i18n
  sur les 6 locales ; cohérence de registre d'un mail à l'autre.
- **Passe D — présentation & délivrabilité** : instruire TR-5, TR-6, TR-7 ;
  layout, logos, sujets, réputation du sous-domaine.

---

## 5. Passe B.1 — instruction des constats TR-1 et TR-2

**Date :** 23 mai 2026.
**Méthode :** lecture du code des handlers (`_shared/`), du routage (`dispatch.ts`),
et du code SQL réellement déployé (triggers et fonctions, via `pg_get_triggerdef`
et `pg_get_functiondef` sur la base de production).

### 5.1 — TR-1 : coexistence legacy / v2

**Question instruite :** un même événement entrant peut-il être traité à la fois
par un handler `legacy.ts` et par un handler v2, produisant un double envoi ?

**Verdict : double envoi impossible.** `dispatch.ts` est une chaîne de
`if … return await handle…()`. La fonction sort à la première branche qui
correspond ; un événement n'atteint jamais deux handlers.

**Mais anomalie de routage révélée.** L'événement `emprestimo_prorrogado` est
listé dans **deux** branches de `dispatch.ts` : la branche legacy (qui vient en
premier et fait `return`) et la branche v2 (lignes 58 et 62). La branche v2
n'est donc **jamais atteinte** pour cet événement — alors que la ligne 62
contient une normalisation explicite `emprestimo_prorrogado → emprestimo_v2_prorrogado`,
signe que le traitement v2 était prévu. Conséquence : si le SIGB émet
`emprestimo_prorrogado`, le lecteur·rice reçoit le mail **legacy**
(`handleEmprestimoOld` : texte en dur, pt-BR uniquement) au lieu du mail **v2**
(`handleEmprestimoV2` : passé par les clés i18n, multilingue).

**Reclassement :** TR-1 n'est plus « risque de doublon » mais « anomalie de
routage : `emprestimo_prorrogado` capté par legacy au lieu de v2 ». À vérifier
en complément : le SIGB émet-il encore cet événement, ou est-il lui-même mort ?

### 5.2 — TR-2 : double envoi à la conversion réservation → emprunt

**Question instruite :** quand une réservation est convertie en emprunt, le
lecteur·rice reçoit-il deux mails ?

**Verdict : doublon confirmé.** Mécanisme établi par lecture du code SQL
déployé :

1. **Côté réservation.** Le trigger `trg_notify_reserva_workflow` (sur
   `reserva_item_workflow_v2`) appelle `trg_notify_reserva_workflow_change()`.
   Dans son mapping de stage : `workflow_stage = 'retirada_efetivada'` émet
   l'événement `reserva_convertida_em_emprestimo`. Côté EF, le dispatch route
   vers `handleReservaV2StatusChange` → clé `res.converted` → **un mail
   lecteur·rice** + copie staff.
2. **Côté emprunt.** La conversion crée une ligne dans `emprestimos_v2`. Cette
   table porte le trigger `trg_notify_emprestimo_criado` (`AFTER INSERT`), dont
   la fonction `trg_notify_emprestimo_criado()` émet `emprestimo_v2_criado`.
   Côté EF, dispatch → `handleEmprestimoV2` → **un second mail lecteur·rice**
   (`loan.created`).

**Le lecteur·rice reçoit donc deux courriels** pour un seul événement vécu
(« j'ai retiré mon livre »). Nature exacte : **redondance de notification** —
les deux mails sont distincts (« réservation convertie » et « emprunt créé »),
ce n'est pas une duplication à l'identique. Le sous-constat n°2 est confirmé.

**Piste de correction** (hors périmètre de l'audit, pour mémoire) : choisir
lequel des deux mails le lecteur·rice doit recevoir lors d'une conversion —
soit supprimer le mail `res.converted` côté lecteur·rice (le mail « emprunt
créé » est plus informatif, il porte la date de retour), soit conditionner le
trigger `trg_notify_emprestimo_criado` pour qu'il n'émette pas la notification
lecteur·rice quand l'emprunt naît d'une conversion. Décision de design, à
trancher en chantier de correction.

### 5.3 — Constat supplémentaire relevé en B.1 : TR-8

L'instruction de TR-2 a fait apparaître un constat voisin, non prévu. Le trigger
`trg_auto_liberate_after_no_show_change` (sur `reserva_item_workflow_v2`)
exécute, lorsqu'un item passe en `cancelada_biblioteca` ou en `no_show`, un
`UPDATE` qui repasse aussitôt le `workflow_stage` à `liberada_para_circulacao`.

Or `trg_notify_reserva_workflow_change()` réagit à tout changement de
`workflow_stage`. La séquence « passage à `cancelada_biblioteca` » puis
« passage automatique à `liberada_para_circulacao` » émet donc potentiellement
**deux événements** (`reserva_cancelada_biblioteca` puis
`liberada_para_circulacao`). C'est le même type de mécanisme que TR-2 : un
`UPDATE` en cascade qui re-déclenche le trigger de notification.

TR-8 est **ajouté au tableau §3** mais **non tranché** : il déborde du périmètre
de B.1 (qui visait la conversion). À instruire dans une sous-passe B ultérieure —
question centrale : le mail `liberada_para_circulacao` part-il au lecteur·rice,
et une seconde notification après une annulation est-elle souhaitable ?

### 5.4 — Bilan de la passe B.1

| Constat | Verdict B.1 |
|---|---|
| TR-1 | Tranché. Double envoi impossible. Reclassé « anomalie de routage » (`emprestimo_prorrogado` → legacy au lieu de v2). |
| TR-2 | Tranché. Doublon confirmé : `reserva_convertida_em_emprestimo` + `emprestimo_v2_criado`. Redondance de notification. |
| TR-8 | Nouveau. Cascade d'annulation re-déclenchant le trigger de notification. Non tranché en B.1 — instruit et tranché ensuite en B.2 (voir §6.3). |

**Reste de la passe B :**
- **B.2** — décomposition fine des handlers à fan-out `team.ts` et
  `library_profile.ts` ; instruction de TR-8.
- **B.3** — décomposition fine de `network.ts` (1305 lignes, le plus gros
  handler du périmètre).

---

## 6. Passe B.2 — décomposition des handlers à fan-out `team.ts` et `library_profile.ts`, instruction de TR-8

**Date :** 24 mai 2026.
**Méthode :** lecture intégrale des deux handlers de domaine ; confrontation à la
spec gouvernance (`spec-gouvernance-roles.md`) ; pour TR-8, lecture du code SQL
des triggers (déjà obtenu en B.1) et du handler de workflow de `reservas.ts`.

### 6.1 — `team.ts` : 13 événements de gouvernance d'équipe

Le handler lit `team_notification_outbox` par `recordId` et route sur le champ
`event`. Décomposition fine :

| # | Événement | Destinataire du mail | Copie staff | Transition |
|---|---|---|---|---|
| TM-1 | `team.promoted_to_librarian` | la personne promue | Oui | T1 |
| TM-2 | `team.promoted_to_coordenador` | la personne promue | Oui | T2 |
| TM-3 | `team.self_demoted` | autres coordenadores actifs (fan-out, acteur·rice exclu·e) | Oui | T3/T4 |
| TM-4 | `team.removal_requested` | la cible | Oui | T5 |
| TM-5 | `team.removal_cancelled` | la cible | Oui | T8 |
| TM-6 | `team.removal_completed` | la cible | Oui | fin T5 (J+7) |
| TM-7 | `team.suspended` | la cible | Oui | T6 |
| TM-8 | `team.unsuspended` | la cible | Oui | T7 |
| TM-9 | `team.last_coordinator_left` | tous les `administrador` (fan-out) | Non | escalade |
| TM-10 | `team.last_coordinator_pending_removal` | tous les `administrador` (fan-out) | Non | escalade |
| TM-11 | `team.inactive_warning_30d` | la cible | Non | T9 (J-30) |
| TM-12 | `team.inactive_warning_7d` | la cible | **Oui** (non conforme spec — TM-A) | T9 (J-7) |
| TM-13 | `team.inactive_completed` | la cible | Oui | T9 |

Un 14ᵉ cas de routage : `event.startsWith("team.library_profile.")` délègue à
`handleLibraryProfileEvent` (voir §6.2).

**Fan-out vérifié sain :** TM-3 (vers les coordenadores) exclut bien l'acteur·rice
de la liste ; TM-9 et TM-10 (vers les administradores) sont des escalades sans
copie biblio, ce qui est cohérent. Aucun oubli ni doublon de destinataire.

**Constats :** TM-A (écart code/spec sur la copie staff au 7j), TM-B (mails
`admin_copy` hors i18n, pt-BR et fr en dur), TM-C (mot-valise « do passage »),
TM-D (nommage `inactive_auto` spec vs `inactive_completed` code). Détail au
registre §3.2.

### 6.2 — `library_profile.ts` : 6 sous-événements de profil de bibliothèque

Module appelé par `team.ts` (`team.library_profile.*`) et `network.ts`
(`network.library_profile.*`). Décape le préfixe, route sur 6 sous-événements.

| # | Sous-événement | Destinataires (fan-out) | Exclusion |
|---|---|---|---|
| LP-1 | `proposed` | staff actif | proposeur exclu |
| LP-2 | `voted` | staff actif | voteur exclu ; proposeur exclu sauf 1er vote (doctrine #21) |
| LP-3 | `accepted` | staff actif + admins réseau (dédoublonnés) | — |
| LP-4 | `rejected` | staff actif | aucune (transparence interne) |
| LP-5 | `cancelled` | staff actif | proposeur exclu |
| LP-6 | `executed` | staff actif + admins réseau (dédoublonnés) | — |
| LP-6bis | `executed` + `axis = circulation_mode` | **+ lecteur·rices actif·ves** de la biblio | — |

**Fichier sain.** Contrairement à `team.ts` : tout passe par i18n (sujets,
intros, libellés, axes, valeurs) — aucun texte en dur ; le fan-out est propre
avec des exclusions pertinentes ; la déduplication staff/admin réseau est
explicite (`mergeProfilesDedup`). Le constat TM-B (texte en dur) ne s'étend
**pas** à ce fichier.

**Constats :** LP-A (doublon B.7 lecteur·rice + staff — assumé, doctrine
confirmée justifiée le 24/05), LP-B (non-constat — usage correct d'`actionBox`),
LP-C (outbox marquée `sent` quand le fan-out est vide). Détail au registre §3.3.

### 6.3 — TR-8 : instruction de la cascade d'annulation

**Question instruite :** une annulation de réservation par la bibliothèque
génère-t-elle deux mails au lecteur·rice ?

**Verdict : doublon confirmé.** Séquence établie par lecture du code SQL et des
handlers EF :

1. L'`UPDATE` initial passe le stage de l'item à `cancelada_biblioteca`. Deux
   triggers `AFTER UPDATE` réagissent sur `reserva_item_workflow_v2` :
   - `trg_auto_liberate_after_no_show_change` calcule `v_reason =
     'cancelled_by_library'` et lance un **second `UPDATE`** (stage →
     `liberada_para_circulacao`).
   - `trg_notify_reserva_workflow_change` émet `reserva_cancelada_biblioteca`
     pour l'`UPDATE` initial.
2. Le second `UPDATE` (stage → `liberada_para_circulacao`) déclenche à nouveau
   les triggers : `auto_liberate` ne fait rien (`v_reason` NULL, garde correcte
   contre la récursion) ; `trg_notify` émet `liberada_para_circulacao`.
3. Côté EF : `reserva_cancelada_biblioteca` → `handleReservaV2StatusChange`
   (mail `res.cancelStaff`, lecteur·rice + staff). `liberada_para_circulacao` →
   `handleReservaV2WorkflowEvent` ; le bloc l.277-279 de `reservas.ts` définit
   `readerKey = 'wf.closed'` et laisse `staffMailEnabled = true` → **mail
   lecteur·rice + mail staff**.

**Le lecteur·rice reçoit donc deux mails** pour une seule annulation. Plus
problématique que TR-2 : le second mail (`wf.closed`, « réservation libérée pour
circulation ») arrive juste après un mail d'annulation, il est redondant pour la
personne et porte un vocabulaire de gestion interne (le document redevient
empruntable) sans intérêt pour elle.

Le mécanisme `auto_liberate` lui-même est de la **logique métier légitime**
(libérer l'exemplaire). Le défaut est que la cascade re-déclenche une
notification *lecteur·rice* sur un changement de stage purement technique.

**Piste de correction** (hors périmètre de l'audit, pour mémoire) : côté EF, le
handler de `liberada_para_circulacao` pourrait poser `readerKey = null` quand le
`final_reason` vaut `cancelled_by_library` ou `no_show` (information disponible,
posée par `auto_liberate`). Cela couperait le mail lecteur·rice redondant tout en
conservant le mail staff `wf.staff.closed`, qui lui reste pertinent. Décision de
chantier de correction.

**Limite assumée :** l'ordre d'exécution des deux triggers (alphabétique :
`auto_liberate` avant `notify`) n'a pas pu être confirmé par le SQL — leur
`CREATE TRIGGER` n'est pas dans le lot de migrations consulté. Cela n'affecte pas
le verdict : les deux événements sont émis et les deux ont un `readerKey` non
nul ; l'ordre ne change que la séquence d'arrivée des mails, pas leur nombre.

### 6.4 — Bilan de la passe B.2

| Objet | Verdict B.2 |
|---|---|
| `team.ts` | 13 événements inventoriés, fan-out sain. Constats TM-A à TM-D (voir §3.2). |
| `library_profile.ts` | 6 sous-événements inventoriés, fichier sain. Constats LP-A à LP-C (voir §3.3). |
| TR-8 | Tranché. Doublon confirmé : annulation biblio → deux mails lecteur·rice (`res.cancelStaff` + `wf.closed`). |

**Reste de la passe B :** B.3 — décomposition fine de `network.ts` (1305 lignes,
le plus gros handler du périmètre).

---

*Audit #153 — passes A, B.1 et B.2. Document de travail interne, à compléter par
la sous-passe B.3 et les passes C et D. Distribué sous licence CC-BY-SA-4.0.*
