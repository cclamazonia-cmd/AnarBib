# Bilan d'audit du méga-item #CL — comparatif cahier Dunkerque / JSX 30/05 / HTML d'origine

**Date** : 30/05/2026
**Auteur** : Xavier (session avec Claude)
**Contexte** : Audit déclenché par la découverte successive, le 30/05, de deux faux non-acquis — la « jonction frontend profils d'adoption » et `#CL.4`, tous deux livrés mais non reconnus par le backlog v22 et le GLB v17. La méthode parité+audit appliquée aux deux chantiers-cadres Biblioteca et Painel est ici étendue au méga-item #CL pour remettre la matière en phase avec la production.
**Méthode** : Pour chaque sous-item #CL.1 à #CL.10, croisement de trois sources — la fiche du *Cahier de chantier de la Bibliothèque de Dunkerque* (mai 2026), l'état actuel de `AccountPage.jsx` (audit du 30/05, ~2127 lignes), et l'ancêtre HTML `conta.html` (~4551 lignes) — selon la grille à trois catégories définie en amont : *réintégrer*, *volontairement retiré*, *à arbitrer*.
**Statut** : Document de référence, à committer dans `docs/decisions/`.

---

## Sommaire

- [Constat préliminaire — l'ancêtre HTML est moins riche que le JSX](#constat-préliminaire)
- [#CL.1 — Historique cliquable → fiche livre → prochaine disponibilité](#cl1)
- [#CL.2 — Réservations lecteur suivies de bout en bout](#cl2)
- [#CL.3 — Bandeau état du compte / blocages / action requise](#cl3)
- [#CL.4 — Prêts en cours avec renouvellement clair](#cl4)
- [#CL.5 — Navigation continue conta → livro → autor → index](#cl5)
- [#CL.6 — Centre d'avis / notifications dans l'interface](#cl6)
- [#CL.7 — Mes données / sécurité / bibliothèque de rattachement](#cl7)
- [#CL.8 — Maîtrise de l'historique par le lecteur](#cl8)
- [#CL.9 — Liste d'envies / guardar para depois](#cl9)
- [#CL.10 — Infos pratiques de retrait intégrées au parcours](#cl10)
- [Tableau récapitulatif](#tableau-récapitulatif)
- [Recommandation d'occupation jusqu'au 06/06](#recommandation-doccupation-jusquau-0606)
- [Conséquences pour le backlog v22 et le GLB v17](#conséquences-pour-le-backlog-v22-et-le-glb-v17)

---

## Constat préliminaire — l'ancêtre HTML est moins riche que le JSX

Avant d'entrer dans l'audit par sous-item, un constat factuel modifie l'usage prévu de la revue HTML→JSX. Le fichier `conta.html` est l'ancêtre **statique** de l'application : ses onglets (`perfil`, `reservar`, `curso`, `historico`) délimitent des panneaux dont le **contenu est rempli dynamiquement par JavaScript externe**, non visible dans l'HTML lui-même. Concrètement, la section `<section id="tab-historico">` ne contient que `<div id="history"></div>` — un container vide que le JS d'époque venait peupler. De même pour la majorité des autres sections.

**Implication pratique** : la revue HTML→JSX ne révèle pas des contenus riches « perdus en chemin ». Elle révèle surtout des structures, des chips de hero, et quelques mécaniques d'interaction. La grille à trois catégories (*réintégrer / volontairement retiré / à arbitrer*) reste pertinente, mais le volume de cas « à réintégrer » sera plus faible que prévu — l'HTML d'origine n'avait pas, par exemple, de centre d'avis, de liste d'envies, ni d'infos pratiques de retrait. Ces fonctionnalités sont des **ajouts** du chantier Dunkerque, pas des récupérations.

Cela ne change pas la valeur de l'audit : l'objectif initial — vérifier ce qui est livré et ce qui ne l'est pas — reste central, et la revue HTML→JSX permet d'écarter explicitement l'hypothèse « il manquerait du contenu d'origine ». Sur quelques points précis (chips de hero, structure du formulaire profil), des écarts apparaîtront néanmoins et seront documentés.

---

<a id="cl1"></a>
## #CL.1 — Historique cliquable → fiche livre → prochaine disponibilité

**Priorité Dunkerque** : Très haute (Sprint 1)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.1)

Transformer l'historique en outil de réemploi : le lecteur repart de ses usages passés pour revenir au catalogue vivant, vérifier la disponibilité et réserver si besoin.

**Données à afficher** : couverture miniature, titre, auteur, bibliothèque concernée, date d'emprunt, date de retour réelle, statut courant du livre (disponible / tout sorti / consultation sur place / indisponible), date de retour prévue la plus proche si tout est sorti.

**Actions** : ouvrir la fiche livre depuis une ligne d'historique, réserver depuis livro.html si réservable, revenir naturellement vers l'historique ou les prêts.

**Dépendances minimales** : surface locale par bibliothèque, champs `available_count_local`, `on_loan_count_local`, `earliest_due_back_at`, `is_reservable`, cohérence avec la règle « si la fiche est contextualisée à une bibliothèque, elle n'affiche que les informations locales ».

### État actuel du JSX

L'onglet `historico` est défini ligne 686, son rendu se déclenche ligne 1440 (`activeTab === 'historico'`). L'état `history` est peuplé ligne 124 depuis `apiQuery('my_loans_history_v1')` (ligne 112). Donc côté chargement, l'historique est récupéré et stocké.

Pour le détail du rendu (cliquabilité, fiche livre, disponibilité locale), il faut lire la section autour de la ligne 1440 plus en détail. L'`apiQuery` `my_loans_history_v1` est une vue dédiée — son nom suggère qu'elle est conçue pour le compte lecteur, mais l'audit ne dit pas si elle expose les champs locaux de disponibilité (`available_count_local`, etc.) que le cahier réclame.

### État de l'HTML d'origine

`<section id="tab-historico">` ne contient que `<div id="history"></div>` (ligne 1273). Rien à récupérer du HTML.

### Écarts et arbitrages

Le sous-item ne peut pas être déclaré clos sur la seule présence d'un onglet et d'un chargement de données. Le cahier réclame **cliquabilité vers la fiche livre** (Link vers `/livro/{book_id}`) et **affichage de la disponibilité locale** au moment où l'historique est consulté — deux éléments qui demandent une lecture détaillée du rendu autour de la ligne 1440 pour confirmer ou infirmer.

À ce stade, sur la seule base des grep, le statut probable est **partiel** : la structure est là, le chargement est là, mais la dimension « pont vers le catalogue vivant » (le cœur politique du sous-item selon le cahier) n'est pas confirmée par un Link visible dans les résultats de recherche pour cet onglet.

### Verdict — #CL.1 : 🟡 PARTIEL (à confirmer par lecture détaillée du rendu)

Action recommandée : ouvrir `AccountPage.jsx` autour de la ligne 1440, vérifier (a) que chaque ligne d'historique a un Link cliquable vers la fiche livre, (b) que la disponibilité actuelle locale est affichée pour chaque titre, (c) que le champ `is_reservable` ou équivalent est exploité pour proposer la réservation. Si oui, sous-item clos. Si manque (a), (b) ou (c), travail de complément à chiffrer (probablement 1 session).

---

<a id="cl2"></a>
## #CL.2 — Réservations lecteur suivies de bout en bout

**Priorité Dunkerque** : Très haute (Sprint 1)
**Statut backlog v22** : 🟡 CADRÉ (absorbe probablement #157)

### Ce que demande le cahier Dunkerque (§2.2)

Faire de la réservation un parcours lisible, avec états, prochaines étapes et actions disponibles à chaque moment.

**Données à afficher** : titre et bibliothèque de retrait, date de demande, statut métier lisible, date limite de retrait quand le livre est prêt, message simple de prochaine étape.

**Actions** : annuler une réservation, ouvrir la fiche du livre, répondre à un agendamento si ce flux est conservé.

**Dépendances minimales** : vue unique côté lecteur pour `reservas_v2`, champs `workflow_stage`, `pickup_library_name`, `pickup_deadline_at`, `can_cancel`, `book_id`, libellés humains stables pour les états : *solicitada, em preparação, pronta para retirada, retirada a combinar, expirada, cancelada pelo leitor, cancelada pela biblioteca*.

### État actuel du JSX

L'audit ramène une matière particulièrement dense. Trois fonctions de gestion de réservation sont câblées côté lecteur :

- `cancelReservation(reservaId)` ligne 406 → RPC `api.cancel_my_reservation` (ligne 433)
- `handleConfirmPickup` → RPC `api.fn_confirm_pickup_slot_as_reader` (ligne 453, paquet 2 bis)
- `handleSubmitCounterProposal` → RPC `api.fn_propose_pickup_slot_as_reader` (ligne 484, paquet 2)

Le commentaire ligne 390 mentionne le déclenchement de la notification `'reserva_v2_criada'` à l'INSERT du `workflow_stage 'solicitada'`. Les transitions de workflow sont donc traitées côté lecteur, et même avec un mécanisme bidirectionnel (la lectrice peut proposer un créneau de retrait, ou en confirmer un proposé par la biblio). C'est au-dessus du minimum du cahier.

Le commentaire des lignes 431-433 référence explicitement les trois RPC. Ce n'est pas une amorce, c'est un système complet, livré et documenté en commentaires.

### État de l'HTML d'origine

`<section id="tab-reservar">` à la ligne 1226 du HTML. Sans inspection détaillée, on peut dire au minimum qu'il existait un onglet de réservation. La densité fonctionnelle du JSX (confirmation de créneau, contre-proposition) est très probablement **un ajout** par rapport à l'HTML d'origine, qui n'avait probablement qu'une gestion plus rudimentaire.

### Écarts et arbitrages

Pas d'écart structurel détecté entre le cahier et le JSX. Le cahier demandait des **libellés humains stables** : à vérifier dans le rendu réel que les sept états (`solicitada`, `em preparação`, etc.) ont chacun leur traduction lisible. Le mécanisme i18n est en place dans tout le JSX, donc c'est probable.

### Verdict — #CL.2 : ✅ LIVRÉ (au-dessus du minimum cahier)

Travail conséquent réalisé, probablement dans la même dynamique que les paquets 2 et 2 bis évoqués en commentaires (mécanique de pickup bidirectionnelle). Le `#157` du backlog v20 (gestion réservation côté conta) est effectivement absorbé. À déclarer clos dans le backlog.

---

<a id="cl3"></a>
## #CL.3 — Bandeau état du compte / blocages / action requise

**Priorité Dunkerque** : Très haute (Sprint 2)
**Statut backlog v22** : ✅ Clos le 24/05/2026 (note de la fiche)

### Ce que demande le cahier Dunkerque (§2.3)

Rendre immédiatement compréhensible pourquoi certaines actions sont disponibles ou non. État général (conta ativa / atenção / bloqueada), cause principale du blocage, action attendue, date de validité de l'inscription. Objet résumé unique côté backend (`account_status`, `blocking_reason_code`, `blocking_reason_label`, `membership_expires_at`).

### État actuel du JSX

Le bandeau est livré, alimenté par `public.fn_my_account_status()` (clôture #CL.3 du 24/05). La RPC retourne un objet `jsonb` avec `status`, `alerts[]`, `dues_status`, `dues_valid_until`, `dues_days_until_expiry`, etc.

**Mise à jour importante non encore reflétée dans le backlog v22** : la session du 25-26/05 a découvert que la branche cotisation de la fonction était **inopérante pour tou·tes les lecteur·rices** (test `record IS NOT NULL` sur des records aux champs nullables). Bug corrigé par la migration `20260525200000_fix_fn_my_account_status_record_isnull.sql`. Validé en conditions réelles dans les deux états (`expired` et `never_paid`) et sur les deux maillons (bandeau lecteur·rice + blocage emprunt côté painel). Ce travail n'apparaît pas encore comme acquis dans la section E du v22.

### État de l'HTML d'origine

Le HTML avait deux notices conditionnelles : `mustChangeNotice` et `restrictedNotice` (visibles lignes 887 et 889 environ). C'étaient des bandeaux simples, sans la cascade fine de la version JSX (active / restricted / attention / incomplete / pending à venir).

### Écarts et arbitrages

Pas d'écart. Le JSX est largement supérieur à l'HTML d'origine sur ce point. La note de réserve qu'on avait ajoutée à la fiche v22 (« clos sauf branche cotisation ») peut tomber depuis le 26/05.

### Verdict — #CL.3 : ✅ LIVRÉ

À régulariser dans le backlog : ajouter en section E la mention de la correction du 25-26/05 (bug `record IS NOT NULL`, migration `20260525200000`), et supprimer toute trace de réserve sur la branche cotisation. C'est un acquis significatif qui mérite d'être tracé — c'est précisément le genre de bug que la doctrine « refus de la fausse fermeture » du GLB v17 exige de ne pas masquer.

---

<a id="cl4"></a>
## #CL.4 — Prêts en cours avec renouvellement clair

**Priorité Dunkerque** : Haute (Sprint 2)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.4)

Afficher des prêts compréhensibles et actionnables, avec explication nette lorsque le renouvellement est impossible.

**Données à afficher** : titre, bibliothèque, date de prêt, date de retour prévue, nombre de renouvellements restants, état du prêt (normal / bientôt à rendre / en retard).

**Actions** : renouveler, ouvrir la fiche du livre, consulter l'historique du titre.

**Dépendances minimales** : stabilisation complète de `emprestimos_v2`, champs `can_renew`, `renewal_denial_reason`, `due_at`, `book_id`, motif de refus explicite (déjà réservé, quota atteint, retard, non renouvelable).

### État actuel du JSX

**Refonte complète livrée le 29/05/2026** (commentaire ligne 1323 : *« parité painel »*). Le rendu se trouve lignes 1318-1430.

- **Architecture** : items ouverts groupés par emprunt, en-tête synthétique (date · n livres · échéance la plus proche), action « Renovar tudo » au niveau du groupe (visible si ≥ 2 items), action « Renovar » par item.
- **Données affichées par item** : Link vers `/livro/{book_id}` (ligne 1395), titre, auteur, référence, échéance avec code couleur (rouge si retard, orange si proche, normal sinon), jours restants (positifs ou négatifs), mention « renouvelé jusqu'au … » si déjà étendu.
- **Source du `can_renew`** : la vue/table `my_loans_renewal_status_by_item_v1` (ligne 110 dans `loadData`), qui expose `can_renew`, `renewals_used`, `blocking_reason` par item.
- **Backend mobilisé** : 8 fonctions SQL dans `api.*` et `public.*` — `renew_my_loan`, `renew_my_loan_item`, `extend_loan_as_library`, `extend_loan_item_as_library`, `get_due_date_after_renewal`, `get_remaining_renewals`, plus `fn_v2_extend_core` côté triggers. Backend ultra-mature.
- **Câblage des actions** : bouton « Renovar » appelle `api.renew_my_loan_item(p_emprestimo_id, p_line_no)` (ligne 1413), bouton « Renovar tudo » appelle `api.renew_my_loan(p_emprestimo_id)` (ligne 1365).
- **Gestion des erreurs typées** : si `data.ok === false`, alerte traduite via `account.renew.${reason}` ; sinon, alerte de confirmation avec nouvelle date.
- **Tooltips** : si le renouvellement est bloqué, tooltip explicatif via `account.renew.tooltipBlocked` avec le motif lisible.

### État de l'HTML d'origine

`<section id="tab-curso">` ligne 1261 du HTML. Comme historico, c'est un container peuplé par JS — pas de structure riche dans le HTML statique.

### Écarts et arbitrages

Aucun écart. La livraison JSX est **au-delà** de ce que le cahier Dunkerque demandait : groupement par emprunt avec action de groupe (cahier ne le demandait pas), parité visuelle avec painel (le cahier mentionne « miroir logique côté bibliothécaire », c'est exactement ce qui a été fait).

### Verdict — #CL.4 : ✅ LIVRÉ (au-dessus du minimum cahier)

À régulariser dans le backlog : marquer le sous-item résolu, daté du 29/05/2026, avec mention « refonte parité painel ».

---

<a id="cl5"></a>
## #CL.5 — Navigation continue conta → livro → autor → index

**Priorité Dunkerque** : Haute (Sprint 2)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.5)

Donner l'impression d'un seul système cohérent au lieu d'une juxtaposition de pages indépendantes. Ouvrir la fiche livre depuis prêts/réservations/historique, ouvrir la fiche auteur depuis livro.html, revenir naturellement.

**Dépendances minimales** : URLs stables par ID, conservation d'un `library_id` ou `library_slug` contextuel si nécessaire, tenue des filtres et tris au retour.

### État actuel du JSX

L'audit ramène la présence de `<Link to={\`/livro/${l.book_id}\`}>` dans le rendu des prêts en cours (ligne 1395), ce qui prouve qu'au moins **un point de pont** existe vers la fiche livre. Les `Link` vers `/livro/...` sont la seule sortie de `AccountPage.jsx` vers le catalogue.

Ce que l'audit **ne dit pas** :

- Si `livro.html` (ou son équivalent JSX `BookPage.jsx`) expose à son tour un lien vers la fiche auteur.
- Si la fiche auteur permet de revenir vers la liste filtrée.
- Si les retours en arrière conservent l'état (filtres, scroll, etc.).

Ces points-là sortent du périmètre de `AccountPage.jsx` et ne peuvent pas être tranchés par l'audit actuel. Le sous-item #CL.5 est un sous-item **transverse** qui touche au moins trois pages (`AccountPage`, `BookPage`, `AuthorPage`).

### État de l'HTML d'origine

L'HTML d'origine n'a pas de Link React — les liens étaient gérés en JS dynamique. Donc rien à comparer ici.

### Écarts et arbitrages

Le sous-item #CL.5 est largement **partiellement vérifiable** par cet audit. La partie « depuis `conta` vers `livro` » est livrée (le Link existe). La partie « depuis `livro` vers `autor` puis retour » demande un audit séparé de `BookPage.jsx` et `AuthorPage.jsx`.

### Verdict — #CL.5 : 🟡 PARTIEL (à confirmer par audit transverse)

Action recommandée : audit ciblé de `BookPage.jsx` et `AuthorPage.jsx` (probablement 30 minutes chacun) pour vérifier la continuité de navigation. Le cœur du sous-item — sortir de la page compte vers le catalogue — est en place côté `AccountPage`.

---

<a id="cl6"></a>
## #CL.6 — Centre d'avis / notifications dans l'interface

**Priorité Dunkerque** : Moyenne (Sprint 3)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.6)

Rendre visibles dans le compte les événements déjà envoyés ou déclenchés par email.

**Données à afficher** : message court, date, niveau de priorité ou statut lu / non lu.

**Actions** : ouvrir la réservation concernée, ouvrir le prêt concerné, marquer comme vu.

**Dépendances minimales** : réutiliser les événements déjà structurés pour la chaîne mail, surface simple des derniers avis récents ou non lus.

### État actuel du JSX

L'onglet `avisos` est présent (ligne 687) avec un compteur d'éléments non lus dans le label (`unreadCount`). Son rendu commence ligne 1569.

- **Source de données** : `supabase.from('user_notifications').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(50)` (ligne 133). Donc une table dédiée existe et est interrogée.
- **Calcul du compteur non lu** : `notifications.filter(n => !n.is_read).length` (ligne 678).
- **Action « Marquer tout comme lu »** : appel à `supabase.rpc('fn_mark_notifications_read')` (ligne 1575), réservé au cas `unreadCount > 0`.
- **Rendu des notifications** : chaque notification affiche son `title` et son `body`, avec une logique spéciale pour les notifications de rétention RGPD (`category` commençant par `rgpd_retention_`) dont les libellés sont traduits via i18n (lignes 1592 et 1595).

Le système d'événements est en place, branché à une table `user_notifications`, avec lecture/non-lecture et action de marquage. C'est conforme au cahier dans sa structure de base.

### État de l'HTML d'origine

**L'onglet `avisos` n'existe pas en HTML.** Les seuls onglets HTML sont `perfil`, `reservar`, `curso`, `historico`. C'est donc une **création** du chantier JSX, pas une récupération.

### Écarts et arbitrages

Deux points méritent une vérification de second niveau, parce que le grep ne les capture pas :

**Premier point — les actions contextuelles**. Le cahier demande de pouvoir « ouvrir la réservation concernée » ou « ouvrir le prêt concerné » depuis une notification. L'audit ramène le rendu du titre et du body, mais pas un Link contextuel. Si chaque notification a un `target_id` (ou équivalent) qui pointe vers une réservation ou un prêt précis, le pont vers le contexte est possible — sinon, la notification reste un message sans action de saut.

**Second point — la granularité de la lecture**. L'action « Marquer tout comme lu » est livrée. Le cahier n'exige pas explicitement un marquage individuel par notification, mais c'est une attente courante. À vérifier si chaque notification a son propre bouton « marquer comme lu », ou si seul le marquage global existe.

### Verdict — #CL.6 : ✅ LIVRÉ (sous réserve de deux vérifications mineures)

L'ossature complète est en place. La structure de données, le compteur de non-lus, le marquage global, le rendu, l'i18n pour les notifications RGPD : tout y est. Les deux points (Link contextuel, marquage individuel) sont des raffinements à arbitrer, pas des manques structurels. À déclarer clos avec mention « raffinements optionnels en attente d'arbitrage ».

---

<a id="cl7"></a>
## #CL.7 — Mes données / sécurité / bibliothèque de rattachement

**Priorité Dunkerque** : Moyenne (Sprint 3)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.7)

Unifier la couche compte lecteur sans perdre le centre de gravité circulation-réservation.

**Données à afficher** : nom, email, bibliothèque de rattachement, validité de l'inscription, **préférences de notification**, sécurité / mot de passe.

**Actions** : mettre à jour les données, changer le mot de passe, voir les règles ou le règlement de la bibliothèque.

**Dépendances minimales** : source claire pour la bibliothèque de rattachement, exposition propre de la validité du compte et des préférences.

### État actuel du JSX

- **Formulaire de données personnelles** : présent, parsing/formatage d'adresse via `parseAddressText`/`formatAddressText` (ligne 16), structure internationale (`address.title`, `address.country`, etc., ligne 2058). Sections : nom, prénom, téléphone, genre, adresse complète.
- **Changement de mot de passe** : section « Mudar minha senha » (ligne 956, *Lot 26.1a*), avec contrôle de longueur minimum (8 caractères), confirmation, et messages d'erreur (`account.changePassword.error.tooShort`, `account.changePassword.error.mismatch`, `account.changePassword.success`). Bouton « Atualizar senha » câblé. Tout est en place.
- **Bibliothèque de rattachement** : exposée via `useLibrary()` dans tout le composant, et visible dans le hero (chip biblio).

### État de l'HTML d'origine

Le HTML avait également un formulaire profil complet (« Seus dados (editar) » ligne 901, section « Endereço » ligne 930) et une section sécurité (« Segurança — Alterar senha » ligne 1205). Donc la structure de base existait déjà.

### Écarts et arbitrages

**Un écart majeur, identifié par recherche directe** : ni l'HTML ni le JSX n'ont de section « préférences de notification ». Le cahier Dunkerque la mentionne explicitement dans les données à afficher de #CL.7. Il s'agit d'une attente non satisfaite par l'état actuel, des deux côtés.

C'est un sujet en soi : préférences de notification, ça veut dire au moins une UI pour choisir quels types d'événements déclenchent un mail (échéance, retard, réservation prête, etc.), avec persistance en base. Le backend ne semble pas l'exposer non plus.

**Point « voir le règlement de la bibliothèque »** : il existe (bouton « Baixar o regimento da biblioteca » visible sur les captures d'écran de la session #33, présent dans BibliotecaPage probablement, mais sa présence dans `AccountPage.jsx` reste à vérifier). À confirmer.

### Verdict — #CL.7 : 🟡 PARTIEL — préférences de notification manquantes

Le cœur du sous-item (formulaire profil + sécurité + bibliothèque de rattachement) est livré et propre. Mais les **préférences de notification** explicitement listées par le cahier Dunkerque ne sont implémentées ni en HTML d'origine, ni en JSX actuel. C'est un complément à arbitrer : soit on le considère comme une **catégorie « volontairement retiré »** (et alors c'est une décision politique à formaliser — peut-être en lien avec la doctrine « refus de la traçabilité marchande » qui peut justifier une politique mail minimale et non configurable), soit on le considère comme un **manque réel** à implémenter.

**Recommandation** : trancher ce point dans une décision dédiée. Si on garde le minimum non configurable, on l'explicite dans la fiche #CL.7 et on déclare clos. Sinon, c'est un travail de complément (1-2 sessions).

---

<a id="cl8"></a>
## #CL.8 — Maîtrise de l'historique par le lecteur

**Priorité Dunkerque** : Moyenne (Sprint 3)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.8)

Permettre au lecteur de décider ce qu'il souhaite conserver ou non dans son historique de prêt.

**Données à afficher** : indication claire de la politique de conservation, état du paramètre de conservation si activable.

**Actions** : masquer ou supprimer une ligne d'historique, désactiver la conservation de l'historique si ce choix est retenu.

**Dépendances minimales** : règle métier explicite sur ce qui est supprimé / masqué / non affiché.

### État actuel du JSX

L'audit ne ramène **aucune occurrence** de `retention`, `deleteHistory`, `maskItem`, `history_retention`, `conservation` dans `AccountPage.jsx`. Les seules occurrences proches sont les notifications RGPD de rétention (lignes 1592, 1595), mais c'est l'inverse : ce sont des notifications **à propos de** la politique de rétention, pas une UI permettant à la lectrice de la **modifier**.

Donc le sous-item #CL.8 n'est pas implémenté côté frontend.

Côté backend, l'existence de notifications `rgpd_retention_*` suggère qu'une politique de rétention RGPD existe au niveau réseau (purges automatiques après X mois ?). Mais c'est une politique imposée, pas un paramètre individuel.

### État de l'HTML d'origine

Rien non plus en HTML — `<section id="tab-historico">` ne contient qu'un `<div id="history"></div>`, et le grep sur l'HTML ne ramène aucune trace de conservation paramétrable.

### Écarts et arbitrages

Ce sous-item est **véritablement ouvert** — ni l'HTML ni le JSX n'en porte trace, et le backend ne semble pas l'exposer non plus. Le cahier Dunkerque le considère comme « moins urgent, très cohérent avec une approche de sobriété et d'autonomie ». Sa mise en œuvre demanderait :

1. **Une décision politique** : quelle est la règle de conservation par défaut ? Que peut désactiver / supprimer la lectrice ? Quelle distinction entre « masqué dans l'UI » et « réellement supprimé » ? Distinction délicate parce qu'elle touche à la fois à la sobriété (refuser l'archivage forcé) et aux besoins de la biblio (statistiques d'usage anonymisées ? politique de prêt ?).
2. **Un schéma backend** : champ utilisateur (par exemple `users.history_retention_mode` avec valeurs `keep_all` / `delete_after_return` / `paranoid`) ou table d'opt-out par ligne.
3. **Une UI** dans `AccountPage.jsx`.

### Verdict — #CL.8 : 🔴 OUVERT — chantier à cadrer

Non livré, des deux côtés. La priorité Dunkerque (« moyenne ») et son caractère secondaire en regard des fonctions cœur de circulation en font un bon candidat **pour la rédaction d'une mini-spec** avant implémentation. Pas urgent, mais à inscrire au backlog comme **vraiment ouvert** (pas seulement « cadré »).

---

<a id="cl9"></a>
## #CL.9 — Liste d'envies / guardar para depois

**Priorité Dunkerque** : Basse (Sprint 3)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.9)

Offrir une couche de confort non bloquante : retrouver plus tard un titre sans devoir le réserver immédiatement.

**Données à afficher** : titre, auteur, date d'ajout, statut de disponibilité.

**Actions** : ajouter à la liste, retirer de la liste, ouvrir la fiche du livre.

**Dépendances minimales** : table légère liée au lecteur, aucune incidence sur la circulation.

### État actuel du JSX

- **Onglet dédié** : `desejos` (ligne 688), avec compteur dans le label `(${wishlist.length})`.
- **Source de données** : `supabase.from('user_wishlist').select('*, books:book_id(id, titulo, autor, bib_ref, editora, ano)').eq('user_id', user.id).order('created_at', { ascending: false })` (ligne 135). Donc une table `user_wishlist` existe, avec un JOIN auto sur la table livres exposant titre, auteur, ref, éditeur, année. C'est un schéma propre.
- **Rendu** : section dédiée ligne 1618, avec gestion de l'état vide (`account.wishlist.empty`) et itération sur `wishlist.map(...)`.

Tout est en place, jusqu'à l'i18n du titre et du hint de l'onglet.

### État de l'HTML d'origine

**L'onglet `desejos` n'existe pas en HTML** — l'HTML n'a que `perfil`, `reservar`, `curso`, `historico`. C'est une **création** du chantier JSX.

### Écarts et arbitrages

Aucun écart. Sous-item livré. Le seul point à confirmer par lecture détaillée du rendu : le bouton « retirer de la liste » et le Link vers la fiche livre. Mais la structure de données est en place, et il serait surprenant que le rendu ne les expose pas.

### Verdict — #CL.9 : ✅ LIVRÉ

À régulariser dans le backlog : marquer le sous-item résolu.

---

<a id="cl10"></a>
## #CL.10 — Infos pratiques de retrait intégrées au parcours

**Priorité Dunkerque** : Basse (Sprint 3)
**Statut backlog v22** : 🟡 CADRÉ

### Ce que demande le cahier Dunkerque (§2.10)

Réduire l'hésitation au moment du retrait physique et rendre le dernier kilomètre plus fluide.

**Données à afficher** : nom de la bibliothèque de retrait, **adresse, horaires, téléphone ou email**, rappel de la date limite de retrait.

**Actions** : ouvrir les infos de la bibliothèque, voir le règlement ou les modalités de retrait.

**Dépendances minimales** : données bibliothèques propres et publiables, lien clair entre réservation et bibliothèque de retrait.

### État actuel du JSX

L'audit ne ramène **rien** sur `address` au sens « adresse de la biblio » (les occurrences trouvées concernent toutes l'adresse personnelle de la lectrice dans son profil). Pas d'occurrence non plus de `hours`, `horaires`, `telephone`, `email_biblio`. La fonction `parseAddressText`/`formatAddressText` est utilisée uniquement pour le profil personnel, pas pour la biblio.

**La bibliothèque de retrait est exposée par nom** (via `pickup_library_name` sur les réservations), mais ses informations pratiques — adresse, horaires, contact — ne semblent pas affichées dans `AccountPage.jsx`.

### État de l'HTML d'origine

Pareil — pas de trace d'horaires ou d'adresse de biblio dans l'HTML statique. Le sous-item n'a jamais été implémenté.

### Écarts et arbitrages

Comme #CL.8, ce sous-item est **véritablement ouvert**. Sa mise en œuvre demanderait :

1. **Côté backend** : enrichir le schéma `libraries` avec des champs `address`, `opening_hours`, `contact_email`, `contact_phone` (vraisemblablement déjà partiellement présents, à vérifier), et les exposer dans les vues consommées par `AccountPage`.
2. **Côté frontend** : sur chaque réservation, dépliable / lien vers les infos pratiques de la biblio de retrait. Plus potentiellement un encart dédié dans la section profil ou en haut de l'onglet réservations.

La dépendance du cahier (« données bibliothèques propres et publiables ») laisse entendre que ce point dépend de la qualité des données réseau, qui est elle-même un chantier à part. C'est cohérent avec la priorité **basse** du sous-item — utile mais pas structurant.

### Verdict — #CL.10 : 🔴 OUVERT — dépend des données bibliothèques publiables

Non livré, sous-item véritablement ouvert. À inscrire au backlog comme **vraiment ouvert**, et conditionner sa programmation à une avancée préalable du chantier données réseau (peut-être à articuler avec `#PARTNERS` ou la future `spec-multi-appartenance-lecteur`, qui auront à se pencher sur l'exposition publique des données biblio).

---

<a id="tableau-récapitulatif"></a>
## Tableau récapitulatif

| Sous-item | Titre | Statut backlog v22 | **Statut réel (audit 30/05)** | Action |
|-----------|-------|--------------------|-------------------------------|--------|
| #CL.1 | Historique cliquable → fiche livre → dispo locale | 🟡 CADRÉ | 🟡 PARTIEL (à confirmer par lecture rendu) | Lecture détaillée AccountPage:1440+, ~30 min |
| #CL.2 | Réservations lecteur bout-à-bout | 🟡 CADRÉ | ✅ LIVRÉ (au-dessus du minimum) | Marquer résolu, absorbe #157 |
| #CL.3 | Bandeau état du compte | ✅ Clos 24/05 | ✅ LIVRÉ + correction bug record IS NOT NULL (25-26/05) | Ajouter mention correction en section E |
| #CL.4 | Prêts en cours avec renouvellement clair | 🟡 CADRÉ | ✅ LIVRÉ (refonte 29/05, parité painel) | Marquer résolu |
| #CL.5 | Navigation continue conta → livro → autor → index | 🟡 CADRÉ | 🟡 PARTIEL côté AccountPage, audit transverse requis | Audit BookPage + AuthorPage, ~1h |
| #CL.6 | Centre d'avis / notifications | 🟡 CADRÉ | ✅ LIVRÉ (sous réserve 2 raffinements) | Marquer résolu, raffinements optionnels |
| #CL.7 | Mes données / sécurité / rattachement | 🟡 CADRÉ | 🟡 PARTIEL — préférences notif manquantes | Décision politique requise sur préf notif |
| #CL.8 | Maîtrise de l'historique | 🟡 CADRÉ | 🔴 OUVERT | Mini-spec à rédiger avant implémentation |
| #CL.9 | Liste d'envies | 🟡 CADRÉ | ✅ LIVRÉ | Marquer résolu |
| #CL.10 | Infos pratiques de retrait | 🟡 CADRÉ | 🔴 OUVERT (dépend données biblio) | Conditionner à #PARTNERS / multi-appartenance |

**Synthèse chiffrée** :
- **5 sous-items livrés** non reconnus comme tels par le backlog v22 (#CL.2, #CL.3, #CL.4, #CL.6, #CL.9) — soit la moitié.
- **2 sous-items partiels** demandant un complément de lecture ou audit transverse (#CL.1, #CL.5).
- **1 sous-item partiel** demandant un arbitrage politique (#CL.7 — préférences notif).
- **2 sous-items véritablement ouverts** non implémentés ni en HTML, ni en JSX (#CL.8, #CL.10).

---

<a id="recommandation-doccupation-jusquau-0606"></a>
## Recommandation d'occupation jusqu'au 06/06

Vu l'état réel, la semaine d'occupation jusqu'au 06/06 (où #BIBLIO étape 8 sera débloqué par #110 R.6) peut être structurée ainsi, par ordre de priorité décroissante :

**1. Confirmation des partiels — 1 demi-journée maximum.**
Lecture détaillée du rendu de #CL.1 (`AccountPage.jsx` autour de la ligne 1440) pour confirmer cliquabilité et exposition de la dispo locale, puis audit transverse rapide de `BookPage.jsx` et `AuthorPage.jsx` pour #CL.5. À l'issue, ces deux partiels passeront soit en LIVRÉ (probable, vu la dynamique de livraison récente), soit en travail de complément clairement chiffré.

**2. Régularisation du backlog v22 et du GLB v17 — 1 session.**
Mise à jour du tableau des sous-items #CL avec les statuts révélés par l'audit, ajout en section E (Acquis) des trois livraisons non tracées : refonte #CL.4 du 29/05, correction du bug `record IS NOT NULL` du 25-26/05, mécanique pickup bidirectionnelle #CL.2. Note d'écart sur le GLB v17 (séquence 3 « jonction frontend profils d'adoption » obsolète + #CL.4 livré non reconnu). Ne pas refondre le GLB lui-même (la cadence Livre blanc est volontairement interrompue jusqu'à fin juillet), mais consigner les écarts dans une note de session.

**3. Décision sur les préférences de notification (#CL.7) — courte session.**
Arbitrage politique : préférences configurables (chantier de complément) ou politique mail minimale non configurable (décision doctrinale, peut-être en lien avec « refus de la traçabilité marchande ») ? Si la seconde, c'est une note en `docs/decisions/` et #CL.7 passe en LIVRÉ.

**4. Cadrage de `spec-multi-appartenance-lecteur` — chantier principal de la semaine.**
C'est le vrai sujet structurant ouvert ce matin. Sa rédaction est largement compatible avec la fenêtre 30/05 → 06/06, et préparera l'attaque de la migration SQL validation physique qui suivra. Cette spec a vocation à intégrer également des arbitrages utiles pour #CL.10 (exposition publique des données biblio).

**5. Si temps disponible — démarrage de la mini-spec #CL.8.**
Décision politique sur la rétention d'historique, schéma de configuration, esquisse d'UI. Pas urgent, mais à entamer maintenant qu'il est explicitement identifié comme vraiment ouvert.

Ce que la semaine **ne doit pas contenir** : redéveloppement de fonctions déjà livrées. Le risque, sans cet audit, aurait été de coder un renouvellement de prêts en pensant que #CL.4 attendait du travail, alors qu'il était fait depuis le 29/05. C'est précisément ce que la doctrine « refus de la fausse fermeture » du GLB v17 doit empêcher — et la valeur de cet audit est d'avoir mesuré l'écart avant qu'il coûte plusieurs jours de travail inutile.

---

<a id="conséquences-pour-le-backlog-v22-et-le-glb-v17"></a>
## Conséquences pour le backlog v22 et le GLB v17

### Pour le backlog v22 (à régulariser au prochain passage de version, v23)

- **Section C.3 (fiche #CL)** : mettre à jour la liste des sous-items résolus. Au minimum #CL.2, #CL.4, #CL.6, #CL.9 passent dans les acquis. #CL.3 sort de sa réserve cotisation. #CL.1 et #CL.5 restent en cadré le temps de la confirmation. #CL.7 dépend d'un arbitrage. #CL.8 et #CL.10 passent explicitement en « ouvert avec spec à rédiger / dépendance externe ».
- **Section E (Acquis)** : ajouter quatre lignes
  - *Correction `fn_my_account_status` (bug `record IS NOT NULL`) — 25-26/05, migration `20260525200000`, sécurise la branche cotisation du bandeau #CL.3 pour tou·tes les lecteur·rices.*
  - *Refonte conta curso parité painel — 29/05, livre #CL.4 (prêts groupés, renouvellement par item ou par groupe, codes couleur, motifs de blocage typés).*
  - *Mécanique pickup bidirectionnelle (`fn_propose_pickup_slot_as_reader`, `fn_confirm_pickup_slot_as_reader`) — paquets 2 et 2 bis, livre #CL.2 (réservation bout-à-bout).*
  - *Centre d'avis #CL.6 — onglet `avisos`, table `user_notifications`, RPC `fn_mark_notifications_read`, intégration RGPD.*
- **Section D (sous-tickets)** : déplacer ou marquer résolus les lignes correspondantes.
- **Section F (Arbitrages à rendre)** : ajouter l'arbitrage préférences de notification (#CL.7).

### Pour le GLB v17 (à régulariser à v18 fin juillet)

Le GLB v17 est explicitement gelé jusqu'à fin juillet ; aucune édition à apporter avant. Mais consigner dans une note de session du 30/05 :

- La séquence 3 du tableau IV (« jonction frontend profils d'adoption ») est obsolète depuis le marathon 19-20 mai. État réel : livré, frontend painel + biblioteca + conta adaptatifs.
- Le présent audit révèle cinq sous-items #CL livrés silencieusement, dont deux dans la dynamique du marathon Painel 28-30 mai (refonte conta curso 29/05, mécanique pickup paquets 2/2 bis).
- L'arbitrage 1 du GLB v17 (« continuer Painel ou basculer sur profils d'adoption ? ») est en partie caduc : les profils d'adoption sont livrés.
- L'arbitrage 2 (« CIRA Marseille avant ou après séquence 3 ? ») devient praticable, la séquence 3 étant en fait close.

Ces points devront alimenter la rédaction du v18 fin juillet pour que la formule de clôture (« la prochaine étape est un chantier tenu — la jonction frontend des profils d'adoption ») ne soit pas reportée par inertie sur un travail déjà fait.

### Leçon de méthode

Cet audit montre que **la cadence de livraison du projet excède désormais la cadence d'inscription dans les documents stratégiques**. C'est un effet de la méthode parité+audit elle-même : un marathon comme celui de Painel 26-30 mai déplace plusieurs périmètres à la fois (Painel + parité conta + corrections collatérales), et les sous-items concernés ne sont pas systématiquement répercutés. Trois pistes pour y répondre, à arbitrer plus tard :

1. **Audit éclair à la fin de chaque marathon** : 30 minutes en fin de session pour grep les sous-items concernés et basculer leur statut.
2. **Document de bilan de marathon** : un fichier court par marathon (genre `BILAN_painel_28-30mai.md`) qui liste les livraisons collatérales, à committer dans `docs/decisions/`.
3. **Inversion de l'invariant backlog** : passer d'un backlog « rien ne sort tant qu'on n'a pas explicitement marqué résolu » à un backlog « tout doit être audité avant de démarrer ». C'est la posture pratiquée par ce bilan, et qui pourrait devenir doctrine.

La troisième piste est probablement la plus saine — elle inscrit comme règle ce que le projet pratique déjà *de facto*, et elle protège du risque que tu pointais en début de session : se lancer sur un chantier déclaré ouvert qui est en réalité livré.

---

*Bilan rédigé le 30/05/2026 par Claude, dans la session avec Xavier qui s'est ouverte au sortir de la session marathon Painel.*
