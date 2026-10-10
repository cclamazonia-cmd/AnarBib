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

# Paquet 5 — le reste, et la clôture du lot `api` (32 fonctions, 01/09)

Les 32 restantes n'avaient plus de forme commune à trier : bascules de réglage,
actes de diffusion, helpers d'écran, gestes sur soi. Lues en une fois.

## Aucune faille — et la doctrine du paquet 4 tient sur les cas extrêmes

Les deux actes les plus lourds du réseau sont les mieux gardés :
`fn_gazette_broadcast` et `fn_lettre_issue_send` — qui écrivent à *tout le
monde* — exigent `network_staff` actif, une garde plus étroite qu'admin réseau.
À l'autre bout, `fn_lettre_cancel`, `fn_lettre_request_optin` et
`fn_clear_my_signup_metadata_field` n'agissent que sur `auth.uid()`.

Entre les deux, la règle de propriété se vérifie encore :
`set_reader_message_inbox_state` charge le `library_id` **du message** avant de
garder dessus (`user_has_library_staff_role`) ; `suggest_next_reader_number` et
`get_last_assigned_reader_identity` gardent sur la bibliothèque passée ;
`merge_book_drafts` garde sans bibliothèque, comme `merge_draft_into_book` —
même raison, les brouillons sont un commun de catalogage.

`fn_assembleia_unvolunteer` mérite une note : elle n'a **aucune garde
explicite**, et c'est correct — son `WHERE user_id = auth.uid()` *est* la garde.
Se désister d'un volontariat qu'on n'a pas ne fait rien, ce qui est le bon
comportement ; ce n'est pas un refus muet au sens du paquet 3, parce qu'on ne
demande rien à personne. Un `DELETE` borné à soi n'a pas besoin d'un `IF`.

## Une observation, pas un défaut

Deux réglages de la même bibliothèque n'ont pas la même garde :
`fn_upsert_library_opening_hours` demande `user_can_manage_library`
(coordination) là où `fn_set_library_theme_active` se contente de
`user_can_engage_library`. C'est défendable — les horaires engagent la
bibliothèque auprès du public, le thème est cosmétique — mais l'écart n'est
écrit nulle part. Noté ici pour que la prochaine lecture n'y voie pas un oubli,
comme les 23 fausses alertes du paquet 1.

# Clôture du lot `api`

**138 sur 138 ont un verdict écrit.** Le bouclage a été vérifié par le second
chemin exigé par `DOC-RECENS-1` : la liste des fonctions lues confrontée à
`pg_proc` rend **zéro non-lue et zéro nom fantôme** — aucune fonction oubliée,
et aucune fonction citée qui n'existerait pas.

| Paquet | Critère | Lues | Trouvé |
|---|---|---:|---|
| 1 | sans garde visible | 24 | `get_due_date_for_loan` — cotisation d'autrui *(dormante)* |
| 2 | nominatives | 15 | `get_member_restriction` — gel global de tout UUID *(dormante)*, + le défaut du correctif |
| 3 | listes à paramètre de portée | 21 | six refus muets *(dont un atteignable par l'interface)* |
| 4 | écritures sur objet | 45 | — |
| 5 | le reste | 32 | — |

**Deux fuites réelles, six silences, zéro sur les 77 écritures et réglages.**
Les deux fuites étaient **dormantes** : l'une attendait qu'une bibliothèque
active les cotisations, l'autre qu'un premier gel réseau soit posé. La leçon du
lot tient en une phrase — *la question utile n'est pas « est-ce exploitable
aujourd'hui ? » mais « qu'est-ce qui l'armerait ? »*, car la réponse est
souvent une case à cocher dans un écran de configuration.

Et le motif qui revient dans les trois prises : **une garde qui vérifie une
relation que la requête suivante n'utilise pas** — dans la fonction d'après
(paquet 1), deux blocs plus haut (paquet 2), ou pour un rôle mais pas pour le
périmètre (paquet 3).

## Compte d'avancement du lot `api`

**138 des 138** fonctions du lot `api` ont un verdict écrit (24, 15, 21, 45, 32) ;
**deux fuites réelles** trouvées et corrigées, toutes deux dormantes — et un défaut introduit par le second correctif, attrapé par sa propre suite avant d'avoir servi. Le lot `api` est clos. Reste le schéma `public` — **326 fonctions**, dont l'audit du 18/05 n'avait vu qu'une partie. Les cinq critères éprouvés ici s'y transposent, dans le même ordre : ils ont produit trois prises sur `api` et ont fermé la liste sans trou.


---
---

# LOT `public` — 326 fonctions

Même méthode, mêmes critères. Premier tri : **69 sans garde visible** sur 326.

# Paquet 1 de `public` — les helpers sans garde (69 lues, 01/09)

## La prise principale : le foyer derrière la façade

Le matin même, le paquet 1 du lot `api` avait fermé `api.get_due_date_for_loan`,
qui lisait l'état de cotisation de n'importe quel UUID. **Le helper qu'elle
appelle, `fn_is_loan_blocked_by_dues`, est lui-même exposé à `authenticated`.**
On pouvait donc poser la même question directement à
`/rest/v1/rpc/fn_is_loan_blocked_by_dues`, sans passer par la façade corrigée.

*Corriger un chemin ne corrige pas ce qu'il traversait.* C'est `DOC-RECENS-1`
appliqué aux correctifs eux-mêmes, et c'est la leçon la plus utile de la
journée : après avoir fermé une fonction, il faut remonter ce qu'elle appelle.

Éprouvé en production avant écriture (elle répond à un tiers ni concerné ni
staff — elle ne consulte jamais `auth.uid()`), corrigé par une garde dans le
corps, et **vérifié après déploiement sur les trois chemins** : la personne
concernée répond, le staff de sa bibliothèque répond, un tiers reçoit `42501`.

## Un oracle exploitable aujourd'hui — sans case à cocher

`fn_painel_find_profile_by_lookup` gardait bien l'**accès**
(`can_manage_profile_from_my_libraries`) mais distinguait deux refus : « compte
trouvé, mais pas dans votre bibliothèque » d'un côté, « rien trouvé » de
l'autre. **Le premier message confirme qu'un compte existe dans le réseau.**
Toute personne inscrite pouvait tester une adresse e-mail et le savoir.

Contrairement aux quatre fuites précédentes, celle-ci n'était **pas dormante** :
il suffisait d'un compte. Dans un réseau de bibliothèques anarchistes, confirmer
qu'une adresse appartient à quelqu'un du réseau n'est pas une donnée technique.

C'est l'exact contraire de `api.resolve_reader_card` (paquet 4 du lot `api`),
qui rend **volontairement** le même motif dans les deux cas. Les deux formes
cohabitaient dans la même base ; celle-ci était la mauvaise. **CLAUDE.md
signalait cette fonction depuis mai** comme prioritaire pour l'audit
d'énumération — c'est fait.

## Quatre helpers internes qui n'avaient rien à faire sur la surface

Fermés à `authenticated` : `fn_membership_can_engage_circulation` (le même
oracle en pire — il distingue `restricted` de `dues`),
`fn_network_notify_event` (émission vers l'outbox réseau : exposé, il laissait
injecter des événements), `fn_purge_audit_draft_snapshots` (purge d'audit à
90 jours, déclenchable par n'importe qui), et
`get_library_contact_for_cooperation` — qui rend courriel, téléphone, WhatsApp
et adresse postale de **n'importe quelle** bibliothèque, sans aucune garde, et
qui **n'a aucun appelant** : ni front, ni fonction, ni policy. Même famille que
la fuite d'annuaire fermée en août pour `anon`.

Aucun n'est appelé par le front, aucun n'est cité par une policy : le `REVOKE`
ne casse rien. **326 → 322 fonctions exposées.**

## Un faux positif de mon propre recensement

Le relevé des appelants (`prosrc ~ 'fn_is_loan_blocked_by_dues'`) faisait
apparaître `api.confirm_pickup_v1`, qui est **SECURITY INVOKER** — un `REVOKE`
l'aurait cassée. Vérification faite : elle ne l'appelle pas, elle la **cite dans
un commentaire** et délègue à une fonction DEFINER. *Chercher un appel par le
texte du corps trouve aussi les commentaires.* La garde a tout de même été mise
dans le corps plutôt qu'un `REVOKE` — défense en profondeur, et `DOC-RPC-3`.

## Le reste des 69 : des gardes que le tri ne connaissait pas

Comme au paquet 1 du lot `api`, la majorité des « sans garde visible » en
avaient une, sous un nom que le regex ignorait : `fn_is_dedup_arbiter()` (les
fusions et démarquages de doublons), `my_access.can_access_painel`
(`fn_partner_search`, `fn_import_list_run_rows`),
`can_manage_profile_from_my_libraries`. Et trois fonctions sont des **stubs
dépréciés qui lèvent** — `fn_team_promote_to_coordenador`,
`fn_team_promote_to_administrador`, `fn_network_admin_request_removal` : la
bonne façon de retirer une fonction, elle refuse en expliquant par quoi elle est
remplacée au lieu de disparaître.

Les prédicats de configuration (`fn_library_*_mode`, `fn_library_has_*`,
`fn_reading_notes_enabled_for`…) n'ont pas de garde **par nature** : ils *sont*
la garde des policies, et ne disent rien qu'une page publique ne dise déjà.

**69 des 326 lues. Restent 257** — les fonctions à garde apparente, à passer par
paquets selon les mêmes critères.


# Paquet 2 de `public` — les nominatives (19 lues, 01/09)

Critère : un identifiant de **personne** en paramètre, autre chose qu'un booléen
en retour. Dix-neuf fonctions.

## Les écritures et les lectures sont gardées

`fn_list_membership_payments_for_user` filtre sur la bibliothèque active de
l'appelant·e ; les `fn_team_*` (promotion, suspension, retrait) gardent par
`user_can_manage_library` de la bibliothèque cible ; les `fn_v2_create_*`
refusent explicitement d'agir pour autrui (« vous ne pouvez créer que pour votre
propre compte ») ; les `fn_import_*` et `upsert_library_*` gardent par
coordination.

`fn_painel_reader_other_memberships` mérite une mention : elle ne révèle les
autres appartenances d'une lectrice **que** si un partenariat porte le droit
« transparence ». Une observation cependant, notée sans être corrigée : sans ce
droit, les colonnes sont nulles mais **la ligne existe** — on apprend donc le
*nombre* d'autres appartenances, sinon lesquelles. C'est peut-être voulu (le
champ s'appelle `enriched`), mais ce n'est écrit nulle part.

## La prise : quatorze sœurs de l'oracle d'existence

`fn_painel_get_profile_by_id` distinguait « compte trouvé, mais pas dans votre
bibliothèque » de « rien trouvé » — **la jumelle exacte** de celle corrigée au
paquet 1. J'avais corrigé une fonction sans chercher ses sœurs.

Cherchées par le MOTIF, il y en avait une deuxième
(`fn_attach_received_asset_record`, sur un **bigint séquentiel** : en
incrémentant on compte les fonds reçus dans le réseau), puis **douze de plus**
quand la suite de test a cherché le message **sans ses accents** — toute la
famille `fn_import_*`, « Run % introuvable » contre « Run % nao pertence a esta
biblioteca », sur des identifiants séquentiels eux aussi : l'activité de
catalogage des autres bibliothèques.

*Chercher un texte dans une base multilingue doit couvrir les variantes
d'accentuation.* Le « second chemin » était lui-même incomplet — et c'est le
test, en cherchant plus large que moi, qui l'a montré.

Les quatorze sont corrigées par substitution vérifiée (`20260901091431`), sans
qu'aucun corps ne soit recopié. Gardé par
`tests/sql/b14_oracle_existence_forme_tests.sql`, qui vérifie la **forme** —
donc attrapera la quinzième — et dont le T3 garde la doctrine inverse là où elle
est écrite : `api.resolve_reader_card` doit continuer de rendre deux fois le
même motif.

## Ce que cette migration a coûté — trois rouges sur `main`

Il faut l'écrire, parce que c'est la partie instructive.

| Rouge | Cause réelle | Ce que j'avais fait |
|---|---|---|
| 1 | `DEFAULT 'both'` omis en **recopiant** le corps d'une fonction | recopié un corps pour changer trois mots |
| 2 | (le même correctif, poussé **sans être éprouvé**) | supposé la cause au lieu de la vérifier |
| 3 | une suite existante assertait le **libellé** du message changé | pas cherché qui assertait ces messages |

Le troisième n'était visible que dans le log du run — fourni par Xavier — qui
dit exactement : *« T10 une source d'une AUTRE bibliotheque est refusee :
mauvaise erreur Source 3 introuvable »*. Les quatre suites `B14` y passaient
toutes ; c'est une suite d'août qui tombait.

Deux règles en sont sorties, au REGISTRE sous `DOC-MSG-1` : **un message
d'erreur est un contrat** (chercher qui l'asserte avant de le changer), et **ne
pas recopier un corps de fonction** (partir de `pg_get_functiondef`). Plus une
troisième, qui est la vraie : *une cause certaine se vérifie quand même* — elle
l'était, et il en restait une autre derrière.

**88 des 326 de `public` lues** (69 + 19). Restent 238.


# Paquet 3 de `public` — les listes à paramètre de portée (57 lues, 01/09)

Critère qui avait payé côté `api` : une liste rendue à partir d'un paramètre de
portée. Cinquante-sept fonctions.

## Aucune fuite

Les portées sont respectées partout : les `fn_list_*(p_library_id)` et
`fn_search_library_books` gardent sur *la* bibliothèque passée ; les
`list_*`/`suggest_*` de dédoublonnage lèvent sur le rôle de catalogage ; les
deux fonctions de dépôt de garantie — appelées par un `p_emprestimo_id`
séquentiel, donc la forme à risque — filtrent bien par
`(e.user_id = auth.uid() OR user_can_engage_library(d.library_id))` : on ne lit
le montant et le moyen de paiement que de son propre dépôt, ou en tant que staff.

**Cinq faux positifs de mon détecteur**, et la distinction mérite d'être
écrite. `search_authors_by_name`, `suggest_author_duplicates`,
`suggest_author_book_matches`, `suggest_subject_duplicates` et
`suggest_duplicates_for_fields` portent bien un `RETURN;` nu — mais après un
contrôle d'**entrée** (« requête vide », « aucune forme normalisée à
comparer »), pas après un contrôle de **droit** : leur garde d'appelant, elle,
lève. *Un `RETURN;` qui suit un paramètre vide est légitime ; un `RETURN;` qui
suit un refus ne l'est pas.* Le motif seul ne suffit pas à trancher, il faut lire
ce qui précède.

## Une question de doctrine, posée plutôt que tranchée

Quatre fonctions mettent leur garde **dans le `WHERE`** plutôt que dans un `IF` :

| Fonction | Garde |
|---|---|
| `fn_list_library_request_invitations` | `where fn_caller_is_network_admin()` |
| `fn_list_orphan_library_mentions` | idem |
| `fn_network_library_metrics` | `where fn_current_user_can_view_network_metrics()` |
| `fn_network_list_library_requests` | `where fn_current_user_can_review_library_requests()` |

