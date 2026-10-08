# AnarBib ↔ PMB : ce qui passe, dans les deux sens

> Engendré par `src/tests/couverture-pmb.test.js`. Viennent du code : au § 1, les zones de chaque champ, les
> zones laissées exprès avec leur motif et leur raison, et la colonne « À l'export »
> (`supabase/functions/_shared/marc/correspondance.ts`, `ecriture.ts`) ; au § 2, le nombre de valeurs perdues,
> mesuré sur les 64 notices des fixtures exportées par PMB 8.1 (`tests/pmb/aller-retour-pertes.json`). Viennent
> des essais au banc PMB : les tableaux des § 3 et 4 et leurs réglages (`tests/pmb/bilans/`). Le reste — ce que
> chaque champ devient, ce qui est écrit, la marche à suivre dans PMB, les écarts expliqués, les limites — est
> rédigé à la main dans le générateur, et daté. Ne pas modifier ce fichier à la main :
> `REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js`.

## En bref

- **De PMB vers AnarBib** : Importations lit un export UNIMARC de PMB — ISO 2709, « XML MARC » ou le XML
  propre à PMB —, en UTF-8 ; un fichier qui n'est pas de l'UTF-8 est lu en windows-1252 **par supposition**,
  l'écran le dit, et l'encodage peut être imposé au retraitement (vérifie les accents). Chaque import montre
  son rapport de couverture : ce qui est repris, ce qui est laissé et pourquoi. Rien n'est publié sans révision
  du lot.
- **D'AnarBib vers PMB** : Importations > Exportation par lot, format « UNIMARC — ISO 2709 » (le catalogue)
  et « UNIMARC Autorités — ISO 2709 » (ses autorités). La marche à suivre dans PMB est au § 3 : deux réglages
  de PMB y décident de tout, l'onglet d'import et « Générer les liens entre notices ? ».
- **Mesuré** : les 64 notices des fixtures PMB passent PMB → AnarBib → PMB ; les écarts sont au § 4.

## 1. De PMB vers AnarBib (import UNIMARC)

### Ce qui est repris

