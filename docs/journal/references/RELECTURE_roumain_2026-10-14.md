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
