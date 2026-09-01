# Audit — les 138 fonctions `SECURITY DEFINER` exécutables par `authenticated` dans `api`

**1er septembre 2026** · base `uflwmikiyjfnikiphtcp` en lecture seule · item **B14**, lot `api`
**Critère repris de l'audit du 18/05/2026** : *que renvoie-t-elle, à partir de quel
paramètre, et qu'est-ce qui interdit à un tiers **simplement inscrit** de le demander ?*

Un compte `authenticated` s'obtient en trois clics et ne prouve l'appartenance à
aucune bibliothèque. Le critère n'est donc pas « appelle-t-elle `auth.uid()` ? »
— les cinq failles de mai en contenaient — mais « que peut demander une inconnue
qui vient de s'inscrire ? ». La forme à chercher en priorité, celle des oracles
de mai : *un identifiant en paramètre, une donnée nominative en retour.*

---

## Méthode et découpage

Le schéma `api` porte **138** fonctions `SECURITY DEFINER` ouvertes à
`authenticated` (relevé du 01/09). Premier tri, par présence d'une garde dans le
corps :

| Groupe | Compte | Ce qu'on y trouve |
|---|---|---|
| Garde par prédicat délégué (`fn_caller_*`, `user_can_*`, `resolve_managed_library_id`, `fn_constitution_guard`, `fn_is_catalog_coordinator`…) | 51 | contrôle explicite d'appelant |
| `auth.uid()` employé directement dans le corps | 63 | à lire au cas par cas (une garde peut être un oracle) |
| Aucune garde visible | 24 | pile à instruire en premier |

La pile « aucune garde visible » a été passée en entier. Résultat : la quasi-
totalité **délègue** la garde à une fonction appelée (le tri par regex ne la
voyait pas), sauf une.

---

## A. Fausses alertes de la pile « sans garde visible » — délégation (23)

- **Cinq `get_library_*_ui` + `get_library_institutional_workspace`** passent par
  `public.resolve_managed_library_id(p_library_id)`, qui lève `authentication
  required` puis `permission denied` si l'appelant n'est pas staff de la
  bibliothèque. Garde solide, simplement indirecte.
- **`get_batch_loan_projection`, `get_due_date_after_renewal`,
  `get_remaining_renewals`** délèguent à `api.resolve_circulation_rule`, dont
  l'étape 3 résout `p_user_id` de façon sécurisée (un identifiant étranger
  retombe sur l'appelant). Elles ne renvoient qu'une projection de règle, pas de
  donnée nominative.
- **Les `fn_circle_*`, `fn_constitution_*`, `fn_set_library_*_public`,
  `fn_subject_remove_*`, `fn_assembleia_withdraw_item`** gardent toutes par
  `user_can_manage_library`, `fn_constitution_guard` (coordenador de la
  constitution) ou `fn_is_catalog_coordinator`. Ce sont des **écritures**
  réservées, pas des lectures.
