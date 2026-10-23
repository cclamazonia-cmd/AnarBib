# D25 — les fichiers Word/ODT d'Anarchief : inventaire et cas de droits proposés (23/10/2026)

> Décision de Xavier du 23/10/2026 : **admettre Word/ODT**, en **téléchargement seulement** (pas de
> lecture en ligne), à la **portée de la lettre du lot** comme les PDF, versés par la file NUMDIF
> (empreinte SHA-256). Ce document fixe la liste et propose le cas de chaque fichier selon NUMDIF-2
> amendé (domaine public = auteur·rice ET traducteur·rice morts depuis plus de 70 ans ; le doute va à
> *(c)*, restreint).

## Comment la liste a été retrouvée

Le compte du 15/10 (« 20 fichiers Word/ODT écartés, plus 4 ODT des pages en doublon ») n'avait pas été
gardé avec ses noms. La liste est relue dans le champ `fichiers` des copies d'import des notices
(`marc_json → ingest → raw_payload`) : **28 notices** citent un fichier `.doc`, `.docx` ou `.odt` du wiki
(le wiki en compte 117 en tout, la plupart attachés à des pages qui ne sont pas des notices).

## Groupe 1 — 8 notices qui ont déjà un PDF du même texte, sous la lettre de leur lot

| Notice | Auteur | Fichier | Le PDF déjà versé | Cas proposé |
|---|---|---|---|---|
| ANARCHIEF-99 | Sheehan, S. M. | *Anarchisme, een reisgids – bewerkt* (.doc) | public, lot « Auteurs met minder dan 3 bestanden » (A + B) | **(a)** comme le PDF |
| ANARCHIEF-372 | Autonome Antifa Gent | *De laarzen van de leeuw* (MS Word, .doc) | public, même lot | **(a)** |
| ANARCHIEF-91 | Malatesta (†1932) | *De anarchie…* (.odt) | public, même lot | **(a)** |
| ANARCHIEF-103 | Mercier Vega | *Affiniteitsgroepen – bewerkt* (.doc) | public, même lot | **(a)** |
| ANARCHIEF-95 | PP | *Anarchie is orde* (.doc) | public, même lot | **(a)** |
| ANARCHIEF-640 | Pannekoek | *Au sujet du Parti Communiste* (.doc) | public, lot « Auteur — Pannekoek » | **(a)** |
| ANARCHIEF-113 | Giele | *Arbeiderszelfbestuur* (.doc) | public, lot des petits auteurs | **(a)** |
| ANARCHIEF-3039 | De Ligt (†1938) | *Soldiers and workers, strike* (.odt, **traduction anglaise**) | public (l'original néerlandais) | **(c)** : traducteur·rice inconnu·e |

## Groupe 2 — 3 originaux d'auteurs morts depuis plus de 70 ans

| Notice | Auteur | Fichier | Cas proposé |
|---|---|---|---|
| ANARCHIEF-2934 | Proudhon (†1865) | *Qu'est-ce que la propriété* (.doc, original français) | **(d)** public |
| ANARCHIEF-591 | Kropotkine (†1921) | *La conquête du pain* (.odt, édition française) | **(d)** public |
| ANARCHIEF-4501 | De Ligt (†1938) | *Vrede als daad* (.odt, original néerlandais) | **(d)** public |

## Groupe 3 — 7 traductions dont le·la traducteur·rice est inconnu·e

| Notice | Auteur | Fichier | Cas proposé |
|---|---|---|---|
| ANARCHIEF-1113 | Gramsci (†1937) | *Fordisme, fascisme en passieve revolutie* (.doc, néerlandais) | **(c)** |
| ANARCHIEF-579 | Goldman (†1940) | *Trotsky proteste trop…* (.odt, français) | **(c)** |
| ANARCHIEF-617 | Rühle (†1943) | *Fascisme brun, fascisme rouge* (.odt, français) | **(c)** |
| ANARCHIEF-582 | Gorter (†1927) | *Die Klassenkampf* (.odt, allemand) | **(c)** |
| ANARCHIEF-570, 572, 574 | Figner (†1942) | *Nacht over Rusland* 1-3 (.odt, néerlandais ; « beperkt » au wiki) | **(c)** |

## Groupe 4 — 10 textes d'auteur·rices récent·es

| Notice | Auteur | Fichier | Cas proposé |
|---|---|---|---|
| ANARCHIEF-4158 | PP | *Reinventing anarchy again and again* (.docx) | **(a)** si le lot des petits auteurs (A + B) vaut pour PP, comme son PDF du groupe 1 ; sinon **(c)** |
| ANARCHIEF-3720 | PP | *Lecture sur le fascisme, Liège 2019* (.docx) | idem |
| ANARCHIEF-1233 | Constandse, Anton | *Michael Bakunin* (.odt) | **(c)** : lettre « C » de J/M (« wél copyright ») |
| ANARCHIEF-4678 | Campion (†1992) | *Le drapeau noir, l'équerre et le compas* (.docx) | **(c)** |
| ANARCHIEF-1020 | Mora, Joao | *Waarom anarchisten niet stemmen* (.odt) | **(c)** sauf lettre de J/M |
| ANARCHIEF-4680 | Colstee, Vervest | *Vrouwen in het leger…* (.odt) | **(c)** sauf lettre de J/M |
| ANARCHIEF-2920 | Buelinckx | *Proudhon's influence in Belgium* (.docx) | **(c)** sauf lettre de J/M |
| ANARCHIEF-2928 | Liesegang | *Landauer und die Räterepublik* (.doc) | **(c)** sauf lettre de J/M |
| ANARCHIEF-2926 | Fürth | *Gustav Landauer* (.doc) | **(c)** sauf lettre de J/M |
| ANARCHIEF-645 | V.A. | *Radikal – 20 Jahre radikal* (.odt) | **(c)** sauf lettre de J/M |

## Ce que demande l'outil (chantier)

Un type de ressource « document » (Word/ODT), des formats admis dans les seaux (ou deux seaux à part),
le versement par la file NUMDIF avec contrôle du type réel (signature ZIP pour .docx/.odt, OLE pour
.doc), l'empreinte et la taille, puis un bouton « Télécharger » dans la notice, sans lecture en ligne.

## Décisions de Xavier (23/10/2026, questionnaire)

- **Groupes 1 et 2 : comme proposé.** Sept fichiers en *(a)* publics (leur PDF l'est déjà, même lot), la
  traduction anglaise de De Ligt en *(c)*, Proudhon, Kropotkine et *Vrede als daad* en *(d)* publics.
- **Groupes 3 et 4 : *(c)*, sauf les deux textes de PP**, en *(a)* comme son PDF du lot des petits
  auteurs ; une question à J/M sur les lettres qui manquent (ci-dessous, à envoyer par Xavier).

Bilan : **12 fichiers publics, 16 restreints.**

## Mise en œuvre (23/10/2026)

- **L'outil** (`20261023130916_d25_word_et_odt_admis_en_telechargement`, REGISTRE `NUMDIF-7`) :
  les deux seaux de la file admettent .doc, .docx et .odt ; type de ressource `documento`, usage
  `telechargement` (notices et brouillons) ; le versement reconnaît un document à l'extension du
  fichier versé (jamais principal, libellé « (arquivo de texto) ») ; le réalignement garde le type ;
  le bouton « Lire » d'une notice ne désigne jamais un document — sur les 20 notices qui n'ont qu'un
  lien vers le wiki, ce lien n'est pas principal, et la ressource la plus récente l'aurait emporté ;
  une porte publique `api.book_documents_v1` liste les documents sur la page de la notice
  (« Fichiers à télécharger »), le restreint signalé « réservé ».
- **La fonction Edge de versement** lit le format au nom du fichier et vérifie la signature du
  contenu (`format.ts`) ; **la lecture** (`read-digital-asset`) signe l'URL en téléchargement, sous
  le nom du fichier, et le lecteur affiche un bouton « Télécharger ».
- **Les 28 candidats** (`20261023133121_d25_les_28_fichiers_word_odt_d_anarchief_valides`) entrent
  validés, avec le SHA-1 et la taille de l'API MediaWiki du wiki ; le versement se fait depuis la
  file, avec la session de l'administration du réseau.

## Question à J/M — brouillon, à envoyer par Xavier (rien n'est envoyé)

> Bonjour J/M,
>
> AnarBib accepte désormais les fichiers Word et ODT d'Anarchief, en téléchargement. Pour 15 d'entre eux,
> nous n'avons pas de lettre de droits dans ta feuille du 15/10 ; nous les versons donc en accès
> restreint, par précaution :
>
> - des traductions dont nous ne connaissons pas le traducteur : Gramsci (*Fordisme, fascisme en passieve
>   revolutie*), Goldman (*Trotsky proteste trop…*), Rühle (*Fascisme brun, fascisme rouge*), Gorter
>   (*Die Klassenkampf*), Figner (*Nacht over Rusland*, trois parties), De Ligt (*Soldiers and workers,
>   strike*) ;
> - des textes récents : Léo Campion, Joao Mora, Ina Colstee et
>   Pietje Vervest, Erik Buelinckx, Torsten Liesegang, René Fürth, et *Radikal – 20 Jahre radikal*.
>
> Si tu connais les traducteur·rices, ou si certains de ces textes peuvent être diffusés librement (lettre
> A ou B), nous les rendrons publics.
>
> Merci,
> Xavier

