# Relecture du roumain — les choix à vérifier (14/10/2026)

Chantier « locale ro », lot 3 (backlog `E39`, REGISTRE `DOC-I18N-5`). La
traduction est **complète** — app (7 631 clés), courriels (709 gabarits et 152
textes des fonctions), `install.sh` (85 messages) — mais **pas encore relue**
par une personne roumanophone : la langue est servie (`?lang=ro`, préférence
d'un profil) et absente des sélecteurs (`listed: false`) jusqu'à cette
relecture (D5). Contact pressenti : Anarhiva (Cluj-Napoca).

Ordre de relecture proposé : inscription et connexion, Mon compte, catalogue
public, courriels, puis le reste.

## Conventions appliquées (décisions D2 à D4)

- Tutoiement partout ; les phrases adressées à une bibliothèque ou à un
  collectif entier sont au pluriel (« voi / vă »).
- Écriture épicène d'abord (« persoana care citește », « echipa de
  coordonare »), doublet à barre sinon (« cititor/cititoare »,
  « coordonator/coordonatoare »).
- ș ț à virgule souscrite (une garde CI refuse ş ţ et « dumneavoastră ») ;
  guillemets „…”.
- Pluriels ICU à trois formes (one / few / other, avec « de » à partir de 20).
  Les compteurs qui ne sont pas des pluriels ICU sont écrits « Libellé: {n} »
  (« Ciorne: {count} ») pour éviter l'accord en « de » — **à juger** : c'est
  plus sec qu'une phrase.

## Vocabulaire à valider

