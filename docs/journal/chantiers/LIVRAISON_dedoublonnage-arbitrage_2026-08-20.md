# Livraison — dédoublonnage : réversibilité et arbitrage réservé à la coordination

**Date** : 2026-08-20
**Auteur** : Xavier (session avec Claude)
**Session** : Dédoublonnage & arbitrage
**Commits** : `99d107e5d` (P3) et `127a5801c` (P4), poussés et appliqués ; `75401486a` (P5
vocabulaire) et `8060189f6` (ce journal), poussés ; `b61831b85` et `bea790d02` (lot 3),
**non poussés** au moment de l'écriture
**Migrations** : `20260821020001_pas_un_doublon_reversible.sql`, `20260821020002_arbitrage_doublons_reserve_coordination.sql`
**Suites CI** : `tests/sql/doublons_p3_reversibilite_tests.sql` (7), `tests/sql/doublons_p4_arbitrage_coordination_tests.sql` (8)

## Pourquoi

Neuf mécanismes de détrompage cohabitaient dans le catalogage, sur quatre niveaux,
et trois d'entre eux détruisaient des données sans retour arrière. Le problème
n'était pas leur nombre — un catalogueur formé s'accommoderait de neuf outils —
mais quatre défauts de présentation :

1. **Un seul verbe pour quatre gestes.** « Fusionner ici » (notice), « Fusionner
   dans cette fiche » (brouillon→notice), « Fusionner ces brouillons »,
   « Fusionner… » (autorité) : quatre portées, quatre conséquences, un mot.
2. **Les trois niveaux mélangés dans une liste.** Le tri par niveau de preuve du
   20/08 le chiffre : sur 266 paires, 3 ISBN, 2 titre+année+éditeur, 7
   titre+année, et **254 titre seul** — c'est-à-dire des cas où la bonne action
   est « Même œuvre », pas la fusion. On exposait un bouton destructeur sur une
   liste dont 95 % des lignes n'appellent aucune destruction.
3. **L'irréversible au même poids visuel que le réversible**, alors que
   `merge_book` ne garde que les métadonnées de la survivante : choisir la
   mauvaise fait disparaître une attribution bibliographique.
4. **« Pas un doublon » sans retour arrière.** Écrit dans `book_not_duplicate`,
   global au réseau, aucune interface pour le défaire. Le geste le plus
   irrattrapable était offert au profil le moins formé.

## Ce qui est livré

### Paquet P3 — réversibilité (`99d107e5d`)

La table portait déjà `created_by`/`created_at` et le `GRANT DELETE` au staff
depuis sa création (`20260620083749`) : la réversibilité était **permise en base,
jamais exposée**. Ajouts : colonne `reason`, `unmark_books_not_duplicate`,
`list_books_not_duplicate`, et `mark_books_not_duplicate` porté à trois
arguments (DROP + CREATE imposés — une surcharge à défaut aurait rendu ambigus
les trois appels existants). Aucune règle de détection touchée.

### Paquet P4 — l'arbitrage passe à la coordination (`127a5801c`)

`fn_is_dedup_arbiter()` définit en **un seul endroit** qui peut arbitrer :
coordination active d'une bibliothèque, ou administration réseau active. Les
quatre fonctions destructrices s'y réfèrent, et un bloc `DO` annule la migration
si l'une d'elles ne l'appelle pas — une garde oubliée est exactement le trou que
le paquet ferme.

`catalog_duplicate_reports` rend au poste de catalogage un geste utile et sans
danger : **signaler**. Le catalogueur a le livre en main ; il est le seul à
savoir que MLEG-0016 et MLEG-0017 sont deux VOLUMES et pas un doublon. On lui
retire le pouvoir de détruire, pas sa connaissance du terrain.

### Paquet P5 — vocabulaire (lot 4)

Quatre boutons portaient le même mot « Fusionner » pour quatre portées, et la
clé `catalogacao.dedup.merge` servait avec **deux orientations opposées** : dans
le balayage le bouton est sous une notice et veut dire « garder celle-ci », dans
la fiche il est sur la ligne du doublon et veut dire « supprimer celle-là ». Les
deux clés ambiguës (`catalogacao.dedup.merge`, `catalogacao.dup.mergeDrafts`)
sont supprimées et remplacées par des libellés orientés, avec infobulle disant
où partent exemplaires et métadonnées.