Un appel non autorisé y rend donc **zéro ligne au lieu d'une erreur** — la forme
que le paquet 3 du lot `api` a corrigée sur six fonctions au nom de
`DOC-SILENCE-1`.

**Mais ici, c'est délibéré et écrit.** `fn_list_orphan_library_mentions` porte le
commentaire : « *Garde DANS le where : un appel non autorisé rend zéro ligne
plutôt qu'une erreur, comme fn_list_library_request_invitations.* » Ce n'est pas
un oubli, c'est un choix, cohérent entre les quatre.

Je ne l'ai donc **pas corrigé** : contrairement aux six du lot `api` — qui ne
disaient nulle part pourquoi elles se taisaient — celles-ci relèvent d'un
arbitrage que le projet a déjà rendu une fois. Les deux positions se défendent :

* *pour le silence* — la garde dans le `WHERE` compose avec les vues et les
  policies, et un écran réservé aux admins réseau n'atteint jamais ce chemin
  (comme `ReportsPanel`, ces quatre-là sont servies derrière la garde stricte de
  `RedePage`) ;
* *contre* — `fn_network_library_metrics` vide se lit « le réseau n'a aucune
  bibliothèque » et `fn_network_list_library_requests` vide se lit « aucune
  candidature n'attend ». Ce sont des phrases fausses, et c'est exactement le
  reproche fait aux rapports de qualité au paquet précédent.

**À trancher collectivement** : soit ces quatre rejoignent la règle du paquet 3
(un refus se dit), soit `DOC-SILENCE-1` gagne une exception écrite pour les
gardes en `WHERE`. Ce qu'il ne faut pas, c'est que les deux formes continuent de
cohabiter sans que le choix soit noté quelque part.

**138 des 326 de `public` lues** (69 + 19 + 50). Restent 188.

> **Correction du compte, faite le jour même.** J'avais d'abord écrit « 145 des
> 326, restent 181 », en additionnant les trois paquets comme si leurs critères
> s'excluaient. Ils ne s'excluent pas : sept fonctions relevaient de deux
> critères à la fois et ont donc été comptées deux fois. Le chiffre qui ne se
> discute pas est celui du **reste mesuré** — 188 fonctions n'avaient pas encore
> été passées — et c'est de lui qu'on déduit les lues, jamais l'inverse. Une
> somme de paquets est une estimation ; un reste compté est une mesure.

---

# `public`, paquet 4 — ce qu'un numéro suivant raconte du fonds

Les 188 restantes ont été retriées, cette fois avec le **vocabulaire réel des
gardes** : au lieu de deviner une liste de noms de prédicats, on extrait par
introspection les appels figurant en position `IF NOT <appel>` dans les corps
existants — **21 prédicats**, dont six que mes listes écrites à la main avaient
manqués aux paquets précédents (`fn_is_dedup_arbiter`,
`my_access.can_access_painel`, `resolve_managed_library_id`,
`user_can_manage_library_notifications`,
`can_manage_library_document_governance`,
`fn_current_user_can_access_network_dashboard`). Les quatre faux positifs des
paquets précédents venaient tous de là : **un recensement qui part d'une liste
inventée mesure la liste, pas le code** (`DOC-RECENS-1`).

Reste après ce tri : **39 fonctions sans garde connue**. Lues une à une, elles
donnent deux non-défauts et quatre cas à traiter.

## Deux qui gardent, à leur manière

`fn_network_dashboard_summary` appelle
`fn_current_user_can_access_network_dashboard()` et lève `42501` — garde en
bonne et due forme, simplement invisible à un tri par noms.

`fn_network_get_library_request` garde **dans le `WHERE`** : cinquième membre de
la famille du paquet 3, et cinquième argument pour la question de doctrine
laissée ouverte ci-dessus.

## Deux fuites, et un piège évité de justesse

| Fonction | Ce qu'elle donnait à n'importe quel compte |
|---|---|
| `fn_next_tombo(uuid)` | le **prochain numéro d'inventaire** d'une bibliothèque : son préfixe donne la convention de cotation, et le numéro lui-même donne **le nombre d'exemplaires déjà catalogués**. Appelée en boucle sur les bibliothèques du réseau, elle rend la volumétrie comparée des fonds — que rien ne publie par ailleurs, et que certaines ont de bonnes raisons de ne pas donner |
| `link_book_contributors_to_authors(bigint)` | aucune garde, **et elle écrit** : réattribuer les contributeur·rices de n'importe quelle notice de n'importe quelle bibliothèque |

Le réflexe acquis sur le lot `api` — révoquer — aurait cassé deux écrans. Le
contrôle des appelants, fait **avant** d'écrire quoi que ce soit, montre que ces
deux-là sont appelées directement par le catalogage
(`ExemplarDraftForm.jsx`, `BookDraftForm.jsx`). C'est exactement le piège de
`api.confirm_pickup_v1` au paquet 1 : un `REVOKE` y remplace un refus lisible
par un écran mort. `DOC-RPC-3` tranche — **le refus vit dans le corps, pas dans
le droit** — et c'est une garde qu'elles ont reçue.

Deux autres n'ont, elles, aucun appelant qui parle en session :
`fn_recompute_serial_holdings` (quatre appelantes, toutes des RPC `api.*` déjà
gardées) et `fn_backup_heartbeat_status` (consommée par `health-probe`, en
`service_role`). Pour celles-là le droit **est** le bon endroit : révoquées.

**La leçon de ce paquet n'est pas « garder » ni « révoquer », c'est que le choix
entre les deux se lit chez les appelants, jamais dans la fonction seule.**

## Ce que l'épreuve a apporté

Migration `20260901101901`, éprouvée en production en transaction annulée dans
les **deux** sens — un seul des deux ne prouvait rien :

| Sous le JWT de… | `fn_next_tombo` | `link_book_contributors_to_authors` |
|---|---|---|
| un lecteur sans rôle | refusée (42501) | refusée (42501) |
| un membre du staff | `CCLA.2026.92` | passée |

Puis le fichier entier, plus sa suite, toujours en transaction annulée :
`B14_GARDES_ECRITURE OK : 4/4`. Production vérifiée intacte après coup — une
migration appliquée à la main casserait la CI pour tout le monde.

La suite `b14_gardes_ecriture_tests.sql` tient **deux invariants de sens
opposé** : deux fonctions gardées mais laissées exécutables, deux fonctions
fermées. C'est délibéré, et c'est ce qui rend la suite utile : un correctif qui
« uniformiserait » les quatre casserait forcément l'un des deux.

**177 des 322 exposées lues.** Restent **145** — à ne pas confondre avec le 145
erroné de l'encadré ci-dessus, qui comptait des lues.

---

# `public`, paquet 5 — le décalage n'était pas dans les fonctions

Ce paquet cherchait, parmi les fonctions qui **écrivent** et portent une garde,
le décalage classique entre l'objet gardé et l'objet écrit : celui de la faille
exemplaires/holdings de juillet, où un exemplaire MLEG pendait au holding d'une
autre bibliothèque.

## Les fonctions sont saines — et se ressemblent

Lues une à une, elles suivent toutes la même forme, la bonne : **la garde se
calcule à partir de l'objet lu, jamais d'un paramètre.**
`fn_partnership_accept` lit le partenariat puis vérifie la coordination de la
bibliothèque *destinataire* ; `fn_partnership_break` accepte l'une ou l'autre
des deux parties ; `fn_team_ratify_invitation` déduit la bibliothèque de
l'invitation, et refuse en plus que la personne visée ratifie sa propre
promotion. `fn_record_deposit` et `fn_record_membership_payment` vont plus loin :
**elles n'acceptent aucune bibliothèque en paramètre**, elle est déduite de la
session — il n'y a donc aucun décalage possible, puisqu'il n'y a qu'une
bibliothèque dans toute la fonction.

Et les deux `fn_v2_create_*_by_holdings`, dont le tri automatique ne voyait
qu'un contrôle métier (`fn_library_has_circulation`), portent en fait la garde
d'un geste de lecteur·rice : *« você só pode criar pedidos para sua própria
conta »*. C'est la bonne garde pour ce geste-là — pas un manque.

## La prise : `api.my_access` répond à deux questions comme si c'en était une

Le décalage n'était dans aucune fonction. Il était dans la vue qu'elles
interrogent toutes.

| Colonne | Question réellement posée |
|---|---|
| `can_access_painel` | « as-tu un rôle staff **quelque part** ? » (`has_any_staff_membership OR is_network_admin`) |
| `library_id` | « quelle est ta bibliothèque **principale** ? » (`ORDER BY is_primary DESC, created_at, slug LIMIT 1`) |

**Trente-sept fonctions lisent ces deux colonnes ensemble, dont vingt-quatre qui
écrivent** : toute la circulation (`fn_v2_*`), tout l'argent (`fn_record_*`,
`fn_refund_deposit`, `fn_retain_deposit`), tout l'import. Elles vérifient
`v_actor.library_id` et n'ont aucun moyen de savoir que l'autorisation vient
d'ailleurs.

Une personne bibliothécaire à A et **simple lectrice** à B, avec B pour
bibliothèque principale, obtenait le panneau de B.

### Démontré, pas supposé

En transaction annulée sur la production, en armant le cas — l'adhésion
lectrice désignée principale :

| | `library_slug` | `can_access_painel` |
|---|---|---|
| état sain d'aujourd'hui | `blmf` | `true` |
| **défaut armé, vue d'alors** | **`btl`** | **`true`** |
| défaut armé, vue corrigée | `blmf` (`role=librarian`) | `true` |

Mesuré : **une** personne cumule aujourd'hui un rôle staff dans une bibliothèque
et une adhésion non-staff dans une autre. Elle est sauve par le tri — son
adhésion staff porte `is_primary`. Ce qui l'armerait n'est pas une attaque :
c'est **désigner l'autre bibliothèque comme principale**, un geste ordinaire
offert par l'interface. Zéro personne exploitable, un clic pour le devenir.

### Le correctif ne peut rien casser, par construction

L'adhésion effective **préfère une adhésion staff** (`is_staff DESC` avant
`is_primary DESC`), et `can_access_painel` se calcule sur **cette** adhésion.
Les deux ensemble sont *équivalents* à l'ancien calcul : si un rôle staff existe
quelque part, le nouveau tri garantit que l'adhésion effective est celle-là.
Personne ne perd un accès — non par chance mesurée, mais par construction. La
mesure le confirme quand même : sur 14 personnes actives, **zéro** voit sa
bibliothèque changer.

## La forme à imiter, trouvée dans le même paquet

`resolve_managed_library_id` était déjà immunisé, et dit pourquoi : quand il
prend la bibliothèque dans `my_access`, il **revérifie**
`user_can_manage_library()` dessus au lieu de lui faire confiance. Les
vingt-quatre autres font confiance. *Une valeur qui vient d'une vue de session
n'est pas une autorisation ; c'est une candidature.*

## Mon propre tri était trop étroit — refermé par le second chemin

Ce paquet a d'abord listé **53** écritures gardées, à partir d'une liste de douze
prédicats. L'introspection du vocabulaire réel en donne **67** : quatorze de
plus, plus huit que les recouvrements masquaient — vingt-deux fonctions
supplémentaires, gardées par `user_can_manage_library`,
`can_manage_library_circulation_policies`, `fn_caller_is_staff`,
`can_manage_library_regulation_documents`, `can_manage_library_contact_profile`.
**C'est exactement le défaut que le paquet 4 venait de corriger, refait un paquet
plus tard.** Le contrôle par un second chemin ne dispense pas de le refaire à
chaque tri : il n'est pas acquis une fois pour toutes.

Les vingt-deux sont saines quant au décalage garde/objet, mais l'une des gardes
mérite un constat à part.

## Un écart de doctrine, mesuré et laissé à décider

| Geste destructeur | Garde | Qui peut |
|---|---|---|
| `merge_book`, `merge_author` | `fn_is_dedup_arbiter()` | admin réseau **ou coordenador** |
| `merge_serial`, `mark_serials_not_duplicate`, `unmark_serials_not_duplicate` | `fn_caller_is_staff()` | **librarian** ou coordenador |

Le chantier DOUBLONS P4 avait tranché : *l'arbitrage destructeur est réservé à
la coordination*. Les périodiques, livrés le 27/08, n'ont pas repris cette
décision — leur fusion accepte le rôle `librarian`. **Quatre personnes** sont
aujourd'hui `librarian` sans être `coordenador` : elles ont sur les revues un
pouvoir de destruction que la même doctrine leur refuse sur les livres.

Je ne l'ai **pas corrigé** : ce n'est pas une fuite (ce sont des membres du
staff du réseau), c'est un arbitrage de gouvernance déjà rendu ailleurs, et
l'appliquer retirerait un pouvoir à quatre personnes sans les prévenir — ce que
ce projet refuse de faire dans un déploiement automatique. **À trancher
collectivement**, comme la question des gardes en `WHERE` du paquet 3.

