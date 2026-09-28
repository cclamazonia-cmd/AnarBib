# AnarBib ↔ PMB : ce qui passe, dans les deux sens

> Engendré par `src/tests/couverture-pmb.test.js` depuis la table partagée de l'import et de l'export
> (`supabase/functions/_shared/marc/correspondance.ts`), les pertes acceptées de la preuve de
> l'aller-retour (`src/tests/helpers/pmb-pertes-acceptees.js`) et les pertes mesurées sur les 64 notices
> des fixtures exportées par PMB 8.1 (`tests/pmb/aller-retour-pertes.json`). Ne pas modifier à la main :
> `REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js`.

## En bref

- **De PMB vers AnarBib** : Importations lit un export UNIMARC de PMB — ISO 2709, « XML MARC » ou le XML
  propre à PMB —, en UTF-8 (un fichier en latin-1 est reconnu et lu en windows-1252, et l'écran le dit).
  Chaque import montre son rapport de couverture : ce qui est repris, ce qui est laissé et pourquoi.
  Rien n'est publié sans révision du lot.
- **D'AnarBib vers PMB** : Importations > Exportation par lot, format « UNIMARC — ISO 2709 » (le catalogue)
  et « UNIMARC Autorités — ISO 2709 » (ses autorités). La marche à suivre dans PMB est au § 3.
- **Mesuré** : les 64 notices des fixtures PMB passent PMB → AnarBib → PMB ; les écarts sont au § 4.

## 1. De PMB vers AnarBib (import UNIMARC)

### Ce qui est repris

| Zone UNIMARC | Dans AnarBib |
|---|---|
| 001 | l'identifiant d'origine, gardé pour la bibliothèque qui importe (il sert à réimporter sans doublon) |
| 200 $a | titre |
| 200 $e | complément du titre |
| 200 $f + 200 $g | mention de responsabilité |
| 200 $h | tome (numéro) |
| 200 $i | tome (titre) |
| 205 $a | édition |
| 210 $a (sinon 214 $a) | lieu de publication |
| 210 $c (sinon 214 $c) | éditeur |
| 210 $d (sinon 214 $d) | année |
| 101 $a | langue — une seule, parmi les 36 du catalogue |
| 010 $a | ISBN |
| 011 $a | ISSN (d'un article : celui de sa revue) |
| 215 $a | étendue — le nombre de pages en est tiré |
| 225 $a (sinon 410 $t) | collection |
| 225 $v (sinon 410 $v) | numéro dans la collection |
| 300 $a, toutes les occurrences | notes |
| 327 $a, toutes les occurrences | sommaire, en note |
| 330 $a, toutes les occurrences | résumé, en note |
| 676 $a | indice Dewey |
| 856 $u | adresse en ligne |
| 530 $a | titre clé (périodique) |
| 461 $t | revue hôte (article) |
| 461 $x | ISSN de la revue hôte |
| 461 $v | volume de la revue hôte |
| 463 $v | numéro du fascicule |
| 463 $d | date du fascicule |
| 610 $a, toutes les occurrences | mots-clés libres, notés « Palavras-chave importadas » (rendus en 610 à l'export) |
| 700, 701, 702, 710, 711, 712 | responsabilités : nom ($a, $b), nature (personne, collectivité, congrès — par la zone et l'indicateur), rôle tiré de la fonction $4 (le code d'origine est gardé), qualificatifs d'un congrès ($d, $f, $e) ; un rapprochement avec une autorité est **proposé** en révision, jamais fait d'office |
| 600, 601, 602, 604, 605, 606, 607, 608 | vedettes ($a, $b et les subdivisions $j, $x, $y, $z), notées « Assuntos importados » pour la révision : le thésaurus ne se remplit jamais d'office |
| 995 | exemplaires, un par zone : code d'origine $f, cote $k, note $u, propriétaire $a ; type $r et public $q en note de provenance. Le numéro d'inventaire suit la série de la bibliothèque ; le code d'origine est gardé à part. Réglable par bibliothèque (profil d'import) |

### Ce qui est laissé exprès

Tout ce qui n'est pas repris reste dans l'enregistrement d'origine, gardé avec la notice ; l'export le rend à la bibliothèque qui l'a importé (§ 2).

| Zone | Sous-zone | Motif | Pourquoi |
|---|---|---|---|
| 009 | toutes | donnée interne au logiciel d’origine | dates de gestion propres à PMB |
| 035 | toutes | donnée interne au logiciel d’origine | identifiants de la notice dans d'autres systèmes (l'export d'AnarBib y met sa référence) |
| 100 | toutes | données codées de traitement | données générales de traitement : seul le jeu de caractères (100 $a/26-29) est lu |
| 319 | toutes | donnée interne au logiciel d’origine | zone locale PMB (droits), sans équivalent |
| 801 | toutes | donnée interne au logiciel d’origine | source de la notice, réécrite par chaque logiciel |
| 896 | toutes | donnée interne au logiciel d’origine | vignette de l'OPAC PMB (adresse locale à l'installation) |
| 996 | toutes | redit une zone reprise | exemplaire détaillé PMB : la 995 porte ce que l'import reprend |
| toutes | $9 | donnée interne au logiciel d’origine | identifiants internes de PMB (id:N, lnk:…), valables dans une seule installation |
| 010 | $d | sans champ dans AnarBib | prix, sans équivalent dans AnarBib |
| 210 | $h | donnée interne au logiciel d’origine | date normalisée propre à PMB (la $d suffit) |
| 214 | $h | donnée interne au logiciel d’origine | date normalisée propre à PMB (la $d suffit) |
| 210 | $b | sans champ dans AnarBib | adresse de l'éditeur, sans équivalent |
| 214 | $b | sans champ dans AnarBib | adresse de l'éditeur, sans équivalent |
| 676 | $l | redit une zone reprise | libellé de la classe Dewey (PMB), redondant avec la classe |
| 676 | $v | sans champ dans AnarBib | édition de la Dewey |
| 686 | toutes | sans champ dans AnarBib | autre classification (CDU, cadre de classement…) : cdd ne porte que la Dewey |
| 700 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur (gardées dans l'enregistrement d'origine ; la fiche d'autorité porte les siennes) |
| 701 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur |
| 702 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur |
| toutes | $3 | sans champ dans AnarBib | numéro d'autorité de la source : jamais rattaché d'office (rapprochements proposés en révision) |
| 463 | $t | sans champ dans AnarBib | titre du fascicule : sans champ (numéro et date sont repris) |
| 101 | $c | sans champ dans AnarBib | langue de l'œuvre originale, sans champ dans AnarBib |
| 102 | toutes | sans champ dans AnarBib | pays de publication, sans champ dans AnarBib |
| 200 | $d | sans champ dans AnarBib | titre parallèle, sans champ dans AnarBib |
| 210 | $z | donnée interne au logiciel d’origine | sous-zone propre à PMB |
| 214 | $z | donnée interne au logiciel d’origine | sous-zone propre à PMB |
| 215 | $c | description matérielle au-delà de la pagination | autres caractéristiques matérielles (ill., coul.), sans champ : seule la pagination est reprise |
| 215 | $d | description matérielle au-delà de la pagination | dimensions, sans champ : seule la pagination est reprise |
| 215 | $e | description matérielle au-delà de la pagination | matériel d'accompagnement, sans champ : seule la pagination est reprise |
| toutes | $0 | donnée interne au logiciel d’origine | numéro de la notice liée dans PMB (identifiant interne) |
| 410 | $a | sans champ dans AnarBib | auteur de la collection, sans champ |
| 410 | $y | sans champ dans AnarBib | ISBN de l'ensemble, sans champ |
| 462 | toutes | lien entre notices propre au logiciel d’origine | lien vers une notice fille dans PMB : AnarBib ne tient pas ces liens (ils se refont en œuvres et en tomes) |
| 464 | toutes | lien entre notices propre au logiciel d’origine | lien vers une pièce (article d'un bulletin) dans PMB : l'article importé porte lui-même son périodique (461/463) |
| 856 | $q | sans champ dans AnarBib | format du fichier en ligne, sans champ |
| 995 | $c | redit une zone reprise | code du prêteur (PMB), redondant avec le propriétaire en $a |

Motifs : *donnée interne au logiciel d’origine*, *sans champ dans AnarBib*, *redit une zone reprise*, *description matérielle au-delà de la pagination*, *lien entre notices propre au logiciel d’origine*, *données codées de traitement*.

## 2. D'AnarBib vers PMB (export UNIMARC)

### Ce qui est écrit

- chaque champ du § 1 dans la **première** zone citée (même table que l'import) ;
- en 001 l'identifiant d'origine de la bibliothèque, sinon sa référence AnarBib ; les autres en 035 ;
- les responsabilités en 700-712, avec leur fonction $4 et, pour une notice rattachée à une autorité, son
  numéro en $3 (`AnarBib-A…`) ; le niveau d'origine (701/702, 711/712) est repris quand la fonction n'a pas changé ;
- les vedettes en 606 (celles du thésaurus portent leur numéro en $3, `AnarBib-S…`), les mots-clés en 610 ;
- les exemplaires **de la seule bibliothèque qui exporte** en 995 ;
- pour une notice qu'elle a importée elle-même, les zones de l'enregistrement d'origine que l'import ne lit
  pas, telles quelles (réémission prudente, décision IMP-22) — jamais une zone qu'AnarBib tient.

### Ce qui ne revient pas à l'identique

Mesuré sur les 64 notices des fixtures PMB : combien de valeurs de chaque sous-zone ne reviennent pas telles quelles, et pourquoi.

| Zone | Valeurs | Pourquoi |
|---|---|---|
| 009 | 62 | dates internes de la notice PMB (création, modification) |
| 010$d | 12 | prix : AnarBib n'a pas de champ pour lui |
| 100$a | 64 | données générales recalculées à l'export : date de l'export, langue de catalogage de la bibliothèque qui exporte |
| 101$a | 3 | une seule langue par notice dans AnarBib (books.idioma), et aucune hors des 36 langues du catalogue (« fro ») |
| 101$c | 3 | langue de l'original : AnarBib n'a pas de champ pour elle |
| 200$9 | 1 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 200$a | 2 | la « notice de bulletin » de PMB est lue comme un fascicule (H17) : titre du périodique, numéro |
| 200$d | 5 | titre parallèle : AnarBib n'a pas de champ pour lui ; et la « notice de bulletin » de PMB est lue comme un fascicule (H17) : titre du périodique, numéro |
| 200$h | 2 | la « notice de bulletin » de PMB est lue comme un fascicule (H17) : titre du périodique, numéro |
| 200$i | 2 | la « notice de bulletin » de PMB est lue comme un fascicule (H17) : titre du périodique, numéro |
| 210$9 | 53 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 210$b | 44 | PMB y met la ville ou l'adresse de l'éditeur : AnarBib ne garde pas d'adresse d'éditeur |
| 210$d | 6 | l'année est normalisée (« 2002 (DL) » → « 2002 », « 1995- » → « 1995 ») |
| 210$h | 62 | date complète de publication : AnarBib garde l'année |
| 210$z | 8 | pays de l'éditeur : AnarBib ne le garde pas |
| 214$9 | 53 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 214$a | 44 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 214$b | 44 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 214$c | 44 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 214$d | 61 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 214$h | 62 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 214$z | 8 | PMB double la 210 en 214 ; l'export n'écrit que la 210, que PMB relit |
| 215$a | 20 | AnarBib garde le nombre de pages : une collation libre (« Cartonné - 48 pages », « Non paginé [59] p. ») revient en « N p. », ou pas du tout |
| 215$c | 23 | illustrations : AnarBib n'a pas de champ pour elles |
| 215$d | 38 | dimensions : AnarBib n'a pas de champ pour elles |
| 215$e | 4 | matériel d'accompagnement : AnarBib n'a pas de champ pour lui |
| 225$9 | 8 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 410$0 | 1 | numéro de la notice PMB liée ($0) : un lien interne à PMB, qu'AnarBib ne garde pas |
| 410$9 | 13 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 410$a | 1 | la collection revient en 225 ; la 410 est le lien de PMB vers sa notice ou son autorité de collection |
| 410$t | 9 | la collection revient en 225 ; la 410 est le lien de PMB vers sa notice ou son autorité de collection |
| 410$v | 1 | la collection revient en 225 ; la 410 est le lien de PMB vers sa notice ou son autorité de collection |
| 410$y | 1 | la collection revient en 225 ; la 410 est le lien de PMB vers sa notice ou son autorité de collection |
| 461$0 | 16 | numéro de la notice PMB liée ($0) : un lien interne à PMB, qu'AnarBib ne garde pas |
| 461$9 | 35 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 461$t | 3 | l'ensemble d'un ouvrage en plusieurs tomes est gardé en collection (225 $a) ; un fascicule PMB exporté comme notice perd le lien vers son périodique (backlog H24 : rattacher les fascicules à leur périodique) |
| 461$v | 2 | le tome d'un ouvrage en plusieurs tomes est gardé en volume (200 $h) |
| 463$0 | 2 | numéro de la notice PMB liée ($0) : un lien interne à PMB, qu'AnarBib ne garde pas |
| 463$9 | 34 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 463$t | 3 | titre du fascicule : AnarBib n'a pas de champ pour lui ; pour une notice de bulletin PMB, c'est le titre du périodique, qui revient en 200 et 530 |
| 606$9 | 147 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 676$9 | 37 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 676$l | 36 | libellé de l'indice Dewey : AnarBib garde l'indice seul |
| 700$9 | 37 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 700$N | 8 | sous-zone propre à PMB (adresse web de l'auteur), hors UNIMARC |
| 701$9 | 3 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 702$9 | 14 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 710$9 | 5 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 710$K | 1 | sous-zone propre à PMB (ville de la collectivité), hors UNIMARC |
| 711$9 | 1 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 712$9 | 1 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 856$q | 4 | format du fichier : AnarBib garde l'adresse seule |
| 995$a | 46 | le propriétaire d'un exemplaire exporté est la bibliothèque qui exporte |
| 995$c | 46 | le code du prêteur (PMB) n'est pas écrit : la bibliothèque qui exporte est nommée en $a |
| 995$q | 46 | valeur de remplissage de PMB (« u ») ; type, public et statut restent en provenance (IMP-21 d) |
| 995$r | 46 | valeur de remplissage de PMB (« uu ») ; type, public et statut restent en provenance (IMP-21 d) |
| 996$1 | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$3 | 40 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$9 | 833 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$a | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$b | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$e | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$f | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$k | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$m | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$n | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$r | 13 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$u | 6 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$v | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$x | 46 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |
| 996$y | 13 | 996 : la zone d'exemplaire propre à PMB, jamais réémise (IMP-22) — l'exemplaire revient en 995 |

## 3. Dans PMB : quelle fonction d'import, quels réglages

Dans cet ordre :

1. **Autorités > Import** : le fichier « UNIMARC Autorités », dans le **thésaurus par défaut** de PMB
   (Administration > Outils > Paramètres > Thésaurus).
2. **Administration > Import** du catalogue, avec :
   - la fonction d'import **« Catégories RAMEAU »** (`func_cpt_rameau_first_level`) : elle garde les 606 en
     catégories. La fonction par défaut (`func_bdp`) fond les 606 en une 610 et perd la seconde 700 ;
   - **« Oui »** à « Tenir compte des notices d'autorités » (« Non » par défaut) ;
   - l'origine des autorités : **AnarBib**.

Ce que PMB en fait :

- une responsabilité rejoint sa fiche par le $3 (numéro, type, origine) : aucun auteur recréé ;
- une vedette est rapprochée par son **libellé**, dans le thésaurus par défaut (le $3 d'une 606 n'est pas lu) :
  deux vedettes de même libellé deviennent une seule catégorie ;
- sans « Tenir compte des notices d'autorités », PMB rapproche les auteurs par la seule forme du nom :
  deux homonymes n'en font qu'un, une forme différente en crée un second ;
- réimporter les autorités met toujours la fiche à jour (l'export n'écrit pas de date en 801 $c) ;
- PMB refuse un exemplaire posé sur une notice d'article.

## 4. Mesuré : un aller-retour complet (28/09/2026)

Les 64 notices des fixtures, importées dans AnarBib, publiées, exportées par l'écran, réimportées dans un PMB
vidé de son jeu de test (`tests/pmb/banc/essai-reimport-pmb.sh`) :

| | PMB d'origine | après l'aller-retour |
|---|---|---|
| notices | 62 (44 monographies, 2 périodiques, 15 articles, 1 bulletin) | 64 (44 monographies, 5 périodiques, 15 articles) |
| exemplaires | 46 | 46 |
| bulletins · dépouillements | 3 · 15 | 3 · 15 |
| responsabilités · auteurs | 61 · 57 | 61 · 57 |
| éditeurs | 36 | 36 |
| notices indexées · liens de catégorie | 42 · 49 | 42 · 48 |
| langues de la notice · de l'original | 62 · 3 | 59 · 0 |
| collections employées | 6 | 8 |

Les écarts : deux « notices de bulletin » de PMB reviennent en périodiques, sans lien vers leur titre ; deux
catégories PMB distinctes de même libellé n'en font qu'une ; une seule langue par notice ; l'ensemble d'un
ouvrage en plusieurs tomes revient en collection. Une notice qu'un fichier MARC importe sans exemplaire n'en
reçoit pas à la publication (IMP-25) : les exemplaires reviennent un pour un.

## Limites connues

- Un fascicule importé n'est pas encore rattaché à son périodique.
- Une collectivité à subdivision ($a $b) revient en un seul $a.
- Aucune autorité n'est exportée pour une notice importée tant que la révision ne l'a pas rattachée.