Défaut trouvé en chemin : les deux fusions de brouillons n'envoient **pas le
même** brouillon à la corbeille — `merge_draft_into_book` absorbe celui qui est
ouvert, `merge_book_drafts(survivant = ouvert)` tue le candidat. Une confirmation
unique servait les deux : elle mentait une fois sur deux. Deux messages
désormais.

### Paquet P6 — l'aperçu de fusion, puis l'assistant (lot 3)

`preview_merge_book` répond en lecture seule à la question que la confirmation
ne posait pas : *qu'est-ce qu'on perd ?* Elle sépare la **perte sèche** (le
doublon porte une valeur, la canonique n'a rien — l'information n'existera plus
nulle part) de la simple **divergence** (les deux portent une valeur, celle du
doublon disparaît). La comparaison est générique : `books` porte plus de cent
colonnes et en gagne à chaque type de matériel, une énumération figée serait
fausse au premier ajout — et fausse en silence.

L'assistant (`DedupAssistantPanel`, onglet « Doublons » réservé à la
coordination) pose une question à la fois. Le temps 2 montre année, éditeur et
ISBN côte à côte et en gros : c'est là que sort la quasi-totalité des paires,
sur « Même œuvre », sans rien détruire. Le temps 3 affiche l'aperçu et exige de
saisir la référence de la fiche supprimée — la lire oblige à regarder *laquelle
des deux meurt*.

Trois contraintes tenues : panneau et jamais modale ; chargement paresseux via
`isActive` (sinon les ~4 s du balayage seraient payées par toute personne qui
catalogue) ; éditeur et ISBN lus dans `books` plutôt que d'élargir la signature
de `suggest_catalog_duplicates`, dont le balayage global dépend.

**Panneau vérifié en navigateur par la coordination le 20/08/2026.** Le message
du commit `bea790d02`, écrit avant cette vérification, porte encore la mention
« non vérifié » : c'est ce journal qui fait foi. L'historique n'a pas été
réécrit — d'autres sessions avaient déjà commité par-dessus.

### Paquet P7 — reprendre ce qui allait être perdu

L'aperçu disait ce qu'on détruisait ; il ne permettait pas de l'éviter. Or le
catalogage savait déjà faire ça — **du mauvais côté** : `merge_book_drafts` et
`merge_draft_into_book` prennent un `p_fields` qui enrichit le survivant, donc
le chemin *réversible* récupérait les données et le chemin *irréversible* non.

`merge_book_with_fields` reprend les champs nommés sur la canonique, puis
**délègue** à `merge_book`, laissée intacte — son corps a déjà été recopié une
fois ce jour-là, le recopier encore pour un paramètre l'aurait abîmé sans qu'on
s'en aperçoive. Le bloc `DO` refuse la migration si la délégation disparaît.

