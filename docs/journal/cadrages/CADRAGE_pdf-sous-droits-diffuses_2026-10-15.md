# Cadrage — Les PDF sous droits déjà diffusés en ligne

> **Date** : 2026-10-15
> **Auteur** : Claude (assistant·e), pour la coordination
> **Session** : Cadrage : PDF sous droits déjà diffusés en ligne
> **Statut** : trois décisions de la coordination (15/10) + une question ouverte (§4).
> Les tâches techniques du §8 ne sont **pas** encore versées au backlog : elles le
> seront à leur validation (CLAUDE.md, règles 11-12).
> **Doctrine de référence** : [`DECISION_profil_numerisation_2026-08-20.md`](../arbitrages/DECISION_profil_numerisation_2026-08-20.md),
> § « La troisième voie : le numérique suit le physique ».

---

## 0. En une page

Beaucoup de livres sous droits que détiennent les bibliothèques du réseau
circulent déjà en PDF ailleurs sur internet. La doctrine du 20/08 permet de les
verser **en restreint** (lecture réservée aux membres d'une bibliothèque
détentrice). Elle ne dit pas *comment* les trouver, *lesquels* accepter, ni ce
qu'on fait du lien vers la copie d'origine. Ce cadrage le dit.

| # | Décision (coordination, 15/10) | Conséquence |
|---|---|---|
| **D1** | On ne valide **que les fichiers de la même édition** que l'exemplaire détenu. | Un PDF d'une autre édition est rejeté, mais le rejet est **tracé** (§5). |
| **D2** | Typologie des sources en trois cas (§3.2). | Le statut de droits et l'accès découlent du cas. |
| **D3** | Quand on peut lire la copie restreinte, on **affiche aussi le lien** vers le fichier trouvé ailleurs. | Revient sur le masquage posé le 20/08 dans `read-digital-asset` (§4). |

Ce qui reste ouvert : la forme exacte de D3 (§4), et la ratification de la
« troisième voie » par l'assemblée générale (§9), toujours en attente.

---

## 1. D'où l'on part

Le 14/10, une recherche de PDF « par édition exacte » a été menée sur trois
corpus du catalogue :

- **Daniel Guérin** (†1988, sous droits) — 17 notices, **aucune** édition exacte
  téléchargeable. Les deux éditions exactes présentes sur Archive.org
  (*100 Years of Labor*, Ink Links 1979 ; *Rosa Luxemburg et la spontanéité
  révolutionnaire*, Flammarion 1971) n'y sont qu'en **prêt contrôlé**. Les PDF
  librement téléchargeables sont **d'autres éditions** : *El anarquismo* chez
  Anarres (Buenos Aires, ~2003) au lieu d'Altamira/Nordan 1992 ; *Para un
  marxismo libertario* chez Proyección (1973) au lieu de Júcar (1979) ; *La lucha
  de clases…* chez RyR (2011) au lieu d'Alianza (1974).
- **Jean Grave** (†1939, domaine public) — 4 notices (Lisbonne 1909-1914,
  Valence 1920), aucun fac-similé trouvé ; le seul PDF de *La sociedad
  moribunda* est un texte **ressaisi**, sans éditeur ni traducteur.
- **Éditions anciennes en langue originale** — succès : les deux Reclus Harper
  (ressources 77 et 78), puis le lot de la session sur les éditions anciennes
  (cinq éditions versées, deux rejetées).

**Leçon** : la méthode marche quand de grands programmes de numérisation sont
passés (domaine public). Pour les œuvres sous droits, ce qui circule est
majoritairement une *autre* édition, mise en ligne par des militant·es ou des
inconnu·es. D1 assume que, dans ce cas, on dépose peu.

Sources fermées aux automates (Cloudflare) : Gallica, HathiTrust, Biblioteca
Digital Hispánica. **On ne contourne pas** ces protections ; ces sources se
consultent à la main. Google Books refuse les requêtes anonymes (quota).

## 2. État des lieux mesuré (production, 15/10)

| Mesure | Valeur |
|---|---|
| Notices au catalogue | 2 564 |
| Bucket `anarbib-pdf-public` | 54 objets, 0,68 Go |
| Bucket `pdf-restrito` | 8 objets, 0,09 Go |
| Ressources actives `publico` | 31 (27 `dominio_publico`, 4 `cessao_autoral`) |
| Ressources actives `conta_ativa` | 7 (6 `sob_direitos`, 1 **sans statut**) |
| Ressources restreintes **avec** `source_url` | 7 sur 7 |

Les sept URL sources des ressources restreintes, par nature :

| Ressource | Hôte | Nature du lien |
|---|---|---|
| 62 | lemaquis.noblogs.org | page |
| 66 | we.riseup.net (`/assets/…`) | **fichier** |
| 70 | dokumen.pub | page de téléchargement |
| 72 | pdfcoffee.com (`/qdownload/…`) | **fichier** |
| 73 | anarquista.net (`/wp-content/uploads/…pdf`) | **fichier** |
| 74 | archive.org (`dn720005.ca.archive.org/0/items/…`) | **fichier** |
| 76 | colectivolibertarioevora (`/wp-content/uploads/…`) | **fichier** |