| Français | Roumain choisi | Question |
|---|---|---|
| camarade, compagnon·ne | tovarăș/tovarășă | Connotation de l'époque communiste ? « camarad/camaradă » serait l'autre choix. Les « bibliothèques compagnes » sont devenues « biblioteci prietene ». |
| notice | fișă | Usage des bibliothèques roumaines (« înregistrare bibliografică » ?) |
| numéro d'inventaire (tombo) | număr de inventar | — |
| prêt entre bibliothèques (PEB) | împrumut între biblioteci | La norme dit plutôt « împrumut interbibliotecar ». |
| prêteuse / emprunteuse (PEB) | bibliotecă furnizoare / solicitantă ; « care dă cu împrumut » / « care primește împrumutul » | Deux tournures coexistent. |
| Dewey / CDU | Dewey / CZU | Pas de sigle roumain pour la Dewey. |
| RGPD | GDPR | — |
| mettre au rebut | a casa, casare | — |
| récolement | inventariere | — |
| fusionner | a uni, unire / fuziune | Les deux apparaissent. |
| Rapprocher (bouton d'import) | Asociază | Harmonisé dans toute l'app. |
| endosser (une invitation) | a susține, susținere | — |
| carence | perioadă de așteptare | — |
| Lettre (de la fédération) | Buletin, Buletinul federației | — |
| Chartes (Communs) | Carte (pluriel de « cartă ») | Se confond avec « carte » (livre). |
| brève (gazette) | știre (scurtă), notă scurtă | Deux formes. |
| Avis (onglet) | Anunțuri | — |
| moissonnage OAI | recoltare | — |
| double authentification | autentificare în doi pași | — |
| SIGB | sistem integrat de bibliotecă | Pas de sigle. |
| Matériel gris | literatură gri | — |

## Points techniques

- Mots à taper pour confirmer : « ELIMINARE » (supprimer le compte),
  « GOLIRE » (vider l'historique) — sans diacritique, pour un clavier sans
  disposition roumaine.
- Double authentification : les libellés des menus d'Aegis et de KeePassXC
  sont repris de leurs propres traductions roumaines (KeePassXC affiche
  « Cheie secreta: » sans diacritique, et laisse « Set up TOTP… » et
  « Default settings (RFC 6238) » en anglais) ; FreeOTP+ n'a pas de roumain :
  ses libellés sont en anglais, et le texte le dit.
- Le guide d'accueil des coordinations renvoie, en roumain, vers la version
  anglaise (`/en/welcome/`) tant que la vitrine n'a pas de pages `/ro/` (lot 5).
- Les noms propres des collectifs, les sigles et les menus de PMB (en
  français) restent tels quels.

## Données en base (migration `20261014202251`)

Carte des bibliothèques (villes, pays, notes), sujets du thésaurus interne,
tâches proposées aux équipes, et le thésaurus de la FICEDL — ce dernier en
**proposition** à la source, affiché comme tel (`THES-FIC6`).

| Source | Roumain choisi | Question |
|---|---|---|
| Rroms, gitans, tziganes… (thésaurus, mot388) | Rromi, gitani, țigani… | La source énumère les trois noms ; « țigani » est souvent ressenti comme péjoratif. |
| bagne (mot39) | colonie penitenciară | « ocnă » écarté (mine de sel). |
| communautés et milieux libres (mot50) | comunități și colonii libertare | « medii libere » n'existe pas. |
| édition (mot103) | editare | « ediție » = l'édition d'un livre. |
| mutualisme et mutuellisme (mot204) | mutualism și mutualitate | Deux mots roumains distincts ? |
| nucléaire (mot212) | nuclear | Seul, pour couvrir énergie et armement. |
| salariat (mot255) | muncă salariată | « salariat » = la personne. |
| France : histoire : 1871 (La Commune) (mot338) | Franța: istorie: 1871 (Comuna) | — |
| Doukhobors (mot444) | Duhobori | Forme roumaine à confirmer. |
| anarcha-féminisme (sujets, notes) | Anarha-feminism, anarha-feminist | Ou « anarhofeminism » ? |
| Makhnovtchina (sujet) | Mahnovșcina | Translittération. |
| désherbage (tâches) | Epurarea colecției | Terme de bibliothéconomie roumain ? |
| infokiosque (notes de la carte) | infokiosk | « infoshop » ? |
| Vieille Taupe (glose) | Bătrâna Cârtiță | — |
| València, Mexico, Katmandou | Valencia, Ciudad de México, Kathmandu | Usage roumain des noms de villes. |

Forme des descripteurs : minuscules comme la source, deux-points collés
(« economie: șomaj »), le même mot de domaine partout (44 domaines vérifiés),
« (generalități) » pour « (généralités) ».

## Documents (lot 4, `cf64ee88`)

Onze documents servis dans Fédération → Communs, plus le guide d'accueil des
coordinations, le DPA et la confidentialité de la BLMF. Ordre de relecture
proposé : confidentialité de la BLMF, guide d'accueil, charte de langage
inclusif (section « Română (ro) »), puis le guide de gouvernance.

| Source | Roumain choisi | Question |
|---|---|---|
| sous-traitant ultérieur (DPA) | persoană împuternicită secundară | Le RGPD roumain dit « altă persoană împuternicită » ; « subîmputernicit » existe aussi. |
| SIGB (le logiciel) | SIGB (gouvernance), SIIB (DPA) | Une seule forme ? L'application dit « sistem integrat de bibliotecă ». |
| J+7, J-30 | Z+7, Z-30 | « Z » pour « zi » : lisible ? |
| « Je passe la main » (bouton cité) | „Îmi cedez rolul” | L'application dit „Părăsește coordonarea” : le guide français est en retard sur l'écran. |
| camarade (doublet) | „un tovarăș/o tovarășă pe care îl/o vei putea suna din nou” | Lourd : reformulation épicène ? |
| infokiosque, Vieille Taupe… | voir la partie « Données » | — |

Les documents français eux-mêmes ont deux retards, que la traduction a
suivis sans les corriger : ils disent encore « dix langues » à plusieurs
endroits (D6), et plusieurs boutons cités n'existent plus sous ce nom
(« Je passe la main », « Inviter dans l'équipe », « Compte actif (restreint) »,
les anciens libellés portugais de l'indexation).

## Vitrine (lot 5, anarbib/pages `997070f`)

Les 17 pages de `anarbib.org/ro/` (joignables, absentes du sélecteur des autres
langues). Ordre proposé : accueil `/ro/`, `/ro/aderare/`, `/ro/proiect/`,
`/ro/bun-venit/` (le guide d'accueil), puis le reste.

| Source | Roumain choisi | Question |
|---|---|---|
| bibliothèques marraines, marrainage | biblioteci-nașe, nășie | Image juste ? |
| SIGB | sistem integrat de bibliotecă (SIIB) | Cf. partie « Documents ». |
| Charte minimale (menu) | Carta minimă | — |
| Guide d'accueil des coordinations (pied de page) | Ghid de primire pentru echipele de coordonare | — |
| Créer un compte contributeur (bouton) | Creează un cont de contribuție | Le texte dit « cont de contribuitor/contribuitoare ». |
| anarchistes noir·es | persoanele anarhiste de culoare | Usage roumain ? |
| tracts | manifeste | — |
| Bibliothèques ayant ouvert leur catalogue : n | Biblioteci cu catalogul deschis: {n} | Forme « libellé: n » pour éviter l'accord en « de ». |

Les pages adressées à une bibliothèque (« Adhérer », « Pourquoi adhérer »,
l'encadré des candidates de « État du projet ») sont au « voi » ; le reste
tutoie.

## Recueils PDF et sous-titres (lot 6, `a67b3405`)

Bloc roumain en fin de chaque recueil : manuel complet (p. 902-987), manuel
lecteur·rice (p. 193-211), guide de gouvernance (p. 587-644) ; sous-titres des
deux tutoriels (fichiers à déposer sur Kolektiva).

| Source | Roumain choisi | Question |
|---|---|---|
| MARQUE POLITIQUE (encadré) | AMPRENTĂ POLITICĂ | « marcă » écarté (sens commercial). |
| ASTUCE / CONSEIL | PONT / SFAT | Deux étiquettes distinctes. |
| Manuel du·de la lecteur·rice | Manualul pentru cititori/cititoare | — |
| le lecteur (l'outil de lecture) | vizualizator | Pour ne pas confondre avec la personne. |
| compa / les compas | tovarășe/tovarășă, tovarășii/tovarășele | Cf. partie « Vocabulaire ». |

Écarts de la source française que la traduction a corrigés en suivant
l'écran : le mot à taper pour vider l'historique est EFFACER (et non
SUPPRIMER) → GOLIRE ; le libellé ancien ou au « vous » d'un bouton → la valeur
actuelle de ro.json. Corrigés le 15/10/2026 dans les onze langues des deux manuels
(94 phrases, PDF republiés, pages publiées reprises sauf celles touchées) :
la gazette s'appelle « Fractale » (et plus « Rizoma »), la visio des
assemblées est Framatalk (et plus « Jitsi hébergé par Autistici »), et le mot
à taper pour vider l'historique est celui de l'écran dans chaque langue.