Trois garde-fous : `p_fields` prend des **noms** de colonnes et jamais des
valeurs (la valeur ne peut venir que de la notice supprimée, sinon la fonction
devient un point d'écriture générique) ; la reprise passe par un `UPDATE` pour
que les triggers se rejouent ; et la liste des champs interdits est une
**denylist** vivant dans `fn_dedup_non_transferable_fields()`, consultée par la
base *et* par l'écran — deux listes auraient divergé, et l'interface aurait
proposé une case que le serveur refuse.

Au temps 3, chaque champ que la fiche supprimée est seule à porter reçoit une
case **cochée par défaut** : perdre une information demande désormais un geste
délibéré. Un champ non reprenable est affiché grisé, pas masqué — sa perte est
réelle, la cacher reviendrait à la passer sous silence.

## Doctrine établie

> **Découper par verbe, pas par personne.** *Signaler* (tout le staff, coût
> d'erreur nul) ; *rapprocher* — « Même œuvre », réversible via
> `detach_book_from_work` (tout le staff) ; *arbitrer* de façon destructrice
> (coordination seule).

> **Écarter et rétablir se relèvent ENSEMBLE.** Il ne doit jamais exister d'état
> où l'on peut écarter une paire sans pouvoir la rétablir.

> **La fusion de BROUILLONS reste ouverte au staff.** Un brouillon en double
> part à la corbeille : c'est réversible, et c'est le travail quotidien de la
> file. La restreindre coûterait beaucoup sans rien protéger.

> **Nommer par la conséquence, pas par l'opération.** « Fusionner » ne dit pas
> qu'une fiche disparaît, ni laquelle. Un libellé de bouton nomme ce qui sera
> perdu, et son infobulle dit où part le reste. Un verbe, une portée, jamais deux.

*À porter au `REGISTRE_decisions.md` — voir « Arbitrages en attente ».*

## Trous refermés au passage

- `merge_author` ne vérifiait pas `status = 'active'` : un rattachement révoqué
  autorisait encore la fusion d'autorités.
- La garde de rattachement de `merge_book` (20/08) acceptait n'importe quelle
  ligne de `network_administrators` sans filtrer `status = 'active'`,
  contrairement à la convention suivie partout ailleurs.
- `DuplicateCompareModal` (comparaison des brouillons, dans la file) appelait
  `mark_books_not_duplicate` : sans correctif, son bouton serait resté visible et
  aurait échoué en 42501 sous les doigts d'une bibliothécaire. Les onze points
  d'appel des fonctions restreintes ont été balayés un par un.

## Pièges rencontrés — à retenir

- **`profiles` n'a pas de colonne `name`** (`first_name` + `last_name`). Le corps
  d'une fonction plpgsql n'étant résolu qu'à l'appel, la migration se créait sans
  broncher ; seul un essai **fonctionnel** l'a attrapé. D'où la règle suivie
  ici : une suite d'acceptation qui **appelle** les fonctions, pas qui vérifie
  leur existence.
- **Le corps de `merge_book` a été recopié** pour n'en changer que la garde. Un
  corps recopié s'abîme sans qu'on s'en aperçoive : le test 6 de la suite P4
  exécute donc une **fusion réelle** de bout en bout et vérifie la journalisation.
- **La base locale a sept semaines de retard** (dernière migration appliquée :
  30/06). Les essais ont tourné en transaction annulée, en rejouant d'abord les
  migrations prérequises. `sql-tests.yml` **ne bloque pas** le `db push` de
  `ci.yml` : une suite rouge n'empêchera pas la migration d'atteindre la prod.
- **Sur ce worktree partagé, commiter c'est publier — et un fichier modifié
  appartient à qui commite en premier.** `git commit -- <chemins>` protège de
  valider l'index d'autrui ; rien ne protège l'inverse. Quatre fois dans les
  deux sens le 20-21/08. Conséquence pratique : « je commite mais je ne pousse
  pas » n'est pas un état stable, et le raisonnement doit vivre dans les
  **en-têtes de fichier**, pas seulement dans les messages de commit.
- **Modale interdite dans le catalogage.** Les panneaux restent tous montés et ne
  sont masqués qu'en CSS ; une modale ouverte depuis un panneau inactif devient
  invisible et bloque le défilement. Motifs et notes se saisissent **en ligne**
  dans la carte. La contrainte vaut pour le lot 3.

## Reste à faire

- **Le balayage global et l'assistant coexistent.** Le premier reste la vue
  d'ensemble (signalements, paires écartées) ; le second est le chemin de
  décision. À surveiller : si l'usage montre que personne n'ouvre plus le
  balayage pour arbitrer, ses boutons destructeurs pourront être retirés au
  profit du seul assistant.
- **Revérifier le temps 3.** La coordination a validé le panneau *avant* les
  cases à cocher ; ce bloc a changé depuis. Les temps 1 et 2 sont intacts.
- **`DEDUP-5` à reformuler.** La carte dit « une confirmation dit ce qu'elle
  détruit » ; depuis P7 elle devrait dire « … et permet de ne pas le détruire ».
  Idem pour `DOC-DESTR-2` en §0.
### Le côté autorités reste en retard de trois crans (vérifié le 21/08)

Le signalement livré au paquet P8 comble le manque le plus criant, mais l'état
des lieux mesuré en base montre que les autorités n'ont pas reçu ce que les
documents ont reçu. Huit fonctions de dédoublonnage côté documents, quatre côté
autorités.

- **Aucun balayage global.** `suggest_author_duplicates` travaille autorité par
  autorité ; il n'existe pas d'équivalent de `suggest_catalog_duplicates`. La
  coordination ne peut donc PAS voir l'état des doublons d'autorités — il
  faudrait ouvrir les 1 300 fiches une par une. Conséquence directe : le
  signalement est aujourd'hui le **seul** chemin par lequel un doublon
  d'autorité parvient à la coordination. C'est beaucoup reposer sur un geste
  volontaire.
- **`merge_author` n'a ni aperçu ni reprise de champs.** Elle garde les
  métadonnées de la seule survivante, comme `merge_book` avant les paquets
  P6/P7. Ce qui est en jeu, mesuré sur les 1 300 autorités : **574 portent des
  dates**, 578 un pays, **75 une biographie**, 28 un identifiant VIAF ou ISNI.
  Fusionner une autorité riche dans une autorité pauvre les détruit sans que
  rien ne l'annonce — exactement le défaut corrigé côté documents.
- **Pas d'arbitrage « pas un doublon ».** Clore un signalement l'acquitte, mais
  la paire réapparaîtra dans la détection : il n'existe pas d'`author_not_duplicate`.

Ordre de traitement suggéré si on y revient : l'aperçu et la reprise d'abord
(c'est ce qui détruit), le balayage global ensuite (c'est ce qui rend le
problème visible), l'arbitrage en dernier (c'est ce qui évite de revoir).

Note de mesure : seules **2** paires d'autorités partagent un nom strictement
identique après normalisation. Le gisement réel est donc dans les formes
approchantes — FERRUA/FERROA, GUYAU M./GUYAU J.M. — que seule la similarité
trigramme attrape. Un décompte par nom exact sous-estime le problème.

## Arbitrages en attente (coordination)

- ~~**REGISTRE**~~ — **fait le 21/08** : la doctrine est portée en **§40 `DEDUP`**
  (9 cartes). Le créneau §37 étant finalement revenu à `CONV`, puis §38 `OPS` et
  §39 `IDENT`, le premier libre était §40. Les deux cartes qui dépassaient le
  sujet ont **gradué en doctrine transverse** le 21/08, sur décision de la
  coordination : `DOC-DESTR-1` (nommer par la conséquence) et `DOC-DESTR-2` (une
  confirmation dit ce qu'elle détruit) vivent désormais en **§0**, le foyer que
  tout le corpus cite ; `DEDUP-4` et `DEDUP-5` n'en sont plus que les
  déclinaisons. Elles valent pour toute action destructrice de l'interface —
  supprimer un lecteur, une bibliothèque, un prêt — pas seulement les doublons.
- **Backlog** : la version courante (`v33`, 17/06) a deux mois ; une autre
  session mène le rattrapage documentaire. Le v34 annotant `#152` et les items
  catalogage/doublons relève de ce rattrapage, pas de cette session.
- ~~**Denylist PII**~~ — **tranché le 21/08 : on ne change rien.** Les trois
  tables créées par ce chantier — `catalog_duplicate_reports`,
  `authority_duplicate_reports` et `author_not_duplicate` — restent en **flux
  long** dans `deploy/bg2-known-tables.txt`, comme `book_not_duplicate` dont
  elles reprennent la forme.

  **Le raisonnement, pour qui voudra le rouvrir.** Aucune ne porte
  d'identifiant direct : `created_by`, `reported_by` et `closed_by` sont des
  uuid, et les noms vivent dans `profiles`, qui est elle-même en flux court. Un
  uuid extrait d'une sauvegarde longue ne se résout donc pas sans la courte.
  À l'inverse, sept jours de rétention détruiraient précisément ce que le
  chantier a construit : la trace d'arbitrage est ce qui rend une mauvaise
  décision rattrapable, et `DEDUP-2` en fait une exigence.

  **Le doute résiduel est nommé** : les champs `note` et `reason` sont du texte
  libre, où quelqu'un peut écrire une phrase parlant d'une personne. Si ce
  risque devient concret — une note nominative constatée —, la bascule se pose
  sur la machine d'ops, hors dépôt, et elle coûte une ligne.
- ~~**Push**~~ — **fait.** Les onze commits du chantier sont poussés et
  déployés ; toutes les migrations sont appliquées et tous les pipelines verts.
  L'avertissement d'origine (« un push sur `main` est un déploiement ») reste
  vrai et a gouverné chaque envoi : sérialisation, attente du vert entre deux
  push touchant la base, et vérification de la signature de chaque commit avant
  de pousser.

  **Reste ouvert, et à l'observation** : le retrait des boutons destructeurs du
  balayage global des documents, approuvé sur le principe le 21/08. Il appelle
  encore `merge_book` en direct, sans aperçu ni reprise, et ne satisfait donc
  pas `DOC-DESTR-2`. C'est le *moment* qui se décide à l'usage, pas le principe.