*(L'enjeu pratique est petit aujourd'hui — 4 périodiques en base — et c'est le
bon moment pour décider, avant qu'il ne le soit plus.)*

---

# Les deux questions ont été tranchées le jour même

Les deux points laissés ouverts par les paquets 3 et 5 ont été posés en formulaire
et décidés le 01/09/2026.

## 1. Les gardes en `WHERE` rejoignent `DOC-SILENCE-1`

**Décidé : on aligne.** Les cinq fonctions lèvent désormais `42501` au lieu de
rendre une liste vide.

La forme du correctif n'est pas celle qu'on attendait. Ces cinq sont en
`LANGUAGE sql` : pas de bloc `IF` possible, et les convertir en `plpgsql`
demanderait de réécrire cinq corps pour n'y changer qu'une garde — ce que
`DOC-MSG-1` interdit depuis qu'il a coûté trois rouges. On garde donc le `WHERE`,
avec un **prédicat levant** (`fn_assert_*`), substitué depuis
`pg_get_functiondef`.

**Ce qui a été vérifié avant d'y compter** : un prédicat levant dans un `WHERE`
se déclenche-t-il quand la relation est **vide** ? C'est le seul cas qui compte.
Mesuré sur deux tables temporaires : `table_vide=LEVEE`, `table_pleine=LEVEE`.
**La limite est écrite parce qu'elle est réelle** — cela dépend du plan choisi.
D'où une suite qui **appelle** les cinq fonctions plutôt que de relire leur
définition : le jour où un plan change, le test rougit.

**Le piège symétrique**, plus dangereux que le défaut lui-même : dans
`list_catalog_libraries` et `fn_team_list_invitations`, le même prédicat
**élargit** un accès (« … OR admin réseau »). Une substitution par motif y aurait
transformé la navigation ordinaire en erreur. La liste corrigée est nominative,
et une garde de fin refuse la migration si un `fn_assert_` apparaît dans ces
deux-là.

### Ce que cette correction a coûté — un quatrième rouge, et une règle élargie

`sql-tests` est passé au rouge sur ce commit. Deux suites vérifiaient qu'un
compte non autorisé reçoit **zéro ligne** — `mentions_orphelines_tests.sql` T10
et `invitation_claims_lot2_tests.sql` T18 : exactement le comportement que la
décision retirait.

J'avais pourtant appliqué `DOC-MSG-1` : `grep -rn "SQLERRM" tests/sql/` pour
vérifier qu'aucune suite n'assertait les **messages**. Je ne l'ai pas fait pour
le **comportement**. *Passer de « rend du vide » à « lève » casse tout autant ce
qui l'atteste, et se cherche de la même façon.* La règle a été élargie en
conséquence : avant de changer le comportement observable d'une fonction — son
message, sa valeur de retour, ou le fait même de lever — chercher qui l'observe.

Le correctif a été poussé après avoir vérifié que **tous** les autres appels de
ces deux fonctions (lot2 T14–T17, lot3a T6) tournent sous JWT d'admin réseau —
pour ne pas enchaîner un second rouge sur une seconde supposition. Le log de CI,
lu ensuite, l'a confirmé sans écart : deux suites rouges, les deux corrigées, et
les trois nouvelles suites du jour vertes.

## 2. L'arbitrage des périodiques rejoint celui des livres — après préavis

**Décidé : on aligne, en prévenant.** Les trois fonctions passent à
`fn_is_dedup_arbiter()`, avec le libellé de refus déjà employé par `merge_book`.

Cataloguer une revue et **signaler** un doublon restent ouverts au catalogage :
c'est la moitié de la décision, et elle suit DOUBLONS P8 (« le test 1 garde
l'OUVERTURE du geste »). Repérer un doublon et trancher un doublon sont deux
actes différents.

**La migration est écrite, éprouvée et volontairement non poussée** : elle retire
un pouvoir à quatre personnes nommées, et le dépôt a déjà posé la règle à propos
des identifiants de lecteur·rice — *changer quelque chose qui appartient à
quelqu'un sans le lui annoncer n'a pas sa place dans un déploiement automatique.*
Le préavis, rédigé en pt-BR (la langue des quatre), attend son envoi. Détail dans
`docs/journal/arbitrages/DECISION_arbitrage_periodiques_2026-09-01.md`.

> **Ce que cet écart enseigne, et qui dépasse les périodiques** : une décision
> prise dans un chantier ne se propage pas toute seule au chantier suivant. Elle
> était écrite, appliquée à trois fonctions, gardée par une suite — et trois mois
> plus tard un nouveau domaine du même modèle (une autorité, ses doublons, sa
> fusion) est né sans elle. Aucune relecture ne l'aurait attrapée : le code des
> périodiques est cohérent avec lui-même. Seule une question posée à l'ensemble —
> *qui peut détruire quoi ?* — pouvait faire apparaître la divergence.

---

# `public`, paquet 6 — ce qui trahit n'est pas le mot, c'est l'ordre

Le paquet 2 avait fermé quatorze oracles d'existence en cherchant le **motif du
message** : d'abord « não pertence », puis la même chose sans les accents. Ce
paquet en trouve **neuf de plus**, et aucune ne dit « pertence ». Elles disent
« Acesso restrito », « Você não tem permissão », « Este empréstimo pertence a
outra pessoa ».

**Chercher un vocabulaire ne trouve que ce qui parle la même langue.**

## Le critère qui les atteint

Il est structurel, et il se mesure : **un test d'existence placé avant le
contrôle de droit**, sur un identifiant qu'on peut deviner. Relevé en comparant,
dans chaque corps, la position du premier refus « ça n'existe pas » et celle du
premier refus « tu n'as pas le droit », sur toute la surface exposée à
`authenticated`. Seize fonctions dans ce cas, dont **neuf sur un identifiant
séquentiel**.

*Le paquet 2 cherchait un mot ; il fallait chercher un ordre.* C'est
`DOC-RECENS-1` d'un cran plus haut : là-bas, l'inventaire se croyait complet
parce qu'il partait d'une liste de noms ; ici, il se croyait complet parce qu'il
partait d'une liste de mots.

## Pourquoi on n'inverse pas l'ordre

Le remède évident — garder d'abord, lire ensuite — est **impossible** : la garde
porte sur la bibliothèque **de l'objet**, qu'il faut donc avoir lu pour la
connaître. C'est même la bonne forme, celle que le paquet 5 a désignée comme
modèle (`fn_import_set_profile` garde sur `v_run.library_id`, pas sur une
bibliothèque de session).

On unifie donc ce que les deux refus **disent**, et l'identifiant sort du
message : le rendre est déjà une confirmation qu'on l'a lu.

| Fonction | Identifiant | Ce qu'on pouvait distinguer |
|---|---|---|
| `fn_confirm_digital_asset_rights` | `bigint` | l'asset existe / vous n'y avez pas droit |
| `fn_publish_digital_asset_from_resource` | `bigint` | idem, sur les ressources |
| `fn_attach_received_asset_record` | `bigint` | *(troisième message resté du paquet 2)* |
| `fn_import_set_adapter_overrides` | `bigint` | le run existe / il est d'une autre bibliothèque |
| `fn_import_set_profile` | `bigint` | idem |
| `fn_set_circulation_limits` | `bigint` | le jeu de règles existe / il est d'ailleurs |
| `discard_exemplar` | `bigint` | l'exemplaire existe / il est d'ailleurs |
| `fn_v2_schedule_emprestimo_return` | `bigint` | l'emprunt existe / il est à quelqu'un d'autre |
| `fn_v2_clear_emprestimo_return_schedule` | `bigint` | idem |

## Une correction du paquet 2 était à moitié faite

`fn_attach_received_asset_record` a été corrigée **le matin même** : deux de ses
trois refus unifiés. Le troisième — « Acesso restrito ao coordenador da
biblioteca detentora » — est resté, et **un seul suffit à rouvrir l'oracle**. La
suite écrite ce matin passait au vert, parce qu'elle demandait « le motif a-t-il
disparu ? ».

La bonne question est : **reste-t-il deux refus distinguables ?** C'est celle que
pose `oracle_existence_ordre_tests.sql`. *Une fonction corrigée n'est pas une
fonction close.*

## Un défaut de ma substitution, attrapé à l'essai à blanc

Ma première version remplaçait les motifs **globalement** sur les neuf fonctions.
`fn_publish_digital_asset_from_resource` et `fn_confirm_digital_asset_rights`
partagent le refus « Acesso restrito ao coordenador da biblioteca detentora »
mais **pas leur objet** : l'une parle d'un « Recurso digital », l'autre d'un
« Asset ». L'unification globale aurait fait dire à la première le message de la
seconde — un refus unifié, mais sur le mauvais nom. Corrigé en substitution
ciblée par fonction, avant écriture, parce que l'essai à blanc rend les neuf
corps et qu'on les relit.

## Ce qui n'est pas touché, et pourquoi

* **les identifiants `uuid`** (`fn_partnership_accept`, `update_exemplar_labels`,
  `api.resubmit_membership`) : deux refus distincts y sont sans portée, un uuid
  ne se devine pas. Les corriger serait du bruit — et une suite qui rougit sur
  des cas sains est une suite qu'on cesse de lire ;
* `fn_v2_mark_emprestimo_return_missed` : ses refus sont des refus de **rôle**,
  pas des tests d'existence ;
* le message de rôle de `discard_exemplar` : il tombe **avant** toute lecture, il
  ne dit donc rien sur l'existence de l'exemplaire.

## Vérification

`DOC-MSG-1` appliqué dans sa forme élargie du matin — aux messages **et** au
comportement : `grep` sur `tests/` et sur le front pour les huit libellés
touchés, **aucune assertion**. Le front traduit par `localizeError` sans liste
blanche : ces textes sont affichés tels quels, il n'y a pas de table de
correspondance à casser. Éprouvé en transaction annulée :
`ORACLE_EXISTENCE_ORDRE OK : 3/3`, production vérifiée intacte après coup.

## Le lot `api` repasse l'épreuve du nouveau critère

Le lot `api` avait été clos avec l'**ancien** critère — la recherche par motif.
Un critère neuf est une occasion de rouvrir ce qu'on croyait fermé, et c'est
exactement ce que `DOC-RECENS-1` demande : contrôler par un second chemin.

Le critère structurel a donc été rejoué sur les 138 fonctions d'`api`. Il en
sort **une seule** — `api.fn_assembleia_order_item` — dont l'objet est désigné
par un **uuid** ; son `integer` n'est qu'un rang d'affichage. Hors périmètre,
pour la même raison que les autres uuid.

**Le lot `api` tient donc aussi avec le nouveau critère.** Ce n'est pas un
résultat nul : c'est la seule façon de savoir qu'une clôture prononcée avec un
outil plus faible n'était pas prématurée.

---

# `public`, paquet 7 — fermer ce que personne n'appelle

## Les fonctions qui rendent une identité

Dernière classe, la plus sensible dans un réseau militant : les **lectures qui
rendent des données nominatives**. Sur 211 lectures exposées, 17 touchent
`profiles` ou `auth.users`, et **14 rendent une identité**.

Treize sont gardées — filtre sur `auth.uid()`, sur la bibliothèque active, ou
sur un rôle. `fn_list_membership_payments_for_user` est même exemplaire : elle
exige le panneau **et** filtre sur `mp.library_id = v_actor.library_id`, donc on
ne voit que les cotisations de sa propre bibliothèque.

La quatorzième n'a **aucune garde** :

> `fn_assembleia_facilitator_name(p_user_id uuid)` rend **prénom et nom** pour
> l'identifiant demandé — et ne répond que si la personne est facilitatrice
> d'assemblée. Elle joint donc une **identité** à un **rôle militant**.

Elle figure dans `CLAUDE.md` parmi les « fuites réelles fermées » du 17/08. Elle
l'avait été **pour `anon`**. Personne n'avait regardé `authenticated` — c'est
tout l'objet de `B14`, et c'en est le meilleur exemple : *une fuite fermée d'un
côté est une fuite ouverte de l'autre tant qu'on n'a pas nommé le côté.*

## Le critère « personne ne l'appelle », et son piège

Une RPC est appelée par le **front**, pas par une autre fonction : « sans
appelant en base » ne veut rien dire tout seul. Le critère utile croise les
deux — sans appelant en base **et** absente du dépôt.

* **227** fonctions exposées n'ont aucun appelant en base (ni fonction, ni
  policy, ni trigger) ;
* **53** n'apparaissent nulle part dans `src/`, `supabase/functions/`, `scripts/`.

**Ce critère aurait pu être faux, et j'ai failli le croire faux à tort.** Le
front appelle certaines RPC par une variable (`supabase.rpc(fn, …)`) : si un nom
était **construit** par concaténation, aucune recherche textuelle ne le verrait,
et une fonction vivante paraîtrait morte. J'ai donc cherché le motif —
`rpc(\`…${…}\`)`, `'fn_' + …` — et il n'existe pas : les `fn` dynamiques sont
toujours des littéraux choisis dans un ternaire, et les wrappers
(`callRpc(rpcName, …)`) reçoivent le nom en clair de leur appelant. Le critère
tient.

*Vérifier qu'un critère peut être faux fait partie du critère.*

## Ce qui est fermé, et ce qui ne l'est pas

**Les 53 ne sont pas révoquées.** Beaucoup sont des fonctions livrées qui
attendent leur écran — tout le prêt entre bibliothèques (`fn_v2_*_interbibliotecas`),
le parcours de candidature (`fn_review_library_request`). Les fermer casserait un
chantier en cours au lieu de protéger quoi que ce soit. C'est une décision de
priorité, pas un oubli, et la liste est ci-dessous pour qu'elle soit reprise.

**Cinq sont fermées** — celles que le dépôt lui-même désigne comme dépréciées ou
remplacées, et qui touchent toutes à l'identité :

| Fonction | Pourquoi |
|---|---|
| `fn_assembleia_facilitator_name` | aucune garde, identité + rôle militant |
| `fn_painel_find_profile_by_email` | remplacée par `…_by_lookup` |
| `fn_painel_get_profile_by_id` | idem |
| `fn_caller_is_administrador` | son corps ne fait que lever « deprecated: use `fn_caller_is_network_admin` » |
| `fn_team_promote_to_administrador` | « RPC dépréciée en D.8 » selon `teamMutations.js` |

> **Une ironie qui vaut leçon.** Les deux fonctions du panneau ont reçu **ce
> matin même** le correctif d'oracle du paquet 2 — messages unifiés, migration
> éprouvée, suite de tests. Elles ne sont appelées par personne. *Le correctif
> était juste ; la cible ne l'était pas.* Un audit qui trie par forme trouve de
> vrais défauts sur des fonctions mortes, et le seul moyen de le savoir est de
> demander qui appelle — question qu'il vaut mieux poser **avant** d'écrire la
> migration que trois paquets plus tard.

## Les 53 sans appelant — chantier à reprendre

`assign_book_to_work`, `fn_activate_approved_library_request`, `fn_book_due_dates`,
`fn_book_restricted_digital_state`, `fn_can_engage_library_for_storage`,
`fn_circle_member_count`, `fn_import_process_deposit`,
`fn_import_register_oai_source`, `fn_import_set_rows_review`,
`fn_is_cross_library_action`, `fn_library_has_staff_roles`,
`fn_library_publishes_catalog`, `fn_library_uses_governance`,
`fn_network_admin_request_removal`, `fn_network_dashboard_summary`,
`fn_network_discard_library_request`, `fn_network_get_library_request`,
`fn_network_library_metrics`, `fn_network_list_library_requests`,
`fn_notify_document_permission_request_now`, `fn_notify_library_request_now`,
`fn_required_governance_for_transition`, `fn_review_library_request`,
`fn_unarchive_transaction`, les huit `fn_v2_*_interbibliotecas`,
`get_book_primary_accessible_digital_asset_v2`, `list_authors_not_duplicate`,
`mark_authors_not_duplicate`, `merge_author_with_fields`,
`preview_library_notification`, `preview_merge_author`,
`set_library_regulation_document_active`, `set_library_theme_config_by_library_id`,
`suggest_authority_duplicates`, `suggest_subject_duplicates`,
`test_library_mail_channel`, `unlink_author_book`, `unmark_authors_not_duplicate`,
`upsert_library_notification_policies`, `upsert_library_notification_profile`,
`upsert_library_regulation_document`.

Trois questions à leur poser, dans cet ordre : *l'écran existe-t-il ailleurs
qu'ici ?* — *la fonction attend-elle un écran à venir ?* — *ou est-elle morte ?*
Les cinq fermées aujourd'hui sont celles dont le dépôt répondait déjà.

## Une garde en `WHERE` qui reste, et pourquoi

`fn_network_resolve_public_id` garde dans son `WHERE`, comme les cinq alignées ce
matin. Elle n'a **pas** été alignée, et son commentaire dit pourquoi : *« un
appelant sans droit obtient NULL, indiscernable de "numéro inconnu". Pas
d'oracle. »*

L'argument est différent de celui des cinq autres, et il tient : **une liste
vide affirme « il n'y a rien », une valeur nulle dit « pas de résultat »** — la
première est fausse pour qui n'a pas le droit de voir, la seconde est vraie dans
les deux cas. La décision du matin visait les listes qui mentent. Appliquer la
règle ici la transformerait en réflexe.

*Toutes les gardes en `WHERE` ne se valent pas : ce qui compte n'est pas la
forme du contrôle, c'est ce que le silence affirme.*

## Ce que ce paquet a coûté — un rouge, et le troisième volet d'une règle