**La ressource 62** (`bibliographic_match_validated = false`, `rights_status`
vide) est **non conforme à D1** : à revoir (§8, T7).

**Le filigrane n'est pas dans le fichier.** Le lecteur PDF pose une couche CSS
au nom de la personne qui lit ([`ReaderPage.jsx`](../../../src/pages/public/ReaderPage.jsx),
`.ab-reader-watermark`). L'URL signée (15 min) livre le PDF **brut**. Le
commentaire de `read-digital-asset` qui justifie le masquage (« le PDF servi est
filigrané au nom du lecteur, l'original ne l'est pas ») surestime donc la
protection : ce que le masquage protège réellement, c'est la **révocabilité** et
l'**attribution** (URL expirante, servie à un compte identifié), pas un filigrane
incrusté.

## 3. Les décisions

### 3.1 D1 — La même édition, et elle seule

Un fichier n'est validé que si sa **page de titre** (et, quand elle existe,
l'achevé d'imprimer ou le copyright) correspond à la notice : éditeur, lieu,
année, traduction. La vérification se fait sur le PDF **téléchargé**, jamais
sur la seule fiche de la source (les métadonnées d'Archive.org se trompent
d'année ou de langue).

*Ce que ça exclut* : le texte voisin (réédition, autre traduction, texte
ressaisi). Le numérique suit **l'exemplaire** ; un texte voisin n'est pas
l'exemplaire.

*Ce que ça n'exclut pas* : garder la **trace** du rejet. Un PDF d'une autre
édition dit qu'une autre édition existe et circule — information utile aux
acquisitions, et qui évite de refaire la recherche (§5).

*Corollaire* : `bibliographic_match_validated` vaut toujours `true` sur une
ressource active. La colonne reste (elle sert la file de candidats), mais une
ressource à `false` n'a plus vocation à être active.

### 3.2 D2 — Trois cas de source

| Cas | Exemple | `rights_status` | Accès | `rights_justification` attendue |
|---|---|---|---|---|
| **Diffusion autorisée par l'éditeur** | Anarres, *El anarquismo* : « La reproducción de este libro […] son permitidos y alentados por los editores. » | `licenca_livre` | **public** | La mention **citée textuellement**, avec la page où elle figure. |
| **Édition militante anti-copyright** | « Copyleft », « reproduction libre », « anti-copyright » imprimé dans l'ouvrage | `licenca_livre` | **public** | Idem : citation et page. Une mention sur le *site* qui héberge ne suffit pas, il faut celle de l'*édition*. |
| **Mise en ligne de statut inconnu** | dépôt par un tiers, sans mention | `sob_direitos` | **restreint** (bibliothèque détentrice) | Ce qui fonde le versement : exemplaire détenu, cote (règle du 20/08). |

Le doute tranche vers le cas 3. La responsabilité reste celle de la bibliothèque
qui verse (doctrine du 20/08) : le réseau fournit l'outil, pas la couverture.

### 3.3 D3 — Le lien vers la copie trouvée ailleurs

Pour qui peut lire la copie restreinte, la fiche et le lecteur affichent aussi
le lien vers la copie d'origine (« aussi en ligne : *source* »). Deux raisons :
les liens externes disparaissent, notre copie restreinte est la conservation ;
et renvoyer vers la source rend visible le travail de qui a numérisé.

Aujourd'hui `read-digital-asset` **masque** `source_url` pour toute ressource
restreinte servie depuis le stockage (`supabase/functions/read-digital-asset/index.ts`,
« Provenance : ne jamais exposer l'URL source d'un document RESTREINT »,
incident de la ressource 61 du 20/08). D3 revient sur ce masquage. Le masquage
doit rester **côté serveur** : c'est la fonction qui décide de renvoyer le lien,
pas l'écran qui le cache.

## 4. Question ouverte — la forme de D3

Le §2 montre que **cinq liens sur sept sont des fichiers** en téléchargement
direct. Deux options :

- **(a) Le lien, toujours.** Simple. Mais pour un fichier direct, c'est remettre
  une copie permanente, non révocable et non attribuée — ce que l'URL signée
  évite.
- **(b) Le lien vers une page, pas vers un fichier.** On enregistre *deux*
  informations : l'URL du fichier (provenance, jamais exposée en restreint) et
  l'URL de la **page** qui le présente (fiche Archive.org `…/details/…`, article
  du blog, page du site). Seule la page est montrée. Pour Archive.org, la page se
  déduit du fichier ; pour les autres, elle se saisit à la validation.

**Recommandation : (b).** Elle tient D3 (le lien est là, la source est créditée)
sans transformer AnarBib en distributeur de liens de téléchargement, et elle
évite à une personne qui lit d'être envoyée, sans le savoir, vers un fichier
hébergé sans autorisation. À trancher par la coordination.

## 5. La méthode : une file de candidats

Pas de dépôt direct. Une **file de candidats** que la coordination de la
bibliothèque détentrice valide, PDF ouvert.