| Zone UNIMARC | Dans AnarBib |
|---|---|
| 001 | l'identifiant d'origine, gardé pour la bibliothèque qui importe et rendu en 001 à l'export ; un réimport ne s'en sert pas encore (backlog H21) : il rapproche par ISBN, ISSN, ou titre + auteur + année, et propose en révision |
| 200 $a | titre |
| 200 $e | complément du titre |
| 200 $f + 200 $g | mention de responsabilité |
| 200 $h | tome (numéro) ; d'une notice de bulletin PMB, le titre du périodique |
| 200 $i | tome (titre) |
| 205 $a | édition |
| 210 $a (sinon 214 $a) | lieu de publication |
| 210 $c (sinon 214 $c) | éditeur — la première maison seulement (un second éditeur PMB, seconde 210, n'est pas repris) |
| 210 $d (sinon 214 $d) | année |
| 101 $a | langue — une seule, parmi les 36 du catalogue |
| 010 $a | ISBN ; d'une publication en série, l'ISSN que PMB écrit en 010 $a va dans ISSN |
| 011 $a | ISSN (d'un article : celui de sa revue) |
| 215 $a | nombre de pages, quand l'étendue en donne un (« XII-318 p. » → 318 ; « 2 vol. », « 1 DVD », « 312 σ. » : rien) ; d'un article, la pagination entière — le reste de la collation reste dans l'enregistrement d'origine, sans revenir à l'export |
| 225 $a (sinon 410 $t) | collection |
| 225 $v (sinon 410 $v) | numéro dans la collection |
| 300 $a, toutes les occurrences | notes |
| 327 $a, toutes les occurrences | sommaire, en note |
| 330 $a, toutes les occurrences | résumé, en note |
| 676 $a | indice Dewey |
| 856 $u | adresse en ligne : le champ de la ressource pour une ressource électronique (guide « l »), sinon en note |
| 530 $a | titre clé (périodique) |
| 461 $t | revue hôte (article) ; d'une monographie, le titre de série PMB (461 sans $9 lnk:) : sa collection si elle n'en a pas, sinon en note « Série: » |
| 461 $x | ISSN de la revue hôte |
| 461 $v | volume de la revue hôte (article) ; d'une monographie, le tome, à défaut de 200 $h et $i |
| 463 $v | numéro du fascicule |
| 463 $d | date du fascicule |
| 610 $a, toutes les occurrences | mots-clés libres, notés « Palavras-chave importadas » (rendus en 610 à l'export) |
| 700, 701, 702, 710, 711, 712 | responsabilités : nom ($a, $b), nature (personne, collectivité, congrès — par la zone et l'indicateur), rôle tiré de la fonction $4 (le code d'origine est gardé ; sans $4, une 702/712 reçoit « autre », les autres « auteur »), qualificatifs d'un congrès ($d, $f, $e) ; un rapprochement avec une autorité est **proposé** en révision, jamais fait d'office |
| 600, 601, 602, 604, 605, 606, 607, 608 | vedettes ($a, $b et les subdivisions $j, $x, $y, $z), notées « Assuntos importados » pour la révision : le thésaurus ne se remplit jamais d'office |
| 995 | exemplaires, un par zone : code d'origine $f, cote $k, note $u, propriétaire $a ; $r et $q — les codes d'import du type et de la section de PMB (« uu » et « u » dans un PMB sans codes) — en note de provenance ; le statut ($o) n'est pas lu. Le numéro d'inventaire suit la série de la bibliothèque ; le code d'origine est gardé à part. Réglable par bibliothèque (profil d'import ; la 996 peut être lue à la place) |
| notice de bulletin PMB (463 $9 lnk:bull_expl) | un périodique : titre et titre clé = le périodique (200 $h, sinon le dernier 463 $t), numéro 463 $v, date 463 $d ; le titre du bulletin, s'il en a un, reste dans l'enregistrement d'origine (sans champ : il ne revient pas à l'export) ; le 200 $a et le $d que PMB y écrit sont écartés |

### Ce qui est laissé exprès

Tout ce qui n'est pas repris reste dans l'enregistrement d'origine, gardé avec la notice. À l'export, seule la
bibliothèque qui a importé la notice le retrouve, et zone par zone : une zone entière qu'AnarBib n'écrit pas
revient telle quelle (réémission prudente, décision IMP-22) ; une sous-zone laissée dans une zone qu'AnarBib
écrit (prix, dimensions, langue de l'original, adresse de l'éditeur…), ainsi que 009, 100 et 996, ne revient
pas — colonne « À l'export » ; le § 2 mesure ces pertes.

| Zone | Sous-zone | Motif | Pourquoi | À l'export |
|---|---|---|---|---|
| 009 | toutes | donnée interne au logiciel d’origine | dates de gestion propres à PMB | non |
| 035 | toutes | donnée interne au logiciel d’origine | identifiants de la notice dans d'autres systèmes (l'export d'AnarBib y met sa référence) | oui, telle quelle |
| 100 | toutes | données codées de traitement | données générales de traitement : seul le jeu de caractères (100 $a/26-29) est lu | non |
| 319 | toutes | donnée interne au logiciel d’origine | zone locale PMB (droits), sans équivalent | oui, telle quelle |
| 801 | toutes | donnée interne au logiciel d’origine | source de la notice, réécrite par chaque logiciel | oui, telle quelle |
| 896 | toutes | donnée interne au logiciel d’origine | vignette de l'OPAC PMB (adresse locale à l'installation) | oui, telle quelle |
| 996 | toutes | sans champ dans AnarBib | exemplaire détaillé PMB : seul son identifiant interne ($9 « expl_id:N ») est lu, second signal du réimport après le code-barres (H21 lot 6a, IMP-33 a) ; type ($e), section ($x), localisation ($v), statut ($1) et prêt ($3) en clair, que rien ne reprend ($a, $f, $k, $u redisent la 995) ; jamais réémise ; un profil d'import peut la lire à la place de la 995 | non |
| toutes | $9 | donnée interne au logiciel d’origine | identifiants internes de PMB (id:N, lnk:…), valables dans une seule installation | dans les zones rendues entières seulement |
| 010 | $d | sans champ dans AnarBib | prix, sans équivalent dans AnarBib | non |
| 210 | $h | donnée interne au logiciel d’origine | date normalisée propre à PMB (la $d suffit) | non |
| 214 | $h | donnée interne au logiciel d’origine | date normalisée propre à PMB (la $d suffit) | non |
| 210 | $b | sans champ dans AnarBib | adresse de l'éditeur, sans équivalent | non |
| 214 | $b | sans champ dans AnarBib | adresse de l'éditeur, sans équivalent | non |
| 676 | $l | redit une zone reprise | libellé de la classe Dewey (PMB), redondant avec la classe | non |
| 676 | $v | sans champ dans AnarBib | édition de la Dewey | non |
| 686 | toutes | sans champ dans AnarBib | autre classification (CDU, cadre de classement…) : cdd ne porte que la Dewey | oui, telle quelle |
| 700 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur (gardées dans l'enregistrement d'origine ; la fiche d'autorité porte les siennes) | oui, si la fiche d'autorité n'a pas de dates |
| 701 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur | oui, si la fiche d'autorité n'a pas de dates |
| 702 | $f | sans champ dans AnarBib | dates de la personne : pas de colonne de contributeur | oui, si la fiche d'autorité n'a pas de dates |
| toutes | $3 | sans champ dans AnarBib | numéro d'autorité de la source : jamais rattaché d'office (rapprochements proposés en révision) | dans les zones rendues entières seulement |
| 463 | $t | sans champ dans AnarBib | titre du fascicule : sans champ (numéro et date sont repris) ; d'une notice de bulletin PMB, le second $t est le périodique, repris en titre | non |
| 463 | $x | sans champ dans AnarBib | ISSN du périodique, porté par la notice de bulletin : non repris tant que le fascicule n'est pas rattaché à son périodique (backlog H24) | non |
| 463 | $e | redit une zone reprise | mention de date du fascicule : la date ($d) est reprise | non |
| 225 | $i | sans champ dans AnarBib | sous-collection, sans champ (PMB la relit en 411, réémise à la bibliothèque d'origine) | non |
| 225 | $x | sans champ dans AnarBib | ISSN de la collection, sans champ | non |
| 410 | $x | sans champ dans AnarBib | ISSN de la collection, sans champ | non |
| 411 | toutes | lien entre notices propre au logiciel d’origine | lien de PMB vers sa sous-collection (réémis tel quel à la bibliothèque d'origine) | oui, telle quelle |
| 101 | $c | sans champ dans AnarBib | langue de l'œuvre originale, sans champ dans AnarBib | non |
| 102 | toutes | sans champ dans AnarBib | pays de publication, sans champ dans AnarBib | oui, telle quelle |
| 200 | $d | sans champ dans AnarBib | titre parallèle, sans champ dans AnarBib | non |
| 210 | $z | donnée interne au logiciel d’origine | sous-zone propre à PMB | non |
| 214 | $z | donnée interne au logiciel d’origine | sous-zone propre à PMB | non |
| 215 | $c | description matérielle au-delà de la pagination | autres caractéristiques matérielles (ill., coul.), sans champ : seule la pagination est reprise | non |
| 215 | $d | description matérielle au-delà de la pagination | dimensions, sans champ : seule la pagination est reprise | non |
| 215 | $e | description matérielle au-delà de la pagination | matériel d'accompagnement, sans champ : seule la pagination est reprise | non |
| toutes | $0 | donnée interne au logiciel d’origine | numéro de la notice liée dans PMB (identifiant interne) | dans les zones rendues entières seulement |
| 410 | $a | sans champ dans AnarBib | auteur de la collection, sans champ | non |
| 410 | $y | sans champ dans AnarBib | ISBN de l'ensemble, sans champ | non |
| 462 | toutes | lien entre notices propre au logiciel d’origine | lien vers une notice fille dans PMB : AnarBib ne tient pas ces liens (ils se refont en œuvres et en tomes) | oui, telle quelle |
| 464 | toutes | lien entre notices propre au logiciel d’origine | lien de PMB vers un article dépouillé : réémis tel quel à la bibliothèque d'origine — au retour, un article dont la 461 ne porte pas à la fois le titre et un volume n'est rattaché à sa revue que par cette 464, lue avant lui | oui, telle quelle |
| 856 | $q | sans champ dans AnarBib | format du fichier en ligne, sans champ | non |
| 995 | $c | redit une zone reprise | code du prêteur (PMB), redondant avec le propriétaire en $a | non |

Motifs : *donnée interne au logiciel d’origine*, *sans champ dans AnarBib*, *redit une zone reprise*, *description matérielle au-delà de la pagination*, *lien entre notices propre au logiciel d’origine*, *données codées de traitement*.

## 2. D'AnarBib vers PMB (export UNIMARC)

### Ce qui est écrit

- chaque champ du § 1 dans la **première** zone citée (même table que l'import) ;
- en 001 l'identifiant d'origine de la bibliothèque, sinon sa référence AnarBib ; les autres en 035 ;
- les responsabilités en 700-712, avec leur fonction $4 et, pour une notice rattachée à une autorité, son
  numéro en $3 (`AnarBib-A…`) ; le niveau d'origine (701/702, 711/712) est repris quand la fonction n'a pas changé ;
- les vedettes en 606 (celles du thésaurus portent leur numéro en $3, `AnarBib-S…`), les mots-clés en 610 ;
- les exemplaires **de la seule bibliothèque qui exporte** en 995 ($a, $f, $k, $u ; type et section
  « indéterminé », $r uu $q u, la valeur que PMB écrit lui-même pour un type sans code) ;
- les périodiques d'abord, les articles en dernier : un article dont la 461 ne porte pas à la fois le titre et
  un volume n'est rattaché à sa revue que par la 464 de la revue, que PMB doit lire avant lui ;
- pour une notice qu'elle a importée elle-même, les zones entières de l'enregistrement d'origine qu'AnarBib
  n'écrit pas, telles quelles (réémission prudente, décision IMP-22) — jamais une zone qu'AnarBib tient, ni
  009, 100 et 996 ; une sous-zone laissée d'une zone tenue ne revient donc pas (tableau ci-dessous), sauf les
  dates d'une personne (700-702 $f) que sa fiche d'autorité ne donne pas.

### Ce qui ne revient pas à l'identique

Mesuré sur les 64 notices des fixtures PMB : combien de valeurs de chaque sous-zone ne reviennent pas telles quelles, et pourquoi.

| Zone | Valeurs | Pourquoi |
|---|---|---|
| 009 | 62 | dates internes de la notice PMB (création, modification) |
| 010$a | 1 | l'ISSN qu'un PMB écrit en 010 $a (le « code » de toute notice) revient, pour un périodique, en 011 $a — que PMB relit comme son code quand la 010 manque |
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
| 461$t | 3 | le titre de série PMB d'un ouvrage en plusieurs tomes est gardé en collection (225 $a) — en note « Série: » si la notice a déjà une collection ; un fascicule PMB exporté comme notice perd le lien vers son périodique (backlog H24 : rattacher les fascicules à leur périodique) |
| 461$v | 2 | le tome d'un ouvrage en plusieurs tomes est gardé en volume (200 $h) |
| 463$0 | 2 | numéro de la notice PMB liée ($0) : un lien interne à PMB, qu'AnarBib ne garde pas |
| 463$9 | 34 | identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base |
| 463$t | 3 | titre du fascicule (article) : AnarBib n'a pas de champ pour lui ; d'une notice de bulletin PMB, la 463 porte deux $t, le titre du bulletin puis celui du périodique — le périodique revient en 200 et 530, le titre du bulletin ne revient pas |
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
| 996$1 | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$3 | 40 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$9 | 833 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$a | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$b | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$e | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$f | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$k | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$m | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$n | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$r | 13 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$u | 6 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$v | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$x | 46 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |
| 996$y | 13 | 996 : la zone d'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l'exemplaire revient en 995, type et section « indéterminé » |

Et ce qui revient changé sans que cette mesure le voie : une responsabilité sans fonction dans PMB revient avec
une fonction (570 « Autre » pour une 702 ou une 712, 070 « Auteur » pour les autres) ; le type et la section d'un
exemplaire (995 $r, $q) reviennent toujours « uu » et « u » — les fixtures les portaient déjà, un PMB qui a réglé
ses codes d'import les verrait remplacés.

## 3. Dans PMB : quelle fonction d'import, quels réglages

(PMB 8.1.1.1 ; chaque réglage a été joué au banc le 29/09/2026 — `tests/pmb/README.md`.) Dans cet ordre :

1. **Autorités > Import** : le fichier « UNIMARC Autorités », dans le **thésaurus par défaut** de PMB
   (Administration > Outils > Paramètres > Thésaurus). S'il est vide — un catalogue importé que la révision
   n'a pas encore rattaché n'exporte aucune autorité —, sauter cette étape.
2. **Administration > Imports > Exemplaires UNIMARC** (« Importer des notices et exemplaires ») — pas l'onglet
   voisin « Notices UNIMARC », qui importe les notices mais ignore les 995 sans le dire —, avec :
   - la fonction d'import **« Catégories RAMEAU »** (`func_cpt_rameau_first_level`) : elle garde les 606 en
     catégories. La fonction par défaut (`func_bdp`) les fond en une seule 610 (aucune catégorie) ;
   - **« Oui »** à « Générer les liens entre notices ? » (« Non » par défaut) : sans lui, PMB ne lit aucune zone
     de lien — mesuré : 0 bulletin, 0 article rattaché sur 15 ;
   - « Tenir compte des notices d'autorités » : **laisser « Non »** dans PMB 8.1.1.1. Le formulaire de cet onglet
     ne transmet pas l'origine qu'on y choisit (sa liste s'appelle `authorities_origin`, l'import lit
     `authorities_default_origin`) : avec « Oui », le $3 ne rejoint aucune fiche, et PMB écrit des liens vers
     des sources qui n'existent pas (tableau ci-dessous) ;
   - le prêteur (propriétaire), le statut et la localisation des exemplaires, choisis dans ce formulaire :
     PMB ne lit pas la 995 $a.

Mesuré, les autorités importées d'abord (autorites-h25.iso, puis notices-h25.iso : 64 notices à $3) :

| « Tenir compte des notices d'autorités » | responsabilités → auteurs | auteurs recréés | liens notice → fiche | dont vers une source absente |
|---|---|---|---|---|
| « Non » | 61 → 57 | 0 | 0 | 0 |
| « Oui », origine « AnarBib » choisie à l'écran (PMB 8.1.1.1 ne la reçoit pas) | 61 → 57 | 0 | 44 | 44 |
| « Oui », origine « AnarBib » reçue par PMB (l'outil du banc, ou un PMB corrigé) | 61 → 57 | 0 | 61 | 0 |

Ce que PMB en fait :

- PMB rapproche les auteurs par la forme du nom et les dates (700-702 $f ; pour une collectivité ou un congrès,
  aussi la subdivision, le lieu et le numéro) : deux homonymes sans dates, ou aux mêmes dates, n'en font
  qu'un ; une autre forme ou d'autres dates (une même personne avec et sans dates) en créent un second ;
- le $3 d'une responsabilité ne rejoint sa fiche que si l'origine arrive à l'import. Dans un PMB dont le
  formulaire est corrigé (une ligne de `admin/import/import_func.inc.php` :
  `origin::gen_combo_box("authorities", "authorities_default_origin")`), « Oui » et l'origine **AnarBib**
  rattachent chaque responsabilité à sa fiche, quelle que soit la forme du nom ;
- une vedette est rapprochée par son **libellé**, dans le thésaurus par défaut (le $3 d'une 606 n'est pas lu) :
  deux vedettes de même libellé deviennent une seule catégorie ;
- un exemplaire prend le type « indéterminé / indéterminé » et la section « indéterminé » (les $r uu et $q u
  de la 995) : PMB les retrouve par ces codes, ou les crée — le type avec une durée de prêt de 0 jour. PMB ne
  reçoit ni le type de document, ni la section, ni le code statistique d'origine : à reprendre dans PMB
  avant de prêter ;
- réimporter les autorités met toujours la fiche à jour (l'export n'écrit pas de date en 801 $c) ;
- PMB refuse un exemplaire posé sur une notice d'article.

## 4. Mesuré : un aller-retour complet (29/09/2026)

Les 64 notices des fixtures, importées dans AnarBib, publiées, exportées par l'écran (« UNIMARC — ISO 2709 »),
réimportées dans un PMB vidé de son jeu de test (`tests/pmb/banc/essai-reimport-pmb.sh`). Le thésaurus et la
table Dewey de PMB restent, comme dans une bibliothèque — vedettes et indices y sont rapprochés par leur
libellé —, ainsi que ses types de documents, sections, codes statistiques et localisations.

Réglages de la mesure :

- Administration > Imports > Exemplaires UNIMARC ;
- fonction d'import : func_cpt_rameau_first_level.inc.php (Catégories RAMEAU) ;
- « Générer les liens entre notices ? » : Oui ;
- « Tenir compte des notices d'autorités » : Non — aucune autorité n'est exportée pour des notices importées que la révision n'a pas encore rattachées : le fichier ne porte aucun $3 ;
- exemplaires : prêteur « BDP », statut « Document en bon état », localisation « Bibliothèque principale ».

| | PMB d'origine | après l'aller-retour |
|---|---|---|
| notices | 62 (44 monographies, 2 périodiques, 15 articles, 1 notice de bulletin) | 64 (44 monographies, 5 périodiques, 15 articles) |
| exemplaires · dont sur des bulletins | 46 · 2 | 46 · 0 |
| types d'exemplaire | 23 Livre, 13 indéterminé / indéterminé, 3 Oeuvre d'art, 2 CD audio, 2 Périodique, 1 Cartes et plans, 1 Cédéroms, 1 DVD | 46 indéterminé / indéterminé |
| sections d'exemplaire | 12 différentes | 46 indéterminé |
| codes statistiques d'exemplaire | 23 Adultes, 14 Indéterminé, 9 Jeunes | 46 Indéterminé |
| bulletins · dépouillements | 3 · 15 | 3 · 15 |
| responsabilités · dont sans fonction | 61 · 10 | 61 · 0 |
| auteurs employés | 57 | 57 |
| éditeurs employés | 36 | 36 |
| notices avec catégorie · liens de catégorie | 42 · 49 | 42 · 48 |
| langues de la notice · de l'original | 62 · 3 | 59 · 0 |
| collections employées · notices en collection | 6 · 8 | 8 · 10 |
| séries employées · notices en série | 2 · 2 | 0 · 0 |
| liens entre notices | 2 | 0 |

Les écarts :

- **trois notices reviennent en périodiques, sans lien vers leur titre** : les deux pseudo-notices par lesquelles PMB
  exporte les exemplaires d'un bulletin (d'où trois « Géo » ; leurs deux exemplaires quittent les bulletins) et
  la notice propre du bulletin 278 (un périodique « 278 ») ;
- **les exemplaires reviennent en nombre, pas en description** : type de document, section et code statistique
  ne passent pas (leurs libellés sont dans la 996 de PMB, qui reste dans l'enregistrement d'origine) ; PMB
  range les exemplaires en « indéterminé » ;
- **l'ordre du fichier compte** : le même export écrit dans l'ordre des identifiants, sans ranger les périodiques
  avant les articles, ne laisse que 7 articles rattachés à leur revue sur 15 (contre-essai du 29/09/2026 :
  52 monographies, 5 périodiques, 7 articles) — l'export range donc les périodiques d'abord ;
- **sans « Générer les liens entre notices ? »** (contre-essai du 29/09/2026) : 0 bulletin et 0 dépouillement,
  les articles entrent sans leur revue ;
- **deux catégories PMB distinctes de même libellé** (« Mammifères ») n'en font qu'une : un lien de moins ;
- **une langue par notice**, aucune hors des langues du catalogue (« fro »), pas de langue de l'original ;
- **les deux séries PMB reviennent en collections** (461 $t → 225) : l'ensemble « Chroniques de l'entraide
  ouvrière » pour le tome 1, et, pour le tome 2, son propre titre, que PMB avait rangé en série ; le lien
  tome ↔ ensemble (462/461 $0) et celui du bulletin 278 vers Géo ne sont pas refaits ;
- **le reste revient en nombre** (responsabilités, auteurs, éditeurs, bulletins, dépouillements, notices indexées),
  le bilan compte des lignes : les 10 responsabilités sans fonction reviennent avec une (570 ou 070), l'adresse
  web des auteurs (700 $N) ne revient pas — le détail, sous-zone par sous-zone, est au § 2.

## Limites connues

- Un fascicule importé n'est pas encore rattaché à son périodique (backlog H24) ; une « notice de bulletin »
  PMB revient en notice de périodique.
- Un article né dans AnarBib (sans 464 d'origine à réémettre) n'est rattaché par PMB que si sa 461 porte le
  titre de la revue et un numéro de volume ; sinon PMB en fait une monographie (lu dans `import_func.inc.php` ;
  observé sur le fichier de l'essai des autorités, dont les articles n'ont pas de 464 à réémettre).
- Réimporter dans un PMB qui détient déjà ces notices ne met rien à jour : PMB ne dédoublonne que sur l'ISBN,
  écarte une notice dont l'ISBN est déjà là et recrée celles qui n'en ont pas (mesuré le 26/09/2026,
  `tests/pmb/README.md`).
- Le type de document, la section, la localisation et le statut d'un exemplaire PMB (996) ne passent pas : au
  retour, PMB range l'exemplaire en type et section « indéterminé ».
- Un second éditeur (seconde 210), une sous-collection (225 $i) et l'ISSN de collection ne sont pas repris ; ils
  restent dans l'enregistrement d'origine (la 411 revient à la bibliothèque d'origine).
- Les liens entre notices de PMB (ensemble ↔ tome, 461/462 $0) ne sont pas refaits au retour.
- Une collectivité à subdivision ($a $b) revient en un seul $a.
- Aucune autorité n'est exportée pour une notice importée tant que la révision ne l'a pas rattachée.