`sql-tests` est passé au rouge sur la révocation. La suite en cause est
`b14_oracle_existence_forme_tests.sql`, **écrite le matin même**, dont le `T2`
exigeait que **les trois** fonctions restent exposées — dont
`fn_painel_get_profile_by_id`, que le paquet 7 venait de fermer.

**La faute n'est pas la révocation, c'est l'hypothèse du test.** Il supposait que
les trois servaient un écran ; deux n'en servent aucun. Il gardait donc d'une
fonction ce qui n'était vrai que d'une autre — transformant une propriété locale
en invariant global.

C'est la **troisième occurrence du même motif dans la journée** :

| | Ce qui a changé | Ce qui l'attestait |
|---|---|---|
| matin | un **message** de refus | `import_candidat_institutionnel_tests` T10 |
| midi | un **comportement** (vide → lève) | `mentions_orphelines` T10, `invitation_claims_lot2` T18 |
| après-midi | un **droit** (`EXECUTE`) | `b14_oracle_existence_forme` T2 |

`DOC-MSG-1` couvrait le premier, a été élargi au deuxième à midi, et gagne le
troisième ici. Sa forme complète : *avant de changer ce qu'une fonction **dit**,
ce qu'elle **rend**, ou ce qu'elle a le **droit** de faire, chercher qui
l'observe.* Pour les droits, la commande est
`grep -rn "has_function_privilege" tests/sql/` — faite cette fois, et une seule
suite était concernée.

Et un corollaire sur l'écriture des tests, que cette journée a payé cher : **un
test qui énumère plusieurs objets doit garder ce qui est vrai de chacun**, jamais
ce qui n'est vrai que du premier. Sinon il bloquera un jour un correctif juste —
et il faudra choisir entre défaire le correctif et défaire le test, ce qui est
exactement le moment où l'on cesse de croire aux tests.

---

# `public`, paquet 8 — agir ou lire pour autrui : rien à corriger

Critère de ce paquet : les fonctions qui **acceptent un identifiant de personne**
en paramètre. C'est la classe qui avait donné la prise du lot `api`
(`api.get_member_restriction`) — lire ou agir sur la chose de quelqu'un d'autre.

**19 fonctions** dans ce cas, dont 11 qui écrivent. Cinq ne citent même pas
`auth.uid()` : elles ne peuvent donc pas savoir qui appelle. C'est le signal le
plus fort du critère — et il produit ici deux faux positifs instructifs.

## Deux pierres tombales, et ce qu'elles apprennent au détecteur

`fn_team_promote_to_coordenador` et `fn_network_admin_request_removal` n'ont ni
`auth.uid()` ni prédicat. Elles ne gardent rien parce qu'elles **ne font rien** :

```
'collegiality_required: direct promotion to coordenador is disabled'
  HINT: Use fn_team_propose_invitation(…, 'coordenador'), then
        fn_team_ratify_invitation() by another staff member, then
        fn_team_accept_invitation() by the person concerned.
```

Ce ne sont pas des fonctions abandonnées : ce sont des **décisions de gouvernance
matérialisées dans le code**. La promotion directe à la coordination a été
désactivée au profit d'un parcours collégial en trois temps, et la fonction qui
la faisait a été remplacée par un refus **qui indique le chemin**. Idem pour le
retrait d'un·e admin réseau, renvoyé vers le vote à l'unanimité.

> **Ce que le détecteur doit apprendre** : une fonction dont le corps ne fait que
> lever est un faux positif structurel de *tout* critère « sans garde » — elle
> n'a rien à garder. Le paquet 4 avait déjà rencontré `fn_caller_is_administrador`
> sous cette forme. Un critère de sûreté doit exclure les pierres tombales, sinon
> il crie à chaque décision bien prise.

## Le modèle du schéma, et il est ici

`fn_painel_reader_other_memberships` rend les **autres rattachements** d'une
lectrice — l'information la plus sensible qu'un réseau de bibliothèques
militantes puisse détenir sur quelqu'un. Elle est construite en quatre temps :

1. l'appelante doit être staff de la bibliothèque **qui regarde** ;
2. la personne doit être rattachée à **cette** bibliothèque — sinon `RETURN`, sans
   rien dire ;
3. chaque autre rattachement n'est nommé que si **trois conditions cumulatives**
   sont réunies : partenariat **actif**, droit `transparence` **explicitement
   accordé** sur ce partenariat, et **consentement valide de la personne** ;
4. sinon la ligne est rendue avec toutes ses colonnes à `NULL`.

Le point 4 pourrait passer pour une fuite — le nombre d'autres rattachements
reste visible. Il ne l'est pas : le front le documente comme un choix, *« minimal
par défaut (compte sans identité), enrichi uniquement sous partenariat actif ∧
droit transparence ∧ consentement »*. L'écran dit donc « il y a autre chose, et
tu n'as pas le droit de le voir » — ce qui est **vrai**, et ce qui laisse à la
personne concernée la décision d'en dire plus.

*C'est la forme à imiter partout où une donnée appartient à quelqu'un : le
consentement n'est pas une case en plus de la garde, c'est un terme de la garde.*

## Résultat

**Aucune faille sur les 19.** Les quatorze qui citent `auth.uid()` comparent
toutes le paramètre à l'appelante ou passent par un prédicat de bibliothèque ;
`user_has_library_staff_role` prend un `p_user_id` parce que c'est un prédicat de
base, appelé avec `auth.uid()` par ses appelants.

Un paquet sans correctif n'est pas un paquet sans résultat : c'est ce qui permet
de dire que la classe est passée. Le lot `api` avait connu la même chose à son
paquet 5, et c'est le signe que la surface commence à converger.

---

# `public`, paquet 9 — la salle des machines

Dernière classe systémique : ce qu'un compte `authenticated` peut déclencher qui
appartient à l'**exploitation** — HTTP sortant (`pg_net`), secrets (`vault`),
mécanique cron, files de notification. C'est la classe de la toute première
fuite du projet : `fn_gazette_translate_call`, qui déclenchait l'API LLM
facturée depuis `/rest/v1/rpc/`.

## Le scan direct ne suffisait pas — le critère était le graphe

Le motif `vault\.|net\.http|cron\.` sur les corps exposés rend deux fonctions et
zéro vault. Mais `fn_send_weekly_report_now` lit ses secrets via un **wrapper**
(`fn_internal_get_vault_secret`) que ce motif ne voit pas dans l'appelante —
même leçon que le paquet 6 : *chercher un vocabulaire ne trouve que ce qui parle
sa langue*. Le critère refait est **transitif** : qui touche la machine, et qui
appelle qui la touche.

## Verdict : l'architecture est en couches, et les couches sont étanches

| Couche | Contenu | Exposée à `authenticated` ? |
|---|---|---|
| moteur | ~30 fonctions : `fn_dispatch_*`, `fn_enqueue_*`, `fn_cron_*`, `fn_internal_get_vault_secret`, `fn_gazette_*_call`, `fn_pseudonymize_token`, triggers d'outbox | **aucune** |
| métier | 44 fonctions qui *aboutissent* au moteur (partenariats, dépôts, adhésions, PEB, OAI, imports) | oui — et chacune porte la garde métier déjà auditée aux paquets 5 et 8 |
| exceptions | `fn_import_harvest_oai` et `fn_send_weekly_report_now`, seules à faire de l'HTTP **en direct** | oui — gardées sur la bibliothèque concernée, URL et secret venus du vault, jamais de l'appelant |

Les fonctions métier atteignent le moteur en tant que `SECURITY DEFINER` : le
droit d'EXECUTE du wrapper n'est jamais celui de l'appelant. C'est exactement la
bonne construction — le lectorat déclenche des *conséquences* (une notification
part quand un partenariat est accepté), jamais la *mécanique* (choisir quoi
envoyer, à qui, avec quel secret).

`fn_gazette_translate_call` est vérifiée **fermée**. La boucle du 17/08 est
bouclée des deux côtés.

## Aucune faille — mais rien ne le gardait

Un `GRANT` distrait sur `fn_internal_get_vault_secret` aurait donné **tous les
secrets du vault** — `service_role`, clés API, secrets webhook — à tout compte
du réseau, sans qu'aucun voyant ne rougisse. L'étanchéité tenait à la discipline,
pas à un test.

D'où `salle_des_machines_tests.sql`, **structurelle et non nominative** : le
critère « touche `vault.` dans son corps » se remesure à chaque passage et
attrape les fonctions qui n'existent pas encore. Seules les deux exceptions HTTP
sont nommées — c'est le sens d'une exception — et le T3 vérifie qu'elles gardent
leur garde : *une exception sans garde n'est plus une exception, c'est un trou.*
Le T2 vérifie aussi `PUBLIC`, parce que le défaut natif de Postgres accorde
EXECUTE à PUBLIC sur toute fonction neuve, et qu'une recréation sans REVOKE y
retomberait. Éprouvée en production : **4/4**.

---

# `public`, paquet 10 — les documents numériques : la chaîne est saine, son talon est le rangement

Dernière famille concrète : **ce qui donne accès aux fichiers** — accesseurs
d'assets, URLs signées, partages de numérisation PEB, et les policies RLS de
`storage.objects`, bucket par bucket (16 buckets, 8 publics, 8 privés).

## Une fausse piste, et ce qu'elle a appris

La policy SELECT de `pdf-restrito` n'admet que le staff (`can_access_catalogacao`),
alors que la RPC `get_accessible_digital_asset_by_id_v2` promet l'accès à toute
lectrice `conta_ativa` membre d'une bibliothèque détentrice. J'ai d'abord conclu
à une promesse cassée — un écran qui montre un PDF que le storage refuse de
servir.

C'était faux, et la vraie architecture vaut d'être écrite :

1. l'EF `read-digital-asset` appelle la RPC **avec le JWT de l'appelante** —
   c'est la garde SQL qui décide (`publico` / `conta_ativa` + rattachement) ;
2. si la RPC accorde, l'EF signe l'URL **en `service_role`**, TTL court —
   la policy storage n'est pas le portier du lectorat, **la RPC l'est** ;
3. la policy staff de `pdf-restrito` n'est que le second chemin, pour l'accès
   direct du catalogage.

Et l'EF pousse le soin jusqu'à masquer `source_url` d'un document restreint
servi depuis le stockage — la provenance d'un document restreint est elle-même
une information.

## Le PEB numérique : la propriété révocable

`fn_ill_signed_url` est un modèle : staff de la bibliothèque **réceptrice**
seulement, flux `transmis` exigé, et **revalidation du droit de partenariat au
moment de l'accès** — rompre le partenariat coupe l'accès aux reçus déjà
transmis (PARTNER-D5). Un droit qui ne se revalide pas à l'accès n'est révocable
que de nom.

Mesuré au passage : `digital_assets` ne peut recevoir que des ressources
*publiques* (`fn_publish_digital_asset_from_resource` refuse le reste) — le
dispositif PEB garde donc l'accès au *service*, pas des octets secrets, et c'est
cohérent.

## Le talon : le rangement, que rien ne gardait

La chaîne entière repose sur un invariant que personne n'avait écrit : **un
asset `conta_ativa` doit vivre dans un bucket non-public**. Catalogué par erreur
dans `anarbib-pdf-public`, il serait servi par l'URL publique du bucket — sans
RPC, sans EF, mondialement — et **rien ne casserait** : le parcours normal via
l'EF continuerait de fonctionner. Ce qui rend l'exposition silencieuse est
précisément que rien ne casse quand elle se produit. Même chose pour le flag
`public` d'un bucket restreint : une bascule, un clic de dashboard, tout le
contenu exposé.

D'où `documents_numeriques_tests.sql` : T1 aucun asset non-`publico` dans un
bucket public ; T2 les trois buckets restreints gardent `public = false` ; T3 la
RPC garde ses deux conditions — *l'EF signe tout ce qu'elle rend : sans elles,
elle signe pour tout le monde* ; T4 la revalidation du PEB reste en place.
Éprouvée en production : **4/4**.

## Deux observations, sans correctif

* Les **4 objets** de `anarbib-media-restricted` ne sont atteignables par
  personne : aucune policy SELECT, aucun asset ne les référence. Probable
  reliquat — à trier un jour, rien ne fuit.
* La policy de `pdf-restrito` ouvre la lecture directe au staff de **n'importe
  quelle** bibliothèque (`can_access_catalogacao` est global). Cohérent avec la
  confiance réseau du catalogage — le staff voit déjà tout le catalogue — mais
  c'est un choix, et il est maintenant écrit.

---

# `public`, paquet 11 — la passe de complétude, et la clôture

## Le complément des dix critères

Dix paquets thématiques ne prouvent rien tant qu'on n'a pas compté **ce
qu'aucun n'a lu**. Le complément — l'union des dix critères, inversée — rend
**24 fonctions**. Six étaient en réalité déjà lues et corrigées (le complément
mesure mes regex, pas mes lectures) ; les dix-huit autres, lues une à une, sont
**toutes gardées et de la bonne forme** — la garde calculée depuis l'objet lu.
La seule sans aucun contrôle, `fn_peb_authorized`, est un pur prédicat de
configuration : deux bibliothèques fédérées, circulation active. Rien de
personnel, rien de volumétrique.

## Le dernier schéma jamais regardé : `private`

Tous les paquets filtraient `public` et `api`. Or `authenticated` a `USAGE` sur
**`private`**, qui expose **6 fonctions `SECURITY DEFINER`** — servies au
travers des vues invoker d'`api` (le schéma n'est pas dans PostgREST : le grant
n'existe que pour ce chemin). Cinq sont des aides de catalogue anodines.

La sixième est **le dernier constat du lot** :

> `private.fn_cartography_network_rows` — le corps de la carte réseau — rendait
> **toutes** les entrées de cartographie, dont les **79 non publiques** (sur
> 187), à tout compte authentifié. L'inscription est ouverte : n'importe qui
> sait créer un compte. Et une entrée `statut_public = false` peut être **en
> attente de consentement** — la doctrine des mentions orphelines exige le
> consentement avant d'exposer un collectif, et cette carte l'exposait à qui
> savait s'inscrire.

Décision collective du 01/09 : **les entrées non publiques sont pour les membres
actifs.** Corrigé à la source (migration `20260901153019`), éprouvé chiffres à
l'appui — sans adhésion : 108 (les publiques) ; membre : 187 — et gardé par
`cartographie_reseau_membres_tests`, dont le T2 tient le bord opposé : un compte
sans adhésion voit *encore* la carte publique, car une garde qui montrerait
moins que la page visiteurs serait un écran cassé.

*Le dernier trou du lot n'était ni dans `public` ni dans `api` : il était dans
le schéma que la question « quelles fonctions de `public` et `api` ? » ne
pouvait pas voir. Un périmètre d'audit est une hypothèse comme une autre — la
passe de complétude sert aussi à l'éprouver.*

---

# CLÔTURE DE `B14`

La clôture à deux chemins (`DOC-RECENS-1`) est faite :

| Chemin | Résultat |
|---|---|
| dix critères thématiques | `api` 138/138 · `public` 315/315, chaque paquet documenté ci-dessus |
| complément des critères | **vide** après lecture des 24 |
| schémas hors hypothèse | `private` 6/6 lues · `ingest` 0 exposée (pas de `USAGE`) |

**Le bilan du lot entier — `api` + `public` + `private`, 459 fonctions :**

