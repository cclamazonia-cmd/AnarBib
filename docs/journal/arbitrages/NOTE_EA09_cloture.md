# EA-09 — Système de toast non-bloquant — CLÔTURÉ

**Chantier** : A — Lisibilité immédiate (audit systématique Painel, 26/05/2026)
**Écart traité** : EA-09 — feedback d'erreur via `alert()` brut du navigateur
**Statut** : livré et validé en production le 26/05/2026
**Nature** : frontend pur — aucune migration, aucune touche à la base

---

## Problème d'origine

Six points du Painel signalaient leurs erreurs via la boîte `alert()` native
du navigateur, en y injectant le message technique brut renvoyé par Supabase.
Trois défauts : canal bloquant et hors charte visuelle, message technique
incompréhensible pour une personne non informaticienne, aucune cohérence avec
le reste de l'interface.

## Solution livrée

Un système de notification (« toast ») global, fondé sur un Context React et
appelable depuis n'importe quel composant via le hook `useToast()`.

Comportement, conforme aux décisions de cadrage :
- succès → disparition automatique après 5 s ;
- erreur → persistant, ne disparaît qu'au clic de fermeture (au comptoir, une
  erreur ne doit pas pouvoir se rater) ;
- le message technique brut n'est jamais affiché : il part en `console.error`
  préfixé `[AnarBib]`. L'écran ne montre qu'un message humain traduit.

Les 6 `alert()` du Painel ont été remplacés par des appels `notifyError()`
porteurs d'un message humain spécifique à l'action (retour d'emprunt, étape de
consultation, statut de tâche).

## Fichiers

Nouveaux : `src/contexts/ToastContext.jsx` (Provider + hook `useToast()`),
`src/components/ui/ToastViewport.jsx` (affichage visuel).

Modifiés : `src/App.jsx` (`<ToastProvider>` placé dans l'arbre, entre
`IdleTimerGuard` et `ThemeGate`), `src/components/ui/ui.css` (bloc `.ab-toast*`),
`src/pages/painel/PanelPage.jsx` (hook appelé dans `PanelPage` et dans le
sous-composant `TaskBucket`, 6 `alert()` remplacés).

i18n : 3 clés ajoutées aux 8 locales — `panel.error.loanReturn`,
`panel.error.consultaWorkflow`, `panel.error.taskStatus` (2953 → 2956 clés).

Commit : `feat(ui): systeme de toast non-bloquant + remplacement des 6 alert()
du Painel (EA-09)`. Pipeline Woodpecker vert.

## Validation en production

Testé sur `app.anarbib.org` en provoquant une erreur réelle (changement de
statut de tâche interne avec le réseau coupé via les DevTools, depuis l'onglet
Trabalho do dia). Résultat conforme : toast rouge en bas à droite, message
humain en français, persistant jusqu'au clic de fermeture. Le déclenchement
depuis Trabalho do dia valide en particulier le fonctionnement de `useToast()`
dans le sous-composant `TaskBucket`, point d'architecture le plus délicat du
lot.

## Portée et limite

Ce lot ne câble que les toasts d'**erreur** : les 6 `alert()` remplacés étaient
tous des blocs `catch`. Le toast de **succès** existe dans le code (`notifySuccess`)
mais n'est encore appelé nulle part — son emploi viendra dans un lot ultérieur.

Le test en production a par ailleurs confirmé, en creux, la nécessité de
l'écart **EA-05** : une erreur de transition de réservation a affiché un
message technique brut (« cible retirada_a_combinar requiert
p_options->>'pickup_scheduled_for' ») qui ne passe **pas** par les 6 `alert()`
traités ici, mais par un canal de message propre à l'onglet Réservations,
alimenté par le backend. EA-05 devra donc traiter ce canal distinct, côté
backend comme décidé lors du cadrage du chantier A.

## Apport pour la suite

Le système de toast est désormais la brique de feedback réutilisable du
projet. EA-05 s'appuiera dessus pour afficher les messages d'erreur de
transition reformulés ; il pourra de même servir à l'espace lecteur et aux
autres pages, au bénéfice de la cohérence d'ensemble visée pour la rencontre
de Bologna.
