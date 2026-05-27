# AnarBib — Dossier-cadre d'ouverture : corrections post-audit #153 (contenus des mails)

> Document d'ouverture de chantier. L'audit #153 (clos le 24/05/2026) **constate
> et instruit** ; il ne corrige rien. Le présent dossier **ouvre, découpe et
> priorise** le programme de correction qui en découle. Il n'engage aucune
> écriture de code par lui-même : chaque chantier ci-dessous reste à exécuter en
> session dédiée.

**Date d'ouverture :** 24 mai 2026
**Dernière mise à jour :** 27 mai 2026 (bilan de clôture en §11)
**Document source :** `AUDIT_153_contenus_mails_2026-05-23.md` (passes A, B, C, D — complet)
**Périmètre :** les 8 Edge Functions qui envoient effectivement des courriels.
**Emplacement cible :** `docs/decisions/`
**Licence :** CC-BY-SA-4.0

---

## 1. Objet et raison d'être

L'audit #153 a relevé **15 constats** (plus 6 non-constats / points positifs) sur
les 8 EF d'envoi de courriels d'AnarBib et les 10 handlers de domaine de
`notify-event`. Sa synthèse de clôture (§10.4) renvoie explicitement la
correction à « des chantiers de correction distincts, à ouvrir et prioriser
séparément ».

