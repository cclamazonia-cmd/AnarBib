# Audit #153 — Contenus des mails AnarBib

> Document de constats. Cet audit **constate et liste**, il ne corrige rien.
> Les corrections feront l'objet de chantiers séparés, à prioriser après audit.

**Date d'ouverture :** 23 mai 2026
**Périmètre :** les 8 Edge Functions qui envoient effectivement des courriels.
**Méthode :** audit en 4 passes — A (inventaire), B (destinataires & doublons),
C (wording & cohérence), D (présentation & délivrabilité).

**État au 23/05/2026 :** passe A réalisée. Passe B amorcée — sous-passe B.1
réalisée (instruction des constats TR-1 et TR-2 ; voir §5). Passes B.2, B.3, C
et D à venir en sessions dédiées.

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

## 3. Constats transverses relevés dès la passe A

Ces constats ne sont pas rattachés à une seule EF — ils traversent le périmètre.

| ID | Constat | Sévérité estimée | Passe de traitement |
|---|---|---|---|
| TR-1 | Coexistence des handlers `legacy.ts` et v2. **Instruit en B.1 :** double envoi via dispatch impossible (`if/return`). Mais anomalie de routage révélée — `emprestimo_prorrogado` capté par la branche legacy, la branche v2 (lignes 58/62 de `dispatch.ts`) est morte. Mail legacy non i18n au lieu du mail v2 multilingue. | À qualifier | B.1 — instruit, voir §5 |
| TR-2 | Conversion réservation → emprunt : **doublon confirmé en B.1.** Le passage du stage à `retirada_efetivada` émet `reserva_convertida_em_emprestimo` (mail `res.converted`), et l'INSERT de l'emprunt dans `emprestimos_v2` émet `emprestimo_v2_criado` (mail `loan.created`). Le lecteur·rice reçoit deux mails. Redondance de notification (mails distincts), non duplication stricte. Sous-constat n°2. | À qualifier | B.1 — instruit, voir §5 |
| TR-3 | Annulation de réservation : clé i18n unique partagée entre mail reader et mail staff (`res.cancelStaff`). Le mail reader est rédigé côté staff. Sous-constat n°1. | À qualifier | C |
| TR-4 | Rendus internes de `register` non harmonisés sur le style du mail lecteur·rice. Sous-constat n°3. | À qualifier | C |
| TR-5 | Incohérence des préfixes de sujet : `[AnarBib]` en dur dans `notify-library-request`, `subjectTag` contextuel ailleurs, `[<BRAND>]` dans `notify-document-permission-request`. | À qualifier | D |
| TR-6 | Logo `logo_url` null : l'affichage du logo dépend de la source que chaque EF interroge. Sous-constat n°4. | À qualifier | D |
| TR-7 | Délivrabilité : le sous-domaine `notifications.anarbib.org` a une réputation jeune ; risque de classement en spam (Gmail observé). Sous-constat n°5. | À qualifier | D |
| TR-8 | **Relevé en B.1.** Cascade d'annulation : `trg_auto_liberate_after_no_show_change` exécute un `UPDATE` qui repasse le stage à `liberada_para_circulacao` juste après `cancelada_biblioteca` / `no_show`. Le trigger de notification réagissant aux changements de stage, une annulation par la biblio pourrait générer deux notifications successives (`reserva_cancelada_biblioteca` puis `liberada_para_circulacao`). À instruire : le mail `liberada_para_circulacao` part-il au lecteur·rice, et est-ce souhaitable après une annulation ? | À qualifier | B (à instruire) |

> Les sévérités sont laissées **à qualifier** : la passe A inventorie, elle ne
> hiérarchise pas. La qualification se fera passe par passe, une fois chaque
> constat instruit.

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
- **Passe B — destinataires & doublons** : sous-passe B.1 réalisée (TR-1, TR-2
  instruits ; TR-8 relevé — voir §5). Reste B.2 (`team.ts`, `library_profile.ts`,
  instruction de TR-8) et B.3 (`network.ts`).
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
| TR-8 | Nouveau. Cascade d'annulation re-déclenchant le trigger de notification. Non tranché, à instruire. |

**Reste de la passe B :**
- **B.2** — décomposition fine des handlers à fan-out `team.ts` et
  `library_profile.ts` ; instruction de TR-8.
- **B.3** — décomposition fine de `network.ts` (1305 lignes, le plus gros
  handler du périmètre).

---

*Audit #153 — passes A et B.1. Document de travail interne, à compléter par les
sous-passes B.2, B.3 et les passes C et D. Distribué sous licence CC-BY-SA-4.0.*