- **`fn_circle_resolve_due`, `fn_entraide_escalate_due`** sont des balayages
  idempotents appelés par cron (et déclenchés au chargement d'un onglet fédéral,
  sans effet pour qui n'a rien à résoudre) ; ils n'exposent aucune donnée.

**Verdict : légitimes.**

## B. La vraie — `api.get_due_date_for_loan`

Un identifiant en paramètre, une donnée nominative en retour : la forme exacte de
mai. `p_user_id` était passé **brut** au bloc « cotisations » (`
fn_is_loan_blocked_by_dues` puis lecture de `v_active_memberships.dues_status`)
qui s'exécute **avant** l'appel à `resolve_circulation_rule`. Une personne
simplement inscrite lisait l'état de cotisation de n'importe quel UUID —
« Contribuição vencida », « não registrada ». Dans une bibliothèque militante,
savoir qui n'est pas à jour n'est pas une donnée technique.

**Pourquoi invisible.** La garde existe, mais dans la fonction *suivante*.
`resolve_circulation_rule` résout `p_user_id` correctement (étape 3) ; le bloc
cotisations était en amont. Lire la fonction déléguée rassurait ; c'est
l'appelante qu'il fallait lire — l'exact enseignement de `DOC-RECENS-1`, un cran
plus loin.

**Pourquoi pas encore exploitable — et pourquoi ça n'atténue pas.**
`fn_is_loan_blocked_by_dues` sort `false` d'emblée sans `membership_enabled`, et
**aucune bibliothèque ne l'a activé au 01/09**. La fuite était **dormante** :
elle se serait armée seule à la première activation des cotisations (chantier
`COTIS`), sans un signal. Un défaut qui attend une case à cocher se corrige avant
la case.

**Verdict : corrigé.** Migration `20260831201011` — la même résolution sécurisée
appliquée avant le bloc cotisations (soi-même, ou un membre dont on est staff).
Gardé par `tests/sql/b14_api_cotisation_autrui_tests.sql`, qui interroge l'effet
et non le code : la curieuse n'apprend rien, la personne concernée voit son
blocage, le staff garde son usage de comptoir, et la fonction déléguée garde
toujours (T4, contre la divergence des deux copies de la règle).

---

## C. Reste à instruire — les prochaines soirées

Les 63 fonctions à `auth.uid()` direct et les actions à garde staff apparente
(`freeze_account`, `restrict_member`, `list_pending_validations`,
`generate_my_reader_card`, `fn_cartography_get_for_edit`, la famille
`recolement_*`…) n'ont **pas encore** été lues ligne à ligne. Elles portent une
garde apparente ; l'audit du 18/05 rappelle que l'apparence d'une garde ne suffit
pas (les cinq failles de mai appelaient `auth.uid()`). À passer par paquets de
dix, même question, même exigence de verdict écrit.

Le schéma `public` (326 fonctions) suit après `api`, comme le prévoit B14.
Le retournement du défaut pour `authenticated` — s'il a lieu un jour — est le
tout dernier geste, et seulement une fois cette liste connue : fermer
`authenticated` par défaut casserait la surface d'écriture de l'application
(`DOC-RPC-3`). Piège hérité de B2, en pire : ne jamais vider la ligne
`pg_default_acl`.

---

# Paquet 2 — les actions nominatives (15 fonctions, 01/09 au soir)

Choisies sur la forme-oracle : celles qui prennent un identifiant de personne
(`p_user_id`, `p_membership_id`, `p_token_id`) **et** rendent autre chose qu'un
booléen. C'est là que les cinq failles de mai vivaient.

## Une prise : `api.get_member_restriction(p_user_id, p_library_id)`

La garde est juste — `user_can_act_as_staff_on_library(p_library_id)` — et le
bloc **local** la respecte (il filtre sur `library_id = p_library_id`). Le bloc
**global** lisait `public.profiles WHERE id = p_user_id`, sans aucun lien avec
la bibliothèque. Un·e staff de n'importe quelle bibliothèque obtenait donc, pour
n'importe quel UUID du réseau : le gel global, **sa raison** (texte libre
motivant une sanction), sa date, son auteur·rice — et jusqu'à l'**e-mail** de
celle-ci quand son profil n'a pas de nom (`by_name` retombe dessus).

*La garde vérifiait une relation que la requête suivante n'utilisait pas.*
Deuxième occurrence de la forme en deux paquets, et la comparaison est
instructive : au paquet 1 (`get_due_date_for_loan`) la garde était dans la
fonction **suivante** ; ici elle est dans la **même fonction, deux blocs plus
haut**. Le trait commun n'est pas la distance, c'est qu'une garde ne protège que
les lignes qui s'y réfèrent.

**Dormante, comme la précédente** : `profiles.is_restricted = true` sur **zéro**
compte au 01/09. Rien à lire aujourd'hui ; tout à lire au premier gel posé.
Deux fuites dormantes en deux paquets — la mesure « exploitable aujourd'hui ? »
n'est pas la bonne : elle daterait la correction du jour où quelqu'un coche une
case.