- **Fuites réelles corrigées** : `api.get_due_date_for_loan`,
  `api.get_member_restriction`, le foyer `fn_is_loan_blocked_by_dues`,
  `fn_next_tombo` (volumétrie des fonds), `link_book_contributors_to_authors`
  (écriture sans garde), la vue `my_access` (37 fonctions ouvraient le panneau
  de la mauvaise bibliothèque), 23 oracles d'existence (14 par motif + 9 par
  ordre), 5 fonctions mortes fermées dont une qui joignait identité et rôle
  militant, la carte réseau (79 entrées non publiques). Toutes **dormantes** —
  aucune trace d'exploitation.
- **Décisions collectives posées et tranchées le même jour** : les refus muets
  (alignés sur `DOC-SILENCE-1`), l'arbitrage des périodiques (aligné après
  préavis), la carte réseau (membres actifs).
- **Neuf suites de garde nées du lot**, toutes en CI — le lot ne s'est pas
  contenté de corriger, il a rendu chaque invariant regardable.
- **Ce que le lot a coûté, et appris** : quatre CI rouges, tous par la même
  faute sous trois formes — changer ce qu'une fonction dit, rend, ou a le droit
  de faire sans chercher qui l'observe. `DOC-MSG-1` porte désormais les trois
  volets, et `DOC-RECENS-1` deux corollaires (un recensement par vocabulaire ne
  trouve que ce qui parle sa langue ; une fonction corrigée n'est pas une
  fonction close).

L'advisor 0029 passe de 464 à 453 — et ce chiffre n'est plus un avertissement :
**chacune des 453 restantes a été lue, et sa raison d'être exposée est écrite.**
L'advisor signale une architecture qu'il ne peut pas connaître ; ce document la
connaît.

---

# Addendum du 02/09/2026 — le solde des 48 différées

L'échéance posée au lendemain de ce relevé (« tenable un mois, pas un
trimestre », GLB v17) a été soldée le 02/09, sur remesure complète et non sur
mémoire : 0 occurrence des 48 noms au dépôt (`src/`, `supabase/functions/`,
`scripts/`, balayage nominatif PEB compris), 0 appelant en base (fonctions,
policies, crons), et six suites qui en exercent 13 — **toutes en `postgres`**,
vérifié fichier par fichier après que le run 9186334 a montré ce que coûte une
convention d'appel déduite du test voisin.

**47 fermées** (migration `20260902104830`, REVOKE compté, gardes des deux
sens, suite `SOLDE_DIFFEREES`). Corps, gardes et suites intacts ; le grant
`service_role` explicite conservé ; restauration = un GRANT le jour où un
écran est réellement dû — l'arbitrage d'autorités (p9-p11) et
l'enregistrement de source OAI (geste H5, faisable en console `postgres`)
sont les premiers candidats.

**Une sortie du solde** : `fn_book_due_dates` est dans la liste nommée T10 de
`grants_herites_tests` — ouverte à `anon` par verdict écrit
(`AUDIT_execute_anon_2026-08-30.md`). Ouverte par décision, appelée par
personne : la contradiction entre les deux audits est réelle et se rejuge au
registre de B2 — un REVOKE de passage l'aurait tranchée en silence, contre un
test et contre une décision.

Avec ce solde, les trois questions posées plus haut aux 53 ont toutes leur
réponse écrite : 5 fermées le 01/09, 47 le 02/09, 1 rejugée ailleurs.

---

# Complément du 06/09/2026 — les seize RPC nées les 04–05/09

**6 septembre 2026** · base `uflwmikiyjfnikiphtcp` en lecture seule · photo du backlog du 06/09.

Le lint 0029 est passé de **399** (03/09) à **411** (06/09) : −3 avec la
suppression des homonymes de `public` (B7, `20260905132602`), **+16 fonctions
`SECURITY DEFINER` exécutables par `authenticated`** nées entre le 04/09 midi et
le 05/09 soir — trois chantiers d'une autre session : l'OPAC par œuvre (lots
1b à 4), la révision des lots importés, l'atelier ouvert aux œuvres, plus la
source « catalogue propre » de l'import. Les seize sont relevées par `oid`
décroissant (toute fonction créée après `fn_assembleia_facilitator_name`, 02/09)
et lues corps par corps, au **même critère** que les paquets du 01/09 : *que
peut demander une inconnue qui vient de s'inscrire ?*

## Verdict : aucune faille, deux limites fonctionnelles, une forme à noter

| Fonction | Garde lue dans le corps | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `api.fn_work_title_validate(p_work_id, p_lang, p_title)` | `fn_caller_is_staff()` en tête, sinon `forbidden` | rien (exception) | **justifiée** |
| `api.fn_work_titles_review_list(p_lang, p_limit)` | prédicat dans le `WHERE` : contributeur·rice réseau **ou** staff **ou** admin | une liste vide (refus muet, forme déjà notée au paquet 3) ; aucune donnée nominative — des titres d'œuvre et un nom d'autorité | **justifiée** |
| `public.fn_batch_reviews_list()` | admin réseau **ou** appartenance active `librarian`/`coordenador` (toute bibliothèque) | rien pour une inconnue ; pour un·e staff : les lots **de tout le réseau**, avec les prénoms et noms des staff qui ont demandé ou revu | **justifiée** — transparence entre staff, aucune lectrice exposée ; *limite fonctionnelle 1* ci-dessous |
| `public.fn_batch_review_verdict(p_review_id, p_verdict, p_notes)` | admin réseau seulement, puis `for update` et états contrôlés | rien | **justifiée** |
| `public.fn_batch_review_request(p_batch_id, p_message)` | admin **ou** `coordenador` actif (toute bibliothèque) ; lot ouvert, né d'un import, pas déjà demandé | rien pour une inconnue | **justifiée** — *limite fonctionnelle 2* : la coordination d'une bibliothèque peut demander la révision d'un lot **d'une autre** (le lot n'est pas rapproché de la bibliothèque de l'appelant·e) ; aucune donnée ne sort, l'effet est un tour de révision de plus chez l'admin |
| `public.fn_batch_review_report(p_batch_id)` | admin **ou** staff actif (toute bibliothèque) | rien pour une inconnue ; pour un·e staff : le rapport de conventions d'un lot de n'importe quelle bibliothèque (titres, doublons, auteurs non liés — des données de catalogue, pas de personnes) | **justifiée** — même transparence de catalogue que `fn_batch_reviews_list` |
| `public.dismiss_volume_group(p_group_key, p_reason)` | staff actif (toute bibliothèque), `42501` sinon | rien | **justifiée** |
| `public.group_books_as_volumes(p_items)` | idem | rien | **justifiée** |
| `public.suggest_volume_groups(p_max)` | idem | rien | **justifiée** |
| `public.set_work_uniform_title(p_work_id, p_title)` | idem, titre non vide, œuvre existante | rien | **justifiée** |
| `public.set_work_title(p_work_id, p_lang, p_title)` | idem, locale contrôlée | rien | **justifiée** |
| `public.search_works_for_link(p_q, p_limit)` | idem | rien (et la recherche ne rend que titres d'œuvre, nom d'autorité, compte d'éditions, années) | **justifiée** |
| `public.mark_works_not_same(p_a, p_b, p_reason)` | idem, deux œuvres distinctes | rien | **justifiée** |
| `public.suggest_split_works(p_max)` | idem | rien | **justifiée** |
| `public.merge_works(p_source, p_target)` | idem, deux œuvres existantes et distinctes | rien | **justifiée** |
| `public.fn_import_own_source()` | `my_access` (accès painel + bibliothèque) **et** `coordenador` ou admin ; n'écrit que pour la bibliothèque de l'appelant·e | rien | **justifiée** |

**La forme à noter.** Les neuf RPC de l'OPAC par œuvre portent la même garde
que `discard_book` et ses sœurs — *staff actif de n'importe quelle
bibliothèque* — et le même `HINT` (`error.catalog.discard.forbidden`). C'est
cohérent avec la doctrine du catalogue commun (une œuvre n'appartient à aucune
bibliothèque ; regrouper, fusionner, titrer sont des gestes de réseau) et avec
ce que le paquet 4 du 01/09 avait constaté sur les 45 écritures. Rien à fermer.

**Les deux limites fonctionnelles** ne sont pas des failles (aucune donnée de
personne, aucun geste sur un objet qu'un tiers ne verrait pas déjà), mais
elles méritent une ligne au backlog si la révision des lots se déploie à
plusieurs bibliothèques : (1) la liste et le rapport des lots sont
**transversaux au réseau** par construction ; (2) `fn_batch_review_request`
devrait vérifier que le lot appartient à la bibliothèque de la coordination
qui le demande — une condition de plus, `catalog_batches.library_id =
v_actor.library_id`, le jour où deux bibliothèques importent en même temps.

**Non concernées.** `api.fn_authority_object`, `api.report_incoherences_auteurs`,
`public.fn_authority_using_libraries`, `public.fn_library_uses_authority`,
nées aussi le 05/09, n'apparaissent pas au lint 0029 (pas exposées à
`authenticated`, ou pas DEFINER) : hors du périmètre de ce complément.

**Compte au 06/09.** 0029 = **411**, tous justifiés : **395** hérités des paquets
du 01/09 et **16** de ce complément (les seize sont bien dans la liste du lint,
vérifié nom par nom). L’arithmétique 399 (03/09) − 3 (B7) donnerait 396 : une
fonction héritée a perdu son `EXECUTE` entre le 03/09 et le 06/09 sans que ce
complément l’identifie — écart d’une unité, dans le bon sens, à relire au
prochain relevé. Le lint 0028 reste à **28**, la liste T10.


---

# Complément du 15/09/2026 — les huit RPC nées le 15/09

**15 septembre 2026, 23 h 30** · base `uflwmikiyjfnikiphtcp` en lecture seule · photo du backlog du 15/09 au soir (`fe0cedf1`).

Le lint 0029 est passé de **411** (06/09) à **419** (15/09) : **+8 fonctions
`SECURITY DEFINER` exécutables par `authenticated`**, toutes nées le 15/09 et
toutes dans `public` — deux chantiers d'une autre session : **un lot importé a
une bibliothèque de destination** (`20260915184154`, 19 h) et **E21, la
numérotation et le rangement d'une bibliothèque depuis l'écran et par lot**
(`20260915201252`, 22 h 15). Rien entre le 06/09 et le 15/09 : le gel de
Bologne a tenu. Les huit sont relevées par `oid` décroissant (toute fonction
créée après `api.fn_work_title_validate`, la dernière du complément du 06/09),
lues corps par corps dans `pg_proc.prosrc` **en production** — pas dans les
fichiers de migration — au **même critère** que les paquets du 01/09 : *que
peut demander une inconnue qui vient de s'inscrire ?*

## Verdict : aucune faille, la limite 2 du 06/09 se referme, une forme à corriger d'une ligne

| Fonction | Garde lue dans le corps | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `public.fn_batch_reassign_library(p_batch_id, p_library_id)` | `fn_caller_is_network_admin()` **en tête**, puis `FOR UPDATE`, lot `open`, bibliothèque existante, **refus si une révision est approuvée** (`fn_batch_review_status = 'approved'`) | rien (exception `admin_only`) | **justifiée** — écrit `owner_library_id` sur les brouillons vivants, remet `initial_copies_library_id` à nul (l'override lu en dernier par `publish_book_draft`), aligne la source compagne (`ingest.partner_catalog_sources.destination_library_id`) et trace le geste, nommé, dans les notes du lot |
| `public.fn_batch_owner_libraries()` | prédicat dans le `WHERE` : admin **ou** appartenance active `librarian`/`coordenador` (toute bibliothèque) | une liste vide (refus muet, forme déjà notée) ; pour un·e staff : par lot, la bibliothèque propriétaire et le nombre de brouillons — **aucune donnée de personne** | **justifiée** — même transparence de réseau que `fn_batch_reviews_list` (limite fonctionnelle 1 du 06/09, assumée) |
| `public.fn_library_numbering_get(p_library_id)` | `user_has_library_staff_role(auth.uid(), p_library_id)` **ou** admin — **le staff de CETTE bibliothèque** | rien (exception `staff_only`) | **justifiée** — lecture seule ; les deux `EXCEPTION WHEN OTHERS` autour de `fn_next_tombo` et `next_bib_ref` rendent `NULL` pour dire « pas de série », c'est leur rôle |
| `public.fn_library_numbering_set(p_library_id, …)` | **coordination active de CETTE bibliothèque** ou admin ; `FOR UPDATE` ; préfixe obligatoire, ≤ 24 caractères, séparateur ≤ 3, **jokers `%` et `_` interdits** (`fn_next_tombo` cherche par `LIKE préfixe || '%'`), remplissage borné (0–8, 1–10) ; **unicité dans le réseau** — ni préfixe égal, ni préfixe contenu ou contenant, ni préfixe déjà porté par des exemplaires d'une autre bibliothèque (séries héritées) ; **figé** dès qu'un exemplaire l'a utilisé (préfixe, année, séparateur ; le remplissage reste modifiable) | rien | **justifiée** — le refus `prefix_taken` dit qu'un préfixe existe ailleurs, pas où : rien de plus que ce que les tombos du catalogue public montrent déjà |
| `public.fn_batch_caller_can_edit(p_batch_id)` | prédicat pur : admin **ou** staff actif de **la bibliothèque propriétaire des brouillons du lot** **ou** (lot sans propriétaire **et** `fn_is_catalog_coordinator()`) | `false`, que le lot existe ou non | **justifiée** — et c'est **la garde qui referme la limite fonctionnelle 2 du 06/09** : depuis que les lots ont une propriétaire, le geste est rapproché de la bibliothèque de l'appelant·e, pas seulement de son rôle. Le repli « lot orphelin → coordination du catalogue » couvre les lots nés avant le 15/09 |
| `public.fn_batch_assign_bib_refs(p_batch_id, p_apply)` | lot existant, **puis** `fn_batch_caller_can_edit`, lot `open`, brouillons sans cote d'**une seule** bibliothèque, convention `bib_ref_auto` posée ; **verrou consultatif par préfixe** (`pg_advisory_xact_lock`) ; le maximum est cherché partout où une cote vit (notices publiées, holdings de la bibliothèque, brouillons non annulés) | `not_found` ou `staff_only` — voir la forme ci-dessous | **justifiée** — `p_apply = false` est une prévisualisation sans écriture ; l'écriture ne touche que `bib_ref` des brouillons du lot et les notes du lot, nommées |
| `public.fn_batch_rubrics(p_batch_id)` | lot existant, **puis** `fn_batch_caller_can_edit` | idem | **justifiée** — lecture seule : rubriques du lot, comptes, brouillons sans classe |
| `public.fn_batch_apply_rubric_classes(p_batch_id, p_map, p_overwrite)` | lot existant, **puis** `fn_batch_caller_can_edit`, lot `open`, `p_map` objet JSON | idem | **justifiée** — n'écrit que `book_drafts.cdd` des brouillons vivants du lot, ne remplace une classe existante que sur `p_overwrite`, trace le geste, nommé, dans les notes du lot |

**La forme à corriger, d'une ligne.** Les trois RPC de lot de E21
(`fn_batch_assign_bib_refs`, `fn_batch_rubrics`,
`fn_batch_apply_rubric_classes`) vérifient **l'existence du lot avant les
droits** : une inconnue reçoit `not_found` pour un identifiant vide et
`staff_only` pour un identifiant pris, et peut donc énumérer les identifiants
de lots existants — des entiers séquentiels, sans aucune donnée derrière.
Ce n'est pas une faille (l'existence d'un lot ne dit rien, et les lots sont
déjà listés à tout·e staff), mais `fn_batch_reassign_library` fait l'inverse,
droits d'abord, et c'est l'ordre du paquet 4 du 01/09. Inverser les deux
`IF` dans chacune des trois — à faire dans la prochaine migration qui les
touche, pas pour elle-même.

**Ce que E21 apporte à l'audit.** `fn_library_numbering_get`/`_set` sont les
premières RPC de configuration de bibliothèque écrites depuis le paquet 2 :
elles portent la garde **par bibliothèque** (`user_has_library_staff_role`,
appartenance `coordenador` à `p_library_id`), pas la garde « staff de
n'importe quelle bibliothèque » du catalogue commun — la bonne, puisqu'une
série d'inventaire appartient à une bibliothèque. Et les contrôles de
`fn_library_numbering_set` (jokers interdits, unicité y compris contre les
séries héritées, figement après usage) ferment d'avance les collisions de
tombos que la mémoire `anarbib-tombo-global-unique-collision` documentait.

**Non concernées.** `public.fn_book_draft_rubric(p_draft_id)` (DEFINER, `SQL`,
l'extraction de la rubrique d'un brouillon — appelée par les deux RPC de
rubriques, **pas exposée** à `authenticated`) et
`public.fn_gazette_submission_decision_enqueue` (GAZ-7, interne à la file de
courriels, pas exposée) sont nées aussi le 15/09 et n'apparaissent pas au
lint 0029 : hors du périmètre de ce complément. Toutes deux sont dans les
704 DEFINER de la photo.

**Compte au 15/09.** 0029 = **419**, tous justifiés : **411** du 06/09 et **8**
de ce complément (les huit sont dans la liste du lint, vérifié nom par nom sur
le relevé de 22 h 45, format groupé — une entrée par lint, tableau
`findings`). Le lint 0028 reste à **28**, la liste T10. Aucune des huit n'est
exécutable par `anon` (vérifié par `has_function_privilege`).


---

# Complément du 16/09/2026 — la 420e, et ce que B22 a retiré de l'autre lint

**16 septembre 2026, 23 h 00** · base `uflwmikiyjfnikiphtcp` en lecture seule · relevé `get_advisors` de 22 h 40, format groupé.

Le lint 0029 est passé de **419** (15/09, 22 h 45) à **420** : **+1 fonction
`SECURITY DEFINER` exécutable par `authenticated`**. Relevée par `oid`
décroissant (toute fonction créée après `fn_batch_apply_rubric_classes`, la
dernière des huit du complément du 15/09) : une seule,
`api.fn_gazette_probe_sources` (`oid` 1159470), née de la migration
`20260915203617_les_sources_se_testent_a_la_main` (GAZ-8), écrite à 20 h 36 et
**poussée à 22 h 56, onze minutes après le relevé de 419** — d'où l'écart. Le
lint la compte à bon droit : DEFINER, `authenticated=X` dans l'ACL, dans `api`.
Lue dans `pg_proc.prosrc` en production, au même critère : *que peut demander
une inconnue qui vient de s'inscrire ?*

## Verdict : aucune faille, une forme à noter

| Fonction | Garde lue dans le corps | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `api.fn_gazette_probe_sources()` | `network_staff` **actif** (`ns.user_id = auth.uid() and ns.is_active`) **en tête**, `errcode 42501` ; `search_path = public, extensions` ; puis `perform public.fn_gazette_build_call('probe_sources')` | rien (exception `forbidden: network_staff only`) | **justifiée** — le corps ne lit ni n'écrit aucune table : il délègue à `fn_gazette_build_call`, DEFINER **non exposée** (`postgres`, `service_role` seuls), qui fait un `net.http_post` asynchrone vers l'Edge Function `gazette-monthly-build` (`private.fn_functions_base_url()`, I20) avec le secret `gazette_cron_secret` lu au Vault en en-tête `X-Cron-Secret`, corps `{step: 'probe_sources'}`. Le secret ne transite jamais par la session appelante ; la RPC ne rend rien (pas même l'identifiant de requête `pg_net`) |

**La forme à noter.** Un·e `network_staff` peut déclencher la sonde des
sources à volonté : chaque appel est un `http_post` vers notre propre Edge
Function, qui sonde à son tour les sources externes (Info Libertaire et les
autres, GAZ-7/8). Aucun compteur ne borne le geste — les compteurs d'abus de
`auth_rate_limits` (B25/B26, `20260916201249`) ne connaissent pas ce chemin,
et la sonde est faite pour être lancée à la main. Ce n'est pas une faille :
le rôle est le plus restreint du réseau (admins), le coût est le nôtre, et
la sonde est idempotente (elle marque des états, ne publie rien). À
reconsidérer si le staff s'élargit ou si une source se plaint d'être
sollicitée : un garde-fou d'une ligne (`pg_advisory_xact_lock` ou un
horodatage « dernière sonde < 1 min → refus ») suffirait.

**Fait le 16/09 à 23 h 45** (`20260916233000_la_sonde_des_sources_attend_une_minute`) :
si une source porte un `last_fetched_at` de moins d'une minute, la RPC refuse
en 55000 « too_soon » avant tout appel réseau ; `gazette_sources_probe_tests`
T5 attend le refus, T4 vide les horodatages avant d'appeler, et le banc nomme
un `network_staff` le temps du test quand le seed n'en a pas (jusque-là T4
était « non exercé » en CI). Le front traduit le code court
(`panel.apiError.too_soon`, dix locales).

