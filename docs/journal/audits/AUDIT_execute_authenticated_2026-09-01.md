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