**Corrigé** : migration `20260901074627`, bloc global borné à la même relation
que la garde. Les trois appels du front (`PanelPage.jsx:1386`,
`TabLeitor.jsx:352` et `:407`) passent tous un lecteur **déjà** résolu comme
membre : rien ne change pour l'usage réel. Gardé par
`tests/sql/b14_api_gel_global_borne_tests.sql` (l'étrangère ne rend rien, la
lectrice de la maison rend son gel, la garde staff d'origine tient).

**Point ouvert, non corrigé ici** : le repli de `by_name` sur l'e-mail. Dans le
bloc local, l'auteur·rice est staff de la même bibliothèque — l'exposition est
faible. Mais c'est le motif exact de `fn_user_display_name`, fermée en mai pour
cette raison. À trancher : afficher un nom ou rien, jamais une adresse.

## Quatorze sans reproche — et deux bien construites

`list_pending_validations` filtre **par ligne** (`EXISTS` staff de
`m.library_id`), ce qui rend l'appel sans `p_library_id` sûr : on ne voit que
les bibliothèques où l'on est staff. `validate_membership`, `reject_membership`
et `set_local_reader_identity` gardent staff de la bibliothèque concernée ;
`resubmit_membership` n'autorise que la candidate elle-même. `freeze_account` /
`unfreeze_account` sont réservées aux admins réseau ; `restrict_member` /
`unrestrict_member` au staff **et** vérifient que la cible est membre actif.
`generate_my_reader_card` et `revoke_my_reader_card` n'agissent que sur soi
(la seconde vérifie explicitement `user_id <> v_uid`). `recolement_start` et
`recolement_scan` passent par `private.fn_recolement_is_staff`.

Deux méritent d'être signalées comme **bien faites**, parce qu'on apprend autant
d'elles que des fautives :

- `fn_cartography_get_for_edit` écrit `v_lib IS NOT NULL AND EXISTS(...)`. Ce
  `IS NOT NULL` explicite n'est pas décoratif : **184 des 187 fiches de
  cartographie n'ont pas de `library_id`** (ce sont des lieux repérés, pas des
  bibliothèques membres). Sans lui, la condition de membership se serait évaluée
  sur `NULL` et la fiche — adresse, e-mail, téléphone d'un lieu militant —
  serait tombée dans un cas indéterminé. Ici, elles sont réservées aux admins
  réseau.
- `recolement_scan` rend `in_acervo` en comparant `library_id` à celle de la
  session : un exemplaire scanné qui appartient à une autre bibliothèque ne
  révèle rien d'elle.

## Le correctif a eu son propre défaut — et c'est le test qui l'a dit

Quinze minutes après `20260901074627`, la CI est passée au rouge : `sql-tests`,
suite `B14_GEL_GLOBAL`, **2/3** — T1 en échec, avec
`record "v_global" is not assigned yet`.

Le bornage était juste sur le fond, faux dans sa forme : il enfermait le SELECT
du bloc global dans un `IF v_est_membre THEN … END IF`. Sur le chemin
« personne étrangère », la branche est sautée, le `record` n'est jamais assigné,
et la lecture suivante lève. **En PL/pgSQL, un `SELECT INTO` sans résultat
assigne le record (champs NULL) ; c'est ne pas l'exécuter du tout qui laisse sa
structure indéterminée.** La version d'origine ne pouvait pas rencontrer le cas :
ses deux SELECT s'exécutaient toujours.

Trois choses méritent d'être notées, parce qu'elles se répéteront :

1. **Le test a attrapé le défaut de son propre correctif.** T1 est le seul des
   trois à emprunter le chemin « étrangère » — celui que le correctif venait de
   créer. Il affirmait « on attend un silence, pas une erreur » : c'est
   exactement ce qui a manqué. Une suite écrite dans le même commit que le
   correctif n'est pas une formalité.
2. **La version fautive était déjà en production.** `backend` (déploiement) et
   `sql-tests` (signal de régression) sont deux jobs parallèles : le premier a
   réussi pendant que le second rougissait. Mesuré avant d'écrire le correctif —
   aucun écran n'atteignait le chemin fautif (les trois appels du front passent
   un membre déjà résolu) et rien ne fuyait : le bornage fonctionnait, il
   plantait. Reproduit en production sur données réelles, puis vérifié corrigé
   au même endroit (`ok=true`, bloc global vide, aucune erreur).
3. **La forme qui ne peut pas retomber dedans** : la condition passe dans le
   `WHERE` du SELECT. Une seule requête, aucune branche, record toujours
   assigné. À préférer systématiquement quand on restreint un bloc existant.