**Non concernées.** Nées aussi le 15/09 au soir, après le relevé :
`public.fn_gazette_submission_staff_edit` (GAZ-9, `20260915211224`, trigger
DEFINER, `postgres`/`service_role` seuls) et
`public.fn_gazette_submission_decision_enqueue` (déjà notée le 15/09) —
pas exposées, hors du lint. La migration `20260916191823` (la gazette
s'appelle Fractale) et `20260916201249` (compteurs d'abus) ne créent aucune
DEFINER.

**Ce que B22 a changé de l'autre côté (même soirée).** Le lint 0028 passe de
**28 à 26** : `fn_current_user_is_member_of_holding_library` et
`fn_reading_notes_enabled_for` ne sont plus exécutables par `anon`
(`20260916223000`, elles n'étaient ouvertes que par un défaut de création,
rien ne les appelle sous `anon`). La liste T10 les a perdues ; **T12** porte
désormais la liste fermée des 90 fonctions, INVOKER compris, que `anon`
exécute sur `public`, `api`, `ingest`, `private`. Le 0029 n'a pas bougé de
ce fait : les deux avaient déjà `authenticated=X`, écrit.

**Compte au 16/09.** 0029 = **420**, tous justifiés : 411 du 06/09, 8 du
15/09, 1 de ce complément. 0028 = **26**, la liste T10. Prochain relevé : à
la prochaine migration qui crée une DEFINER exposée — le lint ne prévient
pas, il compte.

## Complément du 24/09/2026 — deux RPC de « Signaler un problème » (E14)

Migration `20260924201133_e14_signaler_un_probleme`. Deux fonctions `SECURITY
DEFINER` dans `api`, exposées à `authenticated` (le lint 0029 passe de 420 à
**422**), lues corps par corps :

- **`api.fn_bug_report_list()`** — première instruction : `fn_caller_is_network_admin()`
  sinon `42501`. Rend les signalements `open` (contenu saisi, contexte, adresse
  laissée). Aucune donnée de compte : la table ne porte pas de `user_id`. Verdict :
  **justifiée** — même forme que `fn_cartography_submission_list`.
- **`api.fn_bug_report_close(uuid, text)`** — même garde ; `UPDATE` borné à
  `status = 'open'`, `closed_by = auth.uid()`, note tronquée à 2 000. `P0002` si
  rien à clore. Verdict : **justifiée**.

