# DECISION — Arbitrages backlog v21 et GLB v17

**Date** : 29 mai 2026
**Type** : Décision / arbitrages rendus
**Statut** : Acté, à appliquer au backlog v21
**Origine** : Section F du backlog v21 (5 arbitrages techniques) + section IV.4 du GLB v17 (5 arbitrages stratégiques)

---

## Préambule

Le backlog v21 du 29/05/2026 a inscrit cinq points techniques à arbitrer en section F, et le Grand Livre blanc v17 a inscrit cinq points stratégiques en section IV.4. Ces dix points ont été rendus le 29/05 après-midi. La présente note les consolide pour traçabilité et inscrit les actions à reporter au backlog actif.

Les arbitrages techniques touchent la mise en ordre du tableau (fusions, déplacements, dépendances explicites). Les arbitrages stratégiques touchent le séquencement du temps de travail (quel chantier prioriser, quand bascule-t-on, etc.).

---

## I. Cinq arbitrages techniques (section F du backlog v21)

### I.1 — F.1 : `#157` fusionné dans `#CL.2`

**Question.** `#157` (« gestion de réservation côté conta : lecteur·rice ne peut gérer sa réservation », inscrit comme bug, score 8) et `#CL.2` (« réservations lecteur suivies de bout en bout », Cahier Dunkerque, très haute priorité) couvrent-ils le même périmètre ?

**Décision.** **Fusion.** `#157` est versé dans `#CL.2` comme tâche concrète à traiter dans le cadre du méga-item compte lecteur.

**Justification.** Périmètre fonctionnel identique — `#157` est la formulation bug, `#CL.2` est la formulation produit cible. Maintenir les deux distincts risquait de livrer la feature sans corriger le bug, ou inversement de corriger le bug sans le penser dans la cohérence d'ensemble du parcours lecteur.

**Action.** Dans la prochaine itération du backlog : `#157` disparaît du tableau actif, la fiche `#CL.2` mentionne explicitement « (absorbe #157) ».

### I.2 — F.2 : `#155` et `#TASKS-invitation-groupée` restent distincts, dépendance ordonnée

**Question.** Les deux items touchent le domaine de l'invitation aux tâches internes. Sont-ils le même travail ou deux travaux connexes ?

**Décision.** **Deux items distincts, avec dépendance d'ordre.** `#TASKS-invitation-groupée` ne démarre pas avant que `#155` ait confirmé la chaîne de bout en bout.

**Justification.** Vérification factuelle dans les backlogs v15 à v17 : `#155` est un audit de l'existant (« notify-internal-task gère bien une branche `task_invitation`. Reste à confirmer le déclencheur en amont : écran de saisie dans Painel, table d'invitations, webhook Postgres. À vérifier de bout en bout »), tandis que `#TASKS-invitation-groupée` est une évolution fonctionnelle nouvelle (« aujourd'hui, le coordinateur peut inviter une camarade par e-mail à participer à une tâche, mais tâche par tâche uniquement ; le besoin remonté est de pouvoir solliciter l'équipe de façon groupée »). On ne construit pas une fonctionnalité groupée sur un chaînage individuel non vérifié.

