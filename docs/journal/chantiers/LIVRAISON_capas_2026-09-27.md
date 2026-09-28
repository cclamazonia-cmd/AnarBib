# Livraison — couvertures : la chaîne réparée, la recherche par édition, le lot, la photo en rayon

**Date** : 2026-09-27 (note écrite le 28/09, à la clôture)
**Auteur** : Xavier (session avec Claude)
**Session** : Couvertures (capas) — recherche sans GAFAM
**Commits** : chaîne réparée (matin, migration `20260927130518`) ; `e046157f` (édition, pas œuvre) ;
`c89e1099` (du bouton au lot) ; `e6fd1dc2` (campagne photo) — tous déployés par la CI le 27/09
**Migrations** : `20260927130518` (provenance + licence par paire), `20260927164619` (volumes),
`20260927180120_capas_la_recherche_passe_du_bouton_au_lot`, `20260927182008_capas_la_photo_prise_en_rayon`
**Suites CI** : `tests/sql/capas_lot_tests.sql`, `tests/sql/capas_photo_tests.sql`
**Registre** : `CAPAS-1` à `CAPAS-5` (§43)

## Pourquoi

Le 27/09 au matin, 250 notices publiées sur 2 700 portaient une couverture, et le
bouton « chercher une couverture » du formulaire ne rendait plus rien depuis des
semaines : l'URL Open Library appelée n'existait plus (404), Inventaire rejetait tout
le lot dès qu'une clé ISBN était fausse, et aucune sonde ne le disait. Réparée, la
recherche automatique plafonne : ISBN exact 85/267, sans ISBN « même éditeur et
année » ~11 %, « à vérifier » ~17 %, **pt-BR sans ISBN 0/32**. Les éditeurs des
2 094 notices BTL sans couverture sont une longue traîne de petites maisons et
d'éditions anciennes (Imaginário 87, Achiamé 78, Germinal 1948-70, Clube do Livro
1945-67, Sempere 1909-20…) qu'aucune base ouverte ne couvre ; PMB (896) et Koha (856)
n'apportaient **aucune** vignette dans les notices publiées ni dans les 1 820
brouillons d'import. La photo prise en rayon est le levier.

## Ce qui est livré

### 1. La chaîne réparée

Open Library par `/api/books.json?bibkeys=…&jscmd=data` ; Inventaire par ISBN avec
la clé validée d'abord ; le titre à défaut d'ISBN ; les sources en panne dites à
l'écran ; provenance et licence par paire (règle des trois endroits :
`book_drafts`, `publish_book_draft`, `create_book_draft_from_book`) ; une sonde
horaire dans `health-probe`, incident `capas_sources` (premier échec sans alerte, le
second alerte). `motsDeRecherche()` : le trait d'union est un opérateur Solr.

### 2. Une couverture est celle d'une édition (`e046157f`)