Non concernées : `fn_bug_report_enqueue` et `fn_bug_report_outbox_dispatch_trigger`
(triggers DEFINER, `REVOKE … FROM PUBLIC`, `postgres` seul) ;
`fn_consume_altcha_challenge` reprend sa définition réelle (md5 `a8e0233f`) avec un
usage de plus, droits inchangés (`service_role` seul, relevé dans `proacl` avant
d'écrire).

**Compte au 24/09.** 0029 = **422**, tous justifiés. 0028 = 26, inchangé : rien
n'est ouvert à `anon` — la page publique passe par l'Edge Function, pas par une RPC.

## Complément du 25/09/2026 — le rejeu des courriels refusés (F12)

Migration `20260924214108_f12_rejeu_des_courriels_refuses`. Deux fonctions
`SECURITY DEFINER` dans `api`, exposées à `authenticated` (le lint 0029 passe de
422 à **424**), lues corps par corps :

- **`api.fn_outbox_abandonnees()`** — première instruction :
  `fn_caller_is_network_admin()` sinon `42501`. Rend les lignes `abandoned` des
  cinq files nommées EN DUR dans le corps (aucun nom de table venu de l'appelant),
  avec les adresses refusées. Verdict : **justifiée** — l'admin réseau reçoit déjà
  ces courriels ou leurs copies ; c'est lui qui doit décider d'abandonner.
- **`api.fn_outbox_acquitter(text, bigint, text)`** — même garde ; `p_file` doit
  appartenir à la liste fermée des cinq files (`22023` sinon) et n'entre dans le
  SQL que par `format('%I')` ; raison obligatoire ; `UPDATE` borné à
  `status = 'abandoned'`, `P0002` si rien. Verdict : **justifiée**.

Non concernées : `private.fn_outbox_rejouer()` (INVOKER, lancée par le cron,
fermée à `PUBLIC`, `anon`, `authenticated`), `private.fn_outbox_programmer_rejeu()`
(trigger, fermée), `private.fn_outbox_prochain_essai()` (SQL immuable, fermée) ;
`public.fn_healthcheck_notifications` reprend son corps réel (md5 `551268a6`)
avec deux remplacements comptés, droits inchangés.

**Compte au 25/09.** 0029 = **424**, tous justifiés. 0028 = 26, inchangé.

---

# Complément du 27/09/2026 — les vingt-quatre RPC nées le 27/09 (B29, capas, B30)

**27 septembre 2026, 22 h 45** · base `uflwmikiyjfnikiphtcp` en lecture seule · relevé `get_advisors` de 19 h 47 UTC, format groupé.

Le lint 0029 est passé de **424** (25/09) à **448** : **+24 fonctions
`SECURITY DEFINER` exécutables par `authenticated`**, toutes nées le 27/09,
de trois chantiers : **B29**, les brouillons portés par leur bibliothèque
(`20260927160000`, treize aides) ; **les capas**, revue du lot et photo en
rayon (`20260927180120`, cinq RPC ; `20260927182008`, trois) ; **B30**, un
lot a une bibliothèque (`20260927191059`, trois). Le tableau de bord affichait
« 474 warnings » : 26 du lint 0028, la liste T10, inchangée, et ces 448.

Relevées par `oid` décroissant après `api.fn_outbox_acquitter`, la dernière du
complément du 25/09 : **28 `oid`, dont 4 recréations déjà comptées**. Un
`DROP` + `CREATE` pour changer de signature donne un `oid` neuf à une fonction
ancienne : `fn_import_set_adapter_overrides` (H15, `20260926191500`),
`fn_import_profile_create` et `fn_import_profiles_list` (H19,
`20260927113000`), `fn_batch_reviews_list` (B29 puis B30). On les écarte par
la **première** migration qui les nomme dans
`supabase_migrations.schema_migrations` (le socle pour les trois d'import,
`20260905093000` pour la liste des révisions), et 424 + 24 = 448 le confirme.
Leurs corps recréés ont été relus : gardes inchangées (coordination de la
bibliothèque ou admin pour les trois d'import, avec le message unifié « Run
introuvável » pour `fn_import_set_adapter_overrides` ; lots des bibliothèques
de l'appelant·e pour la liste des révisions). Les vingt-quatre sont lues dans
`pg_proc.prosrc` en production, au même critère : *que peut demander une
inconnue qui vient de s'inscrire ?*

## Verdict : aucune faille, une forme à noter, cinq ouvertures sans objet fermées dans la foulée

**B29 — treize aides.** Pour une aide, la question qui tranche n'est pas sa
garde mais **qui l'appelle sous `authenticated`** : une politique RLS, une vue
`security_invoker`, un déclencheur INVOKER ou le front ont besoin du
privilège ; une fonction DEFINER, non (elle exécute ses appels sous son
propriétaire).

| Fonction | Qui l'appelle sous `authenticated` | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `fn_caller_staff_library_ids()` | 7 politiques (`book_drafts`, `exemplar_drafts`, `catalog_batches`, `catalog_audit_log`) ; le front (`useStaffLibraries`) | ses propres bibliothèques de staff : `{}` | **justifiée** |
| `fn_caller_coordinator_library_ids()` | 3 politiques ; le front | les siennes : `{}` | **justifiée** |
| `fn_caller_staff_library()` | déclencheurs INVOKER `tg_drafts_library_fixed`, `tg_catalog_batches_library_fixed` | la sienne : `NULL` | **justifiée** |
| `fn_caller_can_edit_book_draft(p_draft_id)` | la politique de `merge_log` | `false`, que le brouillon existe ou non (« pas d'oracle d'existence », dit le corps) | **justifiée** |
| `fn_caller_owns_batch(p_batch_id)` | la politique de `catalog_batch_reviews` ; le front (`CatalogacaoPage`) | `false` | **justifiée** |
| `fn_caller_coordinates_batch(p_batch_id)` | le front (`CatalogacaoPage`) | `false` | **justifiée** |
| `fn_book_draft_creator_library(p_draft_id, p_created_by)` | 2 politiques de `book_drafts` ; déclencheurs INVOKER | la bibliothèque de staff de **n'importe quel compte** dont on connaît l'UUID — voir la forme | **justifiée**, forme notée |
| `fn_exemplar_draft_fallback_library(p_book_draft_id, p_import_staging_row_id, p_created_by)` | 2 politiques de `exemplar_drafts` ; déclencheurs INVOKER | idem, et la bibliothèque de n'importe quel brouillon de notice | **justifiée**, forme notée |
| `fn_caller_can_edit_draft_library(p_library, p_created_by)` | **personne** — seules des DEFINER | `false` (`true` seulement si `p_created_by` est l'appelant·e, staff) | **fermée** |
| `fn_caller_can_edit_exemplar_draft(p_draft_id)` | **personne** | `false` | **fermée** |
| `fn_caller_can_edit_author_draft(p_draft_id)` | **personne** | `false` | **fermée** |
| `fn_caller_can_edit_batch(p_batch_id, p_all_kinds)` | **personne** | `false` | **fermée** |
| `fn_caller_can_see_batch(p_batch_id)` | **personne** | `false` | **fermée** |

**Capas — huit RPC.**

| Fonction | Garde lue dans le corps | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `api.capas_revue_resume()` | staff actif (`fn_caller_staff_library_ids`) ou admin **en tête** ; comptes bornés par `fn_capas_dans_le_perimetre` — les notices que ses bibliothèques **possèdent ou détiennent** | rien (`42501`, `staff_only`) | **justifiée** |
| `api.capas_revue_liste(p_limite, p_decalage)` | même garde, même périmètre ; page bornée à 1–50 | rien | **justifiée** |
| `api.capas_revue_accepter(p_book_id, p_full_url, p_object_path)` | même garde ; notice verrouillée (`FOR UPDATE`) et **dans le périmètre** ; proposition `a_revoir` ; **provenance et licence lues dans la proposition**, jamais dans le navigateur (`p_full_url` doit être l'une de ses candidates) ; chemin contraint à `books/<bib_ref nettoyée>/(front\|capa-…).(jpg\|png\|webp\|gif)` ; une capa posée entre-temps n'est jamais remplacée (→ `perimee`) | rien | **justifiée** |
| `api.capas_revue_ecarter(p_book_id)`, `api.capas_revue_rouvrir(p_book_id)` | même garde ; notice dans le périmètre ; transition bornée `a_revoir` ↔ `ecartee` | rien | **justifiées** |
| `api.capas_photo_resume(p_library_id)`, `api.capas_photo_liste(p_library_id, p_recherche, …)` | **staff de CETTE bibliothèque** (`user_has_library_staff_role(auth.uid(), p_library_id)`) ou admin | rien | **justifiées** — la garde par bibliothèque, la bonne pour une campagne qui lui appartient ; la recherche ne bâtit d'expression régulière qu'à partir de chiffres (`^\d{1,9}$`) |
| `api.capas_photo_poser(p_book_id, p_object_path, p_remplacer)` | staff ou admin ; notice verrouillée et dans le périmètre ; chemin `books/<bib_ref>/photo-….jpg` ; ne remplace une capa que sur `p_remplacer` (sinon `deja_une_capa`) ; périme la proposition qui attendait | rien | **justifiée** |

**B30 — trois.**

| Fonction | Qui l'appelle, et sa garde | Ce qu'une inconnue inscrite obtient | Verdict |
|---|---|---|---|
| `fn_caller_batch_library(p_batch_id)` | déclencheur INVOKER `tg_drafts_batch_guarded` (et des DEFINER) ; la bibliothèque n'est rendue qu'à l'admin ou au staff de CE lot, et le `FOR KEY SHARE` ne verrouille qu'un lot visible | `NULL` | **justifiée** |
| `fn_caller_batch_library_sans_attente(p_batch_id)` | idem, `SKIP LOCKED` (l'interblocage évité par B30) | `NULL` | **justifiée** |
| `fn_batch_delete_blockers(p_batch_id)` | le front (`CatalogacaoPage`) ; les comptes ne sortent que si `fn_caller_coordinates_batch` | aucune ligne | **justifiée** |

**La forme à noter.** `fn_book_draft_creator_library(p_draft_id, p_created_by)`
et `fn_exemplar_draft_fallback_library(…)` prennent un UUID de compte
**arbitraire** : `rpc/fn_book_draft_creator_library` avec un brouillon
quelconque et l'UUID d'autrui rend la bibliothèque de staff de ce compte. Elles
rouvrent ainsi `fn_user_staff_library`, que B29 a fermée à `authenticated`
pour cette raison même (« pas d'oracle d'existence ou d'adhésion », dit son
bloc `$droits$`). On ne peut pas les fermer : les politiques de
`book_drafts` et `exemplar_drafts` les appellent, sous `authenticated`, avec
le `created_by` de la ligne. Ce n'est pas une faille : l'information n'est pas
neuve — `user_has_library_staff_role(p_user_id, p_library_id)`, exposée et
appelée par six politiques, dit déjà si un compte est staff d'une
bibliothèque, et les bibliothèques se comptent. Ce qu'elles ajoutent : le
statut d'administration du réseau d'un compte (rendu `NULL`), et la
bibliothèque de n'importe quel brouillon de notice
(`fn_exemplar_draft_fallback_library(p_book_draft_id)`), que B29 cloisonne
par ailleurs. La correction, si elle vaut un jour la peine : borner la
réponse au périmètre de l'appelant·e (sa bibliothèque, l'une de ses
bibliothèques de staff ou de coordination, ou un contexte serveur sans
`auth.uid()`) — les politiques ne comparent qu'à ces ensembles. Ce n'est pas
une ligne : les déclencheurs et les DEFINER qui s'en servent attendent la
valeur réelle, il faudrait séparer une version interne. À faire avec la
prochaine migration qui les touche, suites B29 et B30 rejouées.

**Fait le 28/09 (B35), autrement : par le schéma `private`.** PostgREST n'expose
que `public, graphql_public, api, ingest` (PGRST106 sur `private`, vérifié le 28/09).
Les deux aides ont changé de schéma (`20260928105437`, commit `6721277b`, déployée
à 11 h 12 UTC) : recréées dans `private` depuis leur définition réelle, les quinze
appelants (tous par `public.fn_…(`, aucune citation nue) et les quatre politiques
re-pointés sur leur définition réelle, les versions `public` supprimées sans
CASCADE. `authenticated` garde EXECUTE (les politiques et les déclencheurs
l'évaluent), `anon` et PUBLIC non ; plus aucune porte RPC — l'oracle se ferme
sans qu'un corps ni une politique change de sens. Le lint 0029 passe de 443 à
**441** : il ne compte que ce que l'API sert. Garde dans la migration, T32 de la
suite B29 en continu, mutants éprouvés. Backlog B35 clos sur pièces.

**Cinq ouvertures sans objet, fermées dans la foulée**
(`20260927200627_b29_aides_internes_fermees_aux_comptes`, écrite le 27/09 au
soir, déployée le 28/09 au matin par la CI — commit `f1808c85` ; le runner
était éteint la nuit). Le bloc `$droits$`
de B29 ouvrait ses treize aides à `authenticated` d'un seul geste ; cinq n'ont
aucun appelant qui s'exécute sous ce rôle. Cherché en production avant le
`REVOKE`, selon la liste du REGISTRE : aucune politique, aucune vue, aucune
dépendance de catalogue (`pg_depend` : défaut, contrainte, index, règle),
aucune fonction INVOKER (`prosrc`), aucun appel dans `src/` ni dans une Edge
Function ; ACL lue d'abord (`authenticated=X` direct, pas de `PUBLIC` : le
`REVOKE` n'est pas un no-op). Leurs appelants sont tous DEFINER et tous servis :
`publish_book_draft`, `publish_exemplar_draft`, `publish_author_draft`,
`publish_catalog_batch`, `api.merge_book_drafts`, `fn_restore_deleted_draft`,
`create_book_draft_from_book`, `create_exemplar_draft_from_exemplar`,
`fn_batch_caller_can_edit`, `fn_caller_owns_batch`,
`fn_caller_can_edit_book_draft`. Les suites SQL les appelaient en `postgres`,
jeton simulé : aucune n'a eu à changer. Le bloc DO de la migration revérifie
au déploiement l'absence d'appelant sous `authenticated` et les deux camps
(les cinq fermées, les onze servies ouvertes, aucune à `anon`) ; en continu,
`brouillons_par_bibliotheque_tests.sql` **T31** garde le catalogue ET joue,
sous le rôle `authenticated`, les DEFINER qui portent les aides fermées : leur
refus doit être métier (`error.batch.other_libraries`,
`error.batch.other_authors`, `error.catalog.author_draft_creator_only`,
`error.publish.other_library`), jamais un `42501` de privilège. Contre-épreuve
par mutants sur le banc : migration absente, fermeture d'une aide servie, porteur
devenu INVOKER — chacun fait rougir T31 ; appelant INVOKER, politique ou aide
servie fermée apparus avant le déploiement — chacun fait échouer la migration.

**Compte au 27/09.** 0029 = **448** au relevé, tous justifiés : 424 du 25/09
et 24 de ce complément ; **443** après `20260927200627`
(relevé  du 28/09 à 10 h 05 UTC, format groupé : 26 + 443 = 469 warnings, les cinq sorties de la liste ; le compte SQL dit la même chose). 0028 = **26**, la liste T10, inchangée : aucune des
vingt-quatre n'est exécutable par `anon` (`has_function_privilege`). Le
`sql-tests` de `f1808c85` est rouge par héritage : `recherche_index_trigramme_tests`
(B33, `6bdd4331`, déjà rouge sans ce commit) échoue à l'identique avec et sans
l'effet de la migration, vérifié au banc sur deux copies ; au banc, sur l'arbre
poussé, les 133 autres suites sont vertes, dont `brouillons_par_bibliotheque`
31/31. La suite B33 a été corrigée en amont le 28/09 au matin (`8eaa180c`). Le lint
0029 continuera de croître avec chaque RPC — il compte l'API elle-même ;
c'est ce complément, pas le chiffre, qui doit suivre.

## Complément du 05/10/2026 — cinq DEFINER ouvertes à `authenticated` depuis le 28/09

Recette : `has_function_privilege('authenticated', …)` sur les DEFINER de `public`,
`api`, `ingest` et `private`, croisé avec les fonctions dont la première
définition est postérieure à `20260927200627` (dernier compte de ce document).
Cinq, lues corps par corps en production le 05/10.

| Fonction | Né le | Garde | Verdict |
|---|---|---|---|
| `fn_batch_contributor_candidates(bigint, integer)` | 28/09 | `fn_caller_owns_batch` : staff de la bibliothèque du lot, ou administration (B30) ; sinon `error.batch.other_libraries` | **Saine.** Ne rend que les contributeurs non liés des brouillons vivants du lot et les autorités homonymes (données de catalogue) ; plafond 2 000 lignes. |
| `fn_visible_library_ids()` | 28/09 (B32) | aucune, et c'est voulu | **Saine.** Agrège `fn_library_visible_to_caller` : ne rend que ce que l'appelant voit déjà, sous la règle même des politiques RLS qu'elle sert. |
| `fn_export_authorities_lote(uuid)` | 28/09 | coordination active de la bibliothèque, ou administration du réseau | **Saine.** Exporte les autorités liées aux notices détenues par la bibliothèque. *Forme à noter* : le refus n'a pas de HINT (message portugais brut à l'écran) — à reprendre avec E23. |
| `discard_untouched_retake(text, bigint)` | 03/10 (C19) | `auth.uid()` non nul ; ne supprime qu'un brouillon de reprise **jamais enregistré** (`retake_untouched`), au statut `draft`, **créé par l'appelant** (ou par n'importe qui pour l'administration) ; une reprise de notice qui porte déjà un brouillon d'exemplaire reste | **Saine.** Le drapeau `anarbib.retake_oubli`, local à la transaction, n'est posé que par elle et remis à vide avant de rendre la main. |
| `catalog_digital_access_v1(bigint[])` | 04/10 (C20) | aucune ; ouverte aussi à `anon`, exprès (le catalogue public) | **Saine.** Ne répond que pour des notices détenues par une bibliothèque visible de l'appelant ; rend des usages, des booléens et des noms de bibliothèques visibles — jamais un chemin de fichier ; plafond 500 notices. Justifiée dans sa migration (`20261004215035`), gardée par `acces_numerique_catalogue_tests`. |

**Compte au 05/10.** 0029 = **447** (advisor, format groupé), tous justifiés : 443
au 28/09, +5 ci-dessus, −1 fermée entre-temps et non identifiée (même écart
d'une unité qu'au 06/09). 0028 = **28** : 27 au relevé du 29/09, +1 `catalog_digital_access_v1` (04/10,
ouverte au catalogue public, voir ci-dessus).

## Complément du 06/10/2026 — deux DEFINER ouvertes à `authenticated` le 05/10

Relevé à l'inventaire du backlog (05/10 au soir) : le lint 0029 passe de 447 à
**449**. Les deux nouvelles, lues corps par corps dans leur migration et
comparées à la production (`pg_proc`, droits par `has_function_privilege`).

| Fonction | Né le | Garde | Verdict |
|---|---|---|---|
| `public.fn_network_admin_find_user_by_email(text)` | 05/10 (G17, `20261005113021`) | `fn_caller_is_network_admin()` en tête ; sinon `42501`, HINT `error.forbidden`. `REVOKE … FROM PUBLIC, anon`, `GRANT … TO authenticated` | **Saine.** Résout une adresse **exacte** (casse et espaces ignorés, plus de `ilike` et de ses jokers) en identifiant de compte, comptes supprimés exclus, et ne rend que cet identifiant. Elle sert à désigner la personne à coopter : un compte sans bibliothèque est invisible à l'admin sous la RLS de `profiles`, que la fonction ne change pas. *Forme à noter* : elle dit à un·e admin réseau si une adresse a un compte — ce que la cooptation exige, et réservé à l'administration. |
| `api.fn_catalog_networks_v1()` | 05/10 (G13, `20261005173015`) | aucune, ouverte aussi à `anon`, exprès | **Saine.** Verdict écrit à l'audit anon (`AUDIT_execute_anon_2026-08-30.md`, addendum du 05/10) : ne rend que les réseaux « documentation » et les bibliothèques visibles par une fiche publique de la carte. |

**Compte au 06/10.** 0029 = **449**, tous justifiés ; 0028 = **29** (+1,
`api.fn_catalog_networks_v1`).

**Ajout du 06/10 au soir — H21 lot 3** (`e8101139`, migration `20261006182421`,
appliquée par la CI après `f6bb60e5`). Deux DEFINER de plus pour
`authenticated`, aucune pour `anon` (vérifié en production par
`has_function_privilege`) ; la fonction de calcul `ingest.fn_import_trois_etats`
reste fermée à `authenticated`.

| Fonction | Né le | Garde | Verdict |
|---|---|---|---|
| `public.fn_import_recomparer(bigint, bigint[])` | 06/10 (H21 lot 3) | mêmes contrôles que `fn_import_set_editorial` : coordination de la bibliothèque du run, ou administration du réseau avec cette bibliothèque active ; puis verrou du run (`FOR NO KEY UPDATE`, H31) | **Saine.** N'écrit que la comparaison des lignes de staging du run (colonnes `comparaison`, `comparaison_at`), jamais le catalogue ; rend des comptes par verdict. Le librarian est refusé (il lit, il ne recalcule pas). |
| `public.fn_import_row_comparison(bigint, bigint)` | 06/10 (H21 lot 3) | staff de la bibliothèque du run (accès au panneau), ou administration du réseau | **Saine.** Rend, champ par champ, la base, AnarBib et le fichier d'une ligne du run de l'appelant. Les valeurs AnarBib d'une notice que l'appelant ne voit pas sous la règle de `books_select_authenticated` sont masquées (`a_masque`), les verdicts restent. *Forme à noter* : `proposed_title` de `fn_import_list_run_rows` montrait déjà, avant ce lot, le titre d'une telle notice. |

Compte attendu au prochain relevé : 0029 = **451** (+2) ; 0028 inchangé.

## Complément du 06/10/2026, soir — trente-quatre ouvertures sans objet fermées (451 → 417)

Relevé du tableau de bord (export du 06/10, 19 h 22 UTC) : 481 WARN = **451**
(0029) + **29** (0028) + **1** (0011). Les trois comptes sont ceux qu'on
attendait : 0029 = 451 (voir ci-dessus), 0028 = 29 = la liste nommée T10 de
`grants_herites_tests`, et le 0011 est `fn_locale_from_idioma`, voulu (B32).

Ce qui pouvait encore baisser : les fonctions ouvertes à `authenticated` que
**personne** n'appelle sous ce rôle. Méthode, sur les 451, en production
(lecture seule) puis dans le dépôt :

1. appelants qui s'exécutent sous le rôle du lecteur — politiques (tous
   schémas), vues, fonctions INVOKER (`prosrc`, tous schémas), commandes cron,
   `pg_depend` (défaut, contrainte, index, règle, corps SQL standard) :
   52 en ont, **399** n'en ont aucun ;
2. pour ces 399, un nom littéral dans `src/` (hors tests), `supabase/functions/`,
   `scripts/` ou `deploy/` — les sept `.rpc(variable)` du front prennent tous
   leur nom dans un littéral du même fichier, aucun nom n'est construit :
   **43** n'en ont aucun ;
3. sur ces 43, neuf restent ouvertes : les sept de la liste T10 (ouvertes à
   `anon` par décision), `api.fn_outbox_abandonnees` et
   `api.fn_outbox_acquitter` (RPC d'admin réseau voulues par F12, sans écran),
   `fn_import_row_comparison` (H21 lot 3, son écran est en cours).

Les **34** fermées par `20261006202320` (`REVOKE … FROM PUBLIC, anon,
authenticated` ; `service_role` garde ce qu'il avait) :

| Groupe | Fonctions | Pourquoi aucune porte n'est perdue |
|---|---|---|
| Déclencheurs | `fn_audit_draft_deletion`, `fn_guard_catalog_batch_delete` | EXECUTE n'est vérifié qu'à la création du déclencheur. |
| Façade de l'espace institutionnel | `api.get_library_circulation_policy_sets_ui`, `api.get_library_regulation_documents_ui`, `get_library_notification_context`, `get_library_theme_config_by_library_id`, `resolve_managed_library_id` | Appelées par `api.get_library_institutional_workspace` (DEFINER) et ses voisines. |
| Circulation | `api.resolve_circulation_rule`, `api.get_due_date_after_renewal`, `api.get_future_availability`, `fn_circulation_concurrent_max` | Appelées par les `fn_v2_*` et les façades `api.get_*` DEFINER, et par le déclencheur `fn_enforce_circulation_limit`. |
| Lots | `fn_batch_caller_can_edit` | Appelée par `fn_batch_rubrics`, `fn_batch_assign_bib_refs`, `fn_batch_apply_rubric_classes`. |
| Gouvernance | `fn_caller_is_assembleia_facilitator`, `fn_classify_transition`, `fn_library_active_staff_count`, `fn_request_caller_is_owner` | Appelées par les RPC d'assemblée, de changement de profil et de demande, toutes DEFINER. |
| Appartenance, réseau | `fn_current_user_is_in_network`, `fn_current_user_is_member_of`, `fn_current_user_is_member_of_holding_library`, `fn_library_is_federated`, `fn_compute_membership_validity` | Appelées par `fn_library_visible_to_caller`, `catalog_digital_access_v1`, `fn_peb_authorized`, `fn_record_membership_payment`… DEFINER. |
| Partenariats | `fn_partnership_canonical_id`, `fn_partnership_has_active_right`, `fn_partnership_reciprocal_id`, `fn_partnership_transparence_active` | Appelées par les RPC de partenariat, de PEB et du Painel, DEFINER. |
| Autorités, catalogue | `merge_serial`, `merge_subject`, `fn_library_uses_authority`, `fn_painel_find_profile_by_lookup`, `get_library_theme_config`, `set_library_theme_config` | Appelées par `api.fn_authority_apply`, `api.fn_authority_object`, `fn_painel_find_profile_by_email`, `*_by_library_id`, DEFINER. |
| Sans aucun appelant | `api.revoke_my_reader_card` (carte-lecteur bêta, jamais câblée), `discard_book` (supplantée par `discard_book_cascade`), `fn_ensure_current_user_profile` | — |

Aucune n'était une fuite : toutes ont été lues à cet audit ou à ses
compléments. On les ferme parce qu'une ouverture doit servir (DOC-GRANT-1).

**Éprouvé avant de pousser** : la migration, jouée en production dans une
transaction annulée, a passé sa garde (après qu'elle eut refusé ma première
liste de portes : `api.get_due_date_for_loan` y figurait, alors qu'elle est
fermée depuis B20) et donné 0029 = 417. Garde continue :
`tests/sql/aides_definer_fermees_tests.sql` (fermées, aucun appelant sous
`authenticated`, portes ouvertes et DEFINER, portes jouées sous le rôle sans
« permission denied for function »). Quatre suites ajustées :
`circulation_couche_supplantee` (T3 → T4), `paquetA_profils` (15.3 → 15.4),
`brouillons_par_bibliotheque` (T31), `b14_oracle_existence_forme` (T2 → T2b).
Cette dernière affirmait que le Painel appelle `fn_painel_find_profile_by_lookup` :
aucun fichier hors migrations, docs et tests ne l'a jamais nommée (`git log -S`
vide) ; le Painel cherche par `fn_painel_search_reader`. Le rouge du banc l'a
attrapé ; la prémisse était fausse, pas la fermeture.

Compte attendu au prochain relevé : 0029 = **417** ; 0028 = **29** ; 0011 = **1**
(voulu).

### Complément du 06/10 — H21 lot 4 (`44ae324a`, migration `20261006203239`)

Une seule porte nouvelle pour `authenticated`, aucune pour `anon` (vérifié en
production par `has_function_privilege`) ; les aides `ingest.fn_h21_*`
(garde, copie, avance de la base) restent fermées à `authenticated`.
`publish_book_draft` et `api.merge_draft_into_book` gagnent des refus, pas de
droits.

| Fonction | Né le | Garde | Verdict |
|---|---|---|---|
| `public.fn_import_preparer_mises_a_jour(bigint, bigint[])` | 06/10 (H21 lot 4) | mêmes contrôles que `fn_import_set_editorial` : coordination de la bibliothèque du run, ou administration du réseau ; dépôt et OAI à l'administration seule ; puis verrou du run (`FOR NO KEY UPDATE`, H31) ; 200 lignes au plus | **Saine.** Crée, pour les seules lignes reconnues dont la bibliothèque qui importe est la seule détentrice de la notice (`book_holdings`), un brouillon de mise à jour dans le lot du run ; n'écrit jamais `books` (la publication passe par la révision et par la garde de `publish_book_draft`). Les lignes écartées sont comptées par raison, jamais refusées en bloc. |

Compte attendu au prochain relevé : 0029 = **418** (+1 sur le compte ci-dessus,
mesuré avant ce lot) ; 0028 inchangé.

### Complément du 07/10 — H21 lot 5 (`2cb5fd31`, migration `20261007175456`)

Quatre portes nouvelles pour `authenticated`, aucune pour `anon` (vérifié en
production par `has_function_privilege`). La table `ingest.book_import_divergences`
est sous RLS sans politique et sans droit ; le déclencheur
`tg_book_drafts_trace_import_insert` n'est exécutable par personne.
`publish_book_draft`, `fn_import_recomparer`, `fn_import_preparer_mises_a_jour` et
`api.merge_draft_into_book` gagnent des refus, pas de droits.

| Fonction | Né le | Garde | Verdict |
|---|---|---|---|
| `public.fn_divergences_a_traiter(uuid, integer, integer)` | 07/10 (H21 lot 5) | uid non nul ; administration du réseau, ou coordination (`fn_caller_coordinator_library_ids`) d'une bibliothèque qui détient la notice ; `p_library_id` doit être une bibliothèque que l'appelant coordonne, sinon réponse vide | **Saine.** Lecture seule : divergences ouvertes groupées par notice (titre, `bib_ref`, bibliothèque qui importe, valeurs des seuls champs divergents). |
| `public.fn_notice_divergences(bigint)` | 07/10 (H21 lot 5) | même règle ; sinon `{book_id, groupes: []}`, sans titre | **Saine.** Lecture seule, pour le bandeau de la notice. |
| `public.fn_divergences_ecarter(bigint[])` | 07/10 (H21 lot 5) | coordination ou administration, sinon `error.divergence.coord_only` ; 200 au plus ; puis divergence par divergence : notice détenue par une bibliothèque que l'appelant coordonne (ou administration), sinon ignorée avec sa raison | **Saine.** Écrit le statut de la divergence et avance la base de ce champ seul (`ingest.book_import_baselines`) ; jamais le catalogue. |
| `public.fn_divergences_appliquer(bigint, bigint[])` | 07/10 (H21 lot 5) | `my_access` (bibliothèque active, accès au panneau) ; coordination de la bibliothèque active ou administration ; la bibliothèque active détient la notice ; pas de brouillon vivant lié à une divergence ; 200 au plus | **Saine.** Crée un brouillon de reprise prérempli ; la notice ne change qu'à sa publication, sous la garde de `publish_book_draft`. |

Compte attendu au prochain relevé : 0029 = **422** (+4) ; 0028 inchangé.

### Complément du 08/10 — H21 lot 6a (`e225f463`, migration `20261008173955`)

Aucune porte nouvelle pour `authenticated` ni pour `anon` : les aides
`ingest.fn_h21_constat_exemplaire`, `fn_h21_exemplaire_pris`,
`fn_h21_lot_ouvert_du_run`, `fn_h21_trace_exemplaire_rejouable` et les fonctions de
déclencheur sont fermées. `fn_import_list_run_rows` (recréée, droits restaurés),
`fn_import_reconcile_duplicates`, `fn_batch_review_report`, `fn_import_profile_create`,
`publish_exemplar_draft` et `fn_restore_deleted_draft` gardent leur garde.
**Forme à noter** : les colonnes `exemplares.source_item_id`, `import_source_id` et
`import_run_id` sont lisibles par `anon` par la politique `exemplares_public_read`,
comme le reste de l'exemplaire (dont `source_item_code`) ; ce sont des numéros
internes, sans donnée personnelle. Compte 0029 attendu inchangé (422).

### Complément du 08/10 — G19 lot 1, correspondance entre bibliothèques (migration `correspondance_entre_bibliotheques_lot_1`)

Cinq portes neuves pour `authenticated`, aucune pour `anon` ; trois aides fermées.
- `api.fn_correspondance_ouvrir(uuid, uuid, text, text, text)`, `api.fn_correspondance_envoyer(bigint, uuid, text, text)`,
  `api.fn_correspondance_archiver(bigint, uuid, boolean)` : garde lue — `public.fn_correspondance_coordonne(p_library_id)`,
  l'adhésion `coordenador` ACTIVE de l'appelant·e à la bibliothèque au nom de laquelle il ou elle écrit (CORR-1, CORR-6 :
  l'administration du réseau n'y passe pas), refus 42501 `error.correspondance.not_coordinator` ; puis la bibliothèque doit
  être participante du fil (`not_participant`, 42501 — « introuvable » et « pas dans ce fil » ne se distinguent pas).
- `api.fn_correspondance_lue(bigint)` : garde lue — `auth.uid()` non nul et `public.fn_correspondance_lit(fil)` (coordination
  d'une bibliothèque du fil) ; écrit la ligne de lecture de l'appelant·e seulement.
- `public.fn_correspondance_lit(bigint)` : DEFINER STABLE, appelée par les quatre politiques de lecture (une politique qui
  relirait les participantes sous sa propre politique tournerait en rond) ; rend un booléen, ne divulgue rien.
- Fermées (`service_role` seul) : `fn_correspondance_coordonne`, `fn_correspondance_langue`, `fn_correspondance_poser_message`.
**Verdict** : les cinq portes sont voulues ; les tables n'accordent à `authenticated` que SELECT sous politique. Compte 0029
attendu : 422 + 5 = **427**.

### Complément du 08/10 — G19 lot 3, la correspondance prévient (migration `correspondance_lot_3_prevenir`)

Aucune porte nouvelle. `public.tg_library_message_notifier()` (déclencheur AFTER INSERT de `library_messages`) est DEFINER,
`search_path` figé, fermée à `anon`, `authenticated` et `service_role` — un déclencheur n'a besoin d'aucun grant ; elle
n'appelle que `fn_dispatch_notify_event`. `api.fn_correspondance_ouvrir` est réécrite (une garde de plus : bibliothèque
`isolated` refusée), droits inchangés. Compte 0029 attendu inchangé : **427**.

### Complément du 08/10 — G19 lot 4 et lot 4 bis (migrations `correspondance_lot_4_langues_lues`, `correspondance_lot_4bis_liste_en_base`)

Lot 4 : aucune porte nouvelle. `public.tg_libraries_read_languages_normaliser()` (déclencheur BEFORE de `libraries`, dédoublonne et
ordonne `read_languages`) est INVOKER, `search_path` figé, fermée à `anon` et `authenticated`. La colonne reçoit `GRANT UPDATE
(read_languages)` pour `authenticated`, colonne par colonne comme le socle de `libraries` ; la ligne reste sous
`libraries_staff_update`.
Lot 4 bis : **une porte de plus**, `api.fn_correspondance_fils(uuid)` — DEFINER, STABLE, `search_path` figé, EXECUTE à
`authenticated` et `service_role`, fermée à `anon` ; garde `fn_correspondance_coordonne(p_library_id)` (42501 sinon) ; ne lit
que les quatre tables de la correspondance de la bibliothèque appelante, les non-lus pour `auth.uid()`. Compte 0029 attendu : **428**.

### Complément du 10/10 — C29 lot 3, modifier un exemplaire publié en un geste (migration `20261010204944_c29_lot3_modifier_un_exemplaire_en_un_geste`)

**Une porte de plus**, `public.fn_exemplaire_modifier_et_publier(bigint, jsonb)` — DEFINER, `search_path` figé (`public, pg_temp`),
EXECUTE à `authenticated` et `service_role`, fermée à `PUBLIC` et `anon`. Garde : `fn_caller_can_edit_draft_library(library_id, NULL)`
sur la bibliothèque de l'exemplaire (staff de cette bibliothèque, ou administration du réseau ; `auth.uid()` nul → 42501) — la même
que la reprise. Elle enchaîne dans une seule transaction `create_exemplar_draft_from_exemplar`, la mise à jour des douze champs permis
(ni `tombo`, C17, ni `target_library_id`, ni fonds : un autre nom → 22023) et `publish_exemplar_draft` TEL QUEL, dont toutes les gardes
s'appliquent ; un brouillon de mise à jour déjà vivant la fait refuser (`error.copies.update_pending`). Si la base refuse, rien ne
reste. Pas de nouvelle table, pas de politique. Au passage, `create_exemplar_draft_from_exemplar` (déjà ouverte à `authenticated`)
copie désormais `circulation_policy` et `visibility` : un exemplaire « équipe uniquement » ne repassait public à la republication que
par ce défaut de copie. Suite `c29_exemplaire_modifier_et_publier_tests` (9 cas : droits, garde, champs permis, brouillon vivant,
atomicité). Comptes attendus, `public` + `api` : **0029 = 429** (428 le 09/10 au soir), **0028 = 29** (inchangé).