1. **Recherche** — par notice : Archive.org (API `advancedsearch` + `metadata`),
   puis sources consultables sans contourner de protection. Le prêt contrôlé
   d'Archive.org est **exclu** (fichier `private`).
2. **Téléchargement et identification** — le candidat est téléchargé ; la page
   de titre et le copyright sont extraits (`pdftotext` sur les premières pages)
   et l'**édition réelle** est notée (éditeur, lieu, année, traduction, ISBN).
3. **Proposition** — l'outil propose : *même édition / autre édition / texte
   ressaisi*, et un cas D2.
4. **Validation humaine** — la coordination de la bibliothèque détentrice valide
   ou rejette. Un rejet garde son motif et l'édition trouvée.
5. **Versement** — sans manipulation de clé (§8, T4).
6. **Contrôles** — lecture sous `anon` (public) ou sous un compte membre
   (restreint) ; tests T1/T2 de `documents_numeriques_tests.sql`.

**Où vit la file.** Une table dédiée dans le schéma `ingest` (fermé par RLS), et
non `book_draft_digital_resources` : le brouillon de ressource exige que le
fichier existe déjà dans le stockage (`private.fn_objet_stocke_existe`) et vit
attaché à un brouillon de notice, alors qu'un candidat existe *avant* tout
fichier et *sans* brouillon. Champs minimaux : notice, URL fichier, URL page,
édition constatée, verdict (D1), cas (D2), empreinte SHA-256, motif de rejet,
qui a validé et quand.

## 6. Volumétrie

La décision du 20/08 chiffrait le fonds intégral numérisé à **~75-135 Go**.
Aujourd'hui : **0,77 Go**. La file de candidats ne change pas ce plafond ; elle
change le rythme. À suivre avec I21 (hébergement) : un lot de 100 PDF
d'Archive.org pèse 3 à 5 Go (les deux Reclus : 84 Mo).

## 7. Garde-fous

- **Restreint sans détenteur** (ouvert le 20/08) : retirer le dernier exemplaire
  rend un PDF restreint illisible pour tout le monde, sans alerte. La file de
  candidats en multiplie les cas : à rendre **observable** avant le premier lot.
- **Pas de contournement** : ni Cloudflare, ni CAPTCHA, ni prêt contrôlé.
- **Les métadonnées de la source ne prouvent rien** : seule la page de titre du
  PDF téléchargé fait foi (D1).
- **La clé `service_role` legacy est rejetée** par l'API Storage depuis le
  passage aux nouvelles clés : tout outil hors CI doit utiliser `sb_secret_…`
  dans l'en-tête `apikey` (constaté le 14/10).

## 8. Tâches techniques

| # | Tâche | Notes |
|---|---|---|
| T1 | Table `ingest.digital_candidates` + RLS (lecture/écriture : coordination de la bibliothèque détentrice, administration du réseau) | Migration au gabarit `_TEMPLATE.sql`. |
| T2 | Outil de recherche + identification (script `scripts/`, lancé à la main) | Archive.org d'abord ; écrit les candidats dans T1. |
| T3 | Écran de validation (page Importations ou catalogage) | PDF ouvert, verdict D1, cas D2, justification. |
| T4 | Versement sans clé manipulée : fonction Edge appelée avec le JWT de la coordination, qui télécharge l'URL validée **côté serveur**, vérifie l'empreinte SHA-256 validée, verse dans le bon bucket et crée la ressource | Supprime l'étape manuelle de la clé (§7). |
| T5 | D3 selon l'option retenue au §4 : `read-digital-asset` renvoie le lien quand l'accès est accordé ; (b) : nouvelle colonne pour l'URL de la page | Garder le contrôle côté serveur ; i18n 10 locales pour « aussi en ligne ». |
| T6 | Corriger le commentaire de `read-digital-asset` sur le filigrane (§2) | Doit dire ce que le masquage protège vraiment. |
| T7 | Revue des 7 ressources restreintes : ressource 62 (D1), et classement page/fichier des URL sources | Préalable à T5. |
| T8 | Garde-fou « restreint sans détenteur » observable | Item ouvert de la décision du 20/08. |

## 9. Pour l'assemblée générale

La « troisième voie » (le numérique suit le physique) est **appliquée mais non
ratifiée**. Ce cadrage en étend l'usage : passer de « verser ce qu'on a
numérisé soi-même » à « aller chercher ce qui circule déjà ». Questions à porter :

1. Le réseau assume-t-il de **rechercher activement** les PDF sous droits des
   livres qu'il détient, pour les verser en restreint ?
2. Le réseau assume-t-il d'**afficher un lien** vers une copie hébergée ailleurs
   sans autorisation connue (D3), et sous quelle forme (§4) ?
3. Qui valide : chaque bibliothèque pour son fonds (doctrine actuelle), ou un
   groupe du réseau pour les sources récurrentes ?

---

*Matériau : session du 14/10 (Guérin, Grave, Reclus) ; mesures en production du
15/10 ; `supabase/functions/read-digital-asset/index.ts` ;
`src/pages/public/ReaderPage.jsx` ; décision du 20/08.*