Une candidate ISBN porte `edition {annee, editeurs}` ; `accordEdition()` la
confronte à la notice — « à vérifier » si l'année s'écarte de plus d'un an ou si les
éditeurs n'ont aucun mot commun. La recherche par titre lit `editions.*` et `lang=` :
« édition probable » ou « autre édition » (couverture de l'œuvre). Volumes : un ISBN
d'ensemble vaut pour chaque volume, jamais « concordant » pour un tome
(`20260927164619`).

### 3. Du bouton au lot (`c89e1099`)

`_shared/capas/recherche.ts` est l'ordre de recherche partagé entre le formulaire et
le lot. L'EF **cover-batch** (`verify_jwt=false`, `X-Cron-Secret`) traite une notice
à la fois, à 1 s d'écart, 24 par passage, s'arrête après trois notices aux sources
toutes en panne, dans un budget de 80 s ; cron `anarbib-capas-lot` (`7-59/10`).
Table **`cover_proposals`** : une ligne par notice — `a_revoir`, `sans_resultat`
(re-cherchée à 90 jours), `en_panne` (le lendemain), `acceptee`, `ecartee` (jamais
reproposée), `perimee`. Écran « Couvertures proposées » dans Catalogação (vue
notices, sous la file des titres) : `api.capas_revue_*`, périmètre = staff d'une
bibliothèque qui possède ou détient la notice, plus l'administration réseau ; la
provenance est lue dans la proposition ; `cover_lookup` action `apercus` (vignettes
rapatriées côté serveur, hôtes Open Library et Inventaire seulement) ; `store`
refuse les hôtes privés, range sous un nom neuf `capa-…` (jamais par-dessus `front`)
et périme la proposition si une couverture a été posée entre-temps.

Premier passage en production (18:37 UTC) : 24 traitées, 10 à revoir, 14 sans
résultat, 0 panne — les quatre tomes de *La Patagonia Rebelde* reçoivent chacun la
couverture de leur tome.

### 4. La campagne photo (`e6fd1dc2`)

Onglet Painel « Couvertures » pour le staff de terrain (comme le récolement) et
intentions « Je veux… » (`coverPhotos`, `coverReview`). Liste des notices détenues
sans couverture, dans l'ordre des tombos (BTL : 2 094 sur 2 170) ; recherche par QR
(`?ex=`), ISBN à tirets, chiffres du tombo (« 447 » → BTL-TL-000447), titre. La
photo est préparée dans le navigateur (`src/lib/photoCapa.js`) : orientation EXIF
appliquée, 1 600 px, JPEG réencodé — métadonnées GPS et appareil retirées.
`api.capas_photo_poser` : provenance `photo`, remplacement seulement s'il est
annoncé (`deja_une_capa` sinon).

## Ce que la recherche a fait remonter — à corriger dans le formulaire, livre en main

Décision du 28/09 : ces corrections se font à la main, notice par notice (une
migration devinerait). Valeurs relevées en production le 28/09 :

| Notice | Titre | Champ | Valeur en base | Probable |
|---|---|---|---|---|
| BTL-TL-002174 | Teorias e Planejamento Pedagógico (EPU) | année | `0187` | 1987 |
| BTL-TL-002032 | Pedagogia Sociológica (Couto Martins, Lisboa) | année | `0193` | années 1930 — à lire sur le livre |
| BTL-TL-000065 | Os trabalhadores (Paz e Terra, ISBN 85-219-0351-0) | année | `0200` | 2000 |
| BTL-TL-001935 | Mundos do Trabalho (Paz e Terra) | année | `0200` | 2000 |
| BTL-TL-002053 | Pampa Libre (Universidad Nacional de Quilmes) | année | `8000` | 2000 — à vérifier |
| BTL-TL-002278 | Parque industrial (Linha a Linha) | année, lieu | `2200` ; lieu = « São Paulo 2018/06//2018pt- BR978-85-543- -7 192 Câmara Brasileira do Livro ISBN Parque industrial » | 2018 ; lieu « São Paulo » ; l'ISBN 978-85-543…-7 est incomplet, à relire |
| BTL-TL-000503 | El anarquismo y el movimiento obrero en Argentina (Siglo XXI, 1978) | ISBN | `9682300380` | clé de contrôle fausse — à relire sur le livre |

Deux « ISBN partagés » ne sont **pas** des fautes : ce sont deux paires BTL/BLMF de
la même édition — BTL-TL-002100 ↔ BLMF `0000070` (*Renovação de uma Cidade /
Repartição dos Homens*, Imaginário 2010, 978-85-7935-000-9) et BTL-TL-001599 (2007)
↔ BLMF `0000186` (2011) (*O Indivíduo, a Sociedade e o Estado*, Hedra,
978-85-7715-072-4 ; même ISBN, deux tirages). Une fusion inter-bibliothèques est
une mutualisation (`DEDUP-8`) : elle appartient aux collectifs, pas à une correction.

## Ce qui reste

Rien d'ouvert côté outil : le lot tourne (cron actif, `fn_crons_attendus` = 41), la
revue et la campagne photo sont en production. Le rendement de l'automatique est
connu et plafonne ; le nombre de couvertures suivra la photo en rayon.

## Suite du 28/09 — une capa neuve a une adresse neuve (`CAPAS-6`)

Xavier pose six couvertures sur deux séries de tomes de Peirats (MLEG-0145 à 0147,
BTL-TL-000447 à 000449) et en remplace deux dans la foulée. La page Œuvre montre
alors, pour un tome de chaque série, la couverture d'un autre tome — alors que les
six fichiers du bucket sont justes. Cause : le formulaire écrivait chaque capa à
`books/<clé>/front.<ext>` par `upsert`, et le bucket sert ses objets avec
`Cache-Control: max-age=3600` ; le navigateur qui venait d'afficher la première
version (celui de la personne qui catalogue, forcément) et le CDN devant lui
resservaient l'ancienne image pendant une heure. Le commentaire de
`writeCoverThumb` (coverThumbs.js) le savait pour le dérivé ; l'original avait le
même défaut.

Correctif, sans migration : `cheminCapaNeuf()` (coverThumbs.js) donne à chaque dépôt
du formulaire — fichier, candidate choisie via `cover_lookup` (`nom: capa-…`), page 1
d'un PDF — une adresse neuve `books/<clé>/capa-<horodatage base 36>.<ext>`, jamais
d'`upsert` ; la clé du dossier est nettoyée comme par `cover_lookup` et
`photoCapa.js` (une référence à espace ou barre ne fait plus de sous-dossier) ; le
dérivé `.thumb.jpg` suit le nom, donc change d'adresse aussi. L'ancien objet reste
tant qu'une notice ou un brouillon le désigne (un brouillon abandonné ne doit pas
laisser la notice sans image) ; `scripts/purge-orphelins-covers.py` le retire une
fois remplacé (classe B). `front.<ext>` reste un nom valide pour le stock d'avant et
pour un appelant de `cover_lookup` sans `nom`. Gardes : `coverThumbs.test.js` (deux
dépôts successifs ne partagent ni adresse ni dérivé), `cover-sources-ecran.test.js`
(le formulaire n'écrit plus `front.` et ne remplace plus en place).
