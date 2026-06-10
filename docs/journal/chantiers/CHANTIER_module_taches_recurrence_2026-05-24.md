# Chantier #TASKS — Module des tâches de la bibliothèque

**Document de bilan de chantier**
**AnarBib — système intégré de gestion de bibliothèque**
Clôture : 24 mai 2026
Référence du dossier d'ouverture : *Dossier d'ouverture de chantier — Module des tâches de la bibliothèque*, v0.1, 23 mai 2026.

---

## 1. Objet et état final

Le chantier #TASKS approfondissait le module des tâches internes de la bibliothèque — l'onglet « Tarefas internas ». Le dossier d'ouverture du 23 mai partait d'un constat : l'assignation de tâches ponctuelles existait déjà et fonctionnait en production, mais le module ignorait la **récurrence**, ne proposait pas de **tâches-types**, et n'offrait qu'une liste à plat sans **vue par échéance**. Le chantier visait à combler ces trois manques sans refondre l'existant.

À la clôture, les six étapes prévues sont livrées et en production, ainsi qu'une étape supplémentaire non prévue au dossier (l'étape 3-bis, voir §3). Deux bugs du Painel, mis au jour pendant le chantier, ont été corrigés dans la foulée. Le module couvre désormais les tâches ponctuelles et récurrentes, les tâches-types locales, le catalogue de suggestions et la vue par échéance, dans les huit langues du projet.

---

## 2. Ce qui a été réalisé, étape par étape

Le découpage en étapes du dossier d'ouverture a été suivi. Les étapes 1 à 5 et l'étape 3-bis relèvent du backend ; l'étape 6 est le travail frontend.

**Étape 1 — Analyse et conception de la récurrence.** Inventaire complet de l'existant (tables, fonctions serveur, déclencheurs, politiques d'accès) avant toute production, conformément à la méthode du projet. Conception du modèle de récurrence et arbitrage des points doctrinaux laissés ouverts par le dossier (voir §4).

**Étape 2 — Schéma de la récurrence.** Migration livrée en fichier horodaté versionné, appliquée par l'intégration continue. Introduction de la table `painel_recurring_task_rules` (les tâches-types, porteuses de la cadence) et des colonnes de récurrence sur `painel_internal_tasks` (`recurrence_rule_id`, `recurrence_stale_flagged_at`). La cadence est décrite par un couple `interval_count` + `interval_unit` (jour / semaine / mois), avec une contrainte de cohérence : les deux champs sont renseignés ensemble ou nuls ensemble.

**Étape 3 — Logique de récurrence.** Fonctions serveur de création récurrente et de régénération d'occurrence, en `SECURITY INVOKER`. À l'achèvement d'une tâche récurrente, l'occurrence suivante est régénérée automatiquement.

**Étape 3-bis — Étape née en cours de chantier.** Voir §3 : le verrou rencontré sur les types d'événements de notification a imposé une étape backend non prévue.

**Étape 4 — Tâches-types locales.** Chaque bibliothèque crée et gère ses propres modèles de tâches, ponctuels ou récurrents, instanciables en une tâche concrète en un geste. Fonctions `fn_recurring_task_rule_create` / `_update` / `_delete` et `fn_task_instantiate_template`.

**Étape 5 — Catalogue de suggestions.** Banque d'idées de tâches bibliothéconomiques courantes, non imposée : la table `painel_task_suggestion_catalog` réunit quinze suggestions réparties en sept catégories (entretien des documents, rangement des collections, gestion de la collection, entretien des espaces, nouveaux documents, vie collective, administratif). Une bibliothèque peut adopter une suggestion, ce qui la copie comme modèle local éditable ; rien n'est pré-coché ni obligatoire.

**Étape 6 — Interface et vues.** Approfondissement de l'onglet « Tarefas internas » en trois sous-onglets — Liste (vue par échéance avec mise en évidence des tâches récurrentes en retard, et invitation de camarades par e-mail), Modèles, Catalogue. Internationalisation dans les huit langues du projet. À noter : l'étape 6 portait sur l'onglet « Tarefas internas » de la **page Bibliothèque** et non du Painel — le dossier d'ouverture situait le module dans le Painel, mais le câblage des tâches avait en réalité été porté sur la page Bibliothèque lors d'un chantier antérieur. Le travail a suivi le code réel.

**Correctifs Painel.** Deux changements de statut de tâche, dans le Painel, court-circuitaient la fonction `fn_task_update_status` par une écriture directe en base. Ils sont désormais routés par la fonction. Sans ce correctif, terminer une tâche récurrente depuis le Painel ne déclenchait pas la régénération de l'occurrence suivante.

---

## 3. Naissance de l'étape 3-bis

Le dossier d'ouverture prévoyait six étapes. Une septième, l'étape 3-bis, est née en cours de chantier et mérite d'être actée comme telle.