Correctif : `20260901075511`.

# Paquet 3 — les listes (21 fonctions, 01/09)

Critère que le paquet 2 s'était donné : **les fonctions qui rendent une liste à
partir d'un paramètre de portée** — la forme qui produit une *énumération*
plutôt qu'un oracle.

## Aucune énumération — mais six refus muets

Sur les 21 lues, **aucune fuite** : les portées sont respectées.
`get_reader_roster(p_library_id)` — noms, prénoms, e-mails des lectrices — garde
par `user_can_manage_library` sur *la même* bibliothèque que le paramètre ; les
`fn_my_*` filtrent sur `auth.uid()` ; `fn_cartography_submission_list` et les
quatre `conv_*` lèvent proprement.

Un point de portée mérite d'être écrit plutôt que corrigé : `conv_revue_list`
garde par `fn_caller_is_staff()` **sans argument** — staff de n'importe quelle
bibliothèque. Ce n'est pas un oubli : `catalog_review_queue` **n'a pas de
colonne `library_id`** (vérifié), la file de révision est structurellement un
commun du réseau, comme la corbeille du catalogage. La garde est cohérente avec
la table qu'elle protège.

**Ce que le paquet a vraiment trouvé est ailleurs** : six fonctions écrivaient
leur garde avec un `RETURN;` nu — cinq rapports de qualité du catalogue et
`fn_authority_list`. « Vous n'avez pas le droit » et « il n'y a rien » y étaient
le même octet. Sur un rapport de qualité, c'est pire qu'ailleurs : **une liste
vide y signifie « le catalogue est sain »** — un refus déguisé en bilan
rassurant. `DOC-SILENCE-1` au mot près.

L'incohérence interne le démontre : dans le **même schéma**, les quatre
fonctions de liste du chantier conventions lèvent en `42501`. Deux écoles
cohabitaient ; celle qui se tait était la mauvaise.

**Portée réelle, inégale — et c'est la mesure qui l'a dit :**

| | Atteignable par l'interface ? | |
|---|---|---|
| `fn_authority_list` | **oui** — `/atelier-autoridades` est sous `<ProtectedRoute>` **sans garde de rôle** | toute personne inscrite lit « rien à délibérer » au lieu d'« accès réservé » |
| les cinq `report_*` | non — `ReportsPanel` est derrière la garde stricte de `RedePage` (admins réseau) | silence atteignable en appel direct seulement |

Le cas qui aurait coûté : une contributrice dont le statut passe à `inactive`
ouvre l'Atelier, voit une file vide, et n'apprend jamais qu'elle a perdu son
mandat. C'est le motif de `F4` — trois bibliothèques se croyaient couvertes.

**Corrigé** : migration `20260901082124`. Aucun changement de **droit** — elles
refusaient déjà les mêmes personnes ; on change ce qu'elles **disent** en
refusant. La migration reprend le patron du wrap RLS (lire `pg_get_functiondef`,
substituer, ré-exécuter) en y ajoutant ce qui manquait là-bas : **la substitution
est vérifiée**, et la migration échoue si le motif a disparu plutôt que de se
croire appliquée. Essayée à blanc en production avant écriture — une garde ciblée
par fonction, tous les `RETURN QUERY` intacts. Vérifiée après déploiement : zéro
refus muet, six refus explicites.

Gardé par `tests/sql/b14_api_refus_muet_listes_tests.sql`, qui vérifie la
**forme par introspection** (donc attrapera la septième fonction le jour où elle
arrivera avec un `RETURN;` nu), plus l'effet sur le seul cas atteignable et la
preuve que le staff passe toujours.

# Paquet 4 — les écritures sur un objet (45 fonctions, 01/09)

Critère posé par le paquet 3 : les **écritures prenant un identifiant d'objet**
et non de personne — `p_book_id`, `p_draft_id`, `p_reserva_id`, `p_proposal_id`,
`p_entry_id`… La forme où l'on *agit sur la chose d'autrui* plutôt que de la
lire, et où un défaut ne fuit pas : il modifie.

## Résultat : aucune faille sur les 45