**Action.** Réintroduire la dépendance explicite dans le tableau (le v21 l'avait perdue en regroupant les deux dans `#HYG`). Fiche `#TASKS-invitation-groupée` : « dépend de `#155` ».

### I.3 — F.3 : `#79` maintenu distinct de `#BG4`

**Question.** `#79` (« RBAC catalogage : 8 fonctions sans garde », 2-3h, précis) est-il absorbé par `#BG4` (« durcissement RLS / advisors Supabase », 13-22 jours, global) ?

**Décision.** **Séparation maintenue.** `#79` reste dans `#CATALOG-EXT` ; `#BG4` reste dans `#BG-PREP`.

**Justification.** `#79` est précis, court, à fort enjeu fonctionnel (catalogage). `#BG4` est global, long, à fort enjeu sécuritaire transverse. Les absorber l'un dans l'autre faisait perdre la précision de `#79` au profit de la généralité de `#BG4` — risque d'oubli avéré.

**Action.** Aucune modification du v21 sur ce point ; la séparation actuelle est confirmée.

### I.4 — F.4 : `#ACCOUNT-migration` maintenu dans `#CL`

**Question.** `#ACCOUNT-migration` (validation physique + migration de compte, deux specs paire) a-t-il sa place dans `#CL` ou mérite-t-il d'être promu macro-chantier distinct ?

**Décision.** **Maintien dans `#CL`.** Pas de promotion en macro-chantier distinct pour l'instant.

**Justification.** L'item touche au compte lecteur, qui est exactement le domaine de `#CL`. Le promouvoir séparément aurait fragmenté le projecteur stratégique du Cahier Dunkerque. Si à l'avenir le chantier devient effectivement structurel (plusieurs sessions, dépendances transverses qui s'accumulent), la promotion sera reconsidérée.

**Action.** Aucune modification du v21 sur ce point.

### I.5 — F.5 : `#156` versé dans `#BIBLIO` étape 10

**Question.** `#156` (« library_contact_profiles : RLS d'écriture présente mais aucun éditeur frontend ») recoupe-t-il l'étape 10 de `#BIBLIO` (« câblage frontend des échanges ») ?

**Décision.** **Versement.** `#156` rejoint `#BIBLIO` étape 10 comme sous-ticket explicite.

**Justification.** Cohérence thématique forte (échanges = communication = contact_profiles). L'étape 10 de `#BIBLIO` était encore vague ; `#156` lui donne du contenu concret. Effet de bord positif : l'étape 10 ne reste plus une étape abstraite « câblage frontend des échanges » mais devient « ajouter l'éditeur frontend manquant pour library_contact_profiles ».

**Action.** Fiche `#BIBLIO` étape 10 : ajouter « absorbe `#156` ». `#156` disparaît du cluster `#HYG`.

---

## II. Cinq arbitrages stratégiques (section IV.4 du GLB v17)

### II.1 — Continuer la séquence 2 (clôture `#PAINEL`)

**Question.** Maintenir le rythme `#PAINEL` jusqu'à clôture, ou basculer sur la séquence 3 (jonction frontend profils d'adoption) ?

**Décision.** **Continuer `#PAINEL`.**

**Justification.** Reste peu (E.3, E.4, E.5, EA-01, trois cosmétiques EA-03/EA-11/EA-14, `#PN-2`). L'élan du chantier-cadre Painel est en place depuis le 26/05, basculer à 80 % d'avancement pour démarrer un autre chantier-cadre ferait perdre l'inertie et probablement la clôture symbolique du second chantier-cadre dans les délais raisonnables. Finir avant de commencer le suivant : c'est exactement ce que la doctrine de jonction inscrit (v14 chapitre 9).

**Action.** Prochaines sessions : poursuivre `#PAINEL`. Cible de clôture complète : autour du 5 juin 2026 (en coïncidence approximative avec la fin du blocage de `#BIBLIO` étape 8 par `#110` R.6).

### II.2 — `#36` (activation CIRA Marseille) reste en attente

**Question.** Activer la première biblio tierce dès maintenant ou attendre la jonction frontend profils d'adoption ?

**Décision.** **Attendre.**

**Justification.** Deux raisons convergentes. (1) Doctrine v14 (Précision 1) : aucune fermeture déclarée sans audit frontend. Le frontend des profils d'adoption ignore encore les RPC produites par le chantier `#98`. Activer une biblio tierce sur cette base, c'est l'exposer à une expérience dégradée. (2) Signal de terrain : pas de relance ou de signal d'engagement actif de la part de CIRA Marseille à ce stade ; rien ne presse côté usager·es. Le ratio coût/bénéfice de l'activation immédiate n'est pas favorable.

**Action.** Maintenir `#36` au statut « PRÊT, à activer après jonction frontend profils ». La séquence 3 (jonction frontend) reste le prérequis politique avant activation tierce.

### II.3 — `v_active_memberships` : refactor en RPC `fn_get_my_active_membership`

**Question.** Pour résoudre l'unique ERROR des advisors Supabase, faut-il wrapper la vue en api INVOKER ou abandonner la vue au profit d'une RPC SECURITY DEFINER ?

**Décision.** **RPC.** Création d'une RPC `fn_get_my_active_membership` en SECURITY DEFINER avec contrôle d'identité explicite. Abandon de la vue.

**Justification.** La vue n'est pas une lecture simple — c'est un agrégat avec sémantique implicite, qui sort du périmètre où la doctrine RPC v3 nuancée autorise l'accès direct. Une RPC explicite rend la sémantique lisible et auditable. Le coût en refactoring frontend (4-5 sites d'appel à mettre à jour) est borné, et profite de l'occasion pour homogénéiser le pattern d'accès au membership de l'utilisateur·rice connecté·e.

**Action.** Inscrire dans le cluster `#BG-PREP` / `#DETTE-STRICTE-1` comme item décidé. Méthode : (a) écrire `api.fn_get_my_active_membership()` en SECURITY DEFINER REVOKE-é selon doctrine v2, (b) recenser les sites d'appel frontend de `v_active_memberships`, (c) basculer en un seul commit, (d) supprimer la vue, (e) DO-block de vérif.

### II.4 — `#153` détails de finition fusionnés avec `#154`

**Question.** Les deux détails de finition de `#153` (code mort `res.refused`, dé-duplication `notify-internal-task _shared/`) sont-ils traités en session dédiée ou fusionnés avec `#154` (robustesse de la même Edge Function) ?

**Décision.** **Fusion.** Les deux détails de finition rejoignent `#154`.

**Justification.** Ce sont littéralement les mêmes fichiers que `#154`. Scinder en deux sessions perd plus de temps qu'il n'en gagne en lisibilité d'historique. La cohérence thématique (robustesse de `notify-internal-task`) prime sur la traçabilité administrative des chantiers `#153.X`.

**Action.** `#154` voit sa fiche enrichie de deux sous-tâches explicites : (1) retirer le code mort `res.refused`, (2) dé-dupliquer `notify-internal-task _shared/`. Les deux items résiduels de `#153.E` disparaissent du tableau actif et sont mentionnés dans la section E « Acquis » comme « fusionnés dans `#154` ».

### II.5 — Pas de Livre blanc avant mi- ou fin juillet 2026

**Question.** Maintenir la cadence Livre blanc (v14 → v17 en dix jours) ou poser un palier ?

**Décision.** **Palier.** Aucun nouveau Livre blanc avant mi- ou fin juillet 2026.

**Justification.** La cadence rapide était cohérente tant qu'à chaque version correspondait un acquis doctrinal nouveau. Aujourd'hui, les acquis sont stabilisés (six doctrines inscrites, méthode parité+audit éprouvée), et la suite du travail relève de l'exécution, pas de la doctrine. Produire un v18 sans contenu doctrinal nouveau diluerait la valeur des précédents. Reprise du GLB seulement à clôture complète du chantier-cadre Importações, horizon fin juillet 2026.

**Action.** Tenir le palier. Si en juin une décision doctrinale majeure émerge (par exemple sur `#MODEL-item-grain` ou sur `#RESEAU-FED`), une décision pourra être documentée dans `decisions/` sans déclencher un nouveau Livre blanc — la cadence des doctrines et la cadence des Livres blancs sont désormais découplées.

---

## III. Récapitulatif des actions à appliquer au backlog

Au moment de la prochaine itération du backlog (qui ne sera pas un v22 séparé mais une mise à jour incrémentale du v21), reporter les modifications suivantes :

| Action | Détail |
|---|---|
| Fusion | `#157` → `#CL.2` (mention « absorbe #157 ») |
| Dépendance ordonnée | `#TASKS-invitation-groupée` dépend de `#155` |
| Confirmation | `#79` reste distinct de `#BG4` |
| Confirmation | `#ACCOUNT-migration` reste dans `#CL` |
| Versement | `#156` → `#BIBLIO` étape 10 (mention « absorbe #156 ») |
| Décision technique | `v_active_memberships` → RPC `fn_get_my_active_membership` (item `#DETTE-STR-1` reformulé) |
| Fusion | Détails de finition `#153.E` (`res.refused`, dé-duplication `_shared/`) → `#154` |

## IV. Récapitulatif des principes de séquencement confirmés

| Principe | Conséquence pratique |
|---|---|
| Finir `#PAINEL` avant `#98` | Prochaines sessions sur E.3, E.4, E.5, EA-01, cosmétiques et `#PN-2`. Cible clôture autour du 5 juin 2026. |
| `#36` reste en attente | Activation CIRA Marseille conditionnée à la jonction frontend profils. |
| Palier Livre blanc | Pas de v18 avant mi/fin juillet 2026. Décisions doctrinales intermédiaires possibles dans `decisions/` sans nouvelle version du GLB. |

---

*Fin de la note. Les dix points sont actés. Le backlog actif tient compte de ces décisions à compter de cette date. Aucun arbitrage n'est laissé en suspens.*