En implémentant la logique de récurrence (étape 3), le chantier a rencontré un verrou : les types d'événements de notification (`event_kind`) constituaient un ensemble fermé, qui ne prévoyait pas les événements propres à la récurrence. Étendre la logique de récurrence sans toucher à cet ensemble était impossible. L'étape 3-bis a donc été ouverte pour traiter spécifiquement ce point côté backend, avant de pouvoir achever l'étape 3. Cette étape n'était pas prévisible à l'ouverture : elle relève exactement du principe, posé dans la méthode du projet, selon lequel chaque étape commence par sa propre analyse et peut être ajustée.

---

## 4. Décisions prises en cours de chantier

Le dossier d'ouverture laissait trois points explicitement ouverts, à trancher en cours de chantier. Ils l'ont été.

**Modèle de récurrence — intervalle simple.** Le dossier hésitait entre intervalle fixe simple, calendrier et règle souple. Le chantier a retenu l'**intervalle fixe simple** : un couple nombre + unité (« tous les 3 mois »). C'est le modèle le plus lisible pour des personnes non spécialistes, et il couvre la quasi-totalité des besoins d'entretien réels. Une règle calendaire complète aurait été une sur-ingénierie au regard de l'usage.

**Mécanique de régénération — à l'achèvement.** Le dossier hésitait entre régénération à date fixe et régénération à l'achèvement de la précédente. Le chantier a retenu la régénération **à l'achèvement** : l'échéance de l'occurrence suivante est calculée à partir de la date d'achèvement de la précédente, plus l'intervalle. Ce choix respecte le rythme réel du collectif plutôt que d'imposer un calendrier abstrait : si une tâche trimestrielle est faite avec deux semaines de retard, le cycle suivant repart de la date réelle, sans accumuler une dette de retard fictive.

**Assignation — volontaire, pas attribuée.** Le dossier signalait un point doctrinal : l'assignation nominative peut porter une logique de responsabilisation individuelle descendante, étrangère à la doctrine du projet. Le chantier a confirmé la **piste de l'assignation volontaire** : l'invitation est une sollicitation, pas une attribution imposée. L'évolution « invitation groupée » (inviter une personne sur plusieurs tâches, ou signaler à l'équipe les tâches sans responsable) a été identifiée comme un raffinement utile mais hors périmètre ; elle est inscrite au backlog v16 sous l'item `#TASKS-invitation-groupée`.

**Catalogue multilingue par données.** Le texte des suggestions du catalogue (titre, description) est porté par des champs `jsonb` à huit langues, et non par le système d'internationalisation applicatif. Ce choix garde la donnée du catalogue autonome et permet de l'enrichir sans toucher au code. Il prépare aussi l'évolution future décrite au §6.

---

## 5. Réserves et points de vigilance

**Traductions catalogue à relire.** Les suggestions du catalogue sont fournies dans les huit langues du projet. Les versions catalane et espéranto sont un premier jet et méritent une relecture par des locuteurs avant d'être considérées comme définitives. Cette réserve vaut pour le contenu du catalogue, pas pour l'ossature i18n de l'interface.

**Tâches-types locales : la bonne langue.** L'adoption d'une suggestion copie son texte dans la langue de l'interface courante, avec repli sur le portugais brésilien si la clé manque. Une bibliothèque qui change de langue après adoption garde le texte figé tel qu'adopté — c'est le comportement attendu pour un modèle local, mais il faut en avoir conscience.

---

## 6. Évolution future explicitement hors périmètre

Le dossier d'ouverture inscrivait, comme horizon, le **partage des modèles entre bibliothèques du réseau** : une bibliothèque publie son protocole de défongisation, une autre son protocole anti-gel, et chacune reste libre de s'en inspirer. Cette évolution n'a pas été traitée par le chantier #TASKS et reste à mener dans un chantier ultérieur.

Un point de conception doit être acté dès maintenant pour ce futur chantier. Le catalogue de suggestions livré ici est un catalogue **interne au projet** : son texte est traduit dans les huit langues par l'équipe du projet, ce qui a un sens pour une banque d'idées maintenue centralement. Un catalogue **partagé entre bibliothèques** ne peut pas suivre ce modèle : on ne peut pas demander à une bibliothèque amazonienne de traduire son protocole de défongisation en huit langues pour le publier. Le futur catalogue partagé devra donc adopter un modèle différent — **texte libre dans la langue de son autrice**, chaque bibliothèque publiant dans sa propre langue, sans obligation de traduction. Cohérent avec la doctrine de mutualisation horizontale du projet : on partage ce qu'on a, tel qu'on l'a, sans norme imposée.

---

## 7. Conformité à la méthode

Le chantier a respecté les principes de travail du projet : analyse de l'existant avant toute production à chaque étape ; migrations livrées en fichiers horodatés versionnés et appliquées par l'intégration continue, jamais par opération directe sur la base ; séquences de déploiement découpées en blocs séparés par des points de vérification ; livrables validés par la compilation **et** les tests. Les fonctions serveur créées suivent la doctrine de création d'objets sécurisés (forme `REVOKE` puis `GRANT`, vérification par bloc `DO`).

---

*Fin du document de bilan — chantier #TASKS, module des tâches de la bibliothèque. Clôturé le 24 mai 2026.*