**C'est le premier paquet qui ne trouve rien, et il faut le dire.** Trois
paquets d'affilée avaient produit une prise ; celui-ci n'en produit aucune, et
ce n'est pas faute d'avoir cherché la même forme. Les écritures sont la partie
la mieux gardée du schéma `api` — ce qui est cohérent : elles ont été écrites
en sachant qu'elles écrivaient.

## La doctrine implicite qu'elles suivent — constatée, jamais écrite

Les 45 appliquent la même règle, sans qu'aucun document ne l'énonce : **la garde
suit la propriété de l'objet, pas le rang de l'appelant.**

| L'objet appartient à… | Garde constatée | Exemples |
|---|---|---|
| une **personne** | propriété vérifiée (`v_owner <> v_uid` → refus) | `fn_confirm_pickup_slot_as_reader`, `fn_propose_pickup_slot_as_reader`, `fn_authority_withdraw`, `fn_request_solicitante_message` |
| une **bibliothèque** | garde *par cette* bibliothèque | `fn_serial_upsert_holdings` (`fn_team_caller_is_coordenador(p_library_id)`), `fn_cartography_update_self`, `fn_circle_create` |
| le **réseau** (commun) | rôle de catalogage, sans bibliothèque | `merge_draft_into_book`, `fn_serial_update`, les `fn_subject_*`, `conv_revue_decide` |
| l'**assemblée / la fédération** | admin réseau | les `fn_request_*`, `fn_cartography_delete`, `fn_approve_library_request` |

Le troisième cas est celui qui ressemble à un oubli et n'en est pas un : une
notice de livre, un sujet, un titre de revue sont des **communs du réseau** —
même raison que `conv_revue_list` au paquet 3 (`catalog_review_queue` n'a pas de
`library_id`). Ce qui appartient à une bibliothèque est gardé par bibliothèque ;
ce qui appartient à tout le monde est gardé par le métier.

## Trois formes à imiter

- **`attach_exemplar` ne prend pas la bibliothèque en paramètre** : elle la
  déduit du membership actif principal de l'appelant·e. On ne peut donc pas
  rattacher un exemplaire au fonds d'autrui — non parce que c'est vérifié, mais
  parce que ce n'est pas *demandable*. C'est l'héritage de l'incident de juillet
  (un exemplaire MLEG rattaché à un holding BLMF). **La garde la plus sûre est
  celle qu'on ne peut pas contourner parce que le paramètre n'existe pas.**
- **`resolve_reader_card` rend le même motif pour « pas staff » et pour « jeton
  inconnu »**, et son commentaire dit pourquoi : sans cela, un appelant
  distinguerait « carte existante ailleurs » de « carte inexistante » — une
  énumération de cartes par essais. *La banalité du motif est le contrôle.*
- **`fn_authority_object` vérifie deux choses** : qu'on coordonne bien la
  bibliothèque au nom de laquelle on objecte (`user_can_manage_library`), **et**
  que cette bibliothèque est concernée par l'autorité en cause
  (`fn_library_uses_authority`). Le mandat *et* l'intérêt à agir — dans une
  délibération fédérale, les deux sont nécessaires.

## Une limite fonctionnelle, pas une faille

`attach_exemplar` déduit la bibliothèque du membership `is_primary = true` : une
personne staff de deux bibliothèques ne peut cataloguer que dans sa principale.
C'est une contrainte connue du flux de création (la bibliothèque cible se choisit
en admin réseau, décision du 17/08), pas un défaut de garde — noté ici pour que
la prochaine lecture ne le prenne pas pour un oubli.

## Compte d'avancement du lot `api`

**105 des 138** fonctions ont un verdict écrit (24, 15, 21 puis 45) ;
**deux fuites réelles** trouvées et corrigées, toutes deux dormantes — et un défaut introduit par le second correctif, attrapé par sa propre suite avant d'avoir servi. Restent 33 à lire. Pour le reste (33 fonctions sans paramètre d'objet ni de personne : bascules de réglage, compteurs, helpers d'écran), le critère de tri n'a plus grand-chose à trier — les lire en une fois, puis passer au schéma `public` (326), où l'audit du 18/05 n'avait vu qu'une partie.