Ce dossier-cadre exécute ce renvoi. Il regroupe les 15 constats en **5 chantiers
cohérents**, fixe une **séquence de priorité**, acte les **décisions de
cadrage** (dont les deux que l'audit laissait « à qualifier »), et fournit pour
chaque chantier une fiche d'ouverture exploitable directement en session.

La méthode est celle déjà éprouvée sur le chantier-cadre Biblioteca
(21/05/2026) : un document-cadre qui arbitre et séquence, des chantiers
d'exécution distincts derrière.

### 1.1 — Principe de priorisation retenu

Les chantiers sont ordonnés selon un critère unique et politiquement assumé :
**corriger d'abord ce qui dégrade l'expérience d'un·e lecteur·rice réel·le
aujourd'hui, finir par le confort interne du staff.** Une personne qui reçoit
deux courriels pour une seule action vécue subit un défaut visible et immédiat ;
une biblio qui reçoit une notification interne en portugais subit un défaut réel
mais interne. Les deux comptent, mais pas dans le même ordre.

### 1.2 — Écart de regroupement assumé par rapport à l'audit

Deux choix de découpage diffèrent du regroupement implicite de l'audit, et sont
explicités ici pour mémoire :

- **TR-1 est rattaché au chantier A** (et non au lot transverse). L'audit le
  classe « faible » et le range avec les constats transverses, mais son symptôme
  réel — *le lecteur·rice reçoit le mauvais mail* (legacy non-i18n au lieu du
  mail v2 multilingue) — est exactement celui de TR-2 et TR-8. Trois constats, un
  même symptôme côté lecteur·rice : un seul chantier.
- **TR-6.2b est isolé en chantier E.** L'audit traite TR-6 comme un constat
  unique de sévérité moyenne, mais distingue lui-même TR-6.2a (non-constat,
  validé) de TR-6.2b (« défaut, ni anecdotique ni négociable » — doctrine
  24/05). Le hard-coding des logos de bibliothèques est un frein direct à
  l'extensibilité fédérative ; il mérite un chantier propre plutôt que d'être
  dilué dans un lot de nettoyage.

---

## 2. Les décisions de cadrage (actées le 24/05/2026)

L'audit laisse **TR-2 et TR-8 explicitement « à qualifier »** (§10.3) : ce ne
sont pas des bugs techniques mais des choix de doctrine de notification. Aucune
correction du chantier A ne peut commencer avant qu'ils soient tranchés. Ils le
sont ici (D-1, D-2). S'y ajoute une décision de méthode (D-0) qui fixe la
règle de traitement des objets partagés entre chantiers.

### 2.0 — Décision D-0 : règle de traitement unique des points de coordination

**Décision (actée le 24/05/2026).** Les trois recoupements identifiés entre
chantiers (§5) sont traités selon une **règle ferme : chaque objet partagé est
traité une seule fois, intégralement, par le chantier qui le rencontre en
premier dans la séquence.** Le ou les chantiers suivants ne font que constater
la conformité, sans retoucher l'objet.

Concrètement :
- `res.converted` est traité **intégralement dans le chantier D** : ce chantier
  refond la clé (version « message », TR-3) *et* y ajoute la date d'échéance.
  Note : une formulation antérieure rattachait ce traitement au chantier A ;
  l'instruction du 25/05 l'a corrigée (voir §2.1ter). Le chantier A ne touche pas
  cette clé — son volet TR-2 se limite à la résorption du doublon.
- Le repli « logo absent » est **défini dans le chantier C** (règle : repli
  texte) et **propagé tel quel dans le chantier E** sur les 8 EF, sans
  redéfinition.
- TM-A et TM-D sont **tranchés définitivement dans le chantier B** ; ils ne
  retombent pas dans le lot E.

Cette règle supprime tout risque de double travail ou de conflit entre
chantiers. Les recommandations de §5 deviennent, par cette décision, des
contraintes d'exécution.

### 2.1 — Décision D-1 : TR-2 (conversion réservation → emprunt)

**Constat.** Lorsqu'une réservation est convertie en emprunt, le lecteur·rice
reçoit deux courriels distincts : « réservation convertie » (`res.converted`,
émis par le trigger de workflow de réservation) puis « emprunt créé »
(`loan.created`, émis par le trigger `AFTER INSERT` sur `emprestimos_v2`).

**Décision retenue — conditionner le trigger d'emprunt.** Le mail de référence
côté lecteur·rice reste `res.converted` ; la notification lecteur·rice de
`emprestimo_v2_criado` est neutralisée *lorsque l'emprunt naît d'une conversion*.

**Justification.** Les deux options aboutissent au même résultat visible (un
seul mail), mais elles n'ont pas la même portée doctrinale. Une conversion
réservation → emprunt, du point de vue de la personne, c'est « j'ai retiré mon
livre » : elle referme une boucle qu'elle avait elle-même ouverte en réservant.
Le mail `res.converted` parle de cette réservation — un objet que la personne
connaît et reconnaît. Le mail `loan.created` annonce la création d'un emprunt —
un objet technique qu'elle n'a pas créé elle-même. Notifier par l'événement
*vécu* plutôt que par l'événement *technique* est cohérent avec l'esprit de tout
l'audit (§5.2 : « un seul événement vécu — j'ai retiré mon livre ») et avec la
doctrine RPC v3 (focus sur l'opération signifiante, pas sur la mécanique).

**Réserve instruite.** L'objection légitime en faveur de `loan.created` est
qu'il porte la **date de retour**, que `res.converted` ne porte pas
nécessairement. Cette objection ne justifie pas de garder `loan.created` : elle
identifie un besoin d'enrichir la clé `res.converted` de la date d'échéance.
Cet enrichissement, initialement rattaché au chantier A, a été transféré au
chantier D par la révision du 25/05 (voir §2.1ter) : il se fera avec la refonte
TR-3 de la clé. Une conversion *est* un emprunt qui démarre ; le mail qui
l'annonce doit en donner l'échéance — ce sera l'objet du chantier D.

**Dette D-1.a — instruite et close le 24/05/2026.** La question était : le
trigger `trg_notify_emprestimo_criado` peut-il *savoir* qu'un emprunt naît d'une
conversion, ou faut-il ajouter une colonne à `emprestimos_v2` ? L'instruction sur
dump SQL frais (`dump_D1a_2026-05-24.sql`) et lecture du handler EF réel
(`emprestimos.ts`) conclut : **aucune migration de schéma n'est nécessaire.** Le
détail de l'instruction est consigné en §2.1bis ci-dessous ; il reclasse la
correction TR-2 et précise la cible exacte de D-1.

### 2.1bis — Instruction de D-1.a (24/05/2026) et conséquences pour le chantier A

L'instruction a porté sur quatre objets : la table `emprestimos_v2`, le trigger
`trg_notify_emprestimo_criado` et sa fonction, la fonction de dispatch
`fn_dispatch_circulation_notify_event`, et le handler EF `handleEmprestimoV2`
(`emprestimos.ts`). Constats :

1. **`emprestimos_v2` (l'en-tête) ne porte aucune information de provenance** —
   ni `reserva_id`, ni `origem`, ni équivalent. Un emprunt de conversion et un
   emprunt direct y sont indiscernables.
2. **Mais `emprestimo_itens_v2` (les items) porte la liaison.** Le chemin de
   conversion (`fn_v2_convert_reserva_linhas_to_emprestimo`) renseigne
   `reserva_id` et `reserva_line_no` sur chaque item ; le chemin de création
   directe (`fn_v2_create_emprestimo_by_holdings`) les laisse `NULL`. La
   provenance est donc **déjà tracée en base** — pas de colonne à créer.
3. **Le trigger ne peut pas lire cette provenance.** `trg_notify_emprestimo_criado`
   est `AFTER INSERT` sur `emprestimos_v2` ; dans la RPC de conversion, l'INSERT
   de l'en-tête précède la boucle d'insertion des items. Quand le trigger tire,
   `emprestimo_itens_v2` est encore vide pour cet emprunt. Le trigger ne voit que
   `NEW` (l'en-tête, sans provenance) et passe `'{}'::jsonb` comme `p_extra` —
   aucune provenance ne transite vers le handler.
4. **Le handler `handleEmprestimoV2` ne connaît pas non plus la provenance.** Il
   lit `getEmprestimoV2Bundle`, dont le `SELECT` sur `emprestimos_v2` ne ramène
   aucune colonne d'origine ; aucune branche du handler ne distingue conversion
   et création directe.
5. **Le handler envoie *deux* mails pour `emprestimo_v2_criado`** — un mail
   lecteur·rice (gardé par `loanLifecycleEnabled`) et un mail admin/staff (gardé
   par `loanLifecycleEnabled && loanAdminCopyEnabled`). **Raffinement de D-1 :**
   la décision ne vise que le doublon *côté lecteur·rice*. Le mail admin « nouvel
   emprunt créé » reste légitime pour une conversion (côté gestion, un emprunt
   est bien créé) et **ne doit pas être supprimé**. La cible de D-1 est le seul
   envoi `safeSendEmail(user, …)`, pas le bloc admin.

**Conséquences pour la correction TR-2 (mises à jour de la décision D-1) :**

- D-1 ne demande **pas** de migration de schéma. La formulation initiale
  (« conditionner le trigger ») est remplacée : le trigger ne *peut pas* être
  conditionné utilement, faute de voir la provenance au bon moment.
- La voie retenue est de **faire piloter la notification par la RPC**, qui, elle,
  sait dans quel cas elle est — cohérent avec la doctrine #141.2.E (ne pas lutter
  contre l'ordre des triggers, reprendre la main dans la fonction qui orchestre)
  et avec la doctrine RPC v3 (l'action DB signifiante pilote sa notification).
- Le mécanisme recommandé est le **flag `p_extra`** : `fn_dispatch_circulation_notify_event`
  fond déjà son paramètre `p_extra jsonb` dans le `body` du webhook envoyé à
  `notify-event`. La conversion peut donc émettre le dispatch avec
  `p_extra = '{"suppress_user_mail": true}'` (ou clé équivalente) ; le handler
  `handleEmprestimoV2` lit ce flag et conditionne le seul envoi lecteur·rice, en
  laissant partir le mail admin. Variante possible (event distinct
  `emprestimo_v2_criado_por_conversao`) : plus explicite dans les logs, mais plus
  lourde — arbitrage laissé à la session du chantier A.
- L'enrichissement de `res.converted` avec la date d'échéance — initialement
  prévu comme seconde moitié de D-1 — fait l'objet d'une révision actée le
  25/05 ; voir §2.1ter.

### 2.1ter — Révision de D-1 (25/05/2026) : l'enrichissement de `res.converted` est transféré au chantier D

La décision D-1 prévoyait deux volets : (1) supprimer le doublon de mail
lecteur·rice lors d'une conversion — volet *résorption du doublon* ; (2) enrichir
le mail `res.converted` conservé avec la date d'échéance — volet *enrichissement
de contenu*. L'instruction du volet 2 sur le code réel (`reservas.ts`,
`handleReservaV2StatusChange`, et le dump SQL) a révélé ce qui suit :

- L'événement `reserva_convertida_em_emprestimo` n'est **pas** émis par la RPC
  de conversion mais par un **trigger** sur `reserva_item_workflow_v2` (transition
  de `workflow_stage` vers `retirada_efetivada`). Le trigger ne connaît que
  `reserva_id` et `line_no` ; il ne dispose pas de la date d'échéance de
  l'emprunt. Faire porter la date par le `p_extra` de ce dispatch (option dite
  « A ») est donc impossible : la RPC ne contrôle pas ce dispatch.
- La seule voie pour enrichir `res.converted` de la date serait que le handler
  EF `handleReservaV2StatusChange` aille lui-même chercher la `due_at` de
  l'emprunt issu de la réservation, via `emprestimo_itens_v2.reserva_id` — ce qui
  suppose de modifier la **couche data** (`getReservaV2Bundle`) pour une seule
  clé parmi cinq (option dite « B »).
- Or `handleReservaV2StatusChange` sera **rouvert intégralement par le chantier
  D** : le constat TR-3 porte précisément sur la refonte des cinq clés `res.*`
  plates de ce handler, dont `res.converted`. Réaliser l'option B au titre du
  chantier A ferait une greffe data ciblée sur un fichier que le chantier D
  réorganisera ensuite — soit deux passes sur le même objet.

**Décision (actée le 25/05/2026).** L'enrichissement de `res.converted` avec la
date d'échéance est **retiré du chantier A et transféré au chantier D**, où il
sera réalisé en une seule passe avec la refonte TR-3 de la clé. Cette révision
est conforme à l'esprit de la règle D-0 — un objet partagé est traité **une
seule fois** : `res.converted` sera donc traité une seule fois, par le chantier
D. La formulation antérieure de D-0 (« `res.converted` traité intégralement dans
le chantier A ») est corrigée en ce sens (voir §2.0 et §5).

**Conséquence : le volet TR-2 du chantier A se limite à la résorption du
doublon**, livrée par trois fichiers (migration SQL retirant le trigger et
faisant émettre les deux RPC ; `dispatch.ts` transmettant le `payload` ;
`handleEmprestimoV2` lisant `suppress_user_mail`). Le mail `res.converted`
restera, jusqu'au chantier D, sans date d'échéance — ce qui n'est pas une
régression : il ne l'a jamais portée. TR-2 est **clos** au sein du chantier A
avec ces trois fichiers.

### 2.2 — Décision D-2 : TR-8 (cascade d'annulation biblio)

**Constat.** Une annulation de réservation par la bibliothèque fait passer
l'item à `cancelada_biblioteca`, ce qui déclenche le trigger
`trg_auto_liberate_after_no_show_change` : un second `UPDATE` repasse aussitôt
le `workflow_stage` à `liberada_para_circulacao`. Le handler de
`liberada_para_circulacao` définit `readerKey = 'wf.closed'` → un second mail
part au lecteur·rice, porteur de jargon interne (« libérée pour circulation »).

**Décision retenue — neutraliser le mail lecteur·rice de
`liberada_para_circulacao`.** L'étape `liberada_para_circulacao` est une
transition d'état *interne à la bibliothèque* : elle décrit le retour de
l'exemplaire dans le circuit de prêt, fait de gestion sans valeur d'usage pour
la personne. Le lecteur·rice doit recevoir **un** mail — celui qui l'informe que
sa réservation est annulée (`reserva_cancelada_biblioteca`) — et rien d'autre.

**Justification.** Contrairement à TR-2, TR-8 présente peu d'ambiguïté : un mail
disant « libérée pour circulation » envoyé *après* une annulation n'apporte
aucune information actionnable et expose du vocabulaire de back-office. Le
diagnostic de l'audit est net (§6.3).

**Portée à confirmer en chantier — D-2.a.** Reste à trancher en session si
`liberada_para_circulacao` ne doit *jamais* notifier le lecteur·rice, ou
seulement *pas dans le contexte d'une cascade d'annulation*. Deux pistes
possibles : (i) retirer `readerKey` de ce stage de façon inconditionnelle si
aucun parcours légitime ne justifie d'en informer le lecteur·rice ; (ii)
conditionner la notification à l'absence d'un événement d'annulation immédiatement
antérieur sur le même item. La piste (i) est plus simple et probablement
suffisante ; à vérifier qu'aucun autre parcours n'amène un lecteur·rice à
attendre légitimement ce mail.

---

## 3. Les 5 chantiers — vue d'ensemble

| Chantier | Intitulé | Constats couverts | Sévérité | Ordre | État (27/05/2026) |
|---|---|---|---|---|---|
| **A** | Doublons et mauvais routage de notification lecteur·rice | TR-1, TR-2, TR-8 | Haute (impact lecteur·rice direct) | 1 | ✅ bouclé (25/05) |
| **B** | Internationalisation des mails internes | TR-4, TM-B, TM-C | Moyenne-haute | 2 | 🟠 ouvert |
| **C** | Logos de bibliothèques résolus depuis le contexte | TR-6.2b | Moyenne (doctrinale) | 3 | ✅ bouclé (27/05) |
| **D** | Wording des mails de statut de réservation | TR-3 | Moyenne | 4 | ✅ bouclé (27/05, D-1 et D-2) |
| **E** | Lot de cohérence transverse | TR-5, TR-6.1, TR-6.3, NW-A, NW-B, NW-C, LP-C | Faible à moyenne | 5 | ✅ clos sur le code (27/05) ; 2 détails de finition tracés en §11 |

**Couverture.** Les 15 constats de l'audit sont tous affectés. Les 6
non-constats (LP-A, LP-B, TR-6.2a, TR-7, TR-9, revue i18n) ne donnent lieu à
aucun chantier — rappelés en §9 pour mémoire.

**Note sur la séquence.** L'ordre 1→5 est un ordre de *priorité*, pas une
contrainte de dépendance stricte. Les chantiers A à D sont mutuellement
indépendants et pourraient s'exécuter dans un autre ordre si une contrainte
calendaire l'imposait. Le chantier E est volontairement en dernier : c'est un
lot de finition, à traiter en une session de nettoyage groupée. Une seule
dépendance souple existe (voir §4.B et §4.E) : la règle de repli « logo absent »
est fixée par le chantier C et propagée par le chantier E (D-0), donc C précède
E sur ce point. Les constats TM-A et TM-D sont, par décision D-0, traités
exclusivement dans le chantier B et ne concernent plus le lot E.

---

## 4. Fiches d'ouverture des chantiers

### Chantier A — Doublons et mauvais routage de notification lecteur·rice

**Constats couverts :** TR-1, TR-2, TR-8.
**Décisions applicables :** D-1, D-2 (§2).
**Sévérité :** haute. Seul chantier dont le défaut est subi *aujourd'hui* par
un·e lecteur·rice réel·le, de façon visible.
**Nature :** majoritairement SQL (triggers et fonctions de notification),
marginalement EF (routage `dispatch.ts`).

**Objet.** Garantir qu'un·e lecteur·rice reçoit, pour chaque événement de
circulation vécu, **un seul courriel** et **le bon** — c'est-à-dire le mail
multilingue v2, jamais le mail legacy non internationalisé.

**Sous-tâches.**

1. **TR-2 — résorber le doublon côté lecteur·rice — RÉALISÉ (25/05/2026).**
   Instruction D-1.a close (cf. §2.1bis), option β retenue. Trois fichiers
   produits et prêts à déployer : (a) migration
   `20260525110000_tr2_emprestimo_criado_dispatch_rpc.sql` — retire le trigger
   `trg_notify_emprestimo_criado` et fait émettre `fn_dispatch_circulation_notify_event`
   par les deux RPC de création (`fn_v2_create_emprestimo_by_holdings` avec
   `p_extra` vide ; `fn_v2_convert_reserva_linhas_to_emprestimo` avec
   `'{"suppress_user_mail": true}'`) ; (b) `dispatch.ts` — transmet le `payload`
   à `handleEmprestimoV2` ; (c) `emprestimos.ts` — `handleEmprestimoV2` lit
   `suppress_user_mail` et saute le seul envoi lecteur·rice, le mail admin
   restant émis. Reste à faire : déploiement coordonné (EF d'abord, migration
   ensuite) et test BLMF en navigation privée.
2. **TR-2 — enrichir `res.converted` — TRANSFÉRÉ AU CHANTIER D (révision D-1,
   25/05/2026).** L'instruction sur le code réel a montré que l'événement
   `reserva_convertida_em_emprestimo` est émis par un trigger qui ne dispose pas
   de la date d'échéance, et que `handleReservaV2StatusChange` sera de toute
   façon rouvert intégralement par le chantier D (TR-3). L'enrichissement de
   `res.converted` avec la date d'échéance se fera donc dans le chantier D, en
   une seule passe avec la refonte de la clé — voir §2.1ter. Cette sous-tâche ne
   relève plus du chantier A.
3. **TR-8 — appliquer D-2.** Neutraliser la notification lecteur·rice du stage
   `liberada_para_circulacao`. Trancher en session la portée exacte (dette
   D-2.a : inconditionnel vs conditionné à une annulation antérieure).
4. **TR-1 — corriger l'anomalie de routage.** Dans `dispatch.ts`, faire en
   sorte que `emprestimo_prorrogado` soit capté par la branche v2 (qui contient
   déjà la normalisation `emprestimo_prorrogado → emprestimo_v2_prorrogado`,
   lignes 58/62) et non par la branche legacy qui vient en premier et fait
   `return`. Préalable d'instruction : vérifier que le SIGB émet *encore*
   l'événement `emprestimo_prorrogado` — s'il est lui-même mort, la correction
   se réduit à supprimer la branche legacy morte. Note : le patch `dispatch.ts`
   de TR-2 a délibérément laissé ce double routage intact (un changement à la
   fois) ; TR-1 le traitera.

**Doctrine applicable.** Ce chantier touche des triggers en cascade : la
doctrine #141.2.E (ordre des `UPDATE` quand des triggers `AFTER UPDATE` sont en
jeu) s'applique. Toute migration touchant un trigger de notification doit inclure
un bloc `DO` de vérification en fin de transaction (doctrine création d'objets
sécurisés v2, 18/05). Aucune action de durcissement sans dump SQL courant (GLB
v13). Un changement à la fois pour les hotfix (leçon 11-12/05).

**Pré-requis.** Dump SQL à jour des schémas concernés
(`supabase db dump -f schema.sql --linked -s public,api`). L'instruction de
D-1.a (24/05) a déjà été conduite sur le dump `dump_D1a_2026-05-24.sql` et la
lecture du handler `emprestimos.ts` ; un dump rafraîchi reste néanmoins requis
au moment de l'exécution, conformément à la doctrine « aucune action de
durcissement sans dump SQL courant ».

**Critères de clôture.**
- Une conversion réservation → emprunt produit exactement **un** mail
  lecteur·rice (le mail `res.converted`), et le mail admin de création d'emprunt
  continue de partir. (L'ajout de la date d'échéance à `res.converted` relève du
  chantier D — voir §2.1ter.)
- Une annulation biblio produit exactement **un** mail lecteur·rice (le mail
  d'annulation), sans mail « libérée pour circulation ».
- TR-1 instruit le 25/05 : l'événement `emprestimo_prorrogado` n'est plus émis
  par la base (le seul émetteur de prorogation, le trigger
  `trg_notify_emprestimo_prorrogacao`, émet `emprestimo_v2_prorrogado`). Le
  « mauvais routage » de l'audit était théorique. Correction livrée : nettoyage
  du code mort `emprestimo_prorrogado` dans `dispatch.ts` (branche legacy et
  branche v2).
- Tests fonctionnels BLMF passés en navigation privée (fixtures Xavier/Lívia) —
  en particulier : effectuer une conversion et vérifier qu'un seul mail
  lecteur·rice arrive, et qu'un mail admin arrive bien.
- Migrations passées par le pipeline Woodpecker (jamais de SQL en SQL Editor
  avant push).

**Dettes ouvertes par ce chantier.** D-1.a est **close** (instruite le 24/05,
cf. §2.1bis — pas de migration de schéma). D-2.a est **close** (instruite le
25/05, cf. §2.2 — neutralisation conditionnée à `final_reason` non nul, couvrant
`cancelled_by_library` et `no_show`). Deux observations sont portées en dette,
hors périmètre de ce chantier :
- **Branche legacy `handleEmprestimoOld` (constat 25/05, instruction de TR-1).**
  TR-1 a confirmé que l'événement `emprestimo_prorrogado` est mort. La branche
  legacy `handleEmprestimoOld` route encore quatre autres familles d'événements
  — `emprestimo_criado`, `emprestimo_devolvido`, `lembrete_devolucao_*`,
  `aviso_atraso_*` — plus `reserva_criada` (`handleReservaCriadaOld`). Leur
  émission n'a pas été instruite : si elles sont toutes mortes elles aussi, la
  branche legacy et les handlers `handleEmprestimoOld` / `handleReservaCriadaOld`
  seraient du code mort à retirer. À instruire à froid — chantier #153.E
  (cohérence transverse) ou note de backlog dédiée. Ne pas supprimer un handler
  legacy sans avoir confirmé l'absence d'émission de chacun de ses événements.
- **Flag `reservation_mail_liberada_para_circulacao_enabled` (constat TR-8).**
  Voir la migration TR-8 : ce flag (`DEFAULT false`) pourrait n'activer plus
  aucun mail une fois TR-8 posé, toute bascule vers `liberada_para_circulacao`
  portant un `final_reason`. À instruire séparément.

---

### Chantier B — Internationalisation des mails internes

**Constats couverts :** TR-4, TM-B, TM-C. Constat connexe à instruire ici : TM-A,
TM-D (voir ci-dessous).
**Sévérité :** moyenne-haute. TM-B porte sur **54 chaînes en dur** dans
`team.ts` (le constat le plus volumineux de l'audit).
**Nature :** EF (`team.ts`, `register`). Pas de SQL.

**Objet.** Aligner les mails destinés au **staff** sur le standard déjà
appliqué aux mails destinés au **public** : tout passe par le système i18n,
routé par la locale de la bibliothèque (`default_locale` / *libLocale*). Une
biblio non lusophone ne doit plus recevoir ses notifications internes en
portugais — exigence en tension directe avec la promesse fédérative 8 langues.

**Constat de fond.** L'audit qualifie ce défaut d'**incohérence interne**, pas
de dette de traduction (§3.2, TM-B) : les clés i18n équivalentes
(`l.reader`, `l.reason`, `l.contact`…) **existent déjà** dans `mail-strings.ts`,
complètes sur les 8 locales, et sont simplement **inutilisées**. `team.ts`
appelle d'ailleurs déjà `label()` quatre fois dans ses mails lecteur·rice, et
`library_profile.ts` (voisin direct) fait tout en i18n. Le travail est donc
majoritairement du **branchement**, pas de la **traduction**.

**Sous-tâches.**

1. **TM-B — `team.ts`.** Remplacer les 54 chaînes en dur par des appels i18n :
   9 titres + 9 intros (aujourd'hui en pt-BR en dur), 36 libellés de détails
   (aujourd'hui en français en dur). Router les mails `admin_copy` par la locale
   de la biblio. Réutiliser les clés existantes de `mail-strings.ts` ; n'ajouter
   de clés que pour les libellés sans équivalent (à inventorier).
2. **TR-4 — `register`.** Internationaliser les deux rendus internes
   (`libraryMailHtml` → biblio, `adminMailHtml` → gestion AnarBib) : titres,
   sous-titres, pré-titres et sujets, tous codés en dur en pt-BR aujourd'hui.
   Router le mail biblio par la locale de la biblio. Le mail lecteur·rice du
   même fichier est déjà i18n et sert de modèle.
3. **TM-C — coquille.** Corriger le mot-valise FR/PT « do passage » (`team.ts`
   l.738) : « passage » est français au milieu d'un libellé portugais. Sous-cas
   de TM-B, se résout mécaniquement dès que le libellé passe en i18n.
4. **TM-D — aligner le code sur la spec.** Vérification faite sur la spec
   (v1.2, 24/05) : `spec-gouvernance-roles.md` nomme déjà correctement
   l'événement `team.inactive_auto` (§8.2, §7, liste i18n §8.3). C'est donc le
   **code** qui diverge — `team.ts` traite `team.inactive_completed`.
   L'alignement va dans le sens *code → spec* : renommer `inactive_completed` en
   `inactive_auto` dans `team.ts` (et tout point du parc qui émet ou capte ce
   nom). Confirmer au passage qu'aucun événement n'est aujourd'hui émis sous un
   nom non capté. Inverse de TM-A (où c'est la spec qui s'aligne sur le code).
5. **TM-A — amender la spec.** Appliquer l'amendement décrit dans
   `AMENDEMENT_TM-A_spec-gouvernance-roles_2026-05-24.md` (document préparatoire
   dédié, `docs/decisions/`). En résumé : faire passer `team.inactive_warning_7d`
   de « personne uniquement » à « personne + coordenadores », avec escalade aux
   administrateur·rices du réseau si la personne inactive est le·la dernier·e
   coordenador·a. Quatre passages de la spec sont concernés (§5.10, §8.2,
   Annexe Q7, bloc Historique) — voir le document préparatoire. Version cible
   v1.3. Le code de `team.ts` n'est pas modifié au titre de TM-A *en tant que
   tel* ; sa copie staff au 7j est internationalisée au titre de TM-B. **Réserve
   à instruire :** vérifier sur le code réel si le handler gère déjà le cas
   « dernier·e coord » au J-7 ; sinon, l'escalade réseau au J-7 devient une
   correction de code à faire, et non une simple mise à jour de spec.

**Constat TM-A — décision actée : amendement de la spec.** L'audit relève un
écart code/spec : `handleInactiveWarning` envoie une copie staff au seuil
**7 jours** (`if (isShort)`, l.735), non prévue par la spec gouvernance, qui
réserve la notification de la personne seule aux deux seuils 30j et 7j.
**Décision du 24/05/2026 : on amende la spec, on ne touche pas le code** (sur ce
point précis). Le réseau juge utile que la coordination soit prévenue dès le
seuil 7j ; le comportement actuel du code devient donc le comportement *voulu*,
et la spec est mise à jour pour le prévoir. TM-A bascule d'« écart à corriger »
en « spec à mettre à jour » — c'est une **dette documentaire**.

*Spec concernée et précisions issues de sa lecture (24/05).* La spec à amender
est `docs/specs/spec-gouvernance-roles.md`, dans sa version actuelle **v1.2**
(2026-05-20) ; version cible après amendement : **v1.3**. Trois précisions sont
ressorties de sa lecture, qui n'apparaissaient pas dans l'audit :

- *La référence de l'audit est périmée.* L'audit situe le passage en « §9,
  l.654-656 » ; la spec a connu deux refontes depuis (v1.1, v1.2) et le passage
  est en réalité en **§8.2** dans la v1.2 actuelle. L'amendement se repère par
  sections nommées, pas par numéros de ligne.
- *La règle est écrite à quatre endroits.* Amender le seul §8.2 laisserait la
  spec en contradiction interne. Les passages à traiter : §5.10 (workflow T9,
  étape 2), §8.2 (table des event types — celui que cite l'audit), Annexe Q7
  (table des décisions, à passer en statut « amendée v1.3 ») et le bloc
  Historique de l'en-tête. La table §7 ne porte pas de colonne destinataire :
  pas de modification, simple relecture.
- *Cas du·de la dernier·e coordenador·a — arbitré 24/05.* Mettre « la
  coordination » en copie du J-7 pose un cas limite : si la personne inactive
  est le·la dernier·e coordenador·a, il n'y a personne à mettre en copie.
  **Décision : dans ce cas, le J-7 escalade aux administrateur·rices du réseau**
  (`network_administrators` `status='active'`), exactement comme le J-9 mois et
  comme l'escalade « dernier·e coord » déjà décrite en §6.1. Mécanisme réutilisé,
  aucun mécanisme neuf.

Le détail de l'amendement (diff section par section) est consigné dans le
document préparatoire `AMENDEMENT_TM-A_spec-gouvernance-roles_2026-05-24.md`,
à verser dans `docs/decisions/` et à appliquer lors du chantier B. Le code de
`team.ts` n'est pas modifié au titre de TM-A *en tant que tel* — sa copie staff
au 7j est internationalisée au titre de TM-B. **Une réserve subsiste cependant**
(voir document préparatoire §6) : si le handler `team.ts` n'a pas déjà prévu le
cas « dernier·e coord » au J-7, l'escalade réseau au J-7 devient une correction
de code à faire, et non une simple mise à jour de spec — à instruire sur le code
réel en session.

**Doctrine applicable.** Lecture intégrale de chaque fichier avant remplacement
(leçon 13/05 : ne jamais remplacer un fichier partiellement lu — `Measure-Object
-Line` + `cat` complet, vérifier le nombre d'exports attendus). Si patch de
fichiers JSON (`mail-strings.ts` n'est pas du JSON, mais des fichiers de
contenu peuvent l'être) : insertion texte pure, jamais `ConvertFrom-Json`
(leçon 19/05). Lecture UTF-8 sûre via
`[System.IO.File]::ReadAllText` (leçon 17/05). Commit dès qu'un sous-paquet
fonctionne (leçon 14/05). `npm run build` avant tout push.

**Pré-requis.** Inventaire exhaustif des 54 chaînes de `team.ts` et des chaînes
internes de `register`, croisé avec les clés existantes de `mail-strings.ts`
pour distinguer « clés à brancher » de « clés à créer ». Vérifier que
`mail-strings.ts` est bien en 8 locales (confirmé par l'audit, §10.1, TR-9
infirmé — 385 clés × 8 locales).

**Critères de clôture.**
- `team.ts` et `register` ne contiennent plus aucune chaîne de contenu de mail
  en dur ; tout passe par `tMail` / `label`.
- Les mails internes (`admin_copy`, rendus internes de `register`) sont rendus
  dans la locale de la bibliothèque destinataire.
- Toute clé nouvellement créée est complète sur les 8 locales, en langage
  inclusif.
- TM-D résolu — `team.ts` aligné sur la spec (`inactive_completed` →
  `inactive_auto`). TM-A acté — `spec-gouvernance-roles.md` amendée en v1.3
  (notification de la coordination au seuil J-7, escalade réseau si dernier·e
  coord) ; le handler `team.ts` vérifié ou corrigé en conséquence.
- `npm run build` vert avant push ; déploiement EF via CLI
  (`supabase functions deploy notify-event --no-verify-jwt` depuis `anarbib-app` —
  le déploiement par MCP est exclu, taille de bundle au-delà de la limite API).

**Dettes ouvertes par ce chantier.** Amendement de `spec-gouvernance-roles.md`
en version v1.3 au titre de TM-A — sections §5.10, §8.2, Annexe Q7 et bloc
Historique ; détail dans `AMENDEMENT_TM-A_spec-gouvernance-roles_2026-05-24.md`.
Dette documentaire à solder dans le chantier, non reportable. Éventuelle
correction de code si le handler `team.ts` ne gère pas le cas « dernier·e
coord » au J-7 (escalade réseau).

---

### Chantier C — Logos de bibliothèques résolus depuis le contexte

**Constats couverts :** TR-6.2b.
**Sévérité :** moyenne, **doctrinale**. L'audit la qualifie de « ni anecdotique
ni négociable » (doctrine 24/05).
**Nature :** EF (résolution d'asset dans la couche de rendu des mails). Pas de
SQL au-delà de la lecture de `ctx.logo_url`.

**Objet.** Faire en sorte que le logo affiché dans les mails d'une bibliothèque
soit résolu depuis son **contexte** (`ctx.logo_url`), et non depuis une table
d'assets codée en dur dans le code source.

**Constat de fond.** La résolution actuelle s'appuie sur `LIBRARY_MAIL_ASSETS`,
un objet qui code en dur les logos de deux bibliothèques (`blmf`, `btl`).
Conséquence : **une nouvelle bibliothèque rejoignant le réseau n'aurait pas son
logo dans ses mails sans une édition du code source et un redéploiement.** C'est
un frein direct à l'extensibilité fédérative d'AnarBib — le réseau est censé
pouvoir accueillir des bibliothèques sans que chacune impose une modification du
cœur applicatif.

**Distinction avec TR-6.2a (hors périmètre de ce chantier).** Le logo *réseau*
AnarBib, lui, est légitimement codé en dur (TR-6.2a, validé non-constat,
doctrine 24/05) : objet unique et invariant, le hard-coding y est robuste. Ce
chantier ne touche **que** les logos *de bibliothèques*.

**Sous-tâches.**

1. Identifier tous les points de la couche de rendu des mails qui lisent
   `LIBRARY_MAIL_ASSETS` pour résoudre un logo de biblio.
2. Remplacer cette résolution par une lecture de `ctx.logo_url` (colonne
   `logo_url` de la bibliothèque, déjà présente au schéma — à confirmer).
3. Définir le comportement de repli quand `ctx.logo_url` est vide : l'audit
   recommande, au titre de TR-6.1, le repli vers un texte plutôt que l'affichage
   d'un vide (comportement déjà correct de `notify-network-weekly-report`). Ce
   point recoupe TR-6.1, traité en chantier E — coordonner pour ne pas faire le
   travail deux fois (voir §5).
4. Retirer les entrées `blmf` / `btl` de `LIBRARY_MAIL_ASSETS` une fois la
   résolution par contexte en place et testée.

**Doctrine applicable.** Tester en conditions réelles avant de déclarer corrigé.
L'audit note (§9.2, limite d'instruction) que TR-6 est instruit *par lecture de
code* — l'état d'affichage réel d'un logo en production relèverait d'un envoi
test. Ce chantier doit donc se clôturer sur un **envoi test effectif** : un mail
d'une biblio dont le logo vient de `ctx.logo_url`, vérifié visuellement.

**Pré-requis.** Confirmer que la colonne `logo_url` existe sur la table des
bibliothèques et qu'elle est renseignée pour les biblios actives (au moins
BLMF). Sinon, son renseignement devient une sous-tâche préalable.

**Critères de clôture.**
- Aucun logo de bibliothèque n'est plus codé en dur dans le code source.
- Une bibliothèque nouvellement ajoutée affiche son logo dans ses mails sans
  aucune édition de code.
- Repli défini et testé pour le cas `logo_url` vide.
- Envoi test effectif vérifié visuellement.

**Dettes ouvertes par ce chantier.** Éventuel renseignement de `logo_url` pour
les biblios dont la colonne serait vide.

---

### Chantier D — Wording des mails de statut de réservation

**Constats couverts :** TR-3 (sous-constats TR-3.1, TR-3.2 et TR-3.3).
**Sévérité :** moyenne.
**Nature :** EF (`reservas.ts`, handler `handleReservaV2StatusChange`) + écriture
i18n nouvelle.

**Objet.** Donner aux mails de changement de statut de réservation un contenu
réellement informatif, et différencier le propos selon le destinataire
(lecteur·rice vs staff).

**Constat de fond.** Dans `handleReservaV2StatusChange`, chaque événement est
rendu par une clé `res.*` unique qui sert **à la fois** de sujet, de titre et
d'intro — et **la même clé** pour le mail lecteur·rice et le mail staff. Trois
défauts en découlent :

- **TR-3.1 — contenu plat.** Les clés `res.*` sont des étiquettes courtes, sans
  version « message » : l'intro recopie le titre, le mail n'explique rien au
  lecteur·rice. Une personne recevant « Réservation annulée » ne reçoit rien de
  plus que ces deux mots, ni pourquoi, ni quelle suite.
- **TR-3.2 — pas de différenciation.** Le même texte part au lecteur·rice et au
  staff, alors que les deux n'ont pas besoin de la même information. (Précision
  de l'audit : `res.cancelStaff` n'est *pas* une clé « réservée au staff » —
  `Staff` y désigne l'auteur de l'annulation, pas le destinataire.)
- **TR-3.3 — mauvais champ de motif (constaté le 25/05, test de TR-8).** Le mail
  d'annulation biblio (`reserva_cancelada_biblioteca`) affiche son motif depuis
  `reserva.notes` (ligne `const motivo = String(reserva.notes || "").trim();`).
  Or `reservas_v2.notes` contient la note de *création* de la réservation, pas
  le motif d'*annulation*. Résultat constaté : un mail d'annulation affichant
  « Motif : Réservation créée depuis le compte lecteur·rice » au lieu du motif
  réellement saisi par le staff. Le défaut touche **les deux mails** — celui du
  lecteur·rice et celui de la bibliothèque : la variable `motivo` est lue une
  seule fois en tête de `handleReservaV2StatusChange` et alimente à la fois
  l'intro lecteur·rice et l'intro staff. C'est donc une seule cause, une seule
  ligne à corriger, pour les deux mails. Le motif d'annulation est correctement
  enregistré — vérifié sur la base le 25/05 — mais dans
  `reserva_item_workflow_v2.workflow_note`, sur la ligne dont le `workflow_stage`
  est `cancelada_biblioteca`. C'est un bug de lecture, sans perte de donnée : le
  handler lit la mauvaise colonne. Correction : faire lire le motif depuis
  `workflow_note` de la ligne de workflow d'annulation, et non depuis
  `reserva.notes`. À traiter dans la même passe que la refonte du wording de
  `res.cancelStaff` (sous-tâche 1), puisque c'est le même mail. Concerne aussi,
  potentiellement, `res.refused` (`reserva_v2_recusada`), qui lit `motivo` par le
  même mécanisme — à vérifier lors du chantier.

**Sous-tâches.**

1. Doter chaque clé `res.*` concernée d'une version « message » distincte du
   titre court : une intro qui explique au lecteur·rice ce qui s'est passé et,
   le cas échéant, ce qu'il ou elle peut faire.
2. Séparer le contenu lecteur·rice du contenu staff : clés distinctes, ou
   paramétrage du rendu selon le destinataire. Trancher en session quelle des
   deux approches est la plus économe (les 5 clés `res.*` concernées sont déjà
   complètes sur les 8 locales — voir §8.1 de l'audit).
3. Écrire les chaînes nouvelles sur les **8 locales**, en langage inclusif.
4. **Enrichir `res.converted` de la date d'échéance** (transféré du chantier A
   par la révision D-1 du 25/05, §2.1ter). Le mail de conversion réservation →
   emprunt doit indiquer la date de retour. La donnée n'est pas dans le bundle
   de `handleReservaV2StatusChange` (`getReservaV2Bundle` ne ramène qu'un bundle
   de réservation) : il faut l'acheminer. Voie identifiée — le handler s'exécute
   après le COMMIT, l'emprunt et ses items existent ; la `due_at` se récupère
   via `emprestimo_itens_v2.reserva_id` qui lie réservation et emprunt. Modifier
   `getReservaV2Bundle` (couche `data/reservas.ts`) ou ajouter une lecture dédiée
   dans le handler. À faire dans la même passe que la refonte de la clé
   `res.converted` (sous-tâche 1), pour ne traiter cet objet qu'une seule fois.
5. **Corriger le champ de motif des mails d'annulation (TR-3.3).** Faire lire le
   motif depuis `reserva_item_workflow_v2.workflow_note` de la ligne dont le
   `workflow_stage` est `cancelada_biblioteca`, et non depuis `reserva.notes`
   (qui contient la note de création). Concerne `res.cancelStaff`
   (`reserva_cancelada_biblioteca`) ; vérifier si `res.refused`
   (`reserva_v2_recusada`) est affecté par le même mécanisme. Comme pour la
   sous-tâche 4, la donnée n'est pas forcément dans le bundle actuel — vérifier
   ce que ramène `getReservaWorkflowBundle` / `getReservaV2Bundle` et, au besoin,
   l'enrichir.

**Périmètre des événements concernés.** `reserva_v2_recusada`,
`reserva_cancelada_biblioteca`, `reserva_cancelada_leitor`, `reserva_expirada`,
`reserva_convertida_em_emprestimo` (5 clés `res.*`). `res.converted` est traité
**intégralement par ce chantier** : refonte de la clé (sous-tâches 1-3) *et*
ajout de la date d'échéance (sous-tâche 4). Le chantier A ne touche pas cette
clé — voir §2.1ter et §5.

**Doctrine applicable.** Langage inclusif sur les 6+ locales (exigence cœur du
projet). Toute clé créée complète sur les 8 locales. Lecture intégrale du fichier
avant modification.

**Critères de clôture.**
- Chaque mail de statut de réservation porte une intro informative distincte de
  son titre.
- Le contenu reçu par le lecteur·rice est rédigé de son point de vue ; le
  contenu staff du sien.
- Le mail `res.converted` porte la date d'échéance de l'emprunt.
- Toutes les chaînes nouvelles sont complètes sur les 8 locales, en langage
  inclusif.

---

### Chantier E — Lot de cohérence transverse

**Constats couverts :** TR-5, TR-6.1, TR-6.3, NW-A, NW-B, NW-C, LP-C.
**Sévérité :** faible à moyenne (NW-B tire vers moyenne).
**Nature :** EF, plusieurs handlers. Pas de SQL.

**Objet.** Traiter en une session de nettoyage groupée les constats résiduels
de faible portée individuelle, mais qui, ensemble, érodent la cohérence du parc
d'EF.

**Sous-tâches.**

1. **TR-5 — préfixes de sujet.** Aligner `notify-library-request` (7 sujets
   préfixés `[AnarBib]` en dur) sur la convention `[${BRAND_NAME}]` (variable
   d'environnement), comme `notify-document-permission-request`. Les EF non
   rattachées à une biblio unique peuvent légitimement utiliser un préfixe
   global ; rien ne justifie qu'elles divergent entre elles.
2. **NW-B — clé i18n cassée.** Ajouter la clé `l.executed_at` à
   `mail-strings.ts`, complète sur les 8 locales. Aujourd'hui absente,
   `tMail` renvoie la chaîne brute `"l.executed_at"` ; non vide, elle
   court-circuite le fallback `|| "Date"` qui ne s'exécute jamais. Conséquence :
   les mails `network.collective_removal_executed` affichent le texte technique
   `l.executed_at` dans les 8 langues. **À traiter en priorité dans ce lot** —
   c'est le seul constat de E avec un défaut visible en production.
3. **TR-6.1 — comportement « logo absent ».** Uniformiser le repli quand le
   logo est absent : repli vers un texte (comportement correct de
   `notify-network-weekly-report`) plutôt qu'affichage d'un vide (6 EF). À
   coordonner avec le chantier C, qui définit déjà ce repli pour les logos de
   biblios — voir §5.
4. **TR-6.3 — variables d'environnement de logo.** Rationaliser les trois
   variables `LOGO_URL`, `ANARBIB_LOGO_URL`, `NETWORK_LOGO_URL`, lues en ordre
   et sous-ensemble variables selon l'EF. Fixer un ordre de lecture unique et
   documenté, ou réduire le nombre de variables.
5. **NW-A — clés de vote du retrait collectif.** Le handler
   `collective_removal_vote_cast` réutilise `network.vote.favorable` /
   `network.vote.opposed` (clés de la cooptation) comme proxies. Fonctionnel
   aujourd'hui ; créer des clés propres au retrait collectif si l'on veut se
   prémunir d'une divergence future de wording. À trancher : correction
   immédiate ou simple inscription en dette documentée.
6. **NW-C — hypothèse de timing non documentée.** `cooptation_voted` et
   `collective_removal_vote_cast` déterminent « 1er vote ? » par un
   `SELECT count(*)` supposant que le vote courant est déjà inscrit en base.
   Probablement vrai ; ajouter un commentaire de code explicitant la dépendance
   à l'ordre des opérations, ou confirmer formellement l'invariant.
7. **LP-C — outbox marquée `sent` sans envoi.** Quand un fan-out est vide, le
   handler marque l'outbox `status='sent'` malgré l'absence d'envoi réel. Décider
   d'un statut distinct (p. ex. `skipped` / `no_recipients`) pour ne pas tromper
   une lecture ultérieure de la table, ou documenter le comportement.

> TM-A et TM-D ne figurent pas dans ce lot : par décision D-0, ils sont traités
> exclusivement dans le chantier B.

**Doctrine applicable.** Un changement à la fois, même dans un lot groupé :
chaque sous-tâche fait l'objet d'un commit distinct, pour que le diff reste
lisible (leçon 11-12/05). `npm run build` avant push.

**Critères de clôture.**
- Les sujets de `notify-library-request` utilisent `[${BRAND_NAME}]`.
- La clé `l.executed_at` existe sur les 8 locales ; les mails
  `network.collective_removal_executed` affichent un libellé lisible.
- Le comportement « logo absent » est uniforme sur les 8 EF.
- Les variables d'environnement de logo ont un ordre de lecture unique et
  documenté.
- NW-A, NW-C, LP-C : soit corrigés, soit explicitement inscrits en dette
  documentée avec justification.

---

## 5. Points de coordination entre chantiers

Trois recoupements existent entre chantiers. La **décision D-0 (§2.0)** les
règle par une règle ferme : chaque objet partagé est traité une seule fois,
intégralement, par le chantier qui le rencontre en premier. Le détail :

- **`res.converted` — chantier D (révisé le 25/05).** Cette clé est touchée à la
  fois par le besoin d'enrichissement (date d'échéance, initialement volet de
  D-1, chantier A) et par la refonte de wording (version « message », TR-3,
  chantier D). La révision D-1 du 25/05 (§2.1ter) a tranché : l'instruction sur
  le code réel a montré que l'enrichissement ne peut pas se faire proprement
  depuis le chantier A (l'événement est émis par un trigger sans accès à la
  date). **Règle D-0 appliquée :** `res.converted` est traité **une seule fois,
  intégralement, dans le chantier D** — refonte de la clé *et* ajout de la date
  d'échéance dans la même passe. Le chantier A ne touche pas cette clé ; son
  volet TR-2 se limite à la résorption du doublon de mail.
- **Repli « logo absent » — chantiers C et E.** Le chantier C définit le
  comportement de repli pour les logos de biblios (TR-6.2b → `ctx.logo_url`) ; le
  chantier E uniformise ce repli sur les 8 EF (TR-6.1). **Règle D-0 :** le
  chantier C **fixe** la règle de repli (repli texte) ; le chantier E la
  **propage** telle quelle, sans la redéfinir. C s'exécute avant E sur ce point.
- **TM-A et TM-D — chantiers B et E.** **Règle D-0 :** tranchés **définitivement
  dans le chantier B**. Ils ne retombent pas dans le lot E. TM-A est acté
  (amendement de spec v1.3, §2.0 / chantier B) ; TM-D est clarifié — c'est le
  code qui s'aligne sur la spec, dans le chantier B.

---

## 6. Séquence de travail recommandée

| Étape | Chantier | Pré-requis bloquant | Livrable |
|---|---|---|---|
| 1 | A | Dump SQL rafraîchi (D-1.a déjà instruite, cf. §2.1bis) | Patch RPC conversion + `handleEmprestimoV2` + `dispatch.ts` |
| 2 | B | Inventaire des 54 + chaînes `register` croisé `mail-strings.ts` | `team.ts` et `register` entièrement i18n |
| 3 | C | Confirmer la colonne `logo_url` au schéma | Résolution logo par contexte |
| 4 | D | `reservas.ts` + couche `data/reservas.ts` | Mails de statut de réservation informatifs ; `res.converted` refondu et daté |
| 5 | E | TM-A / TM-D tranchés en B ; règle de repli logo fixée en C | Lot de cohérence soldé |

Chaque étape se clôt selon ses critères de clôture propres, avec commit et push
après `npm run build` vert. Aucune étape n'ouvre la suivante avant d'être close
— préférence constante du projet pour la fermeture des fils plutôt que leur
accumulation.

---

## 7. Doctrine transversale aux 5 chantiers

Rappel des règles du projet qui s'appliquent à l'ensemble du programme :

- **Pipeline de migration.** Jamais de SQL collé dans le SQL Editor avant push.
  Jamais d'`apply_migration` via MCP Supabase. Fichier de migration horodaté
  postérieurement à la dernière migration appliquée, push, Woodpecker applique.
- **Déploiement des EF.** `notify-event` (20+ fichiers, ~150 Ko bundlé) ne se
  déploie pas par l'outil MCP (limite de taille de l'API). Méthode :
  `supabase functions deploy <name> --no-verify-jwt` en CLI depuis `anarbib-app`.
- **Quality gate.** `npm run build` vert avant tout `git push`. `git push`
  pousse sur Codeberg (déploiement) et GitHub (miroir).
- **Sécurité.** Aucune action de durcissement sans dump SQL courant. Bloc `DO`
  de vérification en fin de transaction pour toute migration touchant
  permissions, policies ou triggers. Forme `REVOKE` complète pour toute fonction
  privée créée.
- **Fichiers Windows.** Lecture UTF-8 sûre via `[System.IO.File]::ReadAllText`.
  Scripts `.ps1` sauvegardés en UTF-8 *avec* BOM, ou exécutés sous `pwsh`.
  Jamais `ConvertFrom-Json` pour patcher du JSON à séquences échappées.
- **Discipline de session.** Commit dès qu'un sous-paquet fonctionne ; jamais de
  pause sans `git add` + `git commit`. Lecture intégrale d'un fichier avant tout
  remplacement complet. Un changement à la fois pour les hotfix.
- **Infra.** Un message Woodpecker « could not load config from forge: context
  deadline exceeded » est une panne d'infra Codeberg, jamais un défaut de code :
  vérifier `status.codeberg.org` avant tout autre diagnostic, et attendre.
- **Test.** Validation des correctifs en navigation privée, fixtures BLMF
  (Xavier coordenador, Lívia lectrice).

---

## 8. Tableau de suivi des constats

État de prise en charge des 15 constats de l'audit #153 :

| Constat | Sévérité (audit) | Chantier | Décision liée | État (27/05/2026) |
|---|---|---|---|---|
| TR-1 | Faible | A | — | ✅ traité (25/05) |
| TR-2 | À qualifier | A | D-1 | ✅ traité (25/05) |
| TR-3 | Moyenne | D | — | ✅ traité (27/05, D-1 et D-2) |
| TR-4 | Moyenne | B | — | 🟠 ouvert |
| TR-5 | Faible | E | — | ✅ traité (26/05) |
| TR-6.1 | Moyenne (composante) | E | — | ✅ traité (27/05) |
| TR-6.2b | Moyenne, doctrinale | C | — | ✅ traité (27/05) |
| TR-6.3 | Moyenne (composante) | E | — | ✅ traité (27/05) |
| TR-8 | À qualifier | A | D-2 | ✅ traité (25/05) |
| TM-A | Moyenne | B | D-0 ; amendement spec (acté) | 🟠 ouvert |
| TM-B | Moyenne-haute | B | — | 🟠 ouvert |
| TM-C | Faible | B | — | 🟠 ouvert |
| TM-D | Faible | B | D-0 ; code à aligner sur la spec | 🟠 ouvert |
| NW-A | Faible | E | — | ✅ traité (27/05) |
| NW-B | Moyenne | E | — | ✅ traité (26/05) |
| NW-C | Faible — à confirmer | E | — | ✅ traité (27/05, invariant confirmé) |
| LP-C | Faible | E | — | ✅ traité (27/05, requalifié et corrigé) |

---

## 9. Non-constats — aucun chantier (rappel pour mémoire)

L'audit a établi 6 points qui ne donnent lieu à aucune correction. Ils sont
rappelés ici pour qu'aucune session future ne les rouvre par erreur :

- **LP-A** — doublon B.7 lecteur·rice + staff sur `circulation_mode` :
  **volontaire et assumé**, doctrine confirmée justifiée le 24/05.
- **LP-B** — usage d'`actionBox` dans `library_profile.ts` : **référence
  correcte**, contrat `{kind, title, ctaUrl, ctaLabel}` respecté.
- **TR-6.2a** — logo réseau AnarBib en dur : **solution robuste validée** (objet
  unique et invariant).
- **TR-7** — épisode de spam Gmail : **warm-up normal** d'un domaine d'envoi
  neuf, pas un défaut. Check-list d'hygiène DNS (SPF/DKIM/DMARC) fournie en §9.3
  de l'audit — relève de la configuration, hors code.
- **TR-9** — couche i18n supposée restée à 6 langues : **infirmé**,
  `mail-strings.ts` est bien en 8 langues (385 clés × 8 locales).
- **Revue i18n** — couverture des 8 locales de `mail-strings.ts` : **complète**.

---

## 10. Ce que ce dossier n'engage pas

- Aucune écriture de code, aucune migration, aucun déploiement n'est engagé par
  le présent document. Il **ouvre et cadre** ; les 5 chantiers restent à exécuter
  en sessions dédiées.
- Les pistes de correction des fiches §4 sont **indicatives** : la solution
  technique exacte se fixe en session, à la lecture du code réellement déployé.
- Les décisions D-0, D-1 et D-2 (§2) sont, elles, **actées** : D-0 fixe la règle
  de traitement unique des objets partagés entre chantiers ; D-1 et D-2
  tranchent ce que l'audit laissait « à qualifier » et conditionnent le chantier
  A. La dette D-1.a a été instruite et close le 24/05 (cf. §2.1bis) ; la dette
  D-2.a reste à instruire en session du chantier A.
- TM-A est **acté** : il sera traité par amendement de `spec-gouvernance-roles.md`
  en version v1.3 (le réseau entérine la notification de la coordination au seuil
  J-7, avec escalade aux administrateur·rices du réseau si la personne inactive
  est le·la dernier·e coordenador·a). Le diff section par section est consigné
  dans le document préparatoire dédié,
  `AMENDEMENT_TM-A_spec-gouvernance-roles_2026-05-24.md`. C'est une dette
  documentaire à solder dans le chantier B ; une part peut basculer en correction
  de code si le handler `team.ts` ne gère pas déjà le cas « dernier·e coord ».
- TM-D est **clarifié** : la spec nomme déjà correctement `team.inactive_auto` ;
  c'est le code qui diverge. L'alignement se fait dans le sens code → spec, dans
  le chantier B.

---

## 11. Bilan de clôture (27 mai 2026)

**État global.** Quatre des cinq chantiers du méga-item #153 sont bouclés : A
(25/05), C, D et E (27/05). Treize des quinze constats de l'audit sont traités.
Le chantier B (i18n des mails internes — TR-4, TM-A, TM-B, TM-C, TM-D) reste
ouvert dans son intégralité. Deux détails de finition, identifiés en cours de
chantier, sont à traiter hors du périmètre strict de B.

### 11.1 — Séquence d'exécution réelle

L'ordre théorique 1→5 du §6 n'a pas été suivi à la lettre. Les sessions ont
exécuté A, puis E partiellement (constats NW-B et TR-5 traités en première
passe pour limiter la visibilité du défaut), puis C et D en parallèle, et enfin
le reste de E (TR-6.1, TR-6.3, NW-A, NW-C, LP-C) en clôture. L'ordre d'exécution
réel a été : A → NW-B → TR-5 → C → D-1 → D-2 → TR-6.x sur les EF concernées →
NW-A → NW-C → LP-C. La règle de repli logo fixée par C a bien précédé son
application par E (TR-6.1), comme prévu §6. Aucune dépendance bloquante n'a
été contredite par cet ordre.

### 11.2 — Détails de chantier C

Bouclé le 27/05 en deux gestes. Côté base, une migration ajoute la colonne
`libraries.logo_url` ; elle est alimentée par bibliothèque depuis son contexte.
Côté Edge Function, `register` lit désormais ce `logo_url` depuis la base au
lieu de la table en dur, et le restitue dans le rendu des mails. Le logo réseau
AnarBib reste légitimement codé en dur (URL Supabase Storage du paquet 25.10).
Test en production confirmé sur BLMF : le mail affiche le logo résolu depuis la
base. La dette ouverte du §4.C (« renseigner `logo_url` pour toute biblio
créée par la suite ») est désormais matérialisée par la colonne et reste
ouverte comme procédure d'onboarding.

### 11.3 — Détails de chantier D

Bouclé le 27/05 en deux volets séquencés. D-1 : corrections de données.
Le motif d'annulation est porté par `final_reason = 'cancelled_by_library'`
sur `reserva_item_workflow_v2`, pas par le stage transitoire ; la fonction
helper a été corrigée en conséquence. La date d'échéance de l'emprunt est
ajoutée au mail `res.converted` (lecteur·rice comme staff). D-2 : refonte
du wording. Les quatre clés plates `res.cancelStaff` / `cancelReader` /
`expired` / `converted` deviennent des familles structurées `.sub` / `.intro` /
`.adminIntro` — douze clés neuves au total, écrites sur les huit locales en
registre chaleureux et inclusif, lecteur·rice et staff différenciés.
Test en production confirmé. **Détail à traiter** : la clé `res.refused` et
la branche `reserva_v2_recusada` du dispatcher sont du code mort (l'UI n'émet
plus que `reserva_cancelada_biblioteca`). Voir §11.5.

### 11.4 — Détails de chantier E

Clos sur le volet code le 27/05. Les sept constats ont été traités dans l'ordre
suivant :

- **NW-B.** Clé i18n `l.executed_at` ajoutée sur les huit locales ; les mails
  de retrait collectif exécuté n'affichent plus de texte technique.
- **TR-5.** Sujets en dur `[AnarBib]` remplacés par `[${BRAND_NAME}]` dans
  `notify-library-request`.
- **TR-6.1 et TR-6.3.** Examen de toutes les Edge Functions du périmètre logo.
  Corrections appliquées sur `notify-network-weekly-report` (cascade
  complétée), `notify-document-permission-request` (cascade + repli texte),
  `notify-mid-loan-reading` (cascade ; repli déjà correct par construction),
  `notify-weekly-report` (import mort `LOGO_URL` retiré). `register` et
  `notify-internal-task` examinées et jugées conformes ; `notify-event` hors
  périmètre logo direct.
- **NW-A.** Commentaire correctif dans `network.ts` : les clés
  `network.vote.favorable` / `opposed` sont des libellés génériques de vote
  du réseau, volontairement partagés entre cooptation et retrait collectif —
  pas un emprunt de fortune. Pas de duplication 8 langues, mutualisation
  assumée et désormais documentée.
- **NW-C.** Invariant de timing du `SELECT count(*)` documenté en commentaire :
  l'INSERT du vote précède l'émission de l'événement dans la même transaction
  de la RPC `fn_*_collective_removal_vote`, la PK (proposal_id, voter_user_id)
  garantit l'unicité. `isFirstVote = voteCount === 1` est donc fiable par
  construction.
- **LP-C.** Le constat tel que formulé par l'audit (« le fan-out vide marque
  `sent` ») s'est révélé inexact à la lecture du code : `team_notification_outbox`
  est bien marquée à l'issue du traitement par `handleTeamEvent` /
  `handleNetworkEvent` — mais le marquage `sent` était appliqué *aussi* aux
  cas où aucun mail ne part (fan-out vide, event non reconnu). Le constat a été
  **requalifié** sur le code réel, puis corrigé. Migration ajoutant le statut
  `'skipped'` au CHECK de `team_notification_outbox`, alignée sur la convention
  déjà en place pour les outbox de tâches. Helper `markOutboxSkipped` ajouté
  dans `team.ts` et `network.ts`, choix `sent` / `skipped` selon
  `recipients_count` et selon la branche événement reconnu / non reconnu.
  Bilan : la table d'audit cesse de prétendre qu'un mail est parti là où
  aucun ne l'est. Cas méthodologique notable : sans lecture directe du code
  réel, la correction aurait été fausse.

### 11.5 — Deux détails à régler hors périmètre B

Deux constats identifiés en cours de chantier et hors périmètre de B restent
à traiter pour clore intégralement le programme #153 :

1. **Code mort `reserva_v2_recusada` / `res.refused`.** Identifié en #153.D.
   L'événement `reserva_v2_recusada` n'est plus émis par la base (l'UI
   n'expose plus que `reserva_cancelada_biblioteca` via la RPC). La branche
   correspondante dans `dispatch.ts` (`handleReservaV2StatusChange`) et la clé
   `res.refused` dans `mail-strings.ts` (sur les huit locales) sont du code
   mort à retirer. Action courte : `dispatch.ts` (retrait du nom dans le
   tableau `[...].includes(event)`), `reservas.ts` (retrait de la branche),
   `mail-strings.ts` (suppression de la clé sur les huit locales). À vérifier
   après par recherche d'occurrences résiduelles.

2. **Dé-duplication de `_shared/` dans `notify-internal-task`.** Identifié en
   #153.E. L'EF embarque une copie autonome du répertoire `_shared/`,
   aujourd'hui alignée sur la version centrale, mais la divergence future est
   garantie sans surveillance. La résorption au profit du module partagé peut
   être rattachée à #154 (robustesse de la même EF) ou traitée en session
   propre. Travail non trivial : il faut vérifier que la copie n'embarque
   aucun fragment légitimement spécifique avant de la supprimer.

Ces deux détails seront traités à part. Tant qu'ils ne sont pas réglés,
#153.E reste « clos sur le code » sans être *intégralement* clos.

### 11.6 — Acquis méthodologique

L'épisode LP-C — fiche d'audit décrivant un comportement erroné, requalification
sur lecture du code réel, correction juste — confirme une discipline déjà à
l'œuvre dans le projet : **on ne corrige pas sur la foi d'une fiche, on lit le
code que la fiche décrit, et on requalifie si nécessaire**. Cette discipline a
également joué sur D-1 (le motif d'annulation porté par `final_reason`, pas par
le stage transitoire). Elle reste à observer pour le chantier B et pour les deux
détails de §11.5.

---

*Dossier-cadre d'ouverture — corrections post-audit #153. Document de travail
interne AnarBib. À verser dans `docs/decisions/`. Distribué sous licence
CC-BY-SA-4.0.*
